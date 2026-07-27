import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/trail_gate_config.dart';
import '../infra/push_relay.dart';
import '../infra/trail_vault.dart';

class PushInvite extends StatefulWidget {
  const PushInvite({
    super.key,
    required this.vault,
    required this.notifications,
    required this.nextBuilder,
    this.onTokenReady,
  });

  final TrailVault vault;
  final PushRelay notifications;
  final WidgetBuilder nextBuilder;
  final Future<void> Function(String token)? onTokenReady;

  @override
  State<PushInvite> createState() => _PushInviteState();
}

class _PushInviteState extends State<PushInvite> {
  bool _working = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // BootGate locks portrait before routing here; re-enable landscape so this
    // screen rotates with the device (matches the WebView).
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _accept() async {
    if (_working) return;
    setState(() => _working = true);
    final granted = await widget.notifications.askPermission();
    final token = widget.notifications.token;
    if (granted && token != null && token.isNotEmpty) {
      await widget.onTokenReady?.call(token);
    }
    if (!granted) await _snooze();
    _continue();
  }

  Future<void> _skip() async {
    if (_working) return;
    setState(() => _working = true);
    await _snooze();
    _continue();
  }

  Future<void> _snooze() {
    final until =
        DateTime.now().millisecondsSinceEpoch ~/ 1000 +
        TrailGateConfig.pushSnoozeSeconds;
    return widget.vault.snoozePushInvite(until);
  }

  void _continue() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute<void>(builder: widget.nextBuilder));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final landscape = media.orientation == Orientation.landscape;
    final background = landscape
        ? 'assets/Horizontal_Notifications_Screen.webp'
        : 'assets/Vertical_Notifications_Screen.webp';
    // Landscape: centred horizontally with NO safe-area so the notch never
    // shifts the horizontal centre. Landscape button footprint is 20% smaller
    // than portrait so the artwork breathes.
    final width = landscape
        ? (media.size.width * 0.336).clamp(256.0, 448.0)
        : (media.size.width * 0.80).clamp(280.0, 440.0);
    final acceptH = landscape ? 52.8 : 74.0;
    final skipH = landscape ? 46.4 : 64.0;
    final acceptFont = landscape ? 17.6 : 25.0;
    final skipFont = landscape ? 16.0 : 22.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            background,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
          Align(
            alignment: Alignment(0, landscape ? 0.80 : 0.90),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                _InviteButton(
                  width: width,
                  height: acceptH,
                  fontSize: acceptFont,
                  label: 'Accept',
                  emphasized: true,
                  busy: _working,
                  onTap: _accept,
                ),
                SizedBox(height: landscape ? 12 : 16),
                _InviteButton(
                  width: width * 0.9,
                  height: skipH,
                  fontSize: skipFont,
                  label: 'Skip',
                  emphasized: false,
                  busy: false,
                  onTap: _skip,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteButton extends StatelessWidget {
  const _InviteButton({
    required this.width,
    required this.height,
    required this.fontSize,
    required this.label,
    required this.emphasized,
    required this.busy,
    required this.onTap,
  });

  final double width;
  final double height;
  final double fontSize;
  final String label;
  final bool emphasized;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = height / 2;
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            colors: emphasized
                ? const <Color>[Color(0xFF9CE86B), Color(0xFF3EA43C)]
                : const <Color>[Color(0xFF7FC96B), Color(0xFF2E7D32)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(color: const Color(0xFF1D5321), width: 3),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Colors.black45,
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: busy ? null : onTap,
            child: Center(
              child: busy
                  ? const SizedBox.square(
                      dimension: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        height: 1.0,
                        shadows: const <Shadow>[
                          Shadow(color: Colors.black38, blurRadius: 4),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
