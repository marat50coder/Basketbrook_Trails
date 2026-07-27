// ignore_for_file: avoid_print

import 'dart:typed_data';

// Keep this salt + position multiplier in sync with
// lib/trailgate/core/brook_codec.dart. Change them BOTH here and there when
// re-fingerprinting, then re-run this tool and paste the arrays into
// lib/trailgate/config/trail_gate_config.dart.
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

List<int> fold(String value) {
  final bytes = Uint8List.fromList(value.codeUnits);
  final stream = _buildBrookStream(bytes.length);
  return List<int>.generate(
    bytes.length,
    (index) => (bytes[index] + stream[index] + (index * _posMul)) & 0xff,
  );
}

String unfold(List<int> encoded) {
  final stream = _buildBrookStream(encoded.length);
  return String.fromCharCodes(
    List<int>.generate(
      encoded.length,
      (index) => (encoded[index] - stream[index] - (index * _posMul)) & 0xff,
    ),
  );
}

void main() {
  const values = <String, String>{
    'config': 'https://basketbrooktrails.com/config.php',
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
