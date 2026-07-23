import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/daily.dart';
import '../data/upgrades.dart';
import 'audio.dart';
import 'image_bank.dart';
import 'sprites.dart';
import 'storage.dart';

/// App-wide persistent state: currency, unlocks, statistics, dailies and
/// settings. Everything is stored locally so the game is fully offline.
class GameState extends ChangeNotifier {
  GameState({
    required this.storage,
    required this.audio,
    required this.images,
  }) {
    audio.soundOn = storage.soundOn;
    audio.musicOn = storage.musicOn;
    _ensureDaily();
  }

  final GameStorage storage;
  final AudioController audio;
  final ImageBank images;

  // --- Currency & unlocks ---
  int get coins => storage.coins;
  int get unlockedLevel => storage.unlockedLevel;
  int get selectedSkin => storage.selectedSkin;
  List<int> get ownedSkins => storage.ownedSkins;
  bool get musicOn => storage.musicOn;
  bool get soundOn => storage.soundOn;
  int get totalEggs => storage.totalEggs;

  // --- Statistics ---
  int get gamesPlayed => storage.getInt('games_played');
  int get gamesWon => storage.getInt('games_won');
  int get totalChickens => storage.getInt('total_chickens');
  int get totalCoinsEarned => storage.getInt('total_coins_earned');
  int get totalEggsLost => storage.getInt('total_eggs_lost');
  int get totalStars => storage.getInt('total_stars');
  int get bestChain => storage.getInt('best_chain');
  int get chests => storage.getInt('chests');
  String get playerName => storage.getString('player_name', 'Farmer');

  int stars(int level) => storage.stars(level);
  int bestScore(int level) => storage.bestScore(level);

  ChickenSkin get currentSkin => Sprites.skins[selectedSkin];
  bool ownsSkin(int index) => ownedSkins.contains(index);

  /// Player "farm level" derived from delivered eggs, plus XP progress 0..1.
  int get farmLevel => 1 + totalEggs ~/ 25;
  double get farmXp => (totalEggs % 25) / 25.0;

  /// Locations unlock every 5 completed levels (6 total).
  int get unlockedLocations => (1 + (unlockedLevel - 1) ~/ 5).clamp(1, 6);

  void addCoins(int amount) {
    storage.coins = coins + amount;
    notifyListeners();
  }

  void setPlayerName(String name) {
    final trimmed = name.trim();
    storage.setString('player_name', trimmed.isEmpty ? 'Farmer' : trimmed);
    notifyListeners();
  }

  bool buySkin(ChickenSkin skin) {
    if (ownsSkin(skin.index)) return true;
    if (coins < skin.price) return false;
    storage.coins = coins - skin.price;
    storage.ownedSkins = [...ownedSkins, skin.index];
    storage.selectedSkin = skin.index;
    notifyListeners();
    return true;
  }

  void selectSkin(int index) {
    if (!ownsSkin(index)) return;
    storage.selectedSkin = index;
    notifyListeners();
  }

  // --- Gameplay upgrades (permanent, capped, coin-bought) ---
  int upgradeLevel(String key) => storage.getInt(key);

  UpgradeDef _upgrade(String key) => kUpgrades.firstWhere((u) => u.key == key);

  /// Cost of the next level, or `null` when already maxed out.
  int? upgradeCost(String key) {
    final lvl = upgradeLevel(key);
    final costs = _upgrade(key).costs;
    if (lvl >= costs.length) return null;
    return costs[lvl];
  }

  bool buyUpgrade(String key) {
    final cost = upgradeCost(key);
    if (cost == null || coins < cost) return false;
    storage.coins = coins - cost;
    storage.setInt(key, upgradeLevel(key) + 1);
    notifyListeners();
    return true;
  }

  /// Effective in-game bonuses derived from the upgrade levels.
  int get startingChickens => upgradeLevel('up_flock'); // 0..2
  int get shieldCharges => upgradeLevel('up_shield'); // 0..2
  double get coinBonus => 1 + upgradeLevel('up_bonus') * 0.12; // 1.0..1.48

  void setMusic(bool on) {
    storage.musicOn = on;
    audio.musicOn = on;
    if (!on) audio.stopAmbient();
    notifyListeners();
  }

  void setSound(bool on) {
    storage.soundOn = on;
    audio.soundOn = on;
    notifyListeners();
  }

  /// Records the outcome of a level, updating currency, unlocks, statistics,
  /// daily tasks and chest rewards.
  void recordLevelResult({
    required int level,
    required bool won,
    required int stars,
    required int score,
    required int eggsDelivered,
    required int coinsCollected,
    required int coinsEarned,
    required int chickensCollected,
    required int eggsLost,
    required int maxChain,
  }) {
    storage.setInt('games_played', gamesPlayed + 1);
    storage.setInt('total_chickens', totalChickens + chickensCollected);
    storage.setInt('total_coins_earned', totalCoinsEarned + coinsEarned);
    storage.setInt('total_eggs_lost', totalEggsLost + eggsLost);
    storage.setInt('best_chain', max(bestChain, maxChain));
    storage.coins = coins + coinsEarned;

    _ensureDaily();
    _addDailyProgress(DailyGoal.chickens, chickensCollected);
    _addDailyProgress(DailyGoal.coins, coinsCollected);

    if (won) {
      storage.setInt('games_won', gamesWon + 1);
      storage.setInt('total_stars', totalStars + stars);
      storage.setInt('chests', chests + 1);
      storage.totalEggs = totalEggs + eggsDelivered;
      if (stars > storage.stars(level)) storage.setStars(level, stars);
      if (score > storage.bestScore(level)) storage.setBestScore(level, score);
      if (level >= unlockedLevel) storage.unlockedLevel = level + 1;
      _addDailyProgress(DailyGoal.eggs, eggsDelivered);
      _addDailyProgress(DailyGoal.levels, 1);
      _addDailyProgress(DailyGoal.stars, stars);
    }
    notifyListeners();
  }

