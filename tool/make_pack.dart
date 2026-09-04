// Writes Roäc himself out as the first character pack.
//
//   flutter test tool/make_pack.dart
//
// It lives outside test/ so it stays out of the ordinary suite: this writes a
// file, which is not what a test should do. It is run by hand when the raven's
// drawing changes, and its output is committed — an artist opening
// packs/roac-raven.zip finds a working example of the format to copy.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roac/pack.dart';
import 'package:roac/roaming.dart';
import 'package:roac/sprite.dart';

/// Where the finished pack is written.
const _writtenTo = 'packs/roac-raven.zip';

/// The phases each gait is sampled at.
///
/// The walk's three are the poses its cycle names: passing over the standing
/// leg, then each of the two footfalls. Played 0, 1, 0, 2 they make the four
/// steps of a stride, the passing pose serving twice — which is why an artist
/// draws three and not four.
const _sampledAt = {
  'idle': [0.0, 0.25, 0.5, 0.75],
  'walking': [0.0, 0.25, 0.75],
  'pinned': [0.0],
};

/// How the frames of each gait are played, and what carries them on.
const _played = {
  'idle': {
    'sequence': [0, 1, 2, 3],
    'msPerFrame': 600,
  },
  'walking': {
    'sequence': [0, 1, 0, 2],
    'pxPerFrame': 5,
  },
  'pinned': {
    'sequence': [0],
  },
};

void main() {
  test('write Roäc out as the first pack', () async {
    final zip = Archive();
    final gaits = <String, Object>{};
    for (final gait in gaitNames.entries) {
      gaits[gait.key] = await _drawInto(zip, gait.key, gait.value);
    }
    zip.addFile(_manifestOf(gaits));

    final written = File(_writtenTo);
    await written.parent.create(recursive: true);
    await written.writeAsBytes(ZipEncoder().encode(zip));

    // Read back through the very path a bought pack takes. A pack this tool
    // writes that the loader will not read is not a pack at all.
    final read = await packFrom(await written.readAsBytes());
    expect(read, isA<Character>());
    // ignore: avoid_print
    print('wrote $_writtenTo — ${(read as Character).poses.length} gaits');
  });
}

/// Draws one gait's strip into [zip], and says how the manifest should name it.
Future<Map<String, Object>> _drawInto(
  Archive zip,
  String named,
  Gait gait,
) async {
  final phases = _sampledAt[named];
  final played = _played[named];
  if (phases == null || played == null) {
    throw StateError('This tool does not know how to draw $named.');
  }
  final strip = await _stripOf(gait, phases);
  final image = '$named.png';
  zip.addFile(ArchiveFile(image, strip.length, strip));
  return {'image': image, 'frames': phases.length, ...played};
}

/// The manifest, written as an artist would write it by hand — whole pixels
/// as whole numbers, since this file is the example others are copied from.
ArchiveFile _manifestOf(Map<String, Object> gaits) {
  final written = utf8.encode(
    const JsonEncoder.withIndent('  ').convert({
      'format': readableFormat,
      'name': 'Roäc',
      'author': 'Larry Hsiao',
      'licence': 'MIT',
      'frame': {'width': Sprite.size.toInt(), 'height': Sprite.size.toInt()},
      'gaits': gaits,
    }),
  );
  return ArchiveFile(manifestName, written.length, written);
}

/// One strip: every phase of a gait drawn side by side, on nothing, so the
/// bird carries its own transparency wherever it is laid.
Future<Uint8List> _stripOf(Gait gait, List<double> phases) async {
  const frame = Sprite.size;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  for (var at = 0; at < phases.length; at++) {
    canvas.save();
    canvas.translate(frame * at, 0);
    paintRoac(
      canvas,
      const ui.Size(frame, frame),
      gait: gait,
      facing: Facing.right,
      phase: phases[at],
    );
    canvas.restore();
  }
  final drawn = await recorder.endRecording().toImage(
    (frame * phases.length).round(),
    frame.round(),
  );
  final bytes = await drawn.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}
