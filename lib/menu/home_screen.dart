import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/audio.dart';
import '../core/game_state.dart';
import '../core/sprites.dart';
import '../widgets/ui_kit.dart';
import 'achievements_screen.dart';
import 'daily_reward_screen.dart';
import 'levels_screen.dart';
import 'locations_screen.dart';
import 'menu_background.dart';
import 'menu_hub_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';
import 'statistics_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _go(BuildContext context, Widget page) {
    context.read<GameState>().audio.play(Sfx.click);
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, a, _) => page,
        transitionsBuilder: (_, a, _, child) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(
              CurvedAnimation(parent: a, curve: Curves.easeOut),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    return Scaffold(
      body: MenuBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: _ProfileCard(
                        state: state,
                        onTap: () => _go(context, const MenuHubScreen()),
                      ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.2, end: 0),
                    ),
                    const Spacer(),
                    _GiftButton(
                      showBadge: state.canClaimDailyReward,
                      onTap: () => _go(context, const DailyRewardScreen()),
                    ),
                    const SizedBox(width: 10),
                    _CoinPill(coins: state.coins),
                  ],
                ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Center(
                          child: Image.asset(
                            'assets/Basketbrook_Trails_additional_assets/Game_Name.webp',
                            fit: BoxFit.contain,
                          )
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .moveY(
                                  begin: -7,
                                  end: 7,
                                  duration: 2800.ms,
                                  curve: Curves.easeInOut),
                        ),
                      ),
                      const SizedBox(width: 22),
                      Expanded(
                        flex: 6,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            BigButton(
                              label: 'Play',
                              icon: Icons.play_arrow_rounded,
                              colors: AppColors.greenGradient,
                              height: 76,
                              fontSize: 28,
                              onTap: () => _go(context, const LevelsScreen()),
                            )
                                .animate()
                                .fadeIn(delay: 120.ms)
                                .slideX(begin: 0.25, end: 0, curve: Curves.easeOutBack),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: MenuTile(
                                    icon: Icons.pets_rounded,
                                    title: 'Chickens',
                                    accent: AppColors.goldGradient,
                                    onTap: () => _go(context, const ShopScreen()),
                                  )
                                      .animate()
                                      .fadeIn(delay: 240.ms)
                                      .slideX(begin: 0.25, end: 0, curve: Curves.easeOut),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: MenuTile(
                                    icon: Icons.grid_view_rounded,
                                    title: 'Menu',
                                    accent: const [Color(0xFF8FD0F0), Color(0xFF4FA9D8)],
                                    onTap: () => _go(context, const MenuHubScreen()),
                                  )
                                      .animate()
                                      .fadeIn(delay: 320.ms)
                                      .slideX(begin: 0.25, end: 0, curve: Curves.easeOut),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _Dock(
                  onDaily: () => _go(context, const DailyRewardScreen()),
                  onAchievements: () => _go(context, const AchievementsScreen()),
                  onStats: () => _go(context, const StatisticsScreen()),
                  onLocations: () => _go(context, const LocationsScreen()),
                  onSettings: () => _go(context, const SettingsScreen()),
                  dailyBadge: state.canClaimDailyReward,
                ).animate().fadeIn(delay: 400.ms, duration: 400.ms).slideY(begin: 0.4, end: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Player card: avatar, name, farm level and a slim XP bar.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.state, required this.onTap});
  final GameState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 18, 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(color: AppColors.shadow, blurRadius: 14, offset: Offset(0, 7)),
          ],
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.greenGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Image.asset(Sprites.chicken(state.selectedSkin)),
            ),
            const SizedBox(width: 11),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(state.playerName,
                    style: AppText.title(16), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: AppColors.greenGradient),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text('Lv ${state.farmLevel}',
                          style: AppText.label(11, color: Colors.white)),
                    ),
                    const SizedBox(width: 7),
                    SizedBox(width: 70, child: TrackBar(value: state.farmXp, height: 8)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom quick-access dock — a single elevated bar with icon shortcuts.
class _Dock extends StatelessWidget {
  const _Dock({
    required this.onDaily,
    required this.onAchievements,
    required this.onStats,
    required this.onLocations,
    required this.onSettings,
    required this.dailyBadge,
  });

  final VoidCallback onDaily;
  final VoidCallback onAchievements;
  final VoidCallback onStats;
  final VoidCallback onLocations;
  final VoidCallback onSettings;
  final bool dailyBadge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: Offset(0, 8)),
        ],
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _DockButton(
            icon: Icons.card_giftcard_rounded,
            label: 'Daily',
            colors: AppColors.goldGradient,
            onTap: onDaily,
            badge: dailyBadge,
          ),
          _DockButton(
            icon: Icons.emoji_events_rounded,
            label: 'Awards',
            colors: const [Color(0xFFFFD65A), Color(0xFFF2A828)],
            onTap: onAchievements,
          ),
          _DockButton(
            icon: Icons.bar_chart_rounded,
            label: 'Stats',
            colors: const [Color(0xFFB89BE0), Color(0xFF8A63C8)],
            onTap: onStats,
          ),
          _DockButton(
            icon: Icons.map_rounded,
            label: 'Map',
            colors: const [Color(0xFF8FD0F0), Color(0xFF4FA9D8)],
            onTap: onLocations,
          ),
          _DockButton(
            icon: Icons.settings_rounded,
            label: 'Settings',
            colors: const [Color(0xFFBFC7D0), Color(0xFF8A97A6)],
            onTap: onSettings,
          ),
        ],
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
    this.badge = false,
  });

  final IconData icon;
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconChip(icon: icon, colors: colors, size: 42),
                if (badge)
                  Positioned(
                    right: -3,
                    top: -3,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(label, style: AppText.label(11, color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }
}

class _GiftButton extends StatelessWidget {
  const _GiftButton({required this.showBadge, required this.onTap});
  final bool showBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        RoundIconButton(
          icon: Icons.card_giftcard_rounded,
          iconColor: AppColors.goldDark,
          onTap: onTap,
          size: 48,
        ),
        if (showBadge)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class _CoinPill extends StatelessWidget {
  const _CoinPill({required this.coins});
  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: Offset(0, 6)),
        ],
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(Sprites.coin(Sprites.coinFace), height: 26),
          const SizedBox(width: 8),
          Text('$coins', style: AppText.title(20, color: AppColors.goldDark)),
        ],
      ),
    );
  }
}
