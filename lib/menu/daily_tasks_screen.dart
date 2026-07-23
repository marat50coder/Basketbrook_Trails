import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/audio.dart';
import '../core/game_state.dart';
import '../core/sprites.dart';
import '../data/daily.dart';
import '../widgets/ui_kit.dart';
import 'menu_background.dart';

class DailyTasksScreen extends StatelessWidget {
  const DailyTasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final tasks = state.dailyTasks();

    return Scaffold(
      body: MenuBackground(
        child: SafeArea(
          child: Column(
            children: [
              MenuHeader(title: 'Daily Tasks', trailing: CoinBadge(coins: state.coins)),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Text(
                  'Fresh tasks every day. Complete them while playing to earn coins!',
                  style: AppText.label(14, color: AppColors.inkSoft),
                ),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
                      itemCount: tasks.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _TaskCard(
                          task: tasks[index],
                          onClaim: () {
                            if (state.claimDailyTask(index)) {
                              state.audio.play(Sfx.reward);
                            }
                          },
                        )
                            .animate()
                            .fadeIn(delay: (60 * index).ms)
                            .slideY(begin: 0.15, end: 0, curve: Curves.easeOut);
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
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.onClaim});
  final DailyTaskState task;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final done = task.complete;
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppColors.greenGradient),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(task.def.icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.def.title, style: AppText.title(17)),
                const SizedBox(height: 6),
                TrackBar(value: task.progress / task.def.target, height: 12),
                const SizedBox(height: 3),
                Text('${task.progress} / ${task.def.target}',
                    style: AppText.label(12, color: AppColors.inkSoft)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _rewardButton(done),
        ],
      ),
    );
  }

  Widget _rewardButton(bool done) {
    if (task.claimed) {
      return Column(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 30),
          Text('Done', style: AppText.label(12, color: AppColors.inkSoft)),
        ],
      );
    }
    return Pressable(
      onTap: done ? onClaim : null,
      child: Opacity(
        opacity: done ? 1 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: AppColors.goldGradient),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(Sprites.coin(Sprites.coinFace), height: 20),
              const SizedBox(height: 2),
              Text('+${task.def.reward}',
                  style: AppText.title(15, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}
