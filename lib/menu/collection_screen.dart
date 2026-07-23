import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/audio.dart';
import '../core/game_state.dart';
import '../core/sprites.dart';
import '../widgets/ui_kit.dart';
import 'menu_background.dart';

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final owned = state.ownedSkins.length;
    final total = Sprites.skins.length;
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = (width / 190).floor().clamp(2, 6);

    return Scaffold(
      body: MenuBackground(
        child: SafeArea(
          child: Column(
            children: [
              MenuHeader(
                title: 'Collection',
                trailing: _PercentBadge(owned: owned, total: total),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
                child: TrackBar(value: owned / total, height: 12),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(22, 6, 22, 22),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: total,
                  itemBuilder: (context, index) {
                    final skin = Sprites.skins[index];
                    final isOwned = state.ownsSkin(skin.index);
                    final selected = state.selectedSkin == skin.index;
                    return _CollectionCard(
                      name: skin.name,
                      description: skin.description,
                      asset: Sprites.chicken(skin.index),
                      owned: isOwned,
                      selected: selected,
                      onTap: isOwned
                          ? () {
                              state.audio.play(Sfx.click);
                              state.selectSkin(skin.index);
                            }
                          : null,
                    )
                        .animate()
                        .fadeIn(delay: (35 * index).ms)
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

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.name,
    required this.description,
    required this.asset,
    required this.owned,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String description;
  final String asset;
  final bool owned;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
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
              child: owned
                  ? Image.asset(asset, fit: BoxFit.contain)
                  : ColorFiltered(
                      colorFilter: const ColorFilter.matrix(<double>[
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0, 0, 0, 1, 0,
                      ]),
                      child: Opacity(
                        opacity: 0.55,
                        child: Image.asset(asset, fit: BoxFit.contain),
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            Text(owned ? name : '???', style: AppText.title(16)),
            Text(
              owned ? description : 'Locked',
              style: AppText.label(11, color: AppColors.inkSoft),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _PercentBadge extends StatelessWidget {
  const _PercentBadge({required this.owned, required this.total});
  final int owned;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pct = (owned / total * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Text('$pct% • $owned/$total',
          style: AppText.title(15, color: AppColors.green)),
    );
  }
}
