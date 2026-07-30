import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Reads the one-shot cold-start push destination that
/// [SceneDelegate](../../ios/Runner/SceneDelegate.swift) stashes in
/// `UserDefaults`. The shared_preferences iOS plugin exposes those defaults
/// under the same key (with a `flutter.` prefix that the plugin strips), so
/// Dart can consume it directly. MUST stay in sync with
/// `SceneDelegate.launchRouteKey`.
abstract final class LaunchTapReader {
  static const String _tapKey = 'bbtr_launch_destination';

  static Future<String?> consume() async {
    if (!Platform.isIOS) return null;
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }

    final raw = prefs.getString(_tapKey);
    if (raw == null) return null;

    final trimmed = raw.trim();
    // Always burn the key — a stale value must never leak into a later
    // cold launch that had no notification tap of its own.
    try {
      await prefs.remove(_tapKey);
    } catch (_) {}
    return trimmed.isEmpty ? null : trimmed;
  }
}
