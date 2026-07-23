import 'dart:math';

import 'package:flutter/foundation.dart';

import 'level.dart';

enum GamePhase { countdown, running, paused, won, lost }

/// One rendered link in the chicken chain.
class ChickenRender {
  ChickenRender(this.trackPos, this.lateral, this.skin, this.hasEgg, this.scale);
  final double trackPos;
  final double lateral;
  final int skin;
  final bool hasEgg;
  final double scale;
}

/// A short-lived floating label used for juicy feedback (+chicken, -egg, +coin).
class FloatingText {
  FloatingText(this.trackPos, this.lateral, this.text, this.color);
  final double trackPos;
  double lateral;
  final String text;
  final int color; // ARGB
  double age = 0;
}

class _PathPoint {
  _PathPoint(this.x, this.lateral);
  final double x;
  final double lateral;
}

/// Pure game simulation for a single level. The widget owns the ticker and
/// calls [update] every frame; the painter reads the exposed geometry.
class GameWorld extends ChangeNotifier {
  GameWorld({
    required this.level,
    required this.leaderSkin,
    required this.onEvent,
    this.startingChickens = 0,
    this.shieldCharges = 0,
    this.coinBonus = 1.0,
  }) {
    _skins = [leaderSkin];
    _eggs = [true];
    // "Starting Flock" upgrade: begin the run with a few extra chickens.
    for (var i = 0; i < startingChickens; i++) {
      _skins.add(leaderSkin);
      _eggs.add(true);
    }
    _shield = shieldCharges;
    _history.add(_PathPoint(0, 0.5));
  }

  final LevelConfig level;
  final int leaderSkin;
  final void Function(GameEvent event) onEvent;

  /// Upgrade-driven modifiers, supplied by [GameState].
  final int startingChickens;
  final int shieldCharges;
  final double coinBonus;

  int _shield = 0;

  static const double spacing = 0.46; // units between chained chickens
  // Collision windows tuned to match the on-screen sprite footprints so an
  // obstacle that visually overlaps a chicken always registers a hit.
  static const double captureX = 0.78;
  static const double captureLat = 0.2;
  static const double hitX = 0.66;
  static const double hitLat = 0.17;

  GamePhase phase = GamePhase.countdown;

  // Intro countdown + "GO!" flash live in the world so the painter (which
  // repaints from this Listenable) always shows the current value.
  double countdown = 3.0;
  double goTimer = 0.0;

  String? get overlayText {
    if (phase == GamePhase.countdown) {
      final n = countdown.ceil();
      return n <= 0 ? 'GO!' : '$n';
    }
    if (goTimer > 0) return 'GO!';
    return null;
  }

  double leaderX = 0;
  double leaderLateral = 0.5;
  double targetLateral = 0.5;

  late List<int> _skins;
  late List<bool> _eggs;
  final List<_PathPoint> _history = [];
  final List<FloatingText> effects = [];

  int coins = 0;
  int eggsDelivered = 0;
  int chickensCollected = 0;
  int eggsLost = 0;
  int stars = 0;
  int score = 0;
  int coinsEarned = 0;
  String lostReason = '';

  int get chickenCount => _skins.length;
  int get eggCount => _eggs.where((e) => e).length;
  double get progress => (leaderX / level.length).clamp(0.0, 1.0);

  /// Next requirement gate ahead of the leader, if any.
  TrackItem? get nextGate {
    for (final it in level.items) {
      if (it.type == TrackType.gate && !it.opened && it.x >= leaderX - 0.5) {
        return it;
      }
    }
    return null;
  }

  void startRunning() {
    if (phase == GamePhase.countdown) {
      phase = GamePhase.running;
      onEvent(GameEvent.go);
    }
  }

  void togglePause() {
    if (phase == GamePhase.running) {
      phase = GamePhase.paused;
    } else if (phase == GamePhase.paused) {
      phase = GamePhase.running;
    }
    notifyListeners();
  }

  void steer(double deltaLateral) {
    targetLateral = (targetLateral + deltaLateral).clamp(0.06, 0.94);
  }

  void update(double dt) {
    // Age & prune effects regardless of phase (so they finish animating).
    for (final e in effects) {
      e.age += dt;
      e.lateral -= dt * 0.12;
    }
    effects.removeWhere((e) => e.age > 1.1);

    if (phase == GamePhase.countdown) {
      countdown -= dt;
      if (countdown <= 0) {
        goTimer = 0.7;
        startRunning();
      }
      notifyListeners();
      return;
    }

    if (goTimer > 0) goTimer -= dt;

    if (phase != GamePhase.running) {
      notifyListeners();
      return;
    }

    leaderX += level.speed * dt;
    // Ease lateral toward target for smooth, snake-like turning.
    leaderLateral += (targetLateral - leaderLateral) * min(1.0, dt * 9.0);

    if (_history.isEmpty || (leaderX - _history.last.x) > 0.015) {
      _history.add(_PathPoint(leaderX, leaderLateral));
    }
    final maxBehind = spacing * chickenCount + 2.0;
    while (_history.length > 2 && _history.first.x < leaderX - maxBehind) {
      _history.removeAt(0);
    }

    _processItems();
    _checkFinish();

    notifyListeners();
  }

