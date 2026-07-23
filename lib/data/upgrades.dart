import 'package:flutter/material.dart';

/// Permanent, coin-bought gameplay upgrades.
///
/// Every upgrade is intentionally **capped** and priced so it feels rewarding
/// without turning the game into a walkover:
///  - Starting Flock: at most +2 chickens at the start of a run.
///  - Feather Shield: at most 2 obstacle hits absorbed per run.
///  - Golden Eggs: at most +48% coins earned.
///
/// Buying everything costs ~3.3k coins, i.e. a good chunk of steady play, so
/// upgrades matter but are never free power.
class UpgradeDef {
  const UpgradeDef({
    required this.key,
    required this.title,
    required this.icon,
    required this.colors,
    required this.costs,
    required this.effectAt,
  });

  final String key;
  final String title;
  final IconData icon;
  final List<Color> colors;

  /// Cost to reach the next level; `costs.length` == max level.
  final List<int> costs;

  /// Human-readable effect for a given level (0 == not bought yet).
  final String Function(int level) effectAt;

  int get maxLevel => costs.length;
}

const List<UpgradeDef> kUpgrades = [
  UpgradeDef(
    key: 'up_flock',
    title: 'Starting Flock',
    icon: Icons.groups_rounded,
    colors: [Color(0xFF6EC85B), Color(0xFF3E9A3A)],
    costs: [300, 700],
    effectAt: _flockEffect,
  ),
  UpgradeDef(
    key: 'up_shield',
    title: 'Feather Shield',
    icon: Icons.shield_rounded,
    colors: [Color(0xFF8FD0F0), Color(0xFF4FA9D8)],
    costs: [250, 600],
    effectAt: _shieldEffect,
  ),
  UpgradeDef(
    key: 'up_bonus',
    title: 'Golden Eggs',
    icon: Icons.savings_rounded,
    colors: [Color(0xFFFFD65A), Color(0xFFF2A828)],
    costs: [150, 280, 450, 650],
    effectAt: _bonusEffect,
  ),
];

String _flockEffect(int level) =>
    level <= 0 ? 'Start on your own' : 'Start with +$level ${level == 1 ? 'chicken' : 'chickens'}';

String _shieldEffect(int level) =>
    level <= 0 ? 'No protection' : 'Shrug off $level obstacle hit${level == 1 ? '' : 's'} per run';

String _bonusEffect(int level) => '+${level * 12}% coins earned';
