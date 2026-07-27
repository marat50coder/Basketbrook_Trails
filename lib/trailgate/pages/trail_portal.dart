import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../infra/push_relay.dart';
import '../infra/reach_probe.dart';
import '../infra/trail_agent.dart';
import '../infra/trail_vault.dart';
import 'offline_page.dart';

class TrailPortal extends StatefulWidget {
  const TrailPortal({
    super.key,
    required this.url,
    required this.vault,
    required this.probe,
    required this.notifications,
    required this.agent,
    this.coldLaunch = false,
  });

  final String url;
  final TrailVault vault;
  final ReachProbe probe;
  final PushRelay notifications;
  final TrailAgent agent;
  final bool coldLaunch;

  @override
  State<TrailPortal> createState() => _TrailPortalState();
}

class _TrailPortalState extends State<TrailPortal> with WidgetsBindingObserver {
  late final WebViewController _controller;
  StreamSubscription<List<ConnectivityResult>>? _networkSubscription;
  bool _viewportReady = false;
  bool _offlineShown = false;
  int _redirectAttempts = 0;
  String? _lastMainUrl;
  Timer? _metricsDebounce;
  Size? _lastMetricsSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enterImmersive();
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    final params = Platform.isIOS
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          )
        : const PlatformWebViewControllerCreationParams();
    _controller =
        WebViewController.fromPlatformCreationParams(
            params,
            onPermissionRequest: (request) => request.grant(),
          )
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.black)
          ..setUserAgent(widget.agent.userAgent)
          ..enableZoom(false)
          ..setNavigationDelegate(_navigation());
    if (_controller.platform is WebKitWebViewController) {
      (_controller.platform as WebKitWebViewController)
          .setAllowsBackForwardNavigationGestures(true);
    }

    widget.notifications.onDestination = (url) {
      final uri = Uri.tryParse(url);
      if (mounted && uri != null && uri.hasScheme) {
        _controller.loadRequest(uri);
      }
    };
    _networkSubscription = widget.probe.changes.listen((states) {
      if (states.every((state) => state == ConnectivityResult.none)) {
        _goOffline();
      }
    });

    if (widget.coldLaunch) {
      // Drain any duplicate the push relay may have stashed via
      // `getInitialMessage()` — the cold-start URL is already in widget.url,
      // so a re-stash would only trigger a redundant loadRequest via
      // `_consumePending` on the next lifecycle event. Fire-and-forget: we
      // never want that stash to reach us.
      widget.vault.consumePushUrl();
      _settleColdViewport();
    } else {
      _viewportReady = true;
      _controller.loadRequest(Uri.parse(widget.url));
      // Only listen for stashed URLs on non-cold-launch: cold-launch already
      // has widget.url and duplicate consumes were causing the WebView to
      // re-load the same URL a fraction of a second later (which then
      // redirected to the site's home because one-time deep-link tokens had
      // already been spent by the first load).
      WidgetsBinding.instance.addPostFrameCallback((_) => _consumePending());
    }
  }

  void _enterImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _settleColdViewport() async {
    _enterImmersive();
    // Let immersive mode settle in the phone's ACTUAL orientation before the
    // WebView mounts. No forced landscape nudge (that made a cold-start push
    // link open sideways then flip). Residual stretch is fixed after load.
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    setState(() => _viewportReady = true);
    await _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    setState(() {});
    final view = View.of(context);
    final size = view.physicalSize;
    final rotated = _lastMetricsSize != null &&
        ((_lastMetricsSize!.width < _lastMetricsSize!.height) !=
            (size.width < size.height));
    _lastMetricsSize = size;
    if (!rotated) return;
    _enterImmersive();
    _metricsDebounce?.cancel();
    _pokeReflow(const [40, 160, 320, 560, 850]);
  }

  void _pokeReflow(List<int> delaysMs) {
    for (final ms in delaysMs) {
      Timer(Duration(milliseconds: ms), () {
        if (!mounted) return;
        _controller.runJavaScript(
          'window.dispatchEvent(new Event("orientationchange"));'
          'window.dispatchEvent(new Event("resize"));'
          'if(window.visualViewport)'
          '  window.visualViewport.dispatchEvent(new Event("resize"));',
        ).catchError((_) {});
      });
    }
    _metricsDebounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      _installInsetGuard();
      _installZoomLock();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _enterImmersive();
      _consumePending();
    }
  }

  Future<void> _consumePending() async {
    final value = await widget.vault.consumePushUrl();
    final uri = value == null ? null : Uri.tryParse(value);
    if (mounted && uri != null && uri.hasScheme) {
      await _controller.loadRequest(uri);
    }
  }

  NavigationDelegate _navigation() {
    return NavigationDelegate(
      onPageStarted: (url) {
        _lastMainUrl = url;
      },
      onPageFinished: (_) {
        _redirectAttempts = 0;
        _installInsetGuard();
        _installZoomLock();
        _installTapPolish();
        _installKeyboardLift();
        _installFocusScaleGuard();
        _installInlinePlayback();
        // Post-load reflow — NO `_controller.reload()`. `_settleColdViewport`
        // parks the WebView for 280 ms while immersive mode settles, so the
        // first render is already in the final viewport. The reload used to
        // be here as a safety net, but on the current backend it invalidates
        // one-time deep-link tokens and the second request lands on the
        // site's home page — which the user experiences as "correct window
        // opens, then the WebView kicks me out". Rely on JS resize +
        // orientationchange to smooth over any residual pre-immersive layout.
        Future<void>.delayed(const Duration(milliseconds: 800), () async {
          if (!mounted) return;
          setState(() {});
          await _controller.runJavaScript(
            'window.dispatchEvent(new Event("orientationchange"));'
            'window.dispatchEvent(new Event("resize"));'
            'if(window.visualViewport)'
            '  window.visualViewport.dispatchEvent(new Event("resize"));',
          );
        });
      },
      onWebResourceError: (error) {
        if (error.errorCode == -999) return;
        // WKWebView reports isForMainFrame as null for the main navigation —
        // treat null as main-frame so a real failure is never swallowed.
        final mainFrame = error.isForMainFrame ?? true;
        final lower = error.description.toLowerCase();
        final redirectLoop =
            error.errorCode == -1007 ||
            lower.contains('too_many_redirects') ||
            lower.contains('too many redirects');
        if (redirectLoop && _lastMainUrl != null && _redirectAttempts < 3) {
          _redirectAttempts++;
          _controller.loadRequest(Uri.parse(_lastMainUrl!));
          return;
        }
        if (!mainFrame) return;
        _showOfflineAfterProbe();
      },
      onNavigationRequest: (request) {
        final uri = Uri.tryParse(request.url);
        if (uri == null) return NavigationDecision.prevent;
        if (<String>{
          'http',
          'https',
          'about',
          'data',
          'blob',
        }.contains(uri.scheme)) {
          if (request.isMainFrame) _lastMainUrl = request.url;
          return NavigationDecision.navigate;
        }
        launchUrl(uri, mode: LaunchMode.externalApplication);
        return NavigationDecision.prevent;
      },
    );
  }

  /// Confirms the outage with a reachability probe (WebView load errors can be
  /// transient) before routing to the offline screen.
  Future<void> _showOfflineAfterProbe() async {
    if (_offlineShown) return;
    bool online = true;
    try {
      online = await widget.probe.canReachNetwork();
    } catch (_) {
      online = false;
    }
    if (online) return;
    _goOffline();
  }

  Future<void> _goOffline() async {
    if (_offlineShown || !mounted) return;
    _offlineShown = true;
    String current;
    try {
      current = await _controller.currentUrl() ?? widget.url;
    } catch (_) {
      current = widget.url;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => OfflinePage(
          probe: widget.probe,
          retryBuilder: (_) => TrailPortal(
            url: current,
            vault: widget.vault,
            probe: widget.probe,
            notifications: widget.notifications,
            agent: widget.agent,
          ),
        ),
      ),
    );
  }

  void _installInsetGuard() {
    _controller.runJavaScript(r'''
(() => {
  const root = window;
  if (root.__bbInsetKeeper) return;
  root.__bbInsetKeeper = true;
  const marker = 'bb-inset-sheet';
  const rules = [
    ':root{',
    '--safe-area-inset-top:0px!important;',
    '--safe-area-inset-right:0px!important;',
    '--safe-area-inset-bottom:0px!important;',
    '--safe-area-inset-left:0px!important;',
    '--sat:0px!important;--sar:0px!important;',
    '--sab:0px!important;--sal:0px!important;',
    '--safe-top:0px!important;--safe-right:0px!important;',
    '--safe-bottom:0px!important;--safe-left:0px!important;',
    '}',
    'html,body{overscroll-behavior:none!important;',
    'overscroll-behavior-y:none!important;}'
  ].join('');
  const keyboardVisible = () => {
    const visual = root.visualViewport;
    return !!visual && visual.height < root.innerHeight * 0.75;
  };
  const refresh = () => {
    if (keyboardVisible()) return;
    const host = document.head || document.documentElement;
    if (!host) return;
    let viewport = document.querySelector('meta[name="viewport"]');
    if (!viewport) {
      viewport = document.createElement('meta');
      viewport.name = 'viewport';
      viewport.content = 'width=device-width, initial-scale=1, viewport-fit=contain';
      host.appendChild(viewport);
    } else {
      const clean = (viewport.content || '')
        .replace(/,?\s*viewport-fit\s*=\s*\w+/ig, '').trim();
      viewport.content = `${clean}${clean ? ', ' : ''}viewport-fit=contain`;
    }
    let sheet = document.getElementById(marker);
    if (!sheet) {
      sheet = document.createElement('style');
      sheet.id = marker;
      host.appendChild(sheet);
    }
    sheet.textContent = rules;
  };
  const schedule = () => {
    root.setTimeout(refresh, 170);
    root.setTimeout(refresh, 640);
  };
  ['pushState', 'replaceState'].forEach((name) => {
    const original = history[name];
    history[name] = function(...args) {
      const result = original.apply(this, args);
      schedule();
      return result;
    };
  });
  root.addEventListener('popstate', schedule);
  refresh();
  root.setInterval(refresh, 2900);
})();
''');
  }

  void _installZoomLock() {
    _controller.runJavaScript(r'''
(() => {
  if (window.__bbZoomLock) return;
  window.__bbZoomLock = true;
  const lockViewport = () => {
    const host = document.head || document.documentElement;
    if (!host) return;
    let vp = document.querySelector('meta[name="viewport"]');
    if (!vp) {
      vp = document.createElement('meta');
      vp.setAttribute('name', 'viewport');
      host.appendChild(vp);
    }
    vp.setAttribute('content',
      'width=device-width, initial-scale=1.0, maximum-scale=1.0, ' +
      'minimum-scale=1.0, user-scalable=no, viewport-fit=contain');
  };
  lockViewport();
  const stop = (e) => { e.preventDefault(); };
  ['gesturestart', 'gesturechange', 'gestureend'].forEach((t) =>
    document.addEventListener(t, stop, {passive: false}));
  document.addEventListener('touchmove', (e) => {
    if (e.scale !== undefined && e.scale !== 1) e.preventDefault();
  }, {passive: false});
  let lastTap = 0;
  document.addEventListener('touchend', (e) => {
    const now = Date.now();
    if (now - lastTap <= 300) e.preventDefault();
    lastTap = now;
  }, {passive: false});
  ['pushState', 'replaceState'].forEach((name) => {
    const original = history[name];
    history[name] = function(...args) {
      const result = original.apply(this, args);
      setTimeout(lockViewport, 150);
      return result;
    };
  });
  window.addEventListener('popstate', () => setTimeout(lockViewport, 150));
})();
''');
  }

  void _installTapPolish() {
    _controller.runJavaScript(r'''
(() => {
  if (window.__bbTapPolish) return;
  window.__bbTapPolish = true;
  const style = document.createElement('style');
  style.id = 'bb-tap-polish';
  style.textContent =
    '*{-webkit-tap-highlight-color:transparent!important;}' +
    '*:not(input):not(textarea):not([contenteditable="true"]){' +
      '-webkit-touch-callout:none!important;}';
  (document.head || document.documentElement).appendChild(style);
})();
''');
  }

  void _installKeyboardLift() {
    _controller.runJavaScript(r'''
(() => {
  if (window.__bbInputLift) return;
  window.__bbInputLift = true;
  const editable = (node) => !!node && (
    node.matches?.('input, textarea, select, [contenteditable="true"]')
  );
  const reveal = () => {
    const active = document.activeElement;
    if (!editable(active)) return;
    active.scrollIntoView({behavior: 'auto', block: 'nearest'});
  };
  document.addEventListener('focusin', (event) => {
    if (editable(event.target)) window.setTimeout(reveal, 350);
  }, true);
})();
''');
  }

  void _installFocusScaleGuard() {
    if (!Platform.isIOS) return;
    _controller.runJavaScript(r'''
(() => {
  if (window.__bbFocusScale) return;
  window.__bbFocusScale = true;
  const style = document.createElement('style');
  style.textContent =
    'input,textarea,select,[contenteditable="true"]{' +
    'font-size:max(16px,1em)!important;}';
  (document.head || document.documentElement).appendChild(style);
})();
''');
  }

  void _installInlinePlayback() {
    _controller.runJavaScript(r'''
(() => {
  if (window.__bbInlineMedia) return;
  window.__bbInlineMedia = true;
  const awaken = (video) => {
    if (!(video instanceof HTMLVideoElement)) return;
    video.setAttribute('playsinline', '');
    video.setAttribute('webkit-playsinline', '');
    video.playsInline = true;
    video.autoplay = true;
    const attempt = video.play();
    if (attempt?.catch) attempt.catch(() => {});
  };
  const scan = (node) => {
    if (node instanceof HTMLVideoElement) awaken(node);
    node.querySelectorAll?.('video').forEach(awaken);
  };
  scan(document);
  new MutationObserver((records) => {
    records.forEach((record) => record.addedNodes.forEach(scan));
  }).observe(document.documentElement, {childList: true, subtree: true});
})();
''');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _metricsDebounce?.cancel();
    _networkSubscription?.cancel();
    widget.notifications.onDestination = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.of(context).viewPadding;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await _controller.canGoBack()) {
          await _controller.goBack();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: _viewportReady
            ? Padding(
                // Respect notch/Dynamic Island (top + sides) AND the home
                // indicator (bottom) in BOTH orientations. Cold-start uses
                // viewPadding (never EdgeInsets.zero).
                padding: EdgeInsets.only(
                  top: safe.top,
                  bottom: safe.bottom,
                  left: safe.left,
                  right: safe.right,
                ),
                child: WebViewWidget(controller: _controller),
              )
            : const ColoredBox(color: Colors.black),
      ),
    );
  }
}