  void resetProgress() {
    storage.reset();
    _ensureDaily();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Daily login reward (7-day cycle).
  // ---------------------------------------------------------------------------
  static const List<int> dailyRewardTable = [20, 30, 45, 60, 80, 110, 200];

  String get _todayKey {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  int get _todaySeed {
    final n = DateTime.now();
    final start = DateTime(n.year);
    final doy = n.difference(start).inDays;
    return n.year * 366 + doy;
  }

  int get dailyRewardStreak => storage.getInt('dr_streak');
  bool get canClaimDailyReward => storage.getString('dr_last') != _todayKey;

  /// Which day of the cycle (1..7) the *next* claim corresponds to.
  int get dailyRewardDay {
    final streak = dailyRewardStreak;
    if (!canClaimDailyReward) return ((streak - 1) % 7) + 1;
    return (streak % 7) + 1;
  }

  int claimDailyReward() {
    if (!canClaimDailyReward) return 0;
    final last = storage.getString('dr_last');
    final n = DateTime.now();
    final yesterday = '${n.subtract(const Duration(days: 1)).year}-'
        '${n.subtract(const Duration(days: 1)).month}-'
        '${n.subtract(const Duration(days: 1)).day}';
    final newStreak = last == yesterday ? dailyRewardStreak + 1 : 1;
    storage.setInt('dr_streak', newStreak);
    storage.setString('dr_last', _todayKey);
    final reward = dailyRewardTable[(newStreak - 1) % 7];
    storage.coins = coins + reward;
    notifyListeners();
    return reward;
  }

  // ---------------------------------------------------------------------------
  // Daily tasks (3 per day).
  // ---------------------------------------------------------------------------
  void _ensureDaily() {
    if (storage.getString('dt_date') != _todayKey) {
      storage.setString('dt_date', _todayKey);
      storage.setStringList('dt_progress', ['0', '0', '0']);
      storage.setStringList('dt_claimed', ['0', '0', '0']);
    }
  }

  List<DailyTaskState> dailyTasks() {
    _ensureDaily();
    final defs = pickDailyTasks(_todaySeed);
    final progress = storage.getStringList('dt_progress');
    final claimed = storage.getStringList('dt_claimed');
    return List.generate(defs.length, (i) {
      final p = i < progress.length ? int.tryParse(progress[i]) ?? 0 : 0;
      final c = i < claimed.length && claimed[i] == '1';
      return DailyTaskState(defs[i], p, c);
    });
  }

  void _addDailyProgress(DailyGoal goal, int amount) {
    if (amount <= 0) return;
    final defs = pickDailyTasks(_todaySeed);
    final progress = List<String>.from(storage.getStringList('dt_progress'));
    while (progress.length < defs.length) {
      progress.add('0');
    }
    var changed = false;
    for (var i = 0; i < defs.length; i++) {
      if (defs[i].goal == goal) {
        final cur = int.tryParse(progress[i]) ?? 0;
        progress[i] = min(defs[i].target, cur + amount).toString();
        changed = true;
      }
    }
    if (changed) storage.setStringList('dt_progress', progress);
  }

  bool claimDailyTask(int index) {
    final tasks = dailyTasks();
    if (index < 0 || index >= tasks.length) return false;
    final t = tasks[index];
    if (!t.complete || t.claimed) return false;
    final claimed = List<String>.from(storage.getStringList('dt_claimed'));
    while (claimed.length <= index) {
      claimed.add('0');
    }
    claimed[index] = '1';
    storage.setStringList('dt_claimed', claimed);
    storage.coins = coins + t.def.reward;
    notifyListeners();
    return true;
  }

  // ---------------------------------------------------------------------------
  // Chests earned from wins.
  // ---------------------------------------------------------------------------
  ChestReward openChest() {
    if (chests <= 0) return ChestReward(0, null);
    storage.setInt('chests', chests - 1);
    final rnd = Random();
    // Small chance to unlock a new breed, otherwise coins.
    final locked = Sprites.skins.where((s) => !ownsSkin(s.index)).toList();
    if (locked.isNotEmpty && rnd.nextDouble() < 0.15) {
      final skin = locked[rnd.nextInt(locked.length)];
      storage.ownedSkins = [...ownedSkins, skin.index];
      notifyListeners();
      return ChestReward(0, skin);
    }
    final reward = 20 + rnd.nextInt(50);
    storage.coins = coins + reward;
    notifyListeners();
    return ChestReward(reward, null);
  }
}

class ChestReward {
  ChestReward(this.coins, this.skin);
  final int coins;
  final ChickenSkin? skin;
}
