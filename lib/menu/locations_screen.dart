import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/game_state.dart';
import '../widgets/ui_kit.dart';
import 'menu_background.dart';

class LocationsScreen extends StatelessWidget {
  const LocationsScreen({super.key});

  static const List<String> names = [
    'Brook Meadow',
    'Sunny Pasture',
    'Blossom Gardens',
    'Golden Fields',
    'Maple Hollow',
    'Cobble Village',
  ];

  static const List<String> subtitles = [
    'Where the trail begins',
    'Rolling green hills',
    'Fragrant flower beds',
    'Ripe wheat as far as the eye can see',
    'Cool shady woodlands',
    'The cosy heart of the farm',
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final unlocked = state.unlockedLocations;
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = (width / 360).floor().clamp(1, 3);

    return Scaffold(
      body: MenuBackground(
        child: SafeArea(
          child: Column(
            children: [
              MenuHeader(
                title: 'Farm Locations',
                trailing: _CountBadge(text: '$unlocked/6'),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(22, 6, 22, 22),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    mainAxisExtent: 168,
                  ),
                  itemCount: 6,
                  itemBuilder: (context, index) {
                    final isUnlocked = index < unlocked;
                    return _LocationCard(
                      index: index,
                      name: names[index],
                      subtitle: subtitles[index],
                      unlocked: isUnlocked,
                      unlockLevel: index * 5 + 1,
                    )
                        .animate()
                        .fadeIn(delay: (50 * index).ms)
                        .slideY(begin: 0.12, end: 0, curve: Curves.easeOut);
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

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.index,
    required this.name,
    required this.subtitle,
    required this.unlocked,
    required this.unlockLevel,
  });

  final int index;
  final String name;
  final String subtitle;
  final bool unlocked;
  final int unlockLevel;

  @override
  Widget build(BuildContext context) {
    final asset =
        'assets/Basketbrook_Trails_gameplay_assets/bg_location${index + 1}_asset.webp';
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: Offset(0, 6)),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(asset, fit: BoxFit.cover),
          if (!unlocked)
            Container(color: Colors.black.withValues(alpha: 0.5)),
          if (!unlocked)
            const Center(
              child: Icon(Icons.lock_rounded, color: Colors.white, size: 40),
            ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.65)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name, style: AppText.title(20, color: Colors.white)),
                  Text(
                    unlocked ? subtitle : 'Unlocks at level $unlockLevel',
                    style: AppText.label(12, color: Colors.white.withValues(alpha: 0.9)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
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
          const Icon(Icons.map_rounded, color: AppColors.sky, size: 20),
          const SizedBox(width: 6),
          Text(text, style: AppText.title(16, color: AppColors.ink)),
        ],
      ),
    );
  }
}
