import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/audio.dart';
import '../core/game_state.dart';
import '../core/sprites.dart';
import '../data/upgrades.dart';
import '../widgets/ui_kit.dart';
import 'menu_background.dart';

class UpgradesScreen extends StatelessWidget {
  const UpgradesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    return Scaffold(
      body: MenuBackground(
        child: SafeArea(
          child: Column(
            children: [
              MenuHeader(title: 'Upgrades', trailing: CoinBadge(coins: state.coins)),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                  children: [
                    for (var i = 0; i < kUpgrades.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _UpgradeCard(def: kUpgrades[i], state: state)
                            .animate()
                            .fadeIn(delay: (60 * i).ms)
                            .slideY(begin: 0.12, end: 0, curve: Curves.easeOut),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({required this.def, required this.state});
  final UpgradeDef def;
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final level = state.upgradeLevel(def.key);
    final cost = state.upgradeCost(def.key);
    final maxed = cost == null;
    final canAfford = cost != null && state.coins >= cost;

    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          IconChip(icon: def.icon, colors: def.colors, size: 54),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(def.title, style: AppText.title(18))),
                    _LevelDots(level: level, max: def.maxLevel, colors: def.colors),
                  ],
                ),
                const SizedBox(height: 4),
                Text(def.effectAt(level),
                    style: AppText.label(13, color: AppColors.inkSoft),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (!maxed) ...[
                  const SizedBox(height: 2),
                  Text('Next: ${def.effectAt(level + 1)}',
                      style: AppText.label(12, color: AppColors.green),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          maxed
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.greenDark,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text('MAX', style: AppText.title(15, color: Colors.white)),
                )
              : _BuyButton(
                  cost: cost,
                  enabled: canAfford,
                  onTap: () {
                    if (state.buyUpgrade(def.key)) {
                      state.audio.play(Sfx.reward);
                    } else {
                      state.audio.play(Sfx.click);
                    }
                  },
                ),
        ],
      ),
    );
  }
}

class _LevelDots extends StatelessWidget {
  const _LevelDots({required this.level, required this.max, required this.colors});
  final int level;
  final int max;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(max, (i) {
        final filled = i < level;
        return Container(
          margin: const EdgeInsets.only(left: 4),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            gradient: filled ? LinearGradient(colors: colors) : null,
            color: filled ? null : AppColors.creamDeep,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

class _BuyButton extends StatelessWidget {
  const _BuyButton({required this.cost, required this.enabled, required this.onTap});
  final int cost;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: AppColors.goldGradient),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(Sprites.coin(Sprites.coinFace), height: 22),
              const SizedBox(width: 6),
              Text('$cost', style: AppText.title(16, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}
