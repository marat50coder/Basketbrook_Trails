import 'dart:async';
import 'dart:io';

import 'config/trail_gate_config.dart';
import 'core/gate_models.dart';
import 'infra/gate_exchange.dart';
import 'infra/launch_tap_reader.dart';
import 'infra/push_relay.dart';
import 'infra/reach_probe.dart';
import 'infra/trail_agent.dart';
import 'infra/trail_attribution.dart';
import 'infra/trail_vault.dart';

/// Progress checkpoint values reported to the splash bar. Keeping them
/// centralised makes the flow easier to tweak per phase without threading
/// magic numbers through the branch code.
class _Milestone {
  static const double lifted = 0.14;
  static const double warmedUp = 0.31;
  static const double reachable = 0.51;
  static const double signalsIn = 0.74;
  static const double returningRun = 0.58;
  static const double returningNative = 0.62;
  static const double done = 1.0;
}

class TrailCoordinator {
  TrailCoordinator({
    required this.vault,
    required this.probe,
    required this.attribution,
    required this.exchange,
    required this.notifications,
    required this.agent,
    required this.runtimeEnabled,
  });

  final TrailVault vault;
  final ReachProbe probe;
  final TrailAttribution attribution;
  final GateExchange exchange;
  final PushRelay notifications;
  final TrailAgent agent;
  final bool runtimeEnabled;

  bool get enabled => runtimeEnabled && TrailGateConfig.grayCredentialsReady;

  Future<GateStop>? _inflight;

  /// Fire-and-forget warm-up so AppsFlyer / ATT initialise while the app is
  /// still building its first frame. When [decide] runs later, the install
  /// callback has usually already arrived.
  void warmUp() {
    if (!enabled) return;
    unawaited(attribution.start());
  }

  /// De-duplicates only *concurrent* calls (BootGate can build twice at
  /// startup). Cache clears once the pipeline finishes so a later Retry
  /// from the offline screen re-runs it end-to-end.
  Future<GateStop> decide({
    required void Function(double value) onProgress,
  }) {
    final existing = _inflight;
    if (existing != null) return existing;
    final started = _runPipeline(onProgress);
    _inflight = started;
    started.whenComplete(() => _inflight = null);
    return started;
  }

  Future<GateStop> _runPipeline(void Function(double) onProgress) async {
    if (!enabled) {
      _log('gate disabled runtime=$runtimeEnabled '
          'creds=${TrailGateConfig.grayCredentialsReady}');
      onProgress(_Milestone.done);
      return const NativeStop();
    }

    _log('decide start route=${vault.route}');
    notifications.onTokenChanged = _refreshForToken;

    final coldRoute = await LaunchTapReader.consume();
    if (coldRoute != null) {
      await vault.saveRoute(TrailRoute.portal);
      await vault.consumePushUrl();
      unawaited(_backgroundDispatch());
      onProgress(_Milestone.done);
      return PortalStop(coldRoute, coldLaunch: true);
    }

    onProgress(_Milestone.lifted);
    final route = vault.route;
    switch (route) {
      case TrailRoute.undecided:
        return _resolveFresh(onProgress);
      case TrailRoute.portal:
        return _resolveReturningPortal(onProgress);
      case TrailRoute.native:
        return _resolveReturningNative(onProgress);
    }
  }

  Future<GateStop> _resolveFresh(void Function(double) progress) async {
    if (!await probe.hasInterface()) {
      return const OfflineStop(returnToNative: false);
    }
    progress(_Milestone.warmedUp);
    // Parallelise APNs+FCM handshake and AppsFlyer/ATT init — a sequential
    // start added ~3–5 s to the fresh-install path which pushed AppsFlyer's
    // conversion callback past our awaitSignals timeout.
    await _bootWarmup();
    if (!await probe.canReachNetwork()) {
      return const OfflineStop(returnToNative: false);
    }
    progress(_Milestone.reachable);
    await attribution.awaitSignals();
    progress(_Milestone.signalsIn);
    final reply = await _requestConfig();
    progress(_Milestone.done);

    if (reply.hasDestination) {
      await vault.saveRoute(TrailRoute.portal);
      return PortalStop(reply.url!);
    }
    // Only lock the user to the native route when we ACTUALLY talked to
    // AppsFlyer. A 404 caused by an empty attribution body (SDK didn't
    // deliver in time) must leave route=undecided so the next launch
    // re-runs the fresh path.
    if (attribution.hasInstallData) {
      await vault.saveRoute(TrailRoute.native);
    }
    return const NativeStop();
  }

  Future<GateStop> _resolveReturningPortal(
    void Function(double) progress,
  ) async {
    if (!await probe.hasInterface()) {
      return const OfflineStop(returnToNative: false);
    }
    final queued = await vault.consumePushUrl();
    if (queued != null && queued.isNotEmpty) {
      progress(_Milestone.done);
      return PortalStop(queued);
    }
    final cached = await vault.savedUrl();
    if (cached != null && !vault.cachedUrlExpired) {
      progress(_Milestone.done);
      return PortalStop(cached);
    }

    await _bootWarmup();
    if (!await probe.canReachNetwork()) {
      return const OfflineStop(returnToNative: false);
    }
    progress(_Milestone.returningRun);
    await attribution.awaitSignals(installTimeout: const Duration(seconds: 5));
    final reply = await _requestConfig();
    progress(_Milestone.done);
    if (reply.hasDestination) return PortalStop(reply.url!);
    if (cached != null) return PortalStop(cached);
    return const OfflineStop(returnToNative: false);
  }

  Future<GateStop> _resolveReturningNative(
    void Function(double) progress,
  ) async {
    if (!await probe.hasInterface()) {
      progress(_Milestone.done);
      return const NativeStop();
    }
    await _bootWarmup();
    if (!await probe.canReachNetwork()) {
      progress(_Milestone.done);
      return const NativeStop();
    }
    progress(_Milestone.returningNative);
    await attribution.awaitSignals();
    final reply = await _requestConfig();
    progress(_Milestone.done);
    if (!reply.hasDestination) return const NativeStop();
    await vault.saveRoute(TrailRoute.portal);
    return PortalStop(reply.url!);
  }

  Future<void> _bootWarmup() async {
    try {
      await Future.wait<void>(<Future<void>>[
        notifications.boot(),
        attribution.start(),
      ]);
    } catch (_) {}
  }

  Future<GateReply> _requestConfig({String? token}) {
    return attribution
        .compose(
      locale: Platform.localeName.replaceAll('-', '_'),
      pushToken: token ?? notifications.token,
    )
        .then(exchange.request);
  }

  Future<void> _backgroundDispatch() async {
    try {
      await Future.wait<void>(<Future<void>>[
        notifications.boot(),
        attribution.awaitSignals(),
      ]);
      await _requestConfig();
    } catch (_) {}
  }

  Future<void> _refreshForToken(String token) async {
    try {
      await _requestConfig(token: token);
    } catch (_) {}
  }

  void _log(String message) {
    assert(() {
      // ignore: avoid_print
      print('[BB.TRAIL] $message');
      return true;
    }());
  }
}
