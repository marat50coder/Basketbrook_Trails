import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/audio.dart';
import '../core/game_state.dart';
import '../webview/legal_content.dart';
import '../webview/web_page_screen.dart';
import '../widgets/ui_kit.dart';
import 'menu_background.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const String privacyUrl =
      'https://basketbrooktrails.com/privacy-policy.html';
  static const String supportUrl = 'https://basketbrooktrails.com/support.html';

  void _openWeb(BuildContext context, String title, String url, String html) {
    context.read<GameState>().audio.play(Sfx.click);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WebPageScreen(title: title, url: url, fallbackHtml: html),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
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
                    Text('Settings', style: AppText.title(26)),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: SoftCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ToggleRow(
                              icon: Icons.music_note_rounded,
                              label: 'Music',
                              value: state.musicOn,
                              onChanged: state.setMusic,
                            ),
                            const _Divider(),
                            _ToggleRow(
                              icon: Icons.volume_up_rounded,
                              label: 'Sound Effects',
                              value: state.soundOn,
                              onChanged: state.setSound,
                            ),
                            const _Divider(),
                            _LinkRow(
                              icon: Icons.privacy_tip_rounded,
                              label: 'Privacy Policy',
                              onTap: () => _openWeb(context, 'Privacy Policy',
                                  privacyUrl, LegalContent.privacyPolicy),
                            ),
                            const _Divider(),
                            _LinkRow(
                              icon: Icons.support_agent_rounded,
                              label: 'Support',
                              onTap: () => _openWeb(context, 'Support', supportUrl,
                                  LegalContent.support),
                            ),
                            const _Divider(),
                            _LinkRow(
                              icon: Icons.restart_alt_rounded,
                              label: 'Reset Progress',
                              danger: true,
                              onTap: () => _confirmReset(context, state),
                            ),
                            const SizedBox(height: 16),
                            Text('Basketbrook Trails • v1.0.0',
                                style: AppText.label(13, color: AppColors.inkSoft)),
                          ],
                        ),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context, GameState state) {
    state.audio.play(Sfx.click);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: SoftCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Reset progress?', style: AppText.title(24)),
              const SizedBox(height: 8),
              Text(
                'This will erase your coins, unlocked levels and chickens.',
                textAlign: TextAlign.center,
                style: AppText.label(15, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 18),
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
                    label: 'Reset',
                    colors: const [Color(0xFFF08A7A), Color(0xFFD9503C)],
                    height: 50,
                    fontSize: 17,
                    onTap: () {
                      state.resetProgress();
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

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.green, size: 26),
        const SizedBox(width: 14),
        Expanded(child: Text(label, style: AppText.title(19))),
        Switch(
          value: value,
          activeThumbColor: Colors.white,
          activeTrackColor: AppColors.green,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.ink;
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: danger ? AppColors.danger : AppColors.green, size: 26),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: AppText.title(19, color: color))),
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      color: AppColors.creamDeep,
      height: 22,
      thickness: 1.4,
    );
  }
}
