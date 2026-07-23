import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/audio.dart';
import '../core/game_state.dart';
import '../core/sprites.dart';
import '../widgets/ui_kit.dart';
import 'menu_background.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();

    return Scaffold(
      body: MenuBackground(
        child: SafeArea(
          child: Column(
            children: [
              const MenuHeader(title: 'Profile'),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(22),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: SoftCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 96,
                                  height: 96,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                        colors: AppColors.greenGradient),
                                    borderRadius: BorderRadius.circular(28),
                                    boxShadow: const [
                                      BoxShadow(
                                          color: AppColors.shadow,
                                          blurRadius: 10,
                                          offset: Offset(0, 5)),
                                    ],
                                  ),
                                  child: Image.asset(
                                      Sprites.chicken(state.selectedSkin)),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(state.playerName,
                                                style: AppText.title(26),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis),
                                          ),
                                          const SizedBox(width: 8),
                                          Pressable(
                                            onTap: () => _editName(context, state),
                                            child: const Icon(Icons.edit_rounded,
                                                color: AppColors.inkSoft, size: 20),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text('Farm Level ${state.farmLevel}',
                                          style: AppText.label(15,
                                              color: AppColors.greenDark)),
                                      const SizedBox(height: 6),
                                      TrackBar(value: state.farmXp, height: 12),
                                      const SizedBox(height: 3),
                                      Text(
                                          '${(state.totalEggs % 25)}/25 eggs to next level',
                                          style: AppText.label(11,
                                              color: AppColors.inkSoft)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            Row(
                              children: [
                                _mini(Sprites.coin(Sprites.coinFace), '${state.coins}',
                                    'Coins'),
                                const SizedBox(width: 12),
                                _mini(Sprites.chicken(0), '${state.ownedSkins.length}/8',
                                    'Breeds'),
                                const SizedBox(width: 12),
                                _miniIcon(Icons.emoji_events_rounded,
                                    '${state.totalStars}', 'Stars', AppColors.gold),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).animate().fadeIn(duration: 300.ms).slideY(
                      begin: 0.08, end: 0, curve: Curves.easeOut),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mini(String asset, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Image.asset(asset, height: 30),
            const SizedBox(height: 4),
            Text(value, style: AppText.title(18)),
            Text(label, style: AppText.label(11, color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }

  Widget _miniIcon(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 4),
            Text(value, style: AppText.title(18)),
            Text(label, style: AppText.label(11, color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }

  void _editName(BuildContext context, GameState state) {
    state.audio.play(Sfx.click);
    final controller = TextEditingController(text: state.playerName);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: SoftCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Your name', style: AppText.title(22)),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                maxLength: 16,
                textCapitalization: TextCapitalization.words,
                style: AppText.title(18),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.cream,
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BigButton(
                    label: 'Cancel',
                    colors: const [Color(0xFFBFA98C), Color(0xFF8A7256)],
                    height: 50,
                    fontSize: 17,
                    onTap: () => Navigator.of(ctx).pop(),
                  ),
                  const SizedBox(width: 12),
                  BigButton(
                    label: 'Save',
                    height: 50,
                    fontSize: 17,
                    onTap: () {
                      state.setPlayerName(controller.text);
                      Navigator.of(ctx).pop();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