  double _lateralAt(double trackPos) {
    if (trackPos >= leaderX) return leaderLateral;
    if (_history.isEmpty) return leaderLateral;
    if (trackPos <= _history.first.x) return _history.first.lateral;
    // Binary search for the segment containing trackPos.
    var lo = 0;
    var hi = _history.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_history[mid].x < trackPos) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    final b = _history[lo];
    final a = _history[lo == 0 ? 0 : lo - 1];
    if (b.x == a.x) return b.lateral;
    final t = (trackPos - a.x) / (b.x - a.x);
    return a.lateral + (b.lateral - a.lateral) * t;
  }

  /// Chain geometry (leader first), for rendering and collisions.
  List<ChickenRender> chickens() {
    final list = <ChickenRender>[];
    for (var i = 0; i < chickenCount; i++) {
      final trackPos = leaderX - spacing * i;
      final lat = i == 0 ? leaderLateral : _lateralAt(trackPos);
      final scale = 0.8 + lat * 0.32;
      list.add(ChickenRender(trackPos, lat, _skins[i], _eggs[i], scale));
    }
    return list;
  }

  void _processItems() {
    final chain = chickens();
    // Only inspect items within reach of the flock. Items are sorted by x, so
    // we can skip everything far behind the tail and stop once we're well past
    // the leader. This keeps the per-frame cost flat instead of growing with
    // the (much longer) later levels, which is what caused the stutter.
    final behindLimit = spacing * chickenCount + 1.5;
    for (final it in level.items) {
      final dx = it.x - leaderX;
      if (dx > 4.0) break; // nothing further ahead can be reached this frame
      if (dx < -behindLimit) continue; // behind the last chicken
      switch (it.type) {
        case TrackType.chicken:
          if (it.consumed) continue;
          if ((it.x - leaderX).abs() < captureX &&
              (it.lateral - leaderLateral).abs() < captureLat) {
            it.consumed = true;
            _skins.add(it.sprite);
            _eggs.add(true);
            chickensCollected++;
            effects.add(FloatingText(it.x, it.lateral - 0.06, '+1', 0xFF5FB84F));
            onEvent(GameEvent.collectChicken);
          }
          break;
        case TrackType.coin:
          if (it.consumed) continue;
          for (final c in chain) {
            if ((it.x - c.trackPos).abs() < captureX &&
                (it.lateral - c.lateral).abs() < captureLat) {
              it.consumed = true;
              coins += it.value;
              effects.add(FloatingText(it.x, it.lateral - 0.05, '+${it.value}', 0xFFFFC531));
              onEvent(GameEvent.coin);
              break;
            }
          }
          break;
        case TrackType.obstacle:
          if (it.consumed) continue;
          for (final c in chain) {
            if ((it.x - c.trackPos).abs() < hitX &&
                (it.lateral - c.lateral).abs() < hitLat) {
              _hitObstacle(it);
              break;
            }
          }
          break;
        case TrackType.gate:
          if (it.opened) continue;
          if (leaderX >= it.x) {
            if (chickenCount >= it.value) {
              it.opened = true;
              effects.add(FloatingText(it.x, 0.3, 'OPEN', 0xFF3E9A3A));
              onEvent(GameEvent.gate);
            } else {
              _fail('You needed ${it.value} chickens to open the gate');
            }
          }
          break;
        case TrackType.finish:
        case TrackType.decor:
          break;
      }
    }
  }

  void _hitObstacle(TrackItem it) {
    it.consumed = true;
    // "Feather Shield" upgrade absorbs a limited number of hits per run.
    if (_shield > 0) {
      _shield--;
      effects.add(FloatingText(it.x, it.lateral - 0.05, 'Blocked!', 0xFF4FA9D8));
      onEvent(GameEvent.shield);
      return;
    }
    // Hitting an obstacle knocks the last chicken (and its egg) out of the
    // chain. Losing your very last chicken ends the run — so obstacles are a
    // real threat and the player must weave to keep the flock alive.
    if (chickenCount <= 1) {
      onEvent(GameEvent.hit);
      _fail('Your last chicken hit an obstacle!');
      return;
    }
    final lostEgg = _eggs.removeLast();
    _skins.removeLast();
    if (lostEgg) eggsLost++;
    effects.add(FloatingText(it.x, it.lateral - 0.05, '-1', 0xFFE86A5A));
    onEvent(GameEvent.hit);
  }

  void _checkFinish() {
    // The finish line always sits at (length - 3), so we can check it directly
    // instead of scanning every item on the track each frame.
    if (phase == GamePhase.running && leaderX >= level.length - 3.0) {
      _win();
    }
  }

  void _win() {
    phase = GamePhase.won;
    eggsDelivered = eggCount;
    // Stars: based on how many eggs survived relative to chain length.
    final ratio = chickenCount == 0 ? 0.0 : eggsDelivered / chickenCount;
    stars = ratio >= 0.9
        ? 3
        : ratio >= 0.6
            ? 2
            : 1;
    score = eggsDelivered * 100 + chickenCount * 20 + coins * 5;
    // "Golden Eggs" upgrade scales the coins earned from a win.
    coinsEarned = ((coins + eggsDelivered * 8 + stars * 25) * coinBonus).round();
    onEvent(GameEvent.win);
  }

  void _fail(String reason) {
    if (phase != GamePhase.running) return;
    phase = GamePhase.lost;
    lostReason = reason;
    coinsEarned = coins;
    onEvent(GameEvent.lose);
  }
}

enum GameEvent { go, collectChicken, coin, eggLoss, hit, gate, shield, win, lose }
