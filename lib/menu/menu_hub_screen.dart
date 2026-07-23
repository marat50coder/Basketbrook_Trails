import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/audio.dart';
import '../core/game_state.dart';
import '../widgets/ui_kit.dart';
import 'achievements_screen.dart';
import 'chest_screen.dart';
import 'collection_screen.dart';
import 'credits_screen.dart';
import 'daily_reward_screen.dart';
import 'daily_tasks_screen.dart';
import 'how_to_play_screen.dart';
import 'locations_screen.dart';
import 'menu_background.dart';
import 'profile_screen.dart';
import 'records_screen.dart';
import 'statistics_screen.dart';
import 'upgrades_screen.dart';

class MenuHubScreen extends StatelessWidget {
  const MenuHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final width = MediaQuery.of(context).size.width;
    final cols = width >= 1100
        ? 4
        : width >= 720
            ? 3
            : 2;

    final tiles = <_HubTile>[
      _HubTile(
        Icons.card_giftcard_rounded,
        'Daily Reward',
        AppColors.goldGradient,
        const DailyRewardScreen(),
        badge: state.canClaimDailyReward ? '!' : null,
      ),
      _HubTile(Icons.upgrade_rounded, 'Upgrades',
          const [Color(0xFF6EC85B), Color(0xFF3E9A3A)], const UpgradesScreen()),
      _HubTile(Icons.checklist_rounded, 'Daily Tasks', AppColors.greenGradient,
          const DailyTasksScreen()),
      _HubTile(Icons.emoji_events_rounded, 'Achievements',
          const [Color(0xFFFFD65A), Color(0xFFF2A828)], const AchievementsScreen()),
      _HubTile(Icons.collections_rounded, 'Collection',
          const [Color(0xFF6EC85B), Color(0xFF3E9A3A)], const CollectionScreen()),
      _HubTile(Icons.map_rounded, 'Locations',
          const [Color(0xFF8FD0F0), Color(0xFF4FA9D8)], const LocationsScreen()),
      _HubTile(Icons.bar_chart_rounded, 'Statistics',
          const [Color(0xFFB89BE0), Color(0xFF8A63C8)], const StatisticsScreen()),
      _HubTile(Icons.leaderboard_rounded, 'Records',
          const [Color(0xFFF6A96B), Color(0xFFE07E3A)], const RecordsScreen()),
      _HubTile(
        Icons.inventory_2_rounded,
        'Chests',
        const [Color(0xFFC9A063), Color(0xFF9A7238)],
        const ChestScreen(),
        badge: state.chests > 0 ? '${state.chests}' : null,
      ),
      _HubTile(Icons.person_rounded, 'Profile',
          const [Color(0xFF7FC8A9), Color(0xFF4E9E7E)], const ProfileScreen()),
      _HubTile(Icons.help_outline_rounded, 'How to Play',
          const [Color(0xFF9FB8CC), Color(0xFF6E8AA6)], const HowToPlayScreen()),
      _HubTile(Icons.info_outline_rounded, 'About',
          const [Color(0xFFBFA98C), Color(0xFF8A7256)], const CreditsScreen()),
    ];

    return Scaffold(
      body: MenuBackground(
        child: SafeArea(
          child: Column(
            children: [
              MenuHeader(title: 'Menu', trailing: CoinBadge(coins: state.coins)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                  child: _HubGrid(tiles: tiles, cols: cols),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubTile {
  const _HubTile(this.icon, this.label, this.colors, this.page, {this.badge});
  final IconData icon;
  final String label;
  final List<Color> colors;
  final Widget page;
  final String? badge;
}

/// A non-scrolling grid that stretches every tile to fill the screen height,
/// so the whole menu fits at once without scrolling.
class _HubGrid extends StatelessWidget {
  const _HubGrid({required this.tiles, required this.cols});
  final List<_HubTile> tiles;
  final int cols;

  @override
  Widget build(BuildContext context) {
    final rows = (tiles.length / cols).ceil();
    var index = 0;
    return Column(
      children: [
        for (var r = 0; r < rows; r++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  for (var c = 0; c < cols; c++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: c == 0 ? 0 : 5, right: c == cols - 1 ? 0 : 5),
                        child: _cell(context, r * cols + c, index++),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _cell(BuildContext context, int tileIndex, int order) {
    if (tileIndex >= tiles.length) return const SizedBox.shrink();
    final t = tiles[tileIndex];
    return MenuTile(
      icon: t.icon,
      title: t.label,
      accent: t.colors,
      badge: t.badge,
      compact: true,
      onTap: () {
        context.read<GameState>().audio.play(Sfx.click);
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => t.page));
      },
    )
        .animate()
        .fadeIn(delay: (28 * order).ms, duration: 220.ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOut);
  }
}
