import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../config/trail_gate_config.dart';
import 'trail_agent.dart';

/// Assert-wrapped logger so the closure and its string literal are both
/// stripped from release builds (no grep-able `[BB.*]` strings survive).
void trailTrace(String Function() build) {
  assert(() {
    debugPrint(build());
    return true;
  }());
}

/// Wraps AppsFlyer + ATT: kicks the SDK off, buffers conversion / re-open /
/// deep-link callbacks, and composes the payload posted to the config
/// endpoint by [GateExchange]. All errors are swallowed so a broken
/// attribution SDK can never break the boot path.
class TrailAttribution {
  TrailAttribution(this._agent);

  static const Duration _defaultInstallTimeout = Duration(seconds: 25);
  static const Duration _deepLinkTimeout = Duration(seconds: 5);
  static const Duration _gcdTimeout = Duration(seconds: 12);
  static const double _attWaitSeconds = 4;
  static const int _attPromptDelayMs = 320;

  final TrailAgent _agent;
  AppsflyerSdk? _sdk;
  Map<String, dynamic>? _install;
  Map<String, dynamic>? _reopen;
  Map<String, dynamic>? _deepLink;

  Future<void>? _bootFuture;
  final Completer<void> _installReady = Completer<void>();
  final Completer<void> _deepLinkReady = Completer<void>();

  Future<void> start() => _bootFuture ??= _bootSdk();

  Future<void> _bootSdk() async {
    if (!TrailGateConfig.grayCredentialsReady) {
      _completeSignals();
      return;
    }
    try {
      await _requestTrackingIfNeeded();
      final sdk = AppsflyerSdk(
        AppsFlyerOptions(
          afDevKey: TrailGateConfig.appsFlyerKey,
          appId: TrailGateConfig.iosStoreId,
          showDebug: kDebugMode,
          timeToWaitForATTUserAuthorization: _attWaitSeconds,
        ),
      );
      _sdk = sdk;
      _wireCallbacks(sdk);
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (error) {
      trailTrace(() => '[BB.TRAIL] init failed: $error');
      _completeSignals();
    }
  }

  void _wireCallbacks(AppsflyerSdk sdk) {
    sdk.onInstallConversionData(_acceptInstall);
    sdk.onAppOpenAttribution((raw) => _reopen = _flatten(raw));
    sdk.onDeepLinking((result) {
      final event = result.deepLink?.clickEvent;
      if (event != null) {
        _deepLink = Map<String, dynamic>.from(event);
      }
      if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
    });
  }

  Future<void> _requestTrackingIfNeeded() async {
    if (!Platform.isIOS) return;
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status != TrackingStatus.notDetermined) return;
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(
      const Duration(milliseconds: _attPromptDelayMs),
    );
    await AppTrackingTransparency.requestTrackingAuthorization();
  }

  Future<void> _acceptInstall(dynamic raw) async {
    try {
      final received = _flatten(raw);
      final statusText = received['status']?.toString().toLowerCase();
      final looksLikeError = statusText == 'failure' ||
          (received['af_status'] == null && received.containsKey('status'));

      trailTrace(
        () => '[BB.TRAIL] conversion status=$statusText '
            'af_status=${received['af_status']} keys=${received.keys.toList()}',
      );

      if (looksLikeError) {
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
      trailTrace(() => '[BB.TRAIL] conversion parse error: $error');
      _install = <String, dynamic>{};
    } finally {
      if (!_installReady.isCompleted) _installReady.complete();
    }
  }

  bool get hasInstallData => _install != null && _install!.isNotEmpty;

  Map<String, dynamic> _flatten(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final map = Map<String, dynamic>.from(raw);
    final payload = map['payload'];
    if (payload is Map) return Map<String, dynamic>.from(payload);
    return map;
  }

  Future<Map<String, dynamic>?> _fetchGcd() async {
    final uid = await appsFlyerId();
    if (uid == null || uid.isEmpty) return null;
    try {
      // iOS GCD uses the numeric App Store id, not the bundle id.
      final base = TrailGateConfig.gcdBase;
      final joiner = base.contains('?') ? '&' : '?';
      final target = Uri.parse(
        '$base${joiner}app_id=${TrailGateConfig.iosStoreId}&device_id=$uid',
      );
      final response = await _agent
          .get(
            target,
            headers: <String, String>{
              'Authorization': 'Bearer ${TrailGateConfig.appsFlyerKey}',
            },
          )
          .timeout(_gcdTimeout);
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> awaitSignals({
    Duration installTimeout = _defaultInstallTimeout,
  }) async {
    await start();
    final installFuture =
        _installReady.future.timeout(installTimeout, onTimeout: () {});
    final deepLinkFuture =
        _deepLinkReady.future.timeout(_deepLinkTimeout, onTimeout: () {});
    await Future.wait<void>(<Future<void>>[installFuture, deepLinkFuture]);
    if (!_installReady.isCompleted) {
      trailTrace(
        () => '[BB.TRAIL] awaitSignals timeout ${installTimeout.inSeconds}s '
            '— no install data',
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
    _mergeInto(body, _install, force: true);
    _mergeInto(body, _reopen);
    _mergeInto(body, _deepLink);

    body['af_id'] = await appsFlyerId() ?? body['af_id'] ?? '';
    body['bundle_id'] = TrailGateConfig.bundleId;
    body['os'] = 'iOS';
    body['store_id'] = TrailGateConfig.storeToken;
    body['locale'] = locale;

    _attachPushCredentials(body, pushToken);
    await _attachIdfaIfAuthorized(body);

    trailTrace(() => '[BB.TRAIL] payload ${jsonEncode(body)}');
    return body;
  }

  void _mergeInto(
    Map<String, dynamic> target,
    Map<String, dynamic>? source, {
    bool force = false,
  }) {
    if (source == null) return;
    source.forEach((key, value) {
      if (force) {
        target[key] = value;
      } else {
        target.putIfAbsent(key, () => value);
      }
    });
  }

  void _attachPushCredentials(Map<String, dynamic> body, String? pushToken) {
    if (pushToken == null || pushToken.isEmpty) return;
    if (TrailGateConfig.firebaseProjectNumber.isEmpty) return;
    body['push_token'] = pushToken;
    body['firebase_project_id'] = TrailGateConfig.firebaseProjectNumber;
  }

  Future<void> _attachIdfaIfAuthorized(Map<String, dynamic> body) async {
    if (!Platform.isIOS) return;
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status != TrackingStatus.authorized) return;
      final idfa = await AppTrackingTransparency.getAdvertisingIdentifier();
      if (idfa.isEmpty || idfa.startsWith('00000000-')) return;
      body['sub_id_10'] = idfa;
    } catch (_) {}
  }

  void _completeSignals() {
    if (!_installReady.isCompleted) _installReady.complete();
    if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
  }
}
