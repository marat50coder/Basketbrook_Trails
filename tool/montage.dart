// Builds a contact sheet per sprite category so slicing can be verified.
// Output: _webp_preview/montage_<category>.png
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final categories = Directory('assets/sprites')
      .listSync()
      .whereType<Directory>()
      .toList();
  Directory('_webp_preview').createSync(recursive: true);

  for (final cat in categories) {
    final name = cat.path.split(Platform.pathSeparator).last;
    final files = cat
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.png'))
        .toList()
      ..sort((a, b) {
        int idx(File f) => int.parse(
            f.path.split(Platform.pathSeparator).last.split('.').first);
        return idx(a).compareTo(idx(b));
      });
    if (files.isEmpty) continue;

    const cell = 150;
    const cols = 8;
    final rows = (files.length / cols).ceil();
    final sheet = img.Image(width: cols * cell, height: rows * cell, numChannels: 4);
    // checker background
    for (var y = 0; y < sheet.height; y++) {
      for (var x = 0; x < sheet.width; x++) {
        final c = ((x ~/ 16) + (y ~/ 16)) % 2 == 0 ? 210 : 170;
        sheet.setPixelRgba(x, y, c, c, c, 255);
      }
    }
    for (var i = 0; i < files.length; i++) {
      final sp = img.decodePng(files[i].readAsBytesSync())!;
      final scale = (cell - 12) / (sp.width > sp.height ? sp.width : sp.height);
      final w = (sp.width * scale).round();
      final h = (sp.height * scale).round();
      final resized = img.copyResize(sp, width: w, height: h);
      final cx = (i % cols) * cell + (cell - w) ~/ 2;
      final cy = (i ~/ cols) * cell + (cell - h) ~/ 2;
      img.compositeImage(sheet, resized, dstX: cx, dstY: cy);
    }
    final out = '_webp_preview/montage_$name.png';
    File(out).writeAsBytesSync(img.encodePng(sheet));
    stdout.writeln('$name: ${files.length} -> $out');
  }
}
