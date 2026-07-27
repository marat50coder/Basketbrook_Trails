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

  Future<GateStop>? _decideFuture;

  /// Fires when AppsFlyer delivered real conversion data *after* the initial
  /// gate decision already committed to native (fresh iOS installs can take
  /// 10–15 s to hand back the callback). Consumer navigates to the portal.
  void Function(PortalStop stop)? onLatePortal;
  bool _initialDecisionSettled = false;

  /// Fire-and-forget warm-up so AppsFlyer / ATT initialise while the app is
  /// still building its first frame. When `decide()` runs later, the install
  /// callback has usually already arrived.
  void warmUp() {
    if (!enabled) return;
    attribution.onLateInstall = _handleLateInstall;
    unawaited(attribution.start());
  }

  /// De-duplicates only *concurrent* calls (the boot screen can build twice at
  /// startup). The cache clears once the pipeline finishes, so a later Retry
  /// from the offline screen re-runs the whole pipeline instead of replaying a
  /// cached OfflineStop.
  Future<GateStop> decide({
    required void Function(double value) onProgress,
  }) =>
      _decideFuture ??= _decide(onProgress: onProgress)
          .whenComplete(() => _decideFuture = null);

  Future<GateStop> _decide({
    required void Function(double value) onProgress,
  }) async {
    if (!enabled) {
      assert(() {
        // ignore: avoid_print
        print(
          '[BB.GATE] gate disabled '
          'runtime=$runtimeEnabled creds=${TrailGateConfig.grayCredentialsReady}',
        );
        return true;
      }());
      onProgress(1);
      return const NativeStop();
    }

    assert(() {
      // ignore: avoid_print
      print('[BB.GATE] decide start route=${vault.route}');
      return true;
    }());

    notifications.onTokenChanged = _refreshForToken;
    attribution.onLateInstall = _handleLateInstall;
    final coldRoute = await LaunchTapReader.consume();
    if (coldRoute != null) {
      await vault.saveRoute(TrailRoute.portal);
      await vault.consumePushUrl();
      unawaited(_backgroundDispatch());
      onProgress(1);
      return PortalStop(coldRoute, coldLaunch: true);
    }

    onProgress(0.12);
    return switch (vault.route) {
      TrailRoute.undecided => _firstDecision(onProgress),
      TrailRoute.portal => _returningPortal(onProgress),
      TrailRoute.native => _returningNative(onProgress),
    };
  }

  Future<GateStop> _firstDecision(void Function(double) progress) async {
    if (!await probe.hasInterface()) {
      return const OfflineStop(returnToNative: false);
    }
    progress(0.28);
    // Parallelise APNs+FCM handshake and AppsFlyer/ATT init — sequential order
    // used to add ~3–5 s to the fresh-install path, which pushed the AppsFlyer
    // conversion callback past our awaitSignals timeout.
    try {
      await Future.wait<void>(<Future<void>>[
        notifications.boot(),
        attribution.start(),
      ]);
    } catch (_) {}
    if (!await probe.canReachNetwork()) {
      return const OfflineStop(returnToNative: false);
    }
    progress(0.48);
    await attribution.awaitSignals();
    progress(0.72);
    final reply = await _requestConfig();
    progress(1);
    _initialDecisionSettled = true;
    attribution.markInitialResolutionSent();
    if (reply.hasDestination) {
      await vault.saveRoute(TrailRoute.portal);
      return PortalStop(reply.url!);
    }
    // Only lock the user to the native route when we ACTUALLY talked to
    // AppsFlyer. A 404 caused by an empty attribution body (SDK didn't deliver
    // in time) must leave route=undecided so the next launch re-runs the first
    // decision path instead of the returning-native path.
    if (attribution.hasInstallData) {
      await vault.saveRoute(TrailRoute.native);
    }
    return const NativeStop();
  }

  Future<GateStop> _returningPortal(void Function(double) progress) async {
    if (!await probe.hasInterface()) {
      return const OfflineStop(returnToNative: false);
    }
    final pending = await vault.consumePushUrl();
    if (pending != null && pending.isNotEmpty) {
      progress(1);
      return PortalStop(pending);
    }
    final cached = await vault.savedUrl();
    if (cached != null && !vault.cachedUrlExpired) {
      progress(1);
      return PortalStop(cached);
    }

    await Future.wait<void>(<Future<void>>[
      notifications.boot(),
      attribution.start(),
    ]);
    if (!await probe.canReachNetwork()) {
      return const OfflineStop(returnToNative: false);
    }
    progress(0.62);
    await attribution.awaitSignals(installTimeout: const Duration(seconds: 5));
    final reply = await _requestConfig();
    progress(1);
    if (reply.hasDestination) return PortalStop(reply.url!);
    if (cached != null) return PortalStop(cached);
    return const OfflineStop(returnToNative: false);
  }

  Future<GateStop> _returningNative(void Function(double) progress) async {
    if (!await probe.hasInterface()) {
      progress(1);
      return const NativeStop();
    }
    await Future.wait<void>(<Future<void>>[
      notifications.boot(),
      attribution.start(),
    ]);
    if (!await probe.canReachNetwork()) {
      progress(1);
      return const NativeStop();
    }
    progress(0.55);
    await attribution.awaitSignals();
    final reply = await _requestConfig();
    progress(1);
    if (!reply.hasDestination) return const NativeStop();
    await vault.saveRoute(TrailRoute.portal);
    return PortalStop(reply.url!);
  }

  Future<GateReply> _requestConfig({String? token}) async {
    final body = await attribution.compose(
      locale: Platform.localeName.replaceAll('-', '_'),
      pushToken: token ?? notifications.token,
    );
    return exchange.request(body);
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

  /// AppsFlyer callback landed *after* we already committed to a decision.
  /// Re-POST the config with the real attribution body and, if the server now
  /// returns a portal URL, notify the UI so it can navigate.
  Future<void> _handleLateInstall() async {
    if (!_initialDecisionSettled) return;
    try {
      final reply = await _requestConfig();
      if (!reply.hasDestination) return;
      await vault.saveRoute(TrailRoute.portal);
      final stop = PortalStop(reply.url!);
      final callback = onLatePortal;
      if (callback != null) {
        callback(stop);
      } else {
        // No UI listener attached — stash the URL so the next resume/tap
        // consumes it via the portal push-url pipeline.
        await vault.stashPushUrl(reply.url!);
      }
    } catch (_) {}
  }
}
