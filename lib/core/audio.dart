import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// All sound effects, bundled and played fully offline.
enum Sfx {
  click('UI_button_click_asset.mp3'),
  levelStart('Positive_level_start_asset.mp3'),
  coin('coin_pickup_asset.mp3'),
  collectChicken('new_collect_chicken_asset.mp3'),
  eggCollect('egg_collection_asset.mp3'),
  eggLoss('egg_loss_asset.mp3'),
  hit('hit_obtacles_asset.mp3'),
  gate('wooden_gate_opening_asset.mp3'),
  deliver('delivering_eggs_into_a_basket_asset.mp3'),
  victory('victory_win_asset.mp3'),
  failure('failure_loss_asset.mp3'),
  reward('Exciting_reward_opening_asset.mp3');

  const Sfx(this.file);
  final String file;
  String get path => 'Basketbrook_Trails_sounds_assets/$file';
}

const String _ambientAsset =
    'Basketbrook_Trails_sounds_assets/chicken_footsteps_loop_asset.mp3';

/// Centralised audio controller.
///
/// Uses a small round-robin pool of players so rapid, overlapping effects
/// (coins, chickens) never cut each other off or stall the frame by stopping a
/// shared player. All assets are pre-copied into the audio cache once so no
/// per-play disk work happens during gameplay.
class AudioController {
  AudioController() {
    _pool = List.generate(_poolSize, (i) {
      return AudioPlayer(playerId: 'sfx_$i')..setReleaseMode(ReleaseMode.stop);
    });
    _loop = AudioPlayer(playerId: 'loop')..setReleaseMode(ReleaseMode.loop);
  }

  static const int _poolSize = 6;
  late final List<AudioPlayer> _pool;
  late final AudioPlayer _loop;
  int _next = 0;
  bool _warmed = false;

  bool soundOn = true;
  bool musicOn = true;
  bool _loopPlaying = false;

  /// Warms the audio cache so the first plays don't hitch.
  Future<void> preload() async {
    if (_warmed) return;
    _warmed = true;
    try {
      await AudioCache.instance.loadAll([
        for (final s in Sfx.values) s.path,
        _ambientAsset,
      ]);
    } catch (e) {
      debugPrint('audio preload error: $e');
    }
  }

  Future<void> play(Sfx sfx, {double volume = 1.0}) async {
    if (!soundOn) return;
    final player = _pool[_next];
    _next = (_next + 1) % _poolSize;
    try {
      await player.play(AssetSource(sfx.path), volume: volume);
    } catch (e) {
      debugPrint('sfx error: $e');
    }
  }

  Future<void> startAmbient() async {
    if (!musicOn || _loopPlaying) return;
    try {
      _loopPlaying = true;
      await _loop.setReleaseMode(ReleaseMode.loop);
      await _loop.play(AssetSource(_ambientAsset), volume: 0.28);
    } catch (e) {
      debugPrint('ambient error: $e');
      _loopPlaying = false;
    }
  }

  Future<void> stopAmbient() async {
    _loopPlaying = false;
    try {
      await _loop.stop();
    } catch (_) {}
  }

  void dispose() {
    for (final p in _pool) {
      p.dispose();
    }
    _loop.dispose();
  }
}
