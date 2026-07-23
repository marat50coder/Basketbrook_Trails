import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/app_theme.dart';
import '../core/sprites.dart';
import '../widgets/ui_kit.dart';
import 'menu_background.dart';

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final steps = <_Step>[
      _Step(Sprites.chicken(0), 'Lead the flock',
          'Drag up and down to steer your chicken along the winding trail.'),
      _Step(Sprites.chicken(6), 'Gather friends',
          'Touch other chickens to add them to your chain. A longer chain is stronger!'),
      _Step(Sprites.egg(Sprites.eggWhite), 'Protect the eggs',
          'Every chicken carries an egg. Hit an obstacle and it loses its egg.'),
      _Step(Sprites.fence(0), 'Open the gates',
          'Gates need a minimum number of chickens. Gather enough before you reach them.'),
      _Step(Sprites.basket(Sprites.goalBasket), 'Deliver to the basket',
          'Bring your eggs safely to the basket at the end to finish the level.'),
      _Step(Sprites.coin(Sprites.coinFace), 'Earn coins & stars',
          'Collect coins, earn stars and unlock new breeds, locations and rewards.'),
    ];

    return Scaffold(
      body: MenuBackground(
        child: SafeArea(
          child: Column(
            children: [
              const MenuHeader(title: 'How to Play'),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
                      itemCount: steps.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final s = steps[index];
                        return SoftCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.cream,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Image.asset(s.asset, fit: BoxFit.contain),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${index + 1}. ${s.title}',
                                        style: AppText.title(18)),
                                    const SizedBox(height: 4),
                                    Text(s.body,
                                        style: AppText.label(14, color: AppColors.inkSoft)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                            .animate()
                            .fadeIn(delay: (60 * index).ms)
                            .slideX(begin: 0.1, end: 0, curve: Curves.easeOut);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step {
  _Step(this.asset, this.title, this.body);
  final String asset;
  final String title;
  final String body;
}
