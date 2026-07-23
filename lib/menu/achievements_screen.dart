import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/game_state.dart';
import '../data/achievements.dart';
import '../widgets/ui_kit.dart';
import 'menu_background.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = (width / 340).floor().clamp(1, 3);
    final completed = kAchievements.where((a) => a.isComplete(state)).length;

    return Scaffold(
      body: MenuBackground(
        child: SafeArea(
          child: Column(
            children: [
              MenuHeader(
                title: 'Achievements',
                trailing: _CountBadge(text: '$completed/${kAchievements.length}'),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(22, 6, 22, 22),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 96,
                  ),
                  itemCount: kAchievements.length,
                  itemBuilder: (context, index) {
                    final a = kAchievements[index];
                    return _AchievementCard(achievement: a, state: state)
                        .animate()
                        .fadeIn(delay: (25 * index).ms)
                        .slideX(begin: 0.1, end: 0, curve: Curves.easeOut);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement, required this.state});
  final Achievement achievement;
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final current = achievement.currentOf(state);
    final done = achievement.isComplete(state);
    return SoftCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: done
                    ? AppColors.goldGradient
                    : const [Color(0xFFE7DFD0), Color(0xFFCFC4B0)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(achievement.icon,
                color: Colors.white, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(achievement.title,
                          style: AppText.title(17), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (done)
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.green, size: 20),
                  ],
                ),
                Text(
                  achievement.description,
                  style: AppText.label(12, color: AppColors.inkSoft),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                TrackBar(
                  value: current / achievement.goal,
                  height: 10,
                  colors: done ? AppColors.goldGradient : AppColors.greenGradient,
                ),
                const SizedBox(height: 3),
                Text('$current / ${achievement.goal}',
                    style: AppText.label(11, color: AppColors.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 20),
          const SizedBox(width: 6),
          Text(text, style: AppText.title(16, color: AppColors.ink)),
        ],
      ),
    );
  }
}
