import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/app_theme.dart';
import '../widgets/ui_kit.dart';

/// Displays a web page (Privacy Policy / Support) inside a WebView.
///
/// Offline-first: the bundled copy is rendered **immediately** so the page is
/// always readable with zero internet and never shows a blank screen or a
/// stuck spinner. If (and only if) the device is actually online, the live URL
/// is loaded as an upgrade; any failure silently keeps the offline copy. The
/// content always renders as black text on a white background.
class WebPageScreen extends StatefulWidget {
  const WebPageScreen({
    super.key,
    required this.title,
    required this.url,
    required this.fallbackHtml,
  });

  final String title;
  final String url;
  final String fallbackHtml;

  @override
  State<WebPageScreen> createState() => _WebPageScreenState();
}

class _WebPageScreenState extends State<WebPageScreen> {
  late final WebViewController _controller;
  bool _loading = false;
  bool _attemptingLive = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            // Any failure while fetching the live page → revert to offline copy.
            if (_attemptingLive && (error.isForMainFrame ?? true)) _loadFallback();
          },
        ),
      );

    // Guaranteed baseline: show the bundled copy right away. This is the entire
    // reason the page works with no internet at all.
    _controller.loadHtmlString(widget.fallbackHtml);
    _tryLiveUpgrade();
  }

  /// Only if the device is genuinely online, try to replace the offline copy
  /// with the live page. Anything going wrong keeps the offline copy.
  Future<void> _tryLiveUpgrade() async {
    try {
      final result = await Connectivity().checkConnectivity();
      final online = result.isNotEmpty && !result.contains(ConnectivityResult.none);
      if (!online || !mounted) return;
      _attemptingLive = true;
      setState(() => _loading = true);
      _controller.loadRequest(Uri.parse(widget.url));
      // Safety net: if the live page stalls, drop back to the offline copy.
      Future.delayed(const Duration(seconds: 6), () {
        if (mounted && _loading) _loadFallback();
      });
    } catch (_) {
      _loadFallback();
    }
  }

  void _loadFallback() {
    _attemptingLive = false;
    _controller.loadHtmlString(widget.fallbackHtml);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 16, 8),
              child: Row(
                children: [
                  RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).pop(),
                    size: 44,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: AppText.title(24, color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Container(
                    color: Colors.white,
                    child: WebViewWidget(controller: _controller),
                  ),
                  if (_loading)
                    const Center(
                      child: CircularProgressIndicator(color: AppColors.green),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
