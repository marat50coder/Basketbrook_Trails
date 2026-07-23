import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/audio.dart';
import '../core/game_state.dart';
import '../core/sprites.dart';
import '../widgets/ui_kit.dart';
import 'game_painter.dart';
import 'level.dart';
import 'world.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.levelNumber});

  final int levelNumber;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final GameState _state;
  late final LevelConfig _level;
  late final GameWorld _world;
  late final ui.Image _bg;
  late final Ticker _ticker;

  Duration _lastTick = Duration.zero;
  bool _resolved = false;
  double _roadPixels = 400;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _state = context.read<GameState>();
    _level = LevelConfig.generate(widget.levelNumber);
    _bg = _state.images.require(
        'assets/Basketbrook_Trails_gameplay_assets/bg_location${_level.bgIndex}_asset.webp');
    _world = GameWorld(
      level: _level,
      leaderSkin: _state.selectedSkin,
      onEvent: _onEvent,
      startingChickens: _state.startingChickens,
      shieldCharges: _state.shieldCharges,
      coinBonus: _state.coinBonus,
    );
    _state.audio.preload();
    _state.audio.startAmbient();

    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _state.audio.stopAmbient();
    _world.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    var dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0) return;
    if (dt > 0.05) dt = 0.05;

    _world.update(dt);

    if (!_resolved &&
        (_world.phase == GamePhase.won || _world.phase == GamePhase.lost)) {
      _resolved = true;
      _handleResult();
    }
  }

  void _onEvent(GameEvent event) {
    final audio = _state.audio;
    switch (event) {
      case GameEvent.go:
        audio.play(Sfx.levelStart);
        break;
      case GameEvent.collectChicken:
        audio.play(Sfx.collectChicken, volume: 0.8);
        break;
      case GameEvent.coin:
        audio.play(Sfx.coin, volume: 0.7);
        break;
      case GameEvent.eggLoss:
        audio.play(Sfx.eggLoss);
        break;
      case GameEvent.hit:
        audio.play(Sfx.hit, volume: 0.6);
        break;
      case GameEvent.gate:
        audio.play(Sfx.gate, volume: 0.8);
        break;
      case GameEvent.shield:
        audio.play(Sfx.gate, volume: 0.7);
        break;
      case GameEvent.win:
        audio.stopAmbient();
        audio.play(Sfx.deliver);
        break;
      case GameEvent.lose:
        audio.stopAmbient();
        audio.play(Sfx.failure);
        break;
    }
  }

  void _handleResult() {
    final won = _world.phase == GamePhase.won;
    _state.recordLevelResult(
      level: widget.levelNumber,
      won: won,
      stars: _world.stars,
      score: _world.score,
      eggsDelivered: _world.eggsDelivered,
      coinsCollected: _world.coins,
      coinsEarned: _world.coinsEarned,
      chickensCollected: _world.chickensCollected,
      eggsLost: _world.eggsLost,
      maxChain: _world.chickenCount,
    );
    if (won) {
      Future.delayed(const Duration(milliseconds: 500),
          () => _state.audio.play(Sfx.victory));
    }
  }

  void _steer(DragUpdateDetails d) {
    if (_world.phase == GamePhase.running) {
      _world.steer(d.delta.dy / _roadPixels);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_world.phase == GamePhase.running) {
          _world.togglePause();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.greenDeep,
        body: LayoutBuilder(
          builder: (context, constraints) {
            _roadPixels = constraints.maxHeight *
                (GamePainter.roadBottomF - GamePainter.roadTopF);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: _steer,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: GamePainter(
                          world: _world,
                          images: _state.images,
                          bg: _bg,
                        ),
                      ),
                    ),
                  ),
                  _Hud(world: _world, onPause: () => _world.togglePause()),
                  AnimatedBuilder(
                    animation: _world,
                    builder: (context, _) {
                      if (_world.phase == GamePhase.paused) {
                        return _PauseOverlay(
                          onResume: () => _world.togglePause(),
                          onRestart: _restart,
                          onMenu: () => Navigator.of(context).pop(),
                        );
                      }
                      if (_world.phase == GamePhase.won) {
                        return _ResultOverlay(
                          won: true,
                          world: _world,
                          level: widget.levelNumber,
                          onRestart: _restart,
                          onNext: _next,
                          onMenu: () => Navigator.of(context).pop(),
                        );
                      }
                      if (_world.phase == GamePhase.lost) {
                        return _ResultOverlay(
                          won: false,
                          world: _world,
                          level: widget.levelNumber,
                          onRestart: _restart,
                          onNext: _next,
                          onMenu: () => Navigator.of(context).pop(),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _restart() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameScreen(levelNumber: widget.levelNumber),
      ),
    );
  }

  void _next() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameScreen(levelNumber: widget.levelNumber + 1),
      ),
    );
  }
}

