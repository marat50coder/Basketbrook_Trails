import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/sprites.dart';

/// A tappable button that gives a soft press animation. The core building
/// block for every interactive control in the game.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.94,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// A big rounded gradient call-to-action button.
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.colors = AppColors.greenGradient,
    this.textColor = Colors.white,
    this.height = 62,
    this.fontSize = 22,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final List<Color> colors;
  final Color textColor;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final radius = height / 2;
    return Pressable(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: colors.last.withValues(alpha: 0.5),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
            border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glossy top highlight for a polished, tactile feel.
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: height * 0.5,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.28),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: textColor, size: fontSize + 4),
                        const SizedBox(width: 10),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.title(fontSize, color: textColor, weight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A circular icon button used for pause, back, settings, etc.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 52,
    this.color = Colors.white,
    this.iconColor = AppColors.ink,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 5)),
          ],
          border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.2),
        ),
        child: Icon(icon, color: iconColor, size: size * 0.5),
      ),
    );
  }
}

/// A frosted, rounded surface for panels and dialogs.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color = Colors.white,
    this.radius = 28,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 12)),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.2),
      ),
      child: child,
    );
  }
}

/// Standard menu header: back button, title and optional trailing widget.
class MenuHeader extends StatelessWidget {
  const MenuHeader({super.key, required this.title, this.trailing, this.onBack});

  final String title;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
      child: Row(
        children: [
          RoundIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
            size: 46,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: AppText.title(26),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// White pill showing the coin balance.
class CoinBadge extends StatelessWidget {
  const CoinBadge({super.key, required this.coins});
  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(Sprites.coin(Sprites.coinFace), height: 24),
          const SizedBox(width: 6),
          Text('$coins', style: AppText.title(18, color: AppColors.goldDark)),
        ],
      ),
    );
  }
}

/// A rounded progress bar with a fraction 0..1.
class TrackBar extends StatelessWidget {
  const TrackBar({
    super.key,
    required this.value,
    this.height = 14,
    this.colors = AppColors.greenGradient,
  });

  final double value;
  final double height;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.creamDeep,
        borderRadius: BorderRadius.circular(height),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(height),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small pill showing an icon and a value (coins, eggs, chickens...).
class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.icon,
    required this.value,
    this.color = AppColors.ink,
    this.background = Colors.white,
  });

  final Widget icon;
  final String value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 22, height: 22, child: icon),
          const SizedBox(width: 7),
          Text(value, style: AppText.title(18, color: color)),
        ],
      ),
    );
  }
}

/// A rounded-square gradient badge holding a single icon. The building block
/// for the app's card iconography.
class IconChip extends StatelessWidget {
  const IconChip({
    super.key,
    required this.icon,
    this.colors = AppColors.greenGradient,
    this.size = 46,
  });

  final IconData icon;
  final List<Color> colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.54),
    );
  }
}

/// A frosted glass surface (translucent + blur). Sits on top of the meadow
/// backdrop for a modern, premium, minimalist look.
class Frosted extends StatelessWidget {
  const Frosted({
    super.key,
    required this.child,
    this.radius = 24,
    this.padding = const EdgeInsets.all(12),
    this.tint = const Color(0x99FFFFFF),
    this.blur = 16,
  });

  final Widget child;
  final double radius;
  final EdgeInsets padding;
  final Color tint;
  final double blur;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.4),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A clean, minimalist frosted list/grid tile: a colour-accented icon chip,
/// a title and an optional trailing widget. Used across menu surfaces so the
/// whole app shares one visual language.
class MenuTile extends StatelessWidget {
  const MenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.accent,
    required this.onTap,
    this.subtitle,
    this.badge,
    this.trailing,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final List<Color> accent;
  final VoidCallback onTap;
  final String? subtitle;
  final String? badge;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: EdgeInsets.all(compact ? 10 : 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(color: AppColors.shadow, blurRadius: 14, offset: Offset(0, 7)),
              ],
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: Row(
              children: [
                IconChip(icon: icon, colors: accent, size: compact ? 40 : 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: AppText.title(compact ? 15 : 17),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!,
                            style: AppText.label(12, color: AppColors.inkSoft),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                trailing ??
                    Icon(Icons.chevron_right_rounded,
                        color: AppColors.inkSoft.withValues(alpha: 0.6), size: 22),
              ],
            ),
          ),
          if (badge != null)
            Positioned(
              top: -5,
              right: -5,
              child: Container(
                padding: const EdgeInsets.all(5),
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(badge!,
                    textAlign: TextAlign.center, style: AppText.title(12, color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}
