import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/audio.dart';
import '../core/game_state.dart';
import '../core/sprites.dart';
import '../widgets/ui_kit.dart';
import 'menu_background.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = (width / 200).floor().clamp(2, 5);

    return Scaffold(
      body: MenuBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
                child: Row(
                  children: [
                    RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.of(context).pop(),
                      size: 46,
                    ),
                    const SizedBox(width: 14),
                    Text('Chicken Coop', style: AppText.title(26)),
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
                          Image.asset(Sprites.coin(Sprites.coinFace), height: 24),
                          const SizedBox(width: 6),
                          Text('${state.coins}',
                              style: AppText.title(18, color: AppColors.goldDark)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(22, 6, 22, 22),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: Sprites.skins.length,
                  itemBuilder: (context, index) {
                    final skin = Sprites.skins[index];
                    final owned = state.ownsSkin(skin.index);
                    final selected = state.selectedSkin == skin.index;
                    return _SkinCard(
                      skin: skin,
                      owned: owned,
                      selected: selected,
                      canAfford: state.coins >= skin.price,
                      onTap: () {
                        state.audio.play(Sfx.click);
                        if (owned) {
                          state.selectSkin(skin.index);
                        } else {
                          final ok = state.buySkin(skin);
                          if (ok) state.audio.play(Sfx.reward);
                        }
                      },
                    )
                        .animate()
                        .fadeIn(delay: (40 * index).ms)
                        .slideY(begin: 0.15, end: 0, curve: Curves.easeOut);
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

class _SkinCard extends StatelessWidget {
  const _SkinCard({
    required this.skin,
    required this.owned,
    required this.selected,
    required this.canAfford,
    required this.onTap,
  });

  final ChickenSkin skin;
  final bool owned;
  final bool selected;
  final bool canAfford;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppColors.green : Colors.white.withValues(alpha: 0.8),
            width: selected ? 3 : 2,
          ),
          boxShadow: const [
            BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 6)),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(Sprites.chicken(skin.index), fit: BoxFit.contain),
                  if (!owned)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Icon(Icons.lock_rounded,
                          color: AppColors.inkSoft.withValues(alpha: 0.7), size: 20),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(skin.name, style: AppText.title(17)),
            const SizedBox(height: 6),
            _actionChip(),
          ],
        ),
      ),
    );
  }

  Widget _actionChip() {
    if (selected) {
      return _chip('Selected', AppColors.green, Icons.check_rounded);
    }
    if (owned) {
      return _chip('Select', AppColors.wood, null);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: canAfford
              ? AppColors.goldGradient
              : const [Color(0xFFCFC4B0), Color(0xFFB4A992)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(Sprites.coin(Sprites.coinFace), height: 18),
          const SizedBox(width: 5),
          Text('${skin.price}',
              style: AppText.title(15, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color, IconData? icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 4),
          ],
          Text(label, style: AppText.title(15, color: Colors.white)),
        ],
      ),
    );
  }
}
