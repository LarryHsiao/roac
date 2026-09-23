import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:roac/roaming.dart';
import 'package:roac/sprite.dart';
import 'package:roac/tars.dart';

void main() {
  group('TARS keeps inside his frame', () {
    /// The edge of a frame is not empty space — in a sprite sheet the next
    /// frame begins there. Ink on the outermost ring would arrive in the
    /// neighbouring TARS, which is what the raven's own version of this test
    /// guards against for him.
    Future<List<int>> inkOnTheEdgeOf(Gait gait, double phase, int side) async {
      final across = ui.Size(side.toDouble(), side.toDouble());
      final recorder = ui.PictureRecorder();
      paintTars(
        ui.Canvas(recorder),
        across,
        gait: gait,
        facing: Facing.right,
        phase: phase,
      );
      final drawn = await recorder.endRecording().toImage(side, side);
      final raw = await drawn.toByteData(format: ui.ImageByteFormat.rawRgba);
      final pixels = raw!.buffer.asUint8List();
      int alphaAt(int x, int y) => pixels[(y * side + x) * 4 + 3];
      return [
        for (var at = 0; at < side; at++) ...[
          alphaAt(0, at),
          alphaAt(side - 1, at),
          alphaAt(at, 0),
          alphaAt(at, side - 1),
        ],
      ].where((alpha) => alpha > 0).toList();
    }

    for (final gait in Gait.values) {
      // A plain test, not a widget one: encoding an image needs real async,
      // and a widget test's clock is its own.
      test('however $gait stands, at any moment, at any size', () async {
        const expected = <int>[];

        final spilled = <int>[];
        for (final side in [Sprite.size.toInt(), 48, 240]) {
          for (final phase in [0.0, 0.125, 0.25, 0.5, 0.75, 0.875]) {
            spilled.addAll(await inkOnTheEdgeOf(gait, phase, side));
          }
        }

        expect(spilled, expected);
      });
    }
  });
}
