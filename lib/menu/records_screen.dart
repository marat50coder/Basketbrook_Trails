import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/game_state.dart';
import '../widgets/ui_kit.dart';
import 'levels_screen.dart';
import 'menu_background.dart';

class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final playedLevels = <int>[];
    for (var lvl = 1; lvl <= LevelsScreen.totalLevels; lvl++) {
      if (state.bestScore(lvl) > 0 || state.stars(lvl) > 0) playedLevels.add(lvl);
    }
    final totalStars = state.totalStars;

    return Scaffold(
      body: MenuBackground(
        child: SafeArea(
          child: Column(
            children: [
              MenuHeader(
                title: 'Records',
                trailing: _StarsBadge(stars: totalStars),
              ),
              Expanded(
                child: playedLevels.isEmpty
                    ? _empty()
                    : Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
                            itemCount: playedLevels.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final lvl = playedLevels[index];
                              return _RecordRow(
                                level: lvl,
                                score: state.bestScore(lvl),
                                stars: state.stars(lvl),
                              )
                                  .animate()
                                  .fadeIn(delay: (30 * index).ms)
                                  .slideX(begin: 0.08, end: 0, curve: Curves.easeOut);
                            },
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.leaderboard_rounded, size: 60, color: AppColors.inkSoft),
          const SizedBox(height: 12),
          Text('No records yet', style: AppText.title(22, color: AppColors.inkSoft)),
          const SizedBox(height: 4),
          Text('Play a level to set your first record!',
              style: AppText.label(14, color: AppColors.inkSoft)),
        ],
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.level, required this.score, required this.stars});
  final int level;
  final int score;
  final int stars;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppColors.greenGradient),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text('$level', style: AppText.title(20, color: Colors.white)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Level $level', style: AppText.title(18)),
                Text('Best score: $score',
                    style: AppText.label(13, color: AppColors.inkSoft)),
              ],
            ),
          ),
          Row(
            children: List.generate(3, (i) {
              final on = i < stars;
              return Icon(
                on ? Icons.star_rounded : Icons.star_border_rounded,
                color: on ? AppColors.gold : AppColors.inkSoft,
                size: 22,
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _StarsBadge extends StatelessWidget {
  const _StarsBadge({required this.stars});
  final int stars;

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
          const Icon(Icons.star_rounded, color: AppColors.gold, size: 20),
          const SizedBox(width: 6),
          Text('$stars', style: AppText.title(16, color: AppColors.ink)),
        ],
      ),
    );
  }
}
