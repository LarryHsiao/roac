// Writes TARS out as a character pack, in the same format
// packs/roac-raven.zip demonstrates.
//
//   flutter test tool/make_tars_pack.dart
//
// Lives outside test/ for the same reason make_pack.dart does: this writes a
// file, which is not what a test should do. It is run by hand when TARS's
// drawing changes, and its output is committed.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roac/pack.dart';
import 'package:roac/roaming.dart';
import 'package:roac/sprite.dart';
import 'package:roac/tars.dart';

/// Where the finished pack is written.
const _writtenTo = 'packs/tars-robot.zip';

/// The phases each gait is sampled at — the same sampling `make_pack.dart`
/// uses, so a walk plays the same passing-then-both-footfalls rhythm.
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
  test('write TARS out as a pack', () async {
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

/// The manifest, written as an artist would write it by hand.
ArchiveFile _manifestOf(Map<String, Object> gaits) {
  final written = utf8.encode(
    const JsonEncoder.withIndent('  ').convert({
      'format': readableFormat,
      'name': 'TARS',
      'author': 'Larry Hsiao',
      'licence': 'MIT',
      'frame': {'width': Sprite.size.toInt(), 'height': Sprite.size.toInt()},
      'gaits': gaits,
    }),
  );
  return ArchiveFile(manifestName, written.length, written);
}

/// One strip: every phase of a gait drawn side by side, on nothing, so he
/// carries his own transparency wherever it is laid.
Future<Uint8List> _stripOf(Gait gait, List<double> phases) async {
  const frame = Sprite.size;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  for (var at = 0; at < phases.length; at++) {
    canvas.save();
    canvas.translate(frame * at, 0);
    paintTars(
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
