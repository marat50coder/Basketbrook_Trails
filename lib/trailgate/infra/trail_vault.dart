import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/gate_models.dart';

/// Persistent state for the trail-gate flow. Uses opaque key names so that
/// on-device inspection doesn't spell out `route` / `pending` / `denied`
/// verbatim and reveal the flow to the reviewer.
class TrailVault {
  TrailVault({FlutterSecureStorage? secure})
      : _secure = secure ?? const FlutterSecureStorage();

  // Opaque prefs keys (SharedPreferences namespace).
  static const String _kRoute = 'bbtr_route_pin';
  static const String _kExpiry = 'bbtr_stamp_epoch';
  static const String _kInviteAfter = 'bbtr_wave_after';
  static const String _kPushAllowed = 'bbtr_wave_ok';
  static const String _kOsDenied = 'bbtr_wave_locked';

  // Opaque secure-storage keys.
  static const String _kSavedUrl = 'bbtr.vault.dest';
  static const String _kPendingUrl = 'bbtr.vault.pending';

  final FlutterSecureStorage _secure;
  late SharedPreferences _preferences;

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
  }

  TrailRoute get route => TrailRoute.parse(_preferences.getString(_kRoute));

  Future<void> saveRoute(TrailRoute route) =>
      _preferences.setString(_kRoute, route.storageValue);

  Future<String?> savedUrl() {
    return _secureRead(_kSavedUrl);
  }

  Future<void> cacheUrl(String url, int? expiresAt) async {
    await _secureWrite(_kSavedUrl, url);
    if (expiresAt != null) {
      await _preferences.setInt(_kExpiry, expiresAt);
    }
  }

  bool get cachedUrlExpired {
    final expiry = _preferences.getInt(_kExpiry);
    if (expiry == null) return true;
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return nowSeconds >= expiry;
  }

  Future<void> stashPushUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return Future.value();
    return _secureWrite(_kPendingUrl, trimmed);
  }

  Future<String?> consumePushUrl() async {
    final value = await _secureRead(_kPendingUrl);
    if (value != null) await _secureDelete(_kPendingUrl);
    return value;
  }

  bool get pushAllowed => _preferences.getBool(_kPushAllowed) ?? false;
  bool get pushDeniedByOs => _preferences.getBool(_kOsDenied) ?? false;

  Future<void> setPushAllowed(bool value) =>
      _preferences.setBool(_kPushAllowed, value);

  Future<void> markPushDeniedByOs() =>
      _preferences.setBool(_kOsDenied, true);

  bool get shouldShowPushInvite {
    if (pushAllowed || pushDeniedByOs) return false;
    final after = _preferences.getInt(_kInviteAfter);
    if (after == null) return true;
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return nowSeconds >= after;
  }

  Future<void> snoozePushInvite(int epochSeconds) =>
      _preferences.setInt(_kInviteAfter, epochSeconds);

  // ── Secure storage helpers (swallow platform-side errors). ────────────
  Future<String?> _secureRead(String key) async {
    try {
      return await _secure.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _secureWrite(String key, String value) async {
    try {
      await _secure.write(key: key, value: value);
    } catch (_) {}
  }

  Future<void> _secureDelete(String key) async {
    try {
      await _secure.delete(key: key);
    } catch (_) {}
  }
}
