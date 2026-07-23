import 'package:flutter/material.dart';

import '../core/game_state.dart';

/// A single achievement definition. Progress is derived live from the
/// player's cumulative statistics.
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.goal,
    required this.reward,
    required this.progressOf,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final int goal;
  final int reward;
  final int Function(GameState state) progressOf;

  int currentOf(GameState s) => progressOf(s).clamp(0, goal);
  bool isComplete(GameState s) => progressOf(s) >= goal;
}

/// The full catalogue of achievements.
const List<Achievement> kAchievements = [
  Achievement(
    id: 'first_steps',
    title: 'First Steps',
    description: 'Complete your first level',
    icon: Icons.flag_rounded,
    goal: 1,
    reward: 50,
    progressOf: _gamesWon,
  ),
  Achievement(
    id: 'trailblazer',
    title: 'Trailblazer',
    description: 'Complete 10 levels',
    icon: Icons.route_rounded,
    goal: 10,
    reward: 150,
    progressOf: _gamesWon,
  ),
  Achievement(
    id: 'chicken_whisperer',
    title: 'Chicken Whisperer',
    description: 'Gather 100 chickens',
    icon: Icons.pets_rounded,
    goal: 100,
    reward: 120,
    progressOf: _chickens,
  ),
  Achievement(
    id: 'flock_master',
    title: 'Flock Master',
    description: 'Gather 500 chickens',
    icon: Icons.groups_rounded,
    goal: 500,
    reward: 400,
    progressOf: _chickens,
  ),
  Achievement(
    id: 'egg_courier',
    title: 'Egg Courier',
    description: 'Deliver 100 eggs',
    icon: Icons.egg_rounded,
    goal: 100,
    reward: 120,
    progressOf: _eggs,
  ),
  Achievement(
    id: 'egg_tycoon',
    title: 'Egg Tycoon',
    description: 'Deliver 1000 eggs',
    icon: Icons.egg_alt_rounded,
    goal: 1000,
    reward: 500,
    progressOf: _eggs,
  ),
  Achievement(
    id: 'coin_collector',
    title: 'Coin Collector',
    description: 'Earn 500 coins',
    icon: Icons.monetization_on_rounded,
    goal: 500,
    reward: 100,
    progressOf: _coinsEarned,
  ),
  Achievement(
    id: 'rich_farmer',
    title: 'Rich Farmer',
    description: 'Earn 2500 coins',
    icon: Icons.savings_rounded,
    goal: 2500,
    reward: 350,
    progressOf: _coinsEarned,
  ),
  Achievement(
    id: 'star_gazer',
    title: 'Star Gazer',
    description: 'Earn 30 stars',
    icon: Icons.star_rounded,
    goal: 30,
    reward: 200,
    progressOf: _stars,
  ),
  Achievement(
    id: 'perfect_star',
    title: 'Constellation',
    description: 'Earn 60 stars',
    icon: Icons.auto_awesome_rounded,
    goal: 60,
    reward: 450,
    progressOf: _stars,
  ),
  Achievement(
    id: 'long_chain',
    title: 'Grand Parade',
    description: 'Reach a chain of 25 chickens',
    icon: Icons.timeline_rounded,
    goal: 25,
    reward: 200,
    progressOf: _bestChain,
  ),
  Achievement(
    id: 'collector',
    title: 'Coop Curator',
    description: 'Unlock all 8 chicken breeds',
    icon: Icons.collections_rounded,
    goal: 8,
    reward: 500,
    progressOf: _breeds,
  ),
];

int _gamesWon(GameState s) => s.gamesWon;
int _chickens(GameState s) => s.totalChickens;
int _eggs(GameState s) => s.totalEggs;
int _coinsEarned(GameState s) => s.totalCoinsEarned;
int _stars(GameState s) => s.totalStars;
int _bestChain(GameState s) => s.bestChain;
int _breeds(GameState s) => s.ownedSkins.length;
