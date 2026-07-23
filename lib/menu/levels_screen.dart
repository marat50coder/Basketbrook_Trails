import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/audio.dart';
import '../core/game_state.dart';
import '../game/game_screen.dart';
import '../widgets/ui_kit.dart';
import 'menu_background.dart';

class LevelsScreen extends StatelessWidget {
  const LevelsScreen({super.key});

  static const int totalLevels = 30;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = (width / 150).floor().clamp(4, 8);

    return Scaffold(
      body: MenuBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(title: 'Select Level', coins: state.coins),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(22, 6, 22, 22),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1,
                  ),
                  itemCount: totalLevels,
                  itemBuilder: (context, index) {
                    final level = index + 1;
                    final unlocked = level <= state.unlockedLevel;
                    final stars = state.stars(level);
                    return _LevelTile(
                      level: level,
                      unlocked: unlocked,
                      stars: stars,
                      onTap: unlocked
                          ? () {
                              state.audio.play(Sfx.click);
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => GameScreen(levelNumber: level),
                              ));
                            }
                          : null,
                    )
                        .animate()
                        .fadeIn(delay: (20 * index).ms, duration: 260.ms)
                        .scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1));
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

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.level,
    required this.unlocked,
    required this.stars,
    required this.onTap,
  });

  final int level;
  final bool unlocked;
  final int stars;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: unlocked
                ? AppColors.creamGradient
                : const [Color(0xFFDBD3C4), Color(0xFFBFB6A4)],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 6)),
          ],
          border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (unlocked)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$level', style: AppText.title(30, color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      final on = i < stars;
                      return Icon(
                        on ? Icons.star_rounded : Icons.star_border_rounded,
                        size: 14,
                        color: on ? AppColors.gold : AppColors.inkSoft,
                      );
                    }),
                  ),
                ],
              )
            else
              const Icon(Icons.lock_rounded, color: Color(0xFF8A7256), size: 30),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.coins});
  final String title;
  final int coins;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
      child: Row(
        children: [
          RoundIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).pop(),
            size: 46,
          ),
          const SizedBox(width: 14),
          Text(title, style: AppText.title(26)),
          const Spacer(),
          Container(
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
                Image.asset('assets/sprites/coins/0.png', height: 24),
                const SizedBox(width: 6),
                Text('$coins', style: AppText.title(18, color: AppColors.goldDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
