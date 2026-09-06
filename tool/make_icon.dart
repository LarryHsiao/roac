// Writes Roäc's app icon out, for both platforms this ships on.
//
//   flutter test tool/make_icon.dart
//
// It lives outside test/ so it stays out of the ordinary suite: this writes
// files, which is not what a test should do. It is run by hand when the
// raven's drawing changes, and its output is committed — a fresh clone builds
// with the icon already in place, no generation step of its own.
//
// The icon is the same drawn bird as the sprite itself, not a separate
// picture — paintRoac is the one door either goes through, so there is never
// a second Roäc to keep in step with the first.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:roac/roaming.dart';
import 'package:roac/sprite.dart';

/// The Nord-slate background the settings panel already wears, so the icon
/// reads as this app's rather than a stock template's.
const _fill = ui.Color(0xFF2E3440);

/// How much of the square is left bare around the bird, so a tightly cropped
/// silhouette does not touch the corners it is rounded with.
const _padding = 0.14;

/// How rounded the corners are, as a fraction of the edge — a generous round
/// in the shape the desktop's own icons wear, not the sharp square a plain
/// export would leave.
const _cornerFraction = 0.22;

/// Every PNG size Assets.xcassets/AppIcon.appiconset/Contents.json names.
const _macSizes = [16, 32, 64, 128, 256, 512, 1024];

/// The sizes embedded in the Windows .ico — the conventional set Explorer,
/// the taskbar and the title bar each pick their own resolution from.
const _windowsSizes = [16, 32, 48, 256];

void main() {
  test('write the app icon out, macOS and Windows both', () async {
    final master = <int, Uint8List>{
      for (final size in {..._macSizes, ..._windowsSizes})
        size: await _iconPng(size),
    };

    for (final size in _macSizes) {
      final written = File(
        'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_$size.png',
      );
      await written.writeAsBytes(master[size]!);
    }

    final ico = _icoOf([
      for (final size in _windowsSizes) (size: size, png: master[size]!),
    ]);
    await File('windows/runner/resources/app_icon.ico').writeAsBytes(ico);

    // ignore: avoid_print
    print(
      'wrote ${_macSizes.length} macOS sizes and one Windows .ico '
      '(${_windowsSizes.join('/')})',
    );
  });
}

/// The icon at [size], as PNG bytes: the panel's own slate, rounded, holding
/// Roäc at rest.
Future<Uint8List> _iconPng(int size) async {
  final s = size.toDouble();
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  canvas.drawRRect(
    ui.RRect.fromRectAndRadius(
      ui.Rect.fromLTWH(0, 0, s, s),
      ui.Radius.circular(s * _cornerFraction),
    ),
    ui.Paint()..color = _fill,
  );

  final drawn = s * (1 - _padding * 2);
  canvas.save();
  canvas.translate(s * _padding, s * _padding);
  paintRoac(
    canvas,
    ui.Size.square(drawn),
    gait: Gait.idle,
    facing: Facing.right,
    phase: 0,
  );
  canvas.restore();

  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

/// A Windows .ico assembled from [images], each already PNG-encoded at its
/// named size.
///
/// Modern Windows (Vista onward) reads a PNG-compressed image directly inside
/// an ICONDIRENTRY — the format needs no BMP re-encoding, only the ICONDIR
/// header and one directory entry per image ahead of the image data itself.
Uint8List _icoOf(List<({int size, Uint8List png})> images) {
  final header = ByteData(6)
    ..setUint16(0, 0, Endian.little) // reserved
    ..setUint16(2, 1, Endian.little) // type: 1 = icon
    ..setUint16(4, images.length, Endian.little);

  final entries = ByteData(16 * images.length);
  var offset = 6 + 16 * images.length;
  for (var at = 0; at < images.length; at++) {
    final (:size, :png) = images[at];
    // A byte of 0 means 256 in the ICO format's own reckoning — there is no
    // way to write 256 into a single byte, so this is not a special case
    // invented here but the format's own rule for its largest size.
    final edge = size == 256 ? 0 : size;
    entries
      ..setUint8(at * 16, edge)
      ..setUint8(at * 16 + 1, edge)
      ..setUint8(at * 16 + 2, 0) // no palette
      ..setUint8(at * 16 + 3, 0) // reserved
      ..setUint16(at * 16 + 4, 1, Endian.little) // colour planes
      ..setUint16(at * 16 + 6, 32, Endian.little) // bits per pixel
      ..setUint32(at * 16 + 8, png.length, Endian.little)
      ..setUint32(at * 16 + 12, offset, Endian.little);
    offset += png.length;
  }

  final written = BytesBuilder()
    ..add(header.buffer.asUint8List())
    ..add(entries.buffer.asUint8List());
  for (final image in images) {
    written.add(image.png);
  }
  return written.toBytes();
}
