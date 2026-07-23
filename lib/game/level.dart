import 'dart:math';

import '../core/sprites.dart';

/// How many world units fit across the screen width.
const double kViewUnits = 10.0;

enum TrackType { obstacle, chicken, coin, gate, decor, finish }

class TrackItem {
  TrackItem({
    required this.type,
    required this.x,
    required this.lateral,
    required this.sprite,
    this.value = 0,
  });

  final TrackType type;
  final double x; // position along the track, in world units
  final double lateral; // 0..1 across the road width
  final int sprite; // sprite index inside its category
  final int value; // gate requirement / coin worth

  bool consumed = false; // pickup collected / obstacle already hit
  bool opened = false; // gate passed
}

class LevelConfig {
  LevelConfig({
    required this.number,
    required this.bgIndex,
    required this.length,
    required this.speed,
    required this.items,
    required this.gateTotal,
    required this.startEggs,
  });

  final int number;
  final int bgIndex;
  final double length; // total track length in units
  final double speed; // units per second
  final List<TrackItem> items;
  final int gateTotal;
  final int startEggs;

  static LevelConfig generate(int number) {
    final rnd = Random(number * 7919 + 13);
    // Staged scenery: the location advances every 5 levels (matching the
    // Locations screen), then cycles through the 6 backgrounds, instead of
    // flipping to a new background on every single level.
    final bgIndex = (((number - 1) ~/ 5) % 6) + 1;
    final length = 62.0 + number * 10.0;
    final speed = (3.0 + number * 0.12 + rnd.nextDouble() * 0.2).clamp(3.0, 5.4);

    final items = <TrackItem>[];
    var x = 9.0;
    var available = 1; // chickens the player could have by now
    var gateTotal = 0;

    // How many "chapters" (each ends with a requirement gate).
    final chapters = min(2 + number ~/ 2, 5);

    double lateral() => 0.12 + rnd.nextDouble() * 0.76;

    for (var c = 0; c < chapters; c++) {
      final chapterLen = (length - 14) / chapters;
      final end = x + chapterLen;

      // Sprinkle pickups, obstacles and coins across the chapter. Pickups
      // outpace obstacles so a skilful player can keep growing the flock.
      final pickups = 3 + rnd.nextInt(3) + number ~/ 2;
      final obstacles = 2 + rnd.nextInt(2) + number ~/ 3;
      final coins = 3 + rnd.nextInt(4);

      for (var i = 0; i < pickups; i++) {
        items.add(TrackItem(
          type: TrackType.chicken,
          x: x + (end - x) * rnd.nextDouble(),
          lateral: lateral(),
          sprite: Sprites.skins[rnd.nextInt(Sprites.skins.length)].index,
        ));
        available++;
      }
      for (var i = 0; i < obstacles; i++) {
        items.add(TrackItem(
          type: TrackType.obstacle,
          x: x + 1.5 + (end - x - 2) * rnd.nextDouble(),
          lateral: lateral(),
          sprite: Sprites.obstacleSet[rnd.nextInt(Sprites.obstacleSet.length)],
        ));
      }
      for (var i = 0; i < coins; i++) {
        items.add(TrackItem(
          type: TrackType.coin,
          x: x + (end - x) * rnd.nextDouble(),
          lateral: lateral(),
          sprite: Sprites.coinFace,
          value: 1,
        ));
      }
      // Decorations for atmosphere along the edges.
      for (var i = 0; i < 5; i++) {
        items.add(TrackItem(
          type: TrackType.decor,
          x: x + (end - x) * rnd.nextDouble(),
          lateral: rnd.nextBool() ? rnd.nextDouble() * 0.08 : 0.92 + rnd.nextDouble() * 0.08,
          sprite: Sprites.decorSet[rnd.nextInt(Sprites.decorSet.length)],
        ));
      }

      // Requirement gate at the end of the chapter.
      final required = max(2, (available * 0.5).round());
      gateTotal++;
      items.add(TrackItem(
        type: TrackType.gate,
        x: end,
        lateral: 0.5,
        sprite: Sprites.gateSet[c % Sprites.gateSet.length],
        value: required,
      ));

      x = end + 3.0;
    }

    // Finish basket.
    items.add(TrackItem(
      type: TrackType.finish,
      x: length - 3.0,
      lateral: 0.5,
      sprite: Sprites.goalBasket,
    ));

    items.sort((a, b) => a.x.compareTo(b.x));
    return LevelConfig(
      number: number,
      bgIndex: bgIndex,
      length: length,
      speed: speed,
      items: items,
      gateTotal: gateTotal,
      startEggs: 1,
    );
  }
}
