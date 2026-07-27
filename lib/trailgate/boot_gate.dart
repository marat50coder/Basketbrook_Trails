import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/gate_models.dart';
import 'pages/offline_page.dart';
import 'pages/push_invite.dart';
import 'pages/trail_portal.dart';
import 'trail_coordinator.dart';

/// Splash + gray/white routing point. Plays the loading art (orientation
/// aware) while [TrailCoordinator.decide] runs the attribution → config
/// pipeline, then routes to the WebView (gray), the offline screen, or the
/// white game via [gameBuilder].
class BootGate extends StatefulWidget {
  const BootGate({
    super.key,
    required this.coordinator,
    required this.gameBuilder,
  });

  final TrailCoordinator? coordinator;
  final WidgetBuilder gameBuilder;

  @override
  State<BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<BootGate> {
  double _progress = 0;
  GateStop? _destination;
  bool _started = false;
  bool _navigating = false;
  late final DateTime _startTime;
  Timer? _hardDeadline;
  static const Duration _minSplash = Duration(milliseconds: 1600);

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _hardDeadline = Timer(const Duration(seconds: 12), () {
      if (mounted && !_navigating && _destination == null) {
        _destination = const NativeStop();
        _maybeNavigate();
      }
    });
  }

  @override
  void dispose() {
    _hardDeadline?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final coordinator = widget.coordinator;
    if (coordinator == null) {
      _destination = const NativeStop();
      if (mounted) setState(() => _progress = 1);
      _maybeNavigate();
      return;
    }
    try {
      _destination = await coordinator.decide(
        onProgress: (value) {
          if (mounted) setState(() => _progress = value.clamp(0.0, 1.0));
        },
      );
    } catch (_) {
      _destination = const NativeStop();
    }
    if (mounted) setState(() => _progress = 1);
    _hardDeadline?.cancel();
    _maybeNavigate();
  }

  Future<void> _maybeNavigate() async {
    if (_navigating || _destination == null) return;
    final elapsed = DateTime.now().difference(_startTime);
    if (elapsed < _minSplash) {
      await Future<void>.delayed(_minSplash - elapsed);
    }
    if (!mounted || _navigating) return;
    _navigating = true;
    // Only lock portrait on the way to the permit / offline / portal screens —
    // they expect to start upright and re-enable landscape in initState. For
    // the white game, DO NOT pre-lock portrait: the game re-locks to landscape
    // in `GameRoot._onLoaded` and iOS 16+ refuses the transition when we've
    // just told it "portrait only" (`Requested: landscape; Supported: portrait`).
    if (_destination is! NativeStop) {
      await SystemChrome.setPreferredOrientations(
        const [DeviceOrientation.portraitUp],
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
    if (!mounted) return;
    _open(_destination!);
  }

  Future<void> _open(GateStop destination) async {
    final coordinator = widget.coordinator;

    if (destination is NativeStop || coordinator == null) {
      Navigator.of(context)
          .pushReplacement(MaterialPageRoute<void>(builder: widget.gameBuilder));
      return;
    }

    if (destination is OfflineStop) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => OfflinePage(
            probe: coordinator.probe,
            retryBuilder: (_) => BootGate(
              coordinator: coordinator,
              gameBuilder: widget.gameBuilder,
            ),
          ),
        ),
      );
      return;
    }

    if (destination is PortalStop) {
      Widget portalBuilder(BuildContext _) => TrailPortal(
        url: destination.url,
        coldLaunch: destination.coldLaunch,
        vault: coordinator.vault,
        probe: coordinator.probe,
        notifications: coordinator.notifications,
        agent: coordinator.agent,
      );

      final offerInvite = coordinator.vault.shouldShowPushInvite &&
          await coordinator.notifications.canOfferPermission();
      if (!mounted) return;
      if (offerInvite) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => PushInvite(
              vault: coordinator.vault,
              notifications: coordinator.notifications,
              nextBuilder: portalBuilder,
            ),
          ),
        );
      } else {
        Navigator.of(context)
            .pushReplacement(MaterialPageRoute<void>(builder: portalBuilder));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF184A20),
      body: OrientationBuilder(
        builder: (context, orientation) {
          final isLandscape = orientation == Orientation.landscape;
          final asset = isLandscape
              ? 'assets/Basketbrook_Trails_additional_assets/Horizontal_Loading_Screen.webp'
              : 'assets/Basketbrook_Trails_additional_assets/Vertical_Loading_Screen.webp';
          final size = MediaQuery.of(context).size;
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                asset,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: Color(0xFF184A20)),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLandscape ? 24 : 56),
                  child: _ProgressBar(
                    progress: _progress,
                    width: isLandscape ? size.width * 0.42 : size.width * 0.74,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress, required this.width});

  final double progress;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x55000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOut,
              tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
              builder: (context, value, _) {
                return FractionallySizedBox(
                  widthFactor: value <= 0 ? 0.001 : value,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF9CE86B), Color(0xFF3EA43C)],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