/// Top gameplay HUD: counters + progress + pause.
class _Hud extends StatelessWidget {
  const _Hud({required this.world, required this.onPause});

  final GameWorld world;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        child: AnimatedBuilder(
          animation: world,
          builder: (context, _) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RoundIconButton(
                  icon: Icons.pause_rounded,
                  onTap: onPause,
                  size: 46,
                ),
                const SizedBox(width: 12),
                StatChip(
                  icon: Image.asset(Sprites.chicken(world.leaderSkin)),
                  value: '${world.chickenCount}',
                ),
                const SizedBox(width: 8),
                StatChip(
                  icon: Image.asset(Sprites.egg(Sprites.eggWhite)),
                  value: '${world.eggCount}',
                ),
                const SizedBox(width: 8),
                StatChip(
                  icon: Image.asset(Sprites.coin(Sprites.coinFace)),
                  value: '${world.coins}',
                  color: AppColors.goldDark,
                ),
                const Spacer(),
                Expanded(
                  flex: 3,
                  child: _ProgressBar(world: world),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.world});
  final GameWorld world;

  @override
  Widget build(BuildContext context) {
    final gate = world.nextGate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          height: 20,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: Offset(0, 3)),
            ],
          ),
          child: Stack(
            children: [
              FractionallySizedBox(
                widthFactor: world.progress.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: AppColors.greenGradient),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Image.asset(Sprites.basket(Sprites.goalBasket), height: 26),
                ),
              ),
            ],
          ),
        ),
        if (gate != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Next gate: ${world.chickenCount}/${gate.value} chickens',
              style: AppText.label(12,
                  color: world.chickenCount >= gate.value
                      ? Colors.white
                      : AppColors.gold),
            ),
          ),
      ],
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({
    required this.onResume,
    required this.onRestart,
    required this.onMenu,
  });

  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: SoftCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Paused', style: AppText.title(24)),
              const SizedBox(height: 16),
              BigButton(
                  label: 'Resume',
                  icon: Icons.play_arrow_rounded,
                  onTap: onResume,
                  height: 52,
                  fontSize: 18),
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: BigButton(
                      label: 'Retry',
                      icon: Icons.refresh_rounded,
                      colors: AppColors.goldGradient,
                      onTap: onRestart,
                      height: 48,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BigButton(
                      label: 'Menu',
                      icon: Icons.home_rounded,
                      colors: const [Color(0xFFBFA98C), Color(0xFF8A7256)],
                      onTap: onMenu,
                      height: 48,
                      fontSize: 16,
                    ),
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

class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({
    required this.won,
    required this.world,
    required this.level,
    required this.onRestart,
    required this.onNext,
    required this.onMenu,
  });

  final bool won;
  final GameWorld world;
  final int level;
  final VoidCallback onRestart;
  final VoidCallback onNext;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: SoftCard(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  won ? 'Level Complete!' : 'Try Again',
                  style: AppText.title(22, color: won ? AppColors.greenDark : AppColors.danger),
                ),
                if (won) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      final earned = i < world.stars;
                      return Icon(
                        earned ? Icons.star_rounded : Icons.star_border_rounded,
                        color: earned ? AppColors.gold : AppColors.inkSoft,
                        size: 34,
                      );
                    }),
                  ),
                ] else ...[
                  const SizedBox(height: 6),
                  Text(world.lostReason,
                      textAlign: TextAlign.center,
                      style: AppText.label(13, color: AppColors.inkSoft)),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _resultStat(Sprites.egg(Sprites.eggWhite), '${world.eggsDelivered}', 'Eggs'),
                    const SizedBox(width: 16),
                    _resultStat(Sprites.coin(Sprites.coinFace), '+${world.coinsEarned}', 'Coins'),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: BigButton(
                        label: 'Retry',
                        icon: Icons.refresh_rounded,
                        colors: AppColors.goldGradient,
                        onTap: onRestart,
                        height: 48,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: won
                          ? BigButton(
                              label: 'Next',
                              icon: Icons.arrow_forward_rounded,
                              onTap: onNext,
                              height: 48,
                              fontSize: 16,
                            )
                          : BigButton(
                              label: 'Menu',
                              icon: Icons.home_rounded,
                              colors: const [Color(0xFFBFA98C), Color(0xFF8A7256)],
                              onTap: onMenu,
                              height: 48,
                              fontSize: 16,
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Pressable(
                  onTap: onMenu,
                  child: Text('Back to menu',
                      style: AppText.label(13, color: AppColors.inkSoft)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultStat(String asset, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(asset, height: 32),
        const SizedBox(height: 3),
        Text(value, style: AppText.title(18)),
        Text(label, style: AppText.label(11, color: AppColors.inkSoft)),
      ],
    );
  }
}
