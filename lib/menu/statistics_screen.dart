import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/game_state.dart';
import '../widgets/ui_kit.dart';
import 'menu_background.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<GameState>();
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = (width / 240).floor().clamp(2, 5);

    final winRate = s.gamesPlayed == 0
        ? 0
        : (s.gamesWon / s.gamesPlayed * 100).round();

    final stats = <_Stat>[
      _Stat(Icons.sports_esports_rounded, 'Games Played', '${s.gamesPlayed}',
          const [Color(0xFF8FD0F0), Color(0xFF4FA9D8)]),
      _Stat(Icons.emoji_events_rounded, 'Games Won', '${s.gamesWon}',
          AppColors.greenGradient),
      _Stat(Icons.percent_rounded, 'Win Rate', '$winRate%',
          const [Color(0xFFB89BE0), Color(0xFF8A63C8)]),
      _Stat(Icons.pets_rounded, 'Chickens Gathered', '${s.totalChickens}',
          const [Color(0xFFFFD65A), Color(0xFFF2A828)]),
      _Stat(Icons.egg_rounded, 'Eggs Delivered', '${s.totalEggs}',
          const [Color(0xFF7FC8A9), Color(0xFF4E9E7E)]),
      _Stat(Icons.heart_broken_rounded, 'Eggs Lost', '${s.totalEggsLost}',
          const [Color(0xFFF08A7A), Color(0xFFD9503C)]),
      _Stat(Icons.monetization_on_rounded, 'Coins Earned', '${s.totalCoinsEarned}',
          AppColors.goldGradient),
      _Stat(Icons.star_rounded, 'Stars Earned', '${s.totalStars}',
          const [Color(0xFFFFC531), Color(0xFFE8A21C)]),
      _Stat(Icons.timeline_rounded, 'Longest Chain', '${s.bestChain}',
          const [Color(0xFFF6A96B), Color(0xFFE07E3A)]),
      _Stat(Icons.flag_rounded, 'Levels Unlocked', '${s.unlockedLevel - 1}',
          const [Color(0xFF9FB8CC), Color(0xFF6E8AA6)]),
    ];

    return Scaffold(
      body: MenuBackground(
        child: SafeArea(
          child: Column(
            children: [
              const MenuHeader(title: 'Statistics'),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(22, 6, 22, 22),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 104,
                  ),
                  itemCount: stats.length,
                  itemBuilder: (context, index) {
                    final st = stats[index];
                    return _StatCard(stat: st)
                        .animate()
                        .fadeIn(delay: (30 * index).ms)
                        .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1));
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

class _Stat {
  const _Stat(this.icon, this.label, this.value, this.colors);
  final IconData icon;
  final String label;
  final String value;
  final List<Color> colors;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});
  final _Stat stat;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: stat.colors),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(stat.icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stat.value, style: AppText.title(24)),
                Text(stat.label,
                    style: AppText.label(12, color: AppColors.inkSoft),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
