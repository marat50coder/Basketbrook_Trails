// ignore_for_file: avoid_print

import 'dart:typed_data';

// Keep the algorithm + constants below in sync with
// lib/trailgate/core/brook_codec.dart. Change BOTH files when
// re-fingerprinting this project, then re-run this tool and paste the
// printed arrays into lib/trailgate/config/trail_gate_config.dart.
const int _fnvOffsetBasis = 0x811c9dc5;
const int _fnvPrime = 0x01000193;
const int _lcgMultiplier = 1103515245;
const int _lcgIncrement = 12345;
const int _lcgMask = 0xffffffff;
const int _rippleStep = 0x5b;

const List<int> _brookSalt = <int>[
  0xB7, 0x2E, 0x5A, 0x91, 0xC3, 0x0D, 0x74, 0xF1,
  0x88, 0x46, 0xA9, 0x22, 0xDE, 0x63, 0x35, 0xCC,
  0x1F, 0x9B, 0x50,
];

int _fnvDigestOfSalt() {
  var digest = _fnvOffsetBasis;
  for (final byte in _brookSalt) {
    digest = ((digest ^ (byte & 0xff)) * _fnvPrime) & _lcgMask;
  }
  return digest;
}

final int _saltDigest = _fnvDigestOfSalt();

int _brookKeyAt(int position) {
  var mixed = _saltDigest;
  mixed = ((mixed ^ (position & 0xff)) * _fnvPrime) & _lcgMask;
  mixed = ((mixed ^ ((position >> 8) & 0xff)) * _fnvPrime) & _lcgMask;
  mixed = ((mixed * _lcgMultiplier) + _lcgIncrement) & _lcgMask;
  final upper = (mixed >> 24) & 0xff;
  final middle = (mixed >> 13) & 0xff;
  final ripple = (position * _rippleStep) & 0xff;
  return (upper ^ middle ^ ripple) & 0xff;
}

List<int> fold(String value) {
  final bytes = Uint8List.fromList(value.codeUnits);
  return List<int>.generate(
    bytes.length,
    (index) => (bytes[index] ^ _brookKeyAt(index)) & 0xff,
  );
}

String unfold(List<int> encoded) {
  if (encoded.isEmpty) return '';
  final plain = Uint8List(encoded.length);
  for (var index = 0; index < encoded.length; index++) {
    plain[index] = (encoded[index] ^ _brookKeyAt(index)) & 0xff;
  }
  return String.fromCharCodes(plain);
}

void main() {
  const values = <String, String>{
    'endpoint': 'https://basketbrooktrails.com/config.php',
    'privacy': 'https://basketbrooktrails.com/privacy-policy.html',
    'support': 'https://basketbrooktrails.com/support.html',
    'gcd': 'https://gcdsdk.appsflyer.com/install_data/v5.0/',
    'webkit': '605.1.15',
    'safari': '18.5',
    'safariTail': '604.1',
    'appsFlyerDevKey': 'PPGQNpHeSZsj5jhE3wMgkB',
    'firebaseProjectNumber': '150253163944',
    'oneLinkHost': '',
  };

  for (final entry in values.entries) {
    final encoded = fold(entry.value);
    print('${entry.key}: <int>[${encoded.join(', ')}]');
    if (unfold(encoded) != entry.value) {
      throw StateError('Round-trip failed for ${entry.key}');
    }
  }
  print('VERIFY: all values round-tripped');
}
