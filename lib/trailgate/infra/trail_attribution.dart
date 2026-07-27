import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../config/trail_gate_config.dart';
import 'trail_agent.dart';

void trailTrace(String Function() message) {
  assert(() {
    debugPrint(message());
    return true;
  }());
}

class TrailAttribution {
  TrailAttribution(this._agent);

  final TrailAgent _agent;
  AppsflyerSdk? _sdk;
  Map<String, dynamic>? _install;
  Map<String, dynamic>? _reopen;
  Map<String, dynamic>? _deepLink;
  Future<void>? _startFuture;
  final Completer<void> _installReady = Completer<void>();
  final Completer<void> _deepLinkReady = Completer<void>();

  /// Fires ONCE when real (non-empty) conversion data lands *after* start().
  /// Lets the coordinator reroute if the initial decision was made before
  /// AppsFlyer delivered its data (fresh iOS installs often take 10–15 s on
  /// iOS 18+). AppsFlyer re-emits `onInstallConversionData` on every app
  /// resume/relaunch, so this is intentionally one-shot to prevent the
  /// coordinator from re-running the "route to portal" pipeline every time
  /// the user backgrounds and re-opens the app (which manifested as the
  /// WebView "restarting" instead of staying on the last page).
  void Function()? onLateInstall;
  bool _initialResolutionSent = false;
  bool _lateFired = false;

  Future<void> start() => _startFuture ??= _start();

  Future<void> _start() async {
    if (!TrailGateConfig.grayCredentialsReady) {
      _completeEmpty();
      return;
    }
    try {
      await _requestTrackingIfNeeded();
      final sdk = AppsflyerSdk(
        AppsFlyerOptions(
          afDevKey: TrailGateConfig.appsFlyerKey,
          appId: TrailGateConfig.iosStoreId,
          showDebug: kDebugMode,
          timeToWaitForATTUserAuthorization: 4,
        ),
      );
      _sdk = sdk;
      sdk.onInstallConversionData(_acceptInstall);
      sdk.onAppOpenAttribution((raw) => _reopen = _flat(raw));
      sdk.onDeepLinking((result) {
        final event = result.deepLink?.clickEvent;
        if (event != null) _deepLink = Map<String, dynamic>.from(event);
        if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
      });
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (error) {
      trailTrace(() => '[BB.FLIGHT] initialization failed: $error');
      _completeEmpty();
    }
  }

  Future<void> _requestTrackingIfNeeded() async {
    if (!Platform.isIOS) return;
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status != TrackingStatus.notDetermined) return;
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 320));
    await AppTrackingTransparency.requestTrackingAuthorization();
  }

  Future<void> _acceptInstall(dynamic raw) async {
    try {
      final received = _flat(raw);
      final status = received['status']?.toString().toLowerCase();
      // AppsFlyer delivers a {status:failure,...} map when it can't reach its
      // servers (e.g. an ad-blocking VPN). Never merge that error into the body.
      final failed = status == 'failure' ||
          (received['af_status'] == null && received.containsKey('status'));
      trailTrace(
        () => '[BB.FLIGHT] conversion status=$status '
            'af_status=${received['af_status']} keys=${received.keys.toList()}',
      );
      if (failed) {
        _install = <String, dynamic>{};
      } else if (received['af_status'] == 'Organic') {
        await Future<void>.delayed(
          const Duration(seconds: TrailGateConfig.organicRecheckSeconds),
        );
        _install = await _fetchGcd() ?? received;
      } else {
        _install = received;
      }
    } catch (error) {
      trailTrace(() => '[BB.FLIGHT] conversion parse error: $error');
      _install = <String, dynamic>{};
    } finally {
      final firstFill = !_installReady.isCompleted;
      if (firstFill) _installReady.complete();
      // Notify the coordinator EXACTLY ONCE when late install data arrives —
      // even if awaitSignals timed out and we already sent a request with the
      // empty body. This is the recovery path for "first request went out
      // before AppsFlyer callback fired". After that, subsequent re-emits
      // from AppsFlyer (which happen on every app resume) are ignored so the
      // portal is not re-navigated on top of itself.
      final hasData = _install != null && _install!.isNotEmpty;
      if (hasData && _initialResolutionSent && !_lateFired) {
        _lateFired = true;
        onLateInstall?.call();
      }
    }
  }

  /// Called by the coordinator once its first config POST has been sent, so a
  /// later `_acceptInstall` with real data knows it's a *late* arrival.
  void markInitialResolutionSent() {
    _initialResolutionSent = true;
  }

  bool get hasInstallData => _install != null && _install!.isNotEmpty;

  Map<String, dynamic> _flat(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final map = Map<String, dynamic>.from(raw);
    final payload = map['payload'];
    return payload is Map ? Map<String, dynamic>.from(payload) : map;
  }

  Future<Map<String, dynamic>?> _fetchGcd() async {
    final uid = await appsFlyerId();
    if (uid == null || uid.isEmpty) return null;
    try {
      // iOS GCD uses the numeric App Store id, not the bundle id.
      final base = TrailGateConfig.gcdBase;
      final sep = base.contains('?') ? '&' : '?';
      final uri = Uri.parse(
        '$base${sep}app_id=${TrailGateConfig.iosStoreId}&device_id=$uid',
      );
      final response = await _agent
          .get(
            uri,
            headers: <String, String>{
              'Authorization': 'Bearer ${TrailGateConfig.appsFlyerKey}',
            },
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> awaitSignals({
    Duration installTimeout = const Duration(seconds: 25),
  }) async {
    await start();
    var installArrived = false;
    await Future.wait<void>(<Future<void>>[
      _installReady.future.timeout(installTimeout, onTimeout: () {}).then((_) {
        installArrived = _installReady.isCompleted;
      }),
      _deepLinkReady.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      ),
    ]);
    if (!installArrived) {
      trailTrace(
        () => '[BB.FLIGHT] awaitSignals timed out after '
            '${installTimeout.inSeconds}s — falling through with no install data',
      );
    }
  }

  Future<String?> appsFlyerId() async {
    try {
      return await _sdk?.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> compose({
    required String locale,
    String? pushToken,
  }) async {
    final body = <String, dynamic>{};
    if (_install != null) body.addAll(_install!);
    if (_reopen != null) {
      _reopen!.forEach((key, value) => body.putIfAbsent(key, () => value));
    }
    if (_deepLink != null) {
      _deepLink!.forEach((key, value) => body.putIfAbsent(key, () => value));
    }

    body['af_id'] = await appsFlyerId() ?? body['af_id'] ?? '';
    body['bundle_id'] = TrailGateConfig.bundleId;
    body['os'] = 'iOS';
    body['store_id'] = TrailGateConfig.storeToken;
    body['locale'] = locale;
    if (pushToken != null &&
        pushToken.isNotEmpty &&
        TrailGateConfig.firebaseProjectNumber.isNotEmpty) {
      body['push_token'] = pushToken;
      body['firebase_project_id'] = TrailGateConfig.firebaseProjectNumber;
    }

    if (Platform.isIOS) {
      try {
        if (await AppTrackingTransparency.trackingAuthorizationStatus ==
            TrackingStatus.authorized) {
          final idfa = await AppTrackingTransparency.getAdvertisingIdentifier();
          if (idfa.isNotEmpty && !idfa.startsWith('00000000-')) {
            body['sub_id_10'] = idfa;
          }
        }
      } catch (_) {}
    }
    trailTrace(() => '[BB.FLIGHT] payload ${jsonEncode(body)}');
    return body;
  }

  void _completeEmpty() {
    if (!_installReady.isCompleted) _installReady.complete();
    if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
  }
}
