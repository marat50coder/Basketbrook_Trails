import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around [SharedPreferences] for offline persistence.
class GameStorage {
  GameStorage._(this._prefs);

  final SharedPreferences _prefs;

  static Future<GameStorage> open() async {
    final prefs = await SharedPreferences.getInstance();
    return GameStorage._(prefs);
  }

  static const _kCoins = 'coins';
  static const _kUnlockedLevel = 'unlocked_level';
  static const _kSelectedSkin = 'selected_skin';
  static const _kOwnedSkins = 'owned_skins';
  static const _kMusic = 'music_on';
  static const _kSound = 'sound_on';
  static const _kBestPrefix = 'best_';
  static const _kStarsPrefix = 'stars_';
  static const _kTotalEggs = 'total_eggs';

  // --- Generic passthroughs (used for stats, dailies, achievements) ---
  int getInt(String key, [int def = 0]) => _prefs.getInt(key) ?? def;
  void setInt(String key, int v) => _prefs.setInt(key, v);
  String getString(String key, [String def = '']) => _prefs.getString(key) ?? def;
  void setString(String key, String v) => _prefs.setString(key, v);
  List<String> getStringList(String key) => _prefs.getStringList(key) ?? const [];
  void setStringList(String key, List<String> v) => _prefs.setStringList(key, v);

  int get coins => _prefs.getInt(_kCoins) ?? 0;
  set coins(int v) => _prefs.setInt(_kCoins, v);

  int get unlockedLevel => _prefs.getInt(_kUnlockedLevel) ?? 1;
  set unlockedLevel(int v) => _prefs.setInt(_kUnlockedLevel, v);

  int get selectedSkin => _prefs.getInt(_kSelectedSkin) ?? 0;
  set selectedSkin(int v) => _prefs.setInt(_kSelectedSkin, v);

  List<int> get ownedSkins {
    final raw = _prefs.getStringList(_kOwnedSkins);
    if (raw == null) return [0];
    return raw.map(int.parse).toList();
  }

  set ownedSkins(List<int> v) =>
      _prefs.setStringList(_kOwnedSkins, v.map((e) => e.toString()).toList());

  bool get musicOn => _prefs.getBool(_kMusic) ?? true;
  set musicOn(bool v) => _prefs.setBool(_kMusic, v);

  bool get soundOn => _prefs.getBool(_kSound) ?? true;
  set soundOn(bool v) => _prefs.setBool(_kSound, v);

  int get totalEggs => _prefs.getInt(_kTotalEggs) ?? 0;
  set totalEggs(int v) => _prefs.setInt(_kTotalEggs, v);

  int bestScore(int level) => _prefs.getInt('$_kBestPrefix$level') ?? 0;
  void setBestScore(int level, int v) => _prefs.setInt('$_kBestPrefix$level', v);

  int stars(int level) => _prefs.getInt('$_kStarsPrefix$level') ?? 0;
  void setStars(int level, int v) => _prefs.setInt('$_kStarsPrefix$level', v);

  Future<void> reset() async {
    await _prefs.clear();
  }
}
