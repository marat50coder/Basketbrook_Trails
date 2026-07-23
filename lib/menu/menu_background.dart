import 'package:flutter/material.dart';

/// Shared backdrop for all menu screens: the gameplay location artwork, gently
/// lightened so the frosted cards and text stay readable on top.
class MenuBackground extends StatelessWidget {
  const MenuBackground({super.key, required this.child});

  static const String _bg =
      'assets/Basketbrook_Trails_gameplay_assets/bg_location1_asset.webp';

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Decode the backdrop at (roughly) screen resolution instead of its full
    // source size. This keeps the shared image cache small so hopping between
    // menu screens stays smooth.
    final media = MediaQuery.of(context);
    final cacheW = (media.size.width * media.devicePixelRatio).round();
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          _bg,
          fit: BoxFit.cover,
          cacheWidth: cacheW > 0 ? cacheW : null,
          filterQuality: FilterQuality.low,
        ),
        // Soft veil for contrast against the busy scenery.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x66FFFFFF),
                Color(0x22FFFFFF),
                Color(0x55FFFFFF),
              ],
              stops: [0.0, 0.4, 1.0],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
