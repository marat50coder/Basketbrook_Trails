import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'core/audio.dart';
import 'core/game_state.dart';
import 'core/image_bank.dart';
import 'core/storage.dart';
import 'loading/loading_screen.dart';
import 'menu/home_screen.dart';
import 'trailgate/boot_gate.dart';
import 'trailgate/config/trail_gate_config.dart';
import 'trailgate/infra/gate_exchange.dart';
import 'trailgate/infra/push_relay.dart';
import 'trailgate/infra/reach_probe.dart';
import 'trailgate/infra/trail_agent.dart';
import 'trailgate/infra/trail_attribution.dart';
import 'trailgate/infra/trail_vault.dart';
import 'trailgate/trail_coordinator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // ── Gray-flow services ────────────────────────────────────────────────
  final vault = TrailVault();
  final agent = TrailAgent();

  // ── White-game services ───────────────────────────────────────────────
  final storageFuture = GameStorage.open();

  await Future.wait<void>(<Future<void>>[
    vault.initialize(),
    agent.prepare(),
    // Decode the boot artwork before the first frame so each gray-flow screen
    // paints its image immediately — no flash of the scaffold background
    // colour between the loading, notification and portal screens.
    _warmBootArt('assets/Basketbrook_Trails_additional_assets/Vertical_Loading_Screen.webp'),
    _warmBootArt('assets/Basketbrook_Trails_additional_assets/Horizontal_Loading_Screen.webp'),
    _warmBootArt('assets/Vertical_Notifications_Screen.webp'),
    _warmBootArt('assets/Horizontal_Notifications_Screen.webp'),
  ]);

  final storage = await storageFuture;
  final audio = AudioController();
  audio.preload();
  final images = ImageBank();
  final state = GameState(storage: storage, audio: audio, images: images);

  assert(() {
    debugPrint(
      '[BB.BOOT] credentialsReady=${TrailGateConfig.grayCredentialsReady} '
      'endpoint=${TrailGateConfig.endpoint} '
      'afKeyLen=${TrailGateConfig.appsFlyerKey.length} '
      'fbNum=${TrailGateConfig.firebaseProjectNumber}',
    );
    return true;
  }());

  var productionServicesReady = false;
  if (TrailGateConfig.grayCredentialsReady) {
    try {
      await Firebase.initializeApp();
      productionServicesReady = true;
    } catch (error) {
      assert(() {
        debugPrint('[BB.BOOT] Firebase.initializeApp failed: $error');
        return true;
      }());
    }
  }

  final probe = ReachProbe();
  // Attribution + config POST must run even if Firebase failed to init; only
  // push/FCM needs productionServicesReady.
  final notifications = PushRelay(vault, enabled: productionServicesReady);
  final attribution = TrailAttribution(agent);
  final coordinator = TrailCoordinator(
    vault: vault,
    probe: probe,
    attribution: attribution,
    exchange: GateExchange(agent, vault),
    notifications: notifications,
    agent: agent,
    runtimeEnabled: TrailGateConfig.grayCredentialsReady,
  );

  // Kick AppsFlyer/ATT off before the first frame renders. On iOS 18+ a fresh
  // install's conversion callback can take 10–15 s; warming up here means the
  // BootGate almost always sees ready install data when it calls decide().
  coordinator.warmUp();

  runApp(BasketbrookApp(state: state, coordinator: coordinator));
}

/// Resolves and decodes an asset image into Flutter's image cache before the
/// first frame. Once cached, `Image.asset` paints it synchronously on its very
/// first build, so the loading screen never flashes its background colour.
Future<void> _warmBootArt(String asset) {
  final completer = Completer<void>();
  final stream = AssetImage(asset).resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (_, _) {
      stream.removeListener(listener);
      if (!completer.isCompleted) completer.complete();
    },
    onError: (_, _) {
      stream.removeListener(listener);
      if (!completer.isCompleted) completer.complete();
    },
  );
  stream.addListener(listener);
  return completer.future;
}

class BasketbrookApp extends StatelessWidget {
  const BasketbrookApp({
    super.key,
    required this.state,
    required this.coordinator,
  });

  final GameState state;
  final TrailCoordinator coordinator;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        title: 'Basketbrook Trails',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: BootGate(
          coordinator: coordinator,
          gameBuilder: (_) => const GameRoot(),
        ),
      ),
    );
  }
}

/// White-game entry: shows the game's own loading screen (image precache +
/// landscape lock) and then the home menu.
class GameRoot extends StatefulWidget {
  const GameRoot({super.key});

  @override
  State<GameRoot> createState() => _GameRootState();
}

class _GameRootState extends State<GameRoot> {
  bool _loaded = false;

  Future<void> _onLoaded() async {
    // The game itself is strictly landscape.
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (mounted) setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loaded) return const HomeScreen();
    final state = context.read<GameState>();
    return LoadingScreen(images: state.images, onComplete: _onLoaded);
  }
}
