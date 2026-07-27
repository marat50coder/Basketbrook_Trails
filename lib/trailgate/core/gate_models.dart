enum TrailRoute {
  native,
  portal,
  undecided;

  String get storageValue => switch (this) {
    TrailRoute.native => 'native',
    TrailRoute.portal => 'portal',
    TrailRoute.undecided => 'undecided',
  };

  static TrailRoute parse(String? value) => switch (value) {
    'portal' || 'web' => TrailRoute.portal,
    'native' || 'game' => TrailRoute.native,
    _ => TrailRoute.undecided,
  };
}

class GateReply {
  const GateReply({
    required this.accepted,
    this.url,
    this.expiresAt,
    this.reason,
  });

  factory GateReply.fromJson(Map<String, dynamic> json) {
    final rawExpiry = json['expires'];
    return GateReply(
      accepted: json['ok'] == true,
      url: json['url'] is String ? json['url'] as String : null,
      expiresAt: rawExpiry is num
          ? rawExpiry.toInt()
          : int.tryParse(rawExpiry?.toString() ?? ''),
      reason: json['message']?.toString(),
    );
  }

  factory GateReply.rejected(String reason) =>
      GateReply(accepted: false, reason: reason);

  final bool accepted;
  final String? url;
  final int? expiresAt;
  final String? reason;

  bool get hasDestination => accepted && (url?.isNotEmpty ?? false);
}

sealed class GateStop {
  const GateStop();
}

final class NativeStop extends GateStop {
  const NativeStop();
}

final class PortalStop extends GateStop {
  const PortalStop(this.url, {this.coldLaunch = false});

  final String url;
  final bool coldLaunch;
}

final class OfflineStop extends GateStop {
  const OfflineStop({required this.returnToNative});

  final bool returnToNative;
}
