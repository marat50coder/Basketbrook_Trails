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
import 'settings_screen.dart';

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  void _openWeb(BuildContext context, String title, String url, String html) {
    context.read<GameState>().audio.play(Sfx.click);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WebPageScreen(title: title, url: url, fallbackHtml: html),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MenuBackground(
        child: SafeArea(
          child: Column(
            children: [
              const MenuHeader(title: 'About'),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(22),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: SoftCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/Basketbrook_Trails_additional_assets/Game_Name.webp',
                              height: 130,
                            ).animate().scale(
                                begin: const Offset(0.8, 0.8),
                                end: const Offset(1, 1),
                                curve: Curves.elasticOut,
                                duration: 600.ms),
                            const SizedBox(height: 8),
                            Text(
                              'Guide a cheerful chain of chickens along scenic farm '
                              'trails, gather friends, dodge obstacles and deliver '
                              'every egg safely to the basket.',
                              textAlign: TextAlign.center,
                              style: AppText.label(15, color: AppColors.inkSoft),
                            ),
                            const SizedBox(height: 20),
                            const _InfoRow(label: 'Version', value: '1.0.0'),
                            const _InfoRow(label: 'Genre', value: 'Casual • Puzzle'),
                            const _InfoRow(
                                label: 'Play', value: 'Fully offline'),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: BigButton(
                                    label: 'Privacy',
                                    icon: Icons.privacy_tip_rounded,
                                    height: 52,
                                    fontSize: 17,
                                    colors: const [Color(0xFF9FB8CC), Color(0xFF6E8AA6)],
                                    onTap: () => _openWeb(
                                        context,
                                        'Privacy Policy',
                                        SettingsScreen.privacyUrl,
                                        LegalContent.privacyPolicy),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: BigButton(
                                    label: 'Support',
                                    icon: Icons.support_agent_rounded,
                                    height: 52,
                                    fontSize: 17,
                                    onTap: () => _openWeb(
                                        context,
                                        'Support',
                                        SettingsScreen.supportUrl,
                                        LegalContent.support),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text('© 2026 Basketbrook Trails',
                                style: AppText.label(13, color: AppColors.inkSoft)),
                          ],
                        ),
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
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: AppText.label(15, color: AppColors.inkSoft)),
          const Spacer(),
          Text(value, style: AppText.title(16)),
        ],
      ),
    );
  }
}
