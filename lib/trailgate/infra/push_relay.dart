import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'trail_vault.dart';

/// Registered as the FCM background-message handler. Must be a top-level
/// `@pragma('vm:entry-point')` function so Firebase can wire it up from a
/// fresh isolate — we don't do any real work here, we only need the plugin
/// to consider background delivery configured.
@pragma('vm:entry-point')
Future<void> bbBackgroundMessage(RemoteMessage _) async {}

/// FCM/APNs wrapper. The push token is refreshed opportunistically and the
/// user's tap intent is stashed into [TrailVault] so the boot pipeline can
/// consume it — the WebView is not always mounted when a push arrives.
class PushRelay {
  PushRelay(this._vault, {required this.enabled});

  static const Duration _initialTimeout = Duration(seconds: 4);
  static const Duration _apnsInterval = Duration(milliseconds: 550);
  static const int _passiveApnsAttempts = 6;
  static const int _postGrantApnsAttempts = 14;

  static const List<String> _urlKeys = <String>[
    'deep_link',
    'target',
    'url',
    'deeplink',
    'link',
  ];
  static const List<String> _nestedKeys = <String>['payload', 'data'];

  final TrailVault _vault;
  final bool enabled;

  FirebaseMessaging? _messaging;
  Future<void>? _bootFuture;
  Future<bool>? _permissionFuture;
  String? _token;

  void Function(String url)? onDestination;
  void Function(String token)? onTokenChanged;

  String? get token => _token;

  Future<void> boot() => _bootFuture ??= _boot();

  Future<void> _boot() async {
    if (!enabled) return;
    final messaging = FirebaseMessaging.instance;
    _messaging = messaging;

    // Drain the initial message so Firebase's internal queue is emptied,
    // but DO NOT stash it on iOS — SceneDelegate already delivered the
    // cold-start URL through UserDefaults → LaunchTapReader → the
    // coordinator's cold route. Stashing here would leave a duplicate in
    // vault that a later lifecycle-resume `_consumePending` picks up and
    // re-loads on top of the page the user is already reading.
    await _drainInitialMessage(messaging);

    FirebaseMessaging.onBackgroundMessage(bbBackgroundMessage);
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    messaging.onTokenRefresh.listen(_handleTokenRefresh);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleForegroundTap);

    await _waitForApns(_passiveApnsAttempts);
    _token = await _fetchToken(messaging);
  }

  Future<void> _drainInitialMessage(FirebaseMessaging messaging) async {
    final initial = await messaging.getInitialMessage().timeout(
          _initialTimeout,
          onTimeout: () => null,
        );
    if (Platform.isIOS) return;
    if (initial == null) return;
    final url = _extract(initial.data);
    if (url != null) await _vault.stashPushUrl(url);
  }

  void _handleTokenRefresh(String value) {
    _token = value;
    onTokenChanged?.call(value);
  }

  void _handleForegroundTap(RemoteMessage message) {
    final url = _extract(message.data);
    if (url == null) return;
    final consumer = onDestination;
    if (consumer != null) {
      consumer(url);
    } else {
      _vault.stashPushUrl(url);
    }
  }

  Future<String?> _fetchToken(FirebaseMessaging messaging) async {
    try {
      return await messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  String? _extract(Map<String, dynamic> payload) {
    for (final key in _urlKeys) {
      final value = payload[key];
      if (value is! String) continue;
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    for (final key in _nestedKeys) {
      final nested = payload[key];
      if (nested is! Map) continue;
      final found = _extract(Map<String, dynamic>.from(nested));
      if (found != null) return found;
    }
    return null;
  }

  Future<void> _waitForApns(int attempts) async {
    final messaging = _messaging;
    if (messaging == null) return;
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        final token = await messaging.getAPNSToken();
        if (token != null && token.isNotEmpty) return;
      } catch (_) {}
      await Future<void>.delayed(_apnsInterval);
    }
  }

  Future<bool> canOfferPermission() async {
    if (!enabled || _vault.pushDeniedByOs) return false;
    final messaging = _messaging;
    if (messaging == null) return false;

    final settings = await messaging.getNotificationSettings();
    final status = settings.authorizationStatus;
    if (status == AuthorizationStatus.denied) {
      await _vault.markPushDeniedByOs();
      return false;
    }
    return status == AuthorizationStatus.notDetermined ||
        status == AuthorizationStatus.provisional;
  }

  Future<bool> askPermission() {
    return _permissionFuture ??=
        _performPermissionRequest().whenComplete(() {
      _permissionFuture = null;
    });
  }

  Future<bool> _performPermissionRequest() async {
    final messaging = _messaging;
    if (!enabled || messaging == null) return false;

    final result = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    final accepted = _isAccepted(result.authorizationStatus);
    await _vault.setPushAllowed(accepted);

    if (!accepted && result.authorizationStatus == AuthorizationStatus.denied) {
      await _vault.markPushDeniedByOs();
    }
    if (!accepted) return false;

    await _waitForApns(_postGrantApnsAttempts);
    _token = await _fetchToken(messaging);
    final fresh = _token;
    if (fresh != null && fresh.isNotEmpty) onTokenChanged?.call(fresh);
    return true;
  }

  bool _isAccepted(AuthorizationStatus status) {
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }
}
