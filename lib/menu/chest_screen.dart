import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/audio.dart';
import '../core/game_state.dart';
import '../core/sprites.dart';
import '../widgets/ui_kit.dart';
import 'menu_background.dart';

class ChestScreen extends StatelessWidget {
  const ChestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final hasChests = state.chests > 0;

    return Scaffold(
      body: MenuBackground(
        child: SafeArea(
          child: Column(
            children: [
              MenuHeader(title: 'Reward Chests', trailing: CoinBadge(coins: state.coins)),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(22),
                    child: SoftCard(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('You have', style: AppText.label(16, color: AppColors.inkSoft)),
                          const SizedBox(height: 6),
                          Text('${state.chests} chest${state.chests == 1 ? '' : 's'}',
                              style: AppText.title(30, color: AppColors.wood)),
                          const SizedBox(height: 20),
                          Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: hasChests
                                    ? const [Color(0xFFC9A063), Color(0xFF9A7238)]
                                    : const [Color(0xFFD8CDB8), Color(0xFFB4A992)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: const [
                                BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: Offset(0, 10)),
                              ],
                            ),
                            child: const Icon(Icons.inventory_2_rounded,
                                color: Colors.white, size: 84),
                          )
                              .animate(
                                  onPlay: (c) => hasChests ? c.repeat(reverse: true) : c.stop())
                              .moveY(begin: 0, end: -8, duration: 900.ms, curve: Curves.easeInOut),
                          const SizedBox(height: 24),
                          Text(
                            hasChests
                                ? 'Open a chest for coins or a rare chicken breed!'
                                : 'Win levels to earn more chests.',
                            textAlign: TextAlign.center,
                            style: AppText.label(15, color: AppColors.inkSoft),
                          ),
                          const SizedBox(height: 20),
                          BigButton(
                            label: 'Open Chest',
                            icon: Icons.lock_open_rounded,
                            colors: AppColors.goldGradient,
                            onTap: hasChests
                                ? () {
                                    final reward = state.openChest();
                                    state.audio.play(Sfx.reward);
                                    _showReward(context, reward);
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 300.ms),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReward(BuildContext context, ChestReward reward) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: SoftCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('You got', style: AppText.label(16, color: AppColors.inkSoft)),
              const SizedBox(height: 10),
              if (reward.skin != null) ...[
                Image.asset(Sprites.chicken(reward.skin!.index), height: 90)
                    .animate()
                    .scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1), curve: Curves.elasticOut, duration: 700.ms),
                const SizedBox(height: 8),
                Text('New breed: ${reward.skin!.name}!',
                    style: AppText.title(22, color: AppColors.greenDark)),
              ] else ...[
                Image.asset(Sprites.coin(Sprites.coinFace), height: 70)
                    .animate()
                    .scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1), curve: Curves.elasticOut, duration: 700.ms),
                const SizedBox(height: 8),
                Text('+${reward.coins} coins',
                    style: AppText.title(26, color: AppColors.goldDark)),
              ],
              const SizedBox(height: 18),
              BigButton(
                label: 'Awesome!',
                height: 50,
                fontSize: 18,
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
