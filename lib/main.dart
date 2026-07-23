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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  final storage = await GameStorage.open();
  final audio = AudioController();
  // Warm the audio cache immediately so the very first tap/pickup plays with
  // no perceptible delay.
  audio.preload();
  final images = ImageBank();
  final state = GameState(storage: storage, audio: audio, images: images);

  runApp(BasketbrookApp(state: state));
}

class BasketbrookApp extends StatelessWidget {
  const BasketbrookApp({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        title: 'Basketbrook Trails',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
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
