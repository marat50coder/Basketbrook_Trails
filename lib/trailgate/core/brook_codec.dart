import 'dart:typed_data';

// Position-keyed RC4-style stream (KSA/PRGA) with a per-index offset. The salt
// and the position multiplier below MUST stay in sync with
// tool/encode_trail_values.dart. When re-fingerprinting a new app, change both
// files and re-run the tool.
const List<int> _brookSalt = <int>[
  0x9E, 0x37, 0x79, 0xB1, 0x2C, 0x84, 0x5A, 0xF3,
  0x6D, 0x11, 0xC8, 0x4B, 0x20, 0xE7, 0x53, 0xA6,
];
const int _posMul = 29;

Uint8List _buildBrookStream(int length) {
  final state = List<int>.generate(256, (index) => index);
  var cursor = 0;
  for (var index = 0; index < state.length; index++) {
    cursor =
        (cursor + state[index] + _brookSalt[index % _brookSalt.length]) & 0xff;
    final swap = state[index];
    state[index] = state[cursor];
    state[cursor] = swap;
  }

  final result = Uint8List(length);
  var left = 0;
  var right = 0;
  for (var index = 0; index < length; index++) {
    left = (left + 1) & 0xff;
    right = (right + state[left] + index) & 0xff;
    final swap = state[left];
    state[left] = state[right];
    state[right] = swap;
    result[index] = state[(state[left] + state[right]) & 0xff];
  }
  return result;
}

String unfoldBrook(List<int> encoded) {
  if (encoded.isEmpty) return '';
  final stream = _buildBrookStream(encoded.length);
  final plain = Uint8List(encoded.length);
  for (var index = 0; index < encoded.length; index++) {
    plain[index] = (encoded[index] - stream[index] - (index * _posMul)) & 0xff;
  }
  return String.fromCharCodes(plain);
}
