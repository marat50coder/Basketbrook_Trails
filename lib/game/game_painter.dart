import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/image_bank.dart';
import '../core/sprites.dart';
import 'level.dart';
import 'world.dart';

/// Renders the whole gameplay scene. All sprites are sized with a single
/// "fit inside a box" rule so every object reads at a consistent scale
/// regardless of its source aspect ratio.
class GamePainter extends CustomPainter {
  GamePainter({
    required this.world,
    required this.images,
    required this.bg,
  }) : super(repaint: world);

  final GameWorld world;
  final ImageBank images;
  final ui.Image bg;

  static const double roadTopF = 0.34;
  static const double roadBottomF = 0.99;

  // Consistent object sizes, expressed in world units.
  static const double chickenBox = 1.3;
  static const double obstacleBox = 1.6;
  static const double decorBox = 1.45;
  static const double coinBox = 0.82;
  static const double finishBox = 2.9;

  double _px(Size s) => s.width / kViewUnits;
  double _anchorX(Size s) => s.width * 0.24;

  double _screenX(Size s, double trackPos) =>
      _anchorX(s) + (trackPos - world.leaderX) * _px(s);

  double _roadTop(Size s) => s.height * roadTopF;
  double _roadBottom(Size s) => s.height * roadBottomF;

  double _depth(double lateral) => 0.85 + lateral * 0.28;

