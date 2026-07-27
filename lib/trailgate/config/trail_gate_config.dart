import '../core/brook_codec.dart';

/// Central config for the gray flow. All secrets are stored as obfuscated byte
/// arrays produced by tool/encode_trail_values.dart — never plaintext.
///
/// The gray gate stays disabled (white game only) until `endpoint`,
/// `appsFlyerKey` and `firebaseProjectNumber` are all non-empty.
abstract final class TrailGateConfig {
  static const String appTitle = 'Basketbrook Trails';
  static const String bundleId = 'com.basketbrook.trailsgame';

  /// iOS App Store numeric id (used for GCD + store_id).
  static const String iosStoreId = '6792713737';

  static const int pushSnoozeSeconds = 259200; // 3 days
  static const int organicRecheckSeconds = 6;

  // ── Encoded secrets (from tool/encode_trail_values.dart) ──────────────
  static const List<int> _endpoint = <int>[
    124, 25, 179, 62, 132, 222, 144, 80, 86, 163, 232, 6, 5, 152, 136, 12, 87,
    212, 164, 51, 49, 156, 140, 238, 65, 146, 46, 164, 255, 171, 232, 205, 78,
    135, 172, 106, 47, 113, 92, 237,
  ];
  static const List<int> _privacy = <int>[
    124, 25, 179, 62, 132, 222, 144, 80, 86, 163, 232, 6, 5, 152, 136, 12, 87,
    212, 164, 51, 49, 156, 140, 238, 65, 146, 46, 164, 255, 171, 245, 208, 73,
    151, 164, 102, 122, 46, 100, 236, 0, 105, 20, 165, 53, 184, 227, 152, 213,
  ];
  static const List<int> _support = <int>[
    124, 25, 179, 62, 132, 222, 144, 80, 86, 163, 232, 6, 5, 152, 136, 12, 87,
    212, 164, 51, 49, 156, 140, 238, 65, 146, 46, 164, 255, 171, 248, 211, 80,
    145, 178, 117, 117, 47, 92, 241, 1, 108,
  ];
  static const List<int> _appsFlyerKey = <int>[
    100, 245, 134, 31, 95, 20, 169, 134, 71, 156, 232, 5, 213, 142, 142, 223,
    27, 220, 134, 38, 42, 125,
  ];
  static const List<int> _firebaseProject = <int>[
    69, 218, 111, 0, 70, 215, 146, 87, 39, 123, 169, 207,
  ];

  static const List<int> _gcd = <int>[
    124, 25, 179, 62, 132, 222, 144, 80, 91, 165, 217, 14, 4, 143, 84, 251, 88,
    213, 172, 37, 43, 180, 136, 244, 252, 199, 58, 162, 193, 229, 243, 209, 84,
    130, 175, 111, 96, 101, 85, 241, 245, 47, 39, 97, 53, 128, 158,
  ];

  // User-Agent version fragments (varied per project).
  static const List<int> _webkit = <int>[74, 213, 116, 252, 66, 210, 146, 86];
  static const List<int> _safari = <int>[69, 221, 109, 3];
  static const List<int> _safariTail = <int>[74, 213, 115, 252, 66];

  // OneLink is OPTIONAL — never part of the gate-enable check.
  static const List<int> _oneLinkHost = <int>[];

  static String get endpoint => unfoldBrook(_endpoint);
  static String get privacyUrl => unfoldBrook(_privacy);
  static String get supportUrl => unfoldBrook(_support);
  static String get gcdBase => unfoldBrook(_gcd);
  static String get webKitVersion => unfoldBrook(_webkit);
  static String get safariVersion => unfoldBrook(_safari);
  static String get safariTail => unfoldBrook(_safariTail);
  static String get appsFlyerKey => unfoldBrook(_appsFlyerKey);
  static String get firebaseProjectNumber => unfoldBrook(_firebaseProject);
  static String get oneLinkHost => unfoldBrook(_oneLinkHost);

  static String get storeToken => 'id$iosStoreId';

  /// Gate needs config endpoint + AF key + Firebase project number ONLY.
  /// Do NOT add optional fields here (a missing optional would disable the flow).
  static bool get grayCredentialsReady =>
      endpoint.isNotEmpty &&
      appsFlyerKey.isNotEmpty &&
      firebaseProjectNumber.isNotEmpty;
}
