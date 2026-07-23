import 'dart:math';

import 'package:flutter/material.dart';

/// The kind of progress a daily task tracks.
enum DailyGoal { chickens, eggs, coins, levels, stars }

class DailyTaskDef {
  const DailyTaskDef(this.goal, this.target, this.title, this.reward, this.icon);
  final DailyGoal goal;
  final int target;
  final String title;
  final int reward;
  final IconData icon;
}

/// Runtime state of one daily task.
class DailyTaskState {
  DailyTaskState(this.def, this.progress, this.claimed);
  final DailyTaskDef def;
  int progress;
  bool claimed;

  bool get complete => progress >= def.target;
}

/// Pool of possible daily tasks. Three are picked deterministically per day.
const List<DailyTaskDef> _pool = [
  DailyTaskDef(DailyGoal.chickens, 20, 'Gather 20 chickens', 40, Icons.pets_rounded),
  DailyTaskDef(DailyGoal.chickens, 35, 'Gather 35 chickens', 60, Icons.groups_rounded),
  DailyTaskDef(DailyGoal.eggs, 15, 'Deliver 15 eggs', 50, Icons.egg_rounded),
  DailyTaskDef(DailyGoal.eggs, 25, 'Deliver 25 eggs', 70, Icons.egg_alt_rounded),
  DailyTaskDef(DailyGoal.coins, 30, 'Collect 30 coins', 30, Icons.monetization_on_rounded),
  DailyTaskDef(DailyGoal.coins, 50, 'Collect 50 coins', 50, Icons.savings_rounded),
  DailyTaskDef(DailyGoal.levels, 3, 'Complete 3 levels', 60, Icons.flag_rounded),
  DailyTaskDef(DailyGoal.levels, 5, 'Complete 5 levels', 90, Icons.route_rounded),
  DailyTaskDef(DailyGoal.stars, 5, 'Earn 5 stars', 70, Icons.star_rounded),
];

/// Picks the three tasks for the given [seed] (day based), avoiding duplicates.
List<DailyTaskDef> pickDailyTasks(int seed) {
  final rnd = Random(seed);
  final indices = List<int>.generate(_pool.length, (i) => i)..shuffle(rnd);
  final chosen = <DailyTaskDef>[];
  final usedGoals = <DailyGoal>{};
  for (final i in indices) {
    final def = _pool[i];
    if (usedGoals.contains(def.goal)) continue;
    usedGoals.add(def.goal);
    chosen.add(def);
    if (chosen.length == 3) break;
  }
  return chosen;
}