  double _baseY(Size s, double lateral) {
    final top = _roadTop(s) + (_roadBottom(s) - _roadTop(s)) * 0.08;
    final bottom = _roadBottom(s) - (_roadBottom(s) - _roadTop(s)) * 0.03;
    return top + lateral * (bottom - top);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawRoad(canvas, size);

    final px = _px(size);
    final drawables = <_Drawable>[];
    final gateBadges = <_GateBadge>[];

    for (final it in world.level.items) {
      final sx = _screenX(size, it.x);
      // Items are sorted by track position, so once we're past the right edge
      // nothing else is visible — stop instead of scanning the whole level.
      if (sx > size.width + px * 4) break;
      if (sx < -px * 4) continue;
      switch (it.type) {
        case TrackType.decor:
          final img = images.get(Sprites.decorative(it.sprite));
          if (img != null) {
            final y = _baseY(size, it.lateral);
            final box = px * decorBox * _depth(it.lateral);
            drawables.add(_Drawable(y - 2, (c) {
              _shadow(c, sx, y, box * 0.42);
              _fit(c, img, sx, y, box);
            }));
          }
          break;
        case TrackType.coin:
          if (it.consumed) break;
          final img = images.get(Sprites.coin(it.sprite));
          if (img != null) {
            final y = _baseY(size, it.lateral);
            final bob = 0.05 * px * (1 + _sin(world.leaderX * 3 + it.x));
            final box = px * coinBox;
            drawables.add(_Drawable(y, (c) {
              _shadow(c, sx, y, box * 0.32);
              _fitCentered(c, img, sx, y - box * 0.55 - bob, box);
            }));
          }
          break;
        case TrackType.obstacle:
          if (it.consumed) break;
          final img = images.get(Sprites.obstacle(it.sprite));
          if (img != null) {
            final y = _baseY(size, it.lateral);
            final box = px * obstacleBox * _depth(it.lateral);
            drawables.add(_Drawable(y, (c) {
              _shadow(c, sx, y, box * 0.42);
              _fit(c, img, sx, y, box);
            }));
          }
          break;
        case TrackType.chicken:
          if (it.consumed) break;
          final img = images.get(Sprites.chicken(it.sprite));
          if (img != null) {
            final y = _baseY(size, it.lateral);
            final box = px * chickenBox * _depth(it.lateral);
            final bob = 0.04 * px * _sin(world.leaderX * 2.6 + it.x * 3);
            drawables.add(_Drawable(y, (c) {
              _shadow(c, sx, y, box * 0.38);
              _fit(c, img, sx, y + bob, box);
            }));
          }
          break;
        case TrackType.gate:
          _drawGatePosts(canvas, size, it, sx);
          if (!it.opened) {
            gateBadges.add(_GateBadge(sx, it.value));
          }
          break;
        case TrackType.finish:
          final img = images.get(Sprites.basket(it.sprite));
          if (img != null) {
            final y = _baseY(size, 0.62);
            final box = px * finishBox;
            final eggW = images.get(Sprites.egg(Sprites.eggWhite));
            final eggG = images.get(Sprites.egg(Sprites.eggGold));
            drawables.add(_Drawable(y, (c) {
              _drawFinish(c, sx, y, box, img, eggW, eggG);
            }));
          }
          break;
      }
    }

    // Chicken chain (leader last so it is drawn on top of its followers).
    final chain = world.chickens();
    for (var i = chain.length - 1; i >= 0; i--) {
      final c = chain[i];
      final sx = _screenX(size, c.trackPos);
      if (sx < -px * 4 || sx > size.width + px * 4) continue;
      final y = _baseY(size, c.lateral);
      final img = images.get(Sprites.chicken(c.skin));
      if (img == null) continue;
      final box = px * chickenBox * c.scale;
      // A bouncy run cycle: hop height 0..1 with squash on landing, stretch
      // at the top. The leader and each follower are phase-offset.
      final running = world.phase == GamePhase.running;
      final hop = running ? _sin(world.leaderX * 3.4 - i * 0.7).abs() : 0.0;
      final lift = box * 0.13 * hop;
      final stretchY = 1 + 0.09 * hop;
      final squashX = 1 - 0.07 * hop;
      drawables.add(_Drawable(y + 0.5, (canvas) {
        _shadow(canvas, sx, y, box * 0.4 * (1 - 0.25 * hop));
        _fit(canvas, img, sx, y - lift, box, sx: squashX, sy: stretchY);
      }));
    }

    drawables.sort((a, b) => a.y.compareTo(b.y));
    for (final d in drawables) {
      d.draw(canvas);
    }

    // Gate badges sit above everything so the requirement is always readable.
    for (final b in gateBadges) {
      _drawGateBadge(canvas, size, b);
    }

    _drawEffects(canvas, size);
    final overlay = world.overlayText;
    if (overlay != null) _drawCountdown(canvas, size, overlay);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final scale = size.height / bg.height;
    final drawW = bg.width * scale;
    final offset = (-world.leaderX * _px(size) * 0.85) % drawW;
    final paint = Paint()..filterQuality = FilterQuality.medium;
    var x = offset - drawW;
    while (x < size.width) {
      canvas.drawImageRect(
        bg,
        Rect.fromLTWH(0, 0, bg.width.toDouble(), bg.height.toDouble()),
        Rect.fromLTWH(x, 0, drawW, size.height),
        paint,
      );
      x += drawW;
    }
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.30),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x66000000), Color(0x00000000)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.30)),
    );
  }

  void _drawRoad(Canvas canvas, Size size) {
    final top = _roadTop(size);
    final bottom = _roadBottom(size);
    final rect = Rect.fromLTWH(-20, top, size.width + 40, bottom - top);
    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: const Radius.circular(52),
      topRight: const Radius.circular(52),
    );
    // Grassy shoulder behind the trail for a soft framed look.
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(-20, top - 10, size.width + 40, bottom - top + 10),
        topLeft: const Radius.circular(58),
        topRight: const Radius.circular(58),
      ),
      Paint()..color = const Color(0x3341A03A),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xF2EAC896), Color(0xF5D6AC66)],
        ).createShader(rect),
    );
    // Warm center highlight along the trail.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-20, top + (bottom - top) * 0.30, size.width + 40,
            (bottom - top) * 0.42),
        const Radius.circular(40),
      ),
      Paint()..color = const Color(0x22FFFFFF),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0x66FFFFFF),
    );
  }

  /// Wooden gate posts at the top & bottom of the lane (behind the chickens).
  void _drawGatePosts(Canvas canvas, Size size, TrackItem it, double sx) {
    final top = _roadTop(size);
    final bottom = _roadBottom(size);
    final laneH = bottom - top;
    final px = _px(size);
    final postW = px * 0.5;
    final postH = laneH * 0.16;

    void post(double cy) {
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(sx, cy), width: postW, height: postH),
        Radius.circular(postW * 0.4),
      );
      canvas.drawRRect(r.shift(const Offset(0, 3)), Paint()..color = const Color(0x33000000));
      canvas.drawRRect(
        r,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFB07A45), Color(0xFF8A5A32)],
          ).createShader(Rect.fromCenter(center: Offset(sx, cy), width: postW, height: postH)),
      );
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(sx, cy - postH / 2), width: postW * 1.15, height: postW * 0.5),
        Paint()..color = const Color(0xFF6B4423),
      );
    }

    post(top + postH / 2);
    post(bottom - postH / 2);

    if (!it.opened) {
      final enough = world.chickenCount >= it.value;
      final base = enough ? const Color(0xFF5FB84F) : const Color(0xFFE86A5A);
      final fieldRect = Rect.fromLTWH(
          sx - px * 0.28, top + postH, px * 0.56, laneH - postH * 2);
      final field = RRect.fromRectAndRadius(fieldRect, Radius.circular(px * 0.2));
      canvas.drawRRect(field, Paint()..color = base.withValues(alpha: 0.22));
      canvas.drawRRect(
        field,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = base.withValues(alpha: 0.85),
      );
    }
  }

  void _drawGateBadge(Canvas canvas, Size size, _GateBadge b) {
    final top = _roadTop(size);
    final bottom = _roadBottom(size);
    final cy = top + (bottom - top) * 0.5;
    final px = _px(size);
    final enough = world.chickenCount >= b.required;
    final base = enough ? const Color(0xFF3E9A3A) : const Color(0xFFE86A5A);
    final r = px * 0.62;

    canvas.drawCircle(Offset(b.sx, cy + 4), r, Paint()..color = const Color(0x33000000));
    canvas.drawCircle(Offset(b.sx, cy), r, Paint()..color = Colors.white);
    canvas.drawCircle(
      Offset(b.sx, cy),
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = base,
    );
    final chick = images.get(Sprites.chicken(world.leaderSkin));
    if (chick != null) {
      _fitCentered(canvas, chick, b.sx, cy - r * 0.26, r * 1.05);
    }
    _centerText(
      canvas,
      '${world.chickenCount}/${b.required}',
      Offset(b.sx, cy + r * 0.5),
      r * 0.46,
      base,
    );
  }

  /// The level goal: a glowing basket brimming with delivered eggs, crowned
  /// with a little FINISH banner.
  void _drawFinish(Canvas canvas, double cx, double baseY, double box,
      ui.Image basket, ui.Image? eggW, ui.Image? eggG) {
    final glowCenter = Offset(cx, baseY - box * 0.5);
    final glowRect = Rect.fromCircle(center: glowCenter, radius: box * 0.72);
    canvas.drawCircle(
      glowCenter,
      box * 0.72,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF3C4).withValues(alpha: 0.9),
            const Color(0xFFFFE08A).withValues(alpha: 0.0),
          ],
        ).createShader(glowRect),
    );

    _shadow(canvas, cx, baseY, box * 0.5);
    final h = _fit(canvas, basket, cx, baseY, box);

    // A rounded pile of eggs nestled inside the basket mouth. Back rows first.
    final eggBox = box * 0.3;
    final mouthY = baseY - h * 0.55;
    const spots = <Offset>[
      Offset(-0.14, -0.10),
      Offset(0.14, -0.10),
      Offset(-0.30, 0.02),
      Offset(0.30, 0.02),
      Offset(0.0, 0.0),
      Offset(-0.15, 0.12),
      Offset(0.15, 0.12),
    ];
    for (var i = 0; i < spots.length; i++) {
      final egg = (i == 4 && eggG != null) ? eggG : (eggW ?? eggG);
      if (egg == null) break;
      _fitCentered(
        canvas,
        egg,
        cx + spots[i].dx * box,
        mouthY + spots[i].dy * box,
        i == 4 ? eggBox * 1.08 : eggBox,
      );
    }

    _drawFinishBanner(canvas, cx, baseY - h - box * 0.14);
    _drawSparkle(canvas, cx - box * 0.5, baseY - h * 0.9, box * 0.05);
    _drawSparkle(canvas, cx + box * 0.46, baseY - h * 1.02, box * 0.07);
  }

  void _drawFinishBanner(Canvas canvas, double cx, double cy) {
    const text = 'FINISH';
    final tp = TextPainter(
      text: const TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = tp.width + 34;
    const h = 34.0;
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(17));
    canvas.drawRRect(rrect.shift(const Offset(0, 3)), Paint()..color = const Color(0x33000000));
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6EC85B), Color(0xFF3E9A3A)],
        ).createShader(rect),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.85),
    );
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  void _drawSparkle(Canvas canvas, double cx, double cy, double r) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawCircle(Offset(cx, cy), r, paint);
    final thin = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = r * 0.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - r * 2, cy), Offset(cx + r * 2, cy), thin);
    canvas.drawLine(Offset(cx, cy - r * 2), Offset(cx, cy + r * 2), thin);
  }

  /// Draws [img] fitted (contain) inside a [box]-sized square, bottom-centred
  /// at ([cx], [bottomY]). Optional [sx]/[sy] apply squash & stretch anchored
  /// at the feet. Returns the drawn height.
  double _fit(Canvas canvas, ui.Image img, double cx, double bottomY, double box,
      {double sx = 1, double sy = 1}) {
    final scale = box / math.max(img.width, img.height);
    final w = img.width * scale * sx;
    final h = img.height * scale * sy;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(cx - w / 2, bottomY - h, w, h),
      Paint()..filterQuality = FilterQuality.medium,
    );
    return h;
  }

  /// Same as [_fit] but centred on ([cx], [cy]).
  void _fitCentered(Canvas canvas, ui.Image img, double cx, double cy, double box) {
    final scale = box / math.max(img.width, img.height);
    final w = img.width * scale;
    final h = img.height * scale;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(cx - w / 2, cy - h / 2, w, h),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  void _shadow(Canvas canvas, double cx, double y, double radius) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, y - 2), width: radius * 2, height: radius * 0.62),
      Paint()..color = const Color(0x2E000000),
    );
  }

  void _centerText(Canvas canvas, String text, Offset center, double fontSize, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  void _drawEffects(Canvas canvas, Size size) {
    for (final e in world.effects) {
      final sx = _screenX(size, e.trackPos);
      final y = _baseY(size, e.lateral) - 50 - e.age * 42;
      final opacity = (1.0 - e.age / 1.1).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: e.text,
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Color(e.color).withValues(alpha: opacity),
            shadows: [
              Shadow(color: Colors.white.withValues(alpha: opacity * 0.9), blurRadius: 5),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(sx - tp.width / 2, y));
    }
  }

  void _drawCountdown(Canvas canvas, Size size, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: text == 'GO!' ? 100 : 130,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          shadows: const [
            Shadow(color: Color(0xAA000000), blurRadius: 18, offset: Offset(0, 4)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
  }

  double _sin(double v) => math.sin(v);

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => false;
}

class _Drawable {
  _Drawable(this.y, this.draw);
  final double y;
  final void Function(Canvas canvas) draw;
}

class _GateBadge {
  _GateBadge(this.sx, this.required);
  final double sx;
  final int required;
}
