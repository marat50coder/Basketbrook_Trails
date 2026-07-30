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
  Timer? _reflowTimer;
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
    _scheduleRotationSettle();
  }

  /// Fires a SINGLE resize dispatch after the native rotation animation has
  /// settled. Earlier versions dispatched five bursts (40/160/320/560/850
  /// ms) as WKWebView-safety, but that visibly shook responsive sites that
  /// already reflow on the native rotation event. One well-timed poke gets
  /// WKWebView to recalc its viewport without stacking synthetic reflows on
  /// top of the site's own layout code.
  void _scheduleRotationSettle() {
    _reflowTimer?.cancel();
    _metricsDebounce?.cancel();
    _reflowTimer = Timer(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      _controller.runJavaScript(_reflowScript).catchError((_) {});
    });
    _metricsDebounce = Timer(const Duration(milliseconds: 520), () {
      if (!mounted) return;
      _installInsetGuard();
      _installZoomLock();
    });
  }

  static const String _reflowScript = r'''
;(function(w){
  try { w.dispatchEvent(new Event('resize')); } catch (e) {}
  var vv = w.visualViewport;
  if (vv) { try { vv.dispatchEvent(new Event('resize')); } catch (e) {} }
})(window);
''';

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
        // opens, then the WebView kicks me out". A single dozed resize
        // handles residual pre-immersive layout without shaking the page.
        Future<void>.delayed(const Duration(milliseconds: 760), () async {
          if (!mounted) return;
          await _controller.runJavaScript(_reflowScript);
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
;(function(scope){
  var STAMP = 'brookInsetSweep';
  if (scope[STAMP]) return;
  scope[STAMP] = 1;

  var STYLE_ID = 'bt-brook-inset';
  var VIEWPORT_FIT = 'viewport-fit=contain';
  var VIEWPORT_BASE = 'width=device-width, initial-scale=1, ' + VIEWPORT_FIT;

  function buildRules(){
    var vars = ':root{';
    var pairs = [
      'safe-area-inset-top','safe-area-inset-right',
      'safe-area-inset-bottom','safe-area-inset-left',
      'sat','sar','sab','sal',
      'safe-top','safe-right','safe-bottom','safe-left'
    ];
    for (var i = 0; i < pairs.length; i++) {
      vars += '--' + pairs[i] + ':0px!important;';
    }
    vars += '}';
    var body = 'html,body{overscroll-behavior:none!important;' +
              'overscroll-behavior-y:none!important;}';
    return vars + body;
  }

  var RULES = buildRules();

  function isKeyboardOpen(){
    var vv = scope.visualViewport;
    if (!vv) return false;
    return vv.height < scope.innerHeight * 0.75;
  }

  function ensureMetaViewport(host){
    var meta = document.querySelector('meta[name="viewport"]');
    if (!meta) {
      meta = document.createElement('meta');
      meta.setAttribute('name', 'viewport');
      meta.setAttribute('content', VIEWPORT_BASE);
      host.appendChild(meta);
      return;
    }
    var content = (meta.getAttribute('content') || '')
      .replace(/,?\s*viewport-fit\s*=\s*\w+/ig, '')
      .trim();
    meta.setAttribute('content',
      content ? content + ', ' + VIEWPORT_FIT : VIEWPORT_BASE);
  }

  function ensureStyleSheet(host){
    var node = document.getElementById(STYLE_ID);
    if (!node) {
      node = document.createElement('style');
      node.id = STYLE_ID;
      host.appendChild(node);
    }
    if (node.textContent !== RULES) node.textContent = RULES;
  }

  function apply(){
    if (isKeyboardOpen()) return;
    var host = document.head || document.documentElement;
    if (!host) return;
    ensureMetaViewport(host);
    ensureStyleSheet(host);
  }

  function reapplyBurst(){
    scope.setTimeout(apply, 170);
    scope.setTimeout(apply, 640);
  }

  var wrapHistoryFn = function(name){
    var orig = history[name];
    if (typeof orig !== 'function') return;
    history[name] = function(){
      var out = orig.apply(this, arguments);
      reapplyBurst();
      return out;
    };
  };
  wrapHistoryFn('pushState');
  wrapHistoryFn('replaceState');
  scope.addEventListener('popstate', reapplyBurst);

  apply();
  scope.setInterval(apply, 2900);
})(window);
''');
  }

  void _installZoomLock() {
    _controller.runJavaScript(r'''
;(function(){
  var STAMP = 'brookZoomLatch';
  if (window[STAMP]) return;
  window[STAMP] = 1;

  var VP = 'width=device-width, initial-scale=1.0, ' +
           'maximum-scale=1.0, minimum-scale=1.0, ' +
           'user-scalable=no, viewport-fit=contain';

  function affix(){
    var host = document.head || document.documentElement;
    if (!host) return;
    var meta = document.querySelector('meta[name="viewport"]');
    if (!meta) {
      meta = document.createElement('meta');
      meta.setAttribute('name', 'viewport');
      host.appendChild(meta);
    }
    if (meta.getAttribute('content') !== VP) {
      meta.setAttribute('content', VP);
    }
  }
  affix();

  function halt(event){ event.preventDefault(); }
  var gestures = ['gesturestart', 'gesturechange', 'gestureend'];
  for (var g = 0; g < gestures.length; g++) {
    document.addEventListener(gestures[g], halt, {passive: false});
  }

  document.addEventListener('touchmove', function(event){
    if (event.scale !== undefined && event.scale !== 1) event.preventDefault();
  }, {passive: false});

  var doubleTapWindow = 300;
  var lastTapAt = 0;
  document.addEventListener('touchend', function(event){
    var stamp = Date.now();
    if (stamp - lastTapAt <= doubleTapWindow) event.preventDefault();
    lastTapAt = stamp;
  }, {passive: false});

  ['pushState', 'replaceState'].forEach(function(fn){
    var prev = history[fn];
    if (typeof prev !== 'function') return;
    history[fn] = function(){
      var res = prev.apply(this, arguments);
      window.setTimeout(affix, 150);
      return res;
    };
  });
  window.addEventListener('popstate', function(){
    window.setTimeout(affix, 150);
  });
})();
''');
  }

  void _installTapPolish() {
    _controller.runJavaScript(r'''
;(function(){
  var STAMP = 'brookTapVeneer';
  if (window[STAMP]) return;
  window[STAMP] = 1;

  var sheet = document.createElement('style');
  sheet.setAttribute('id', 'bt-brook-tap');
  var css = '';
  css += '*{-webkit-tap-highlight-color:transparent!important;}';
  css += '*:not(input):not(textarea):not([contenteditable="true"])';
  css += '{-webkit-touch-callout:none!important;}';
  sheet.appendChild(document.createTextNode(css));
  (document.head || document.documentElement).appendChild(sheet);
})();
''');
  }

  void _installKeyboardLift() {
    _controller.runJavaScript(r'''
;(function(){
  var STAMP = 'brookInputSurface';
  if (window[STAMP]) return;
  window[STAMP] = 1;

  var SELECTOR = 'input, textarea, select, [contenteditable="true"]';
  var REVEAL_DELAY = 350;

  function isEditable(node){
    return !!node && typeof node.matches === 'function' &&
      node.matches(SELECTOR);
  }
  function surface(){
    var focus = document.activeElement;
    if (!isEditable(focus)) return;
    focus.scrollIntoView({behavior: 'auto', block: 'nearest'});
  }
  document.addEventListener('focusin', function(event){
    if (!isEditable(event.target)) return;
    window.setTimeout(surface, REVEAL_DELAY);
  }, true);
})();
''');
  }

  void _installFocusScaleGuard() {
    if (!Platform.isIOS) return;
    _controller.runJavaScript(r'''
;(function(){
  var STAMP = 'brookFontFloor';
  if (window[STAMP]) return;
  window[STAMP] = 1;
  var sheet = document.createElement('style');
  sheet.appendChild(document.createTextNode(
    'input,textarea,select,[contenteditable="true"]{' +
    'font-size:max(16px,1em)!important;}'
  ));
  (document.head || document.documentElement).appendChild(sheet);
})();
''');
  }

  void _installInlinePlayback() {
    _controller.runJavaScript(r'''
;(function(){
  var STAMP = 'brookInlineReel';
  if (window[STAMP]) return;
  window[STAMP] = 1;

  function primeVideo(node){
    if (!(node instanceof HTMLVideoElement)) return;
    node.setAttribute('playsinline', '');
    node.setAttribute('webkit-playsinline', '');
    node.playsInline = true;
    node.autoplay = true;
    var promise = node.play();
    if (promise && typeof promise.catch === 'function') {
      promise.catch(function(){});
    }
  }
  function traverse(root){
    if (!root) return;
    if (root instanceof HTMLVideoElement) primeVideo(root);
    if (typeof root.querySelectorAll !== 'function') return;
    var found = root.querySelectorAll('video');
    for (var i = 0; i < found.length; i++) primeVideo(found[i]);
  }
  traverse(document);

  var observer = new MutationObserver(function(records){
    for (var r = 0; r < records.length; r++) {
      var added = records[r].addedNodes;
      for (var a = 0; a < added.length; a++) traverse(added[a]);
    }
  });
  observer.observe(document.documentElement, {
    childList: true,
    subtree: true,
  });
})();
''');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _metricsDebounce?.cancel();
    _reflowTimer?.cancel();
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
