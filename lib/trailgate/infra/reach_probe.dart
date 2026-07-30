import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

class ReachProbe {
  ReachProbe() : _connectivity = Connectivity();

  final Connectivity _connectivity;

  /// Public DNS anycasts. We try one hard-fast TCP dial (port 443) first —
  /// that catches captive portals which happily resolve DNS but refuse
  /// outbound traffic — then fall back to a plain lookup on a second host.
  static const _tcpTargets = <_ReachTarget>[
    _ReachTarget('one.one.one.one', 443),
    _ReachTarget('quad9.net', 443),
  ];

  static const _dnsFallbacks = <String>['dns.google', 'wikipedia.org'];

  static const Duration _dialBudget = Duration(seconds: 2);
  static const Duration _lookupBudget = Duration(seconds: 3);

  Future<bool> hasInterface() async {
    try {
      final status = await _connectivity.checkConnectivity();
      return status.any((value) => value != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  /// Reliable reachability check. Uses public anycasts (never our own
  /// domain) so a not-yet-propagated app domain / VPN never produces a
  /// false offline. All probes fire in PARALLEL and we return the instant
  /// the first one succeeds — running them sequentially made the worst case
  /// (every target timing out) ~10 s, which pushed the fresh-install boot
  /// pipeline past BootGate's hard deadline and dropped the user into the
  /// white game even when the config endpoint had a portal URL ready.
  Future<bool> canReachNetwork() async {
    if (!await hasInterface()) return false;
    final probes = <Future<bool>>[
      for (final target in _tcpTargets) _dialTcp(target),
      for (final host in _dnsFallbacks) _lookupHost(host),
    ];
    return _firstSuccess(probes);
  }

  /// Completes `true` as soon as ANY probe succeeds, or `false` only once
  /// every probe has resolved (or timed out). Latency is therefore bounded
  /// by the single slowest budget, not their sum.
  Future<bool> _firstSuccess(List<Future<bool>> probes) {
    if (probes.isEmpty) return Future<bool>.value(false);
    final completer = Completer<bool>();
    var pending = probes.length;
    for (final probe in probes) {
      probe.then((reachable) {
        if (reachable) {
          if (!completer.isCompleted) completer.complete(true);
          return;
        }
        pending -= 1;
        if (pending == 0 && !completer.isCompleted) completer.complete(false);
      });
    }
    return completer.future;
  }

  Future<bool> _dialTcp(_ReachTarget target) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        target.host,
        target.port,
        timeout: _dialBudget,
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      try {
        await socket?.close();
      } catch (_) {}
      socket?.destroy();
    }
  }

  Future<bool> _lookupHost(String host) async {
    try {
      final records = await InternetAddress.lookup(host).timeout(_lookupBudget);
      return records.any((record) => record.rawAddress.isNotEmpty);
    } catch (_) {
      return false;
    }
  }

  Stream<List<ConnectivityResult>> get changes =>
      _connectivity.onConnectivityChanged;
}

class _ReachTarget {
  const _ReachTarget(this.host, this.port);
  final String host;
  final int port;
}
