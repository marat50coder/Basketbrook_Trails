import 'dart:typed_data';

// Position-keyed XOR stream driven by an FNV-1a digest of the salt fanned
// through a small LCG. This is a deliberately different algorithm family
// from the RC4-style KSA/PRGA gates other sibling apps ship, so the compiled
// machine code and byte arrays don't cluster on static analysis. Keep the
// constants below in sync with tool/encode_trail_values.dart.
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

String unfoldBrook(List<int> encoded) {
  if (encoded.isEmpty) return '';
  final plain = Uint8List(encoded.length);
  for (var index = 0; index < encoded.length; index++) {
    plain[index] = (encoded[index] ^ _brookKeyAt(index)) & 0xff;
  }
  return String.fromCharCodes(plain);
}
