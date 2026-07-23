import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/audio.dart';
import '../core/game_state.dart';
import '../core/sprites.dart';
import '../widgets/ui_kit.dart';
import 'menu_background.dart';

class DailyRewardScreen extends StatelessWidget {
  const DailyRewardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final canClaim = state.canClaimDailyReward;
    final currentDay = state.dailyRewardDay;

    return Scaffold(
      body: MenuBackground(
        child: SafeArea(
          child: Column(
            children: [
              MenuHeader(title: 'Daily Reward', trailing: CoinBadge(coins: state.coins)),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(22),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: SoftCard(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              canClaim ? 'Your reward is ready!' : 'Come back tomorrow',
                              style: AppText.title(24, color: AppColors.greenDark),
                            ),
                            const SizedBox(height: 4),
                            Text('Log in every day for bigger rewards',
                                style: AppText.label(14, color: AppColors.inkSoft)),
                            const SizedBox(height: 18),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 10,
                              runSpacing: 10,
                              children: List.generate(7, (i) {
                                final day = i + 1;
                                final reward = GameState.dailyRewardTable[i];
                                final claimedDay = canClaim ? day < currentDay : day <= currentDay;
                                final isToday = canClaim && day == currentDay;
                                return _DayTile(
                                  day: day,
                                  reward: reward,
                                  claimed: claimedDay,
                                  highlight: isToday,
                                  big: day == 7,
                                );
                              }),
                            ),
                            const SizedBox(height: 22),
                            BigButton(
                              label: canClaim ? 'Claim' : 'Claimed',
                              icon: canClaim
                                  ? Icons.card_giftcard_rounded
                                  : Icons.check_rounded,
                              onTap: canClaim
                                  ? () {
                                      final reward = state.claimDailyReward();
                                      state.audio.play(Sfx.reward);
                                      _showClaimed(context, reward);
                                    }
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).animate().fadeIn(duration: 300.ms).scale(
                      begin: const Offset(0.94, 0.94), end: const Offset(1, 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClaimed(BuildContext context, int reward) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: SoftCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(Sprites.coin(Sprites.coinFace), height: 60)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.1, 1.1),
                      duration: 700.ms),
              const SizedBox(height: 10),
              Text('+$reward coins', style: AppText.title(26, color: AppColors.goldDark)),
              const SizedBox(height: 16),
              BigButton(
                label: 'Great!',
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

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.day,
    required this.reward,
    required this.claimed,
    required this.highlight,
    required this.big,
  });

  final int day;
  final int reward;
  final bool claimed;
  final bool highlight;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: big ? 150 : 86,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: claimed
              ? const [Color(0xFFDDEFD4), Color(0xFFC4E3B6)]
              : (big ? AppColors.goldGradient : AppColors.creamGradient),
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlight ? AppColors.green : Colors.white.withValues(alpha: 0.8),
          width: highlight ? 3 : 2,
        ),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(big ? 'Day 7' : 'Day $day',
              style: AppText.label(12,
                  color: big ? Colors.white : AppColors.inkSoft, weight: FontWeight.w800)),
          const SizedBox(height: 6),
          Image.asset(Sprites.coin(Sprites.coinFace), height: big ? 44 : 30),
          const SizedBox(height: 4),
          Text('+$reward',
              style: AppText.title(big ? 20 : 16,
                  color: big ? Colors.white : AppColors.goldDark)),
          if (claimed) ...[
            const SizedBox(height: 2),
            const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 18),
          ],
        ],
      ),
    );
  }
}
