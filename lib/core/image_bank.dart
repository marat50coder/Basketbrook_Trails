import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'sprites.dart';

/// Decodes and caches [ui.Image] objects so the game can render them on a
/// [Canvas] without any per-frame async work. Everything is loaded from
/// bundled assets, so it works with no network connection.
class ImageBank {
  final Map<String, ui.Image> _images = {};

  ui.Image? get(String path) => _images[path];

  ui.Image require(String path) {
    final img = _images[path];
    if (img == null) {
      throw StateError('Image not preloaded: $path');
    }
    return img;
  }

  Future<void> _load(String path) async {
    if (_images.containsKey(path)) return;
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    _images[path] = frame.image;
  }

  /// The full set of assets required for gameplay.
  List<String> gameplayManifest() {
    final paths = <String>{};
    for (final s in Sprites.skins) {
      paths.add(Sprites.chicken(s.index));
    }
    paths.add(Sprites.egg(Sprites.eggWhite));
    paths.add(Sprites.egg(Sprites.eggGold));
    paths.add(Sprites.egg(Sprites.eggBlue));
    paths.add(Sprites.basket(Sprites.goalBasket));
    paths.add(Sprites.coin(Sprites.coinFace));
    paths.add(Sprites.coin(Sprites.coinEgg));
    for (final i in Sprites.obstacleSet) {
      paths.add(Sprites.obstacle(i));
    }
    for (final i in Sprites.decorSet) {
      paths.add(Sprites.decorative(i));
    }
    for (final i in Sprites.gateSet) {
      paths.add(Sprites.fence(i));
    }
    for (var i = 1; i <= 6; i++) {
      paths.add('assets/Basketbrook_Trails_gameplay_assets/bg_location$i'
          '_asset.webp');
    }
    paths.add('assets/Basketbrook_Trails_additional_assets/Game_Name.webp');
    return paths.toList();
  }

  /// Loads [paths], invoking [onProgress] with a 0..1 fraction as it goes.
  Future<void> preload(
    List<String> paths, {
    void Function(double fraction)? onProgress,
  }) async {
    var done = 0;
    for (final p in paths) {
      await _load(p);
      done++;
      onProgress?.call(done / paths.length);
    }
  }
}
