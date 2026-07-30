import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../config/trail_gate_config.dart';

/// HTTP client that stamps a Safari-shaped `User-Agent` on every outgoing
/// request. Same UA is fed to the WebView via `setUserAgent` so partner
/// backends see one consistent identity across HTTP + WKWebView.
class TrailAgent extends http.BaseClient {
  TrailAgent() : _transport = http.Client();

  final http.Client _transport;
  String? _cachedUa;

  /// Minimum iOS major we advertise. Anything older is bumped so we don't
  /// look like a device that Apple no longer ships. Change per project.
  static const int _iosFloorMajor = 18;
  static const String _iosFloorVersion = '18.5';

  Future<void> prepare() async {
    if (!Platform.isIOS) {
      _cachedUa = _fallback();
      return;
    }
    try {
      final info = await DeviceInfoPlugin().iosInfo;
      final version = _clampIosVersion(info.systemVersion);
      _cachedUa = _mobileSafari(version);
    } catch (_) {
      _cachedUa = _fallback();
    }
  }

  String get userAgent => _cachedUa ?? _fallback();

  String _clampIosVersion(String raw) {
    final parts = <int>[];
    for (final token in raw.split('.')) {
      final value = int.tryParse(token);
      if (value != null) parts.add(value);
      if (parts.length == 3) break;
    }
    if (parts.isEmpty || parts.first < _iosFloorMajor) return _iosFloorVersion;
    return parts.join('.');
  }

  // GAME THEME CATEGORY: crash (no appid/appname suffix).
  String _mobileSafari(String iosVersion) {
    final cpu = iosVersion.replaceAll('.', '_');
    final buffer = StringBuffer()
      ..write('Mozilla/5.0 (iPhone; CPU iPhone OS ')
      ..write(cpu)
      ..write(' like Mac OS X) AppleWebKit/')
      ..write(TrailGateConfig.webKitVersion)
      ..write(' (KHTML, like Gecko) Version/')
      ..write(TrailGateConfig.safariVersion)
      ..write(' Mobile/15E148 Safari/')
      ..write(TrailGateConfig.safariTail);
    return buffer.toString();
  }

  String _fallback() => _mobileSafari(_iosFloorVersion);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => userAgent);
    return _transport.send(request);
  }

  @override
  void close() => _transport.close();
}
