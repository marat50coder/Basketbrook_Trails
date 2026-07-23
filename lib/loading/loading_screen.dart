import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/app_theme.dart';
import '../core/image_bank.dart';

/// Adaptive splash / loading screen.
///
/// * Uses the vertical **or** horizontal artwork depending on the device
///   orientation.
/// * The progress bar starts empty and fills strictly left → right, only
///   reaching 100% right before the game launches.
/// * "Loading" (with animated dots) sits above the bar, the percentage below.
/// * Guaranteed to finish within 10 seconds and never stalls short of 100%.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({
    super.key,
    required this.images,
    required this.onComplete,
  });

  final ImageBank images;
  final VoidCallback onComplete;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  static const double _minDuration = 2.8; // pleasant minimum, seconds
  static const double _maxDuration = 9.0; // hard safety cap, seconds

  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _elapsed = 0;

  double _displayed = 0; // shown fill 0..1
  double _realFrac = 0; // actual asset load progress 0..1
  bool _preloadDone = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _startPreload();
    _ticker = createTicker(_onTick)..start();
  }

  Future<void> _startPreload() async {
    try {
      await widget.images.preload(
        widget.images.gameplayManifest(),
        onProgress: (f) {
          if (mounted) _realFrac = f;
        },
      );
    } catch (_) {
      // Even if something fails to decode we still let the player in; assets
      // are bundled so this should not happen in practice.
    } finally {
      _preloadDone = true;
    }
  }

  void _onTick(Duration now) {
    final dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    if (dt <= 0) return;
    _elapsed += dt;

    // Target the bar can move toward. Hold below 90% until the real work is
    // actually finished so the fill only completes right before launch.
    final timeFloor = (_elapsed / _minDuration).clamp(0.0, 0.9);
    final safety = _elapsed >= _maxDuration;
    final done = _preloadDone || safety;
    final target = done ? 1.0 : (_realFrac.clamp(0.0, 0.9)).clamp(timeFloor, 0.9);

    // Ease toward the target, but always crawl a minimum amount so the bar can
    // never freeze (this is what avoids the classic "stuck at 97%").
    final ease = (target - _displayed) * (dt * 3.2);
    final crawl = done ? dt * 0.6 : dt * 0.10;
    _displayed = (_displayed + (ease > crawl ? ease : crawl)).clamp(0.0, target);
    if (_displayed > target) _displayed = target;

    if (!_finished &&
        done &&
        _displayed >= 0.999 &&
        _elapsed >= _minDuration) {
      _finished = true;
      _displayed = 1.0;
      _ticker.stop();
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onComplete());
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_displayed * 100).clamp(0, 100).floor();
    final dots = '.' * ((_elapsed * 2).floor() % 4);

    return Scaffold(
      backgroundColor: AppColors.greenDeep,
      body: OrientationBuilder(
        builder: (context, orientation) {
          final isLandscape = orientation == Orientation.landscape;
          final asset = isLandscape
              ? 'assets/Basketbrook_Trails_additional_assets/Horizontal_Loading_Screen.webp'
              : 'assets/Basketbrook_Trails_additional_assets/Vertical_Loading_Screen.webp';
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(asset, fit: BoxFit.cover),
              _buildProgressArea(context, isLandscape, percent, dots),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgressArea(
      BuildContext context, bool isLandscape, int percent, String dots) {
    final size = MediaQuery.of(context).size;
    final barWidth =
        isLandscape ? size.width * 0.44 : size.width * 0.74;
    final barHeight = isLandscape ? 16.0 : 22.0;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Loading$dots',
          textAlign: TextAlign.center,
          style: AppText.title(isLandscape ? 22 : 26, color: Colors.white).copyWith(
            shadows: const [
              Shadow(color: Color(0xCC000000), blurRadius: 10, offset: Offset(0, 2)),
            ],
          ),
        ),
        SizedBox(height: isLandscape ? 10 : 14),
        _ProgressBar(
          width: barWidth,
          height: barHeight,
          value: _displayed,
        ),
        SizedBox(height: isLandscape ? 8 : 12),
        Text(
          '$percent%',
          textAlign: TextAlign.center,
          style: AppText.title(isLandscape ? 20 : 24, color: Colors.white).copyWith(
            shadows: const [
              Shadow(color: Color(0xCC000000), blurRadius: 10, offset: Offset(0, 2)),
            ],
          ),
        ),
      ],
    );

    if (isLandscape) {
      // Horizontal: smaller bar, text + percentage centred, anchored to the
      // bottom of the screen.
      return Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.only(bottom: size.height * 0.06),
          child: content,
        ),
      );
    }
    // Vertical: sit in the lower third.
    return Align(
      alignment: const Alignment(0, 0.62),
      child: content,
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.width,
    required this.height,
    required this.value,
  });

  final double width;
  final double height;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(height),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x55000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.greenGradient,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(height),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.green.withValues(alpha: 0.6),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
