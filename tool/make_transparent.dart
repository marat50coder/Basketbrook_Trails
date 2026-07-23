import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final im = img.Image(width: 432, height: 432, numChannels: 4);
  img.fill(im, color: img.ColorRgba8(0, 0, 0, 0));
  File('assets/Basketbrook_Trails_additional_assets/icon_transparent.png')
      .writeAsBytesSync(img.encodePng(im));
  stdout.writeln('wrote transparent foreground');
}
