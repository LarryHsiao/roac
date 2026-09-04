import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roac/pack.dart';
import 'package:roac/roaming.dart';
import 'package:roac/sprite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const window = Rect.fromLTWH(100, 200, restingSize, restingSize);

  test('the sprite area sits centred within the window', () {
    const margin = (restingSize - Sprite.size) / 2;
    const expected = Rect.fromLTWH(
      100 + margin,
      200 + margin,
      Sprite.size,
      Sprite.size,
    );

    final actual = spriteBoundsWithin(window);

    expect(actual, expected);
  });

  test('a cursor in the transparent margin falls outside the sprite area', () {
    const inMargin = Offset(105, 205);
    const expected = (margin: false, centre: true);

    final sprite = spriteBoundsWithin(window);
    final actual = (
      margin: sprite.contains(inMargin),
      centre: sprite.contains(window.center),
    );

    expect(actual, expected);
  });

  group('the walk cycle, which the sprite sheet will sample', () {
    test('the footfalls are a quarter and three quarters through', () {
      const expected = (
        passing: 0.0,
        contactNear: 1.0,
        over: 0.0,
        contactFar: -1.0,
      );

      final actual = (
        passing: legSwingAt(0),
        contactNear: legSwingAt(0.25),
        over: legSwingAt(0.5),
        contactFar: legSwingAt(0.75),
      );

      expect(actual.passing, closeTo(expected.passing, 0.001));
      expect(actual.contactNear, closeTo(expected.contactNear, 0.001));
      expect(actual.over, closeTo(expected.over, 0.001));
      expect(actual.contactFar, closeTo(expected.contactFar, 0.001));
    });

    test('the body is lowest at each footfall and highest passing over', () {
      const expected = (passing: 0.0, footfall: 1.0);

      final actual = (passing: bodyDropAt(0.5), footfall: bodyDropAt(0.25));

      expect(actual.passing, closeTo(expected.passing, 0.001));
      expect(actual.footfall, closeTo(expected.footfall, 0.001));
    });

    test('the head pushes and catches up twice a stride, once per step', () {
      const expected = (start: 1.0, firstStep: -1.0, middle: 1.0);

      final actual = (
        start: headThrustAt(0),
        firstStep: headThrustAt(0.25),
        middle: headThrustAt(0.5),
      );

      expect(actual.start, closeTo(expected.start, 0.001));
      expect(actual.firstStep, closeTo(expected.firstStep, 0.001));
      expect(actual.middle, closeTo(expected.middle, 0.001));
    });
  });

  group('the raven is redrawn only when it needs to be', () {
    testWidgets('a change of gait or of facing calls for a fresh painting', (
      tester,
    ) async {
      const expected = (gait: true, facing: true, neither: false);

      await tester.pumpWidget(
        const MaterialApp(
          home: Sprite(gait: Gait.idle, facing: Facing.right),
        ),
      );
      // Narrowed to the raven's own painting rather than taken by position:
      // a Material ancestor added here later would otherwise slip its own
      // CustomPaint in, and this would assert about the wrong thing quietly.
      CustomPainter drawn() => tester
          .widget<CustomPaint>(
            find.descendant(
              of: find.byType(Sprite),
              matching: find.byType(CustomPaint),
            ),
          )
          .painter!;
      final painting = drawn();
      await tester.pumpWidget(
        const MaterialApp(
          home: Sprite(gait: Gait.walking, facing: Facing.right),
        ),
      );
      final walking = drawn();
      await tester.pumpWidget(
        const MaterialApp(
          home: Sprite(gait: Gait.idle, facing: Facing.left),
        ),
      );
      final turned = drawn();

      final actual = (
        gait: walking.shouldRepaint(painting),
        facing: turned.shouldRepaint(painting),
        neither: painting.shouldRepaint(painting),
      );

      expect(actual, expected);
    });

    testWidgets('the bird moving through its cycle calls for one too', (
      tester,
    ) async {
      const expected = true;

      await tester.pumpWidget(
        const MaterialApp(
          home: Sprite(gait: Gait.idle, facing: Facing.right),
        ),
      );
      CustomPainter drawn() => tester
          .widget<CustomPaint>(
            find.descendant(
              of: find.byType(Sprite),
              matching: find.byType(CustomPaint),
            ),
          )
          .painter!;
      final atFirst = drawn();
      await tester.pump(const Duration(milliseconds: 300));

      // Nothing but the phase has moved. If that alone did not ask for a fresh
      // painting, the bird would stand frozen however long it breathed.
      expect(drawn().shouldRepaint(atFirst), expected);
    });
  });

  group('which frame of a pack is shown', () {
    Poses posesOf({
      required List<int> sequence,
      int? everyMs,
      int? everyPx,
      required ui.Image strip,
    }) => Poses(
      strip: strip,
      frames: sequence.length,
      sequence: sequence,
      everyMs: everyMs,
      everyPx: everyPx,
    );

    late ui.Image strip;

    setUpAll(() async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(
        recorder,
      ).drawPaint(ui.Paint()..color = const ui.Color(0xFF000000));
      strip = await recorder.endRecording().toImage(4, 1);
    });

    test('a walk counts the ground it has covered, not the clock', () {
      const expected = [0, 1, 0, 2];
      final walking = posesOf(sequence: [0, 1, 0, 2], everyPx: 5, strip: strip);

      final actual = [
        for (final walked in [0.0, 5.0, 10.0, 15.0])
          frameAt(walking, phase: 0, walked: walked),
      ];

      expect(actual, expected);
    });

    test('and comes round again, however far it has gone', () {
      const expected = 0;
      final walking = posesOf(sequence: [0, 1, 0, 2], everyPx: 5, strip: strip);

      final actual = frameAt(walking, phase: 0, walked: 20);

      expect(actual, expected);
    });

    test('a rest counts its own turning through the cycle', () {
      const expected = [0, 1, 2, 3];
      final resting = posesOf(
        sequence: [0, 1, 2, 3],
        everyMs: 600,
        strip: strip,
      );

      final actual = [
        for (final phase in [0.0, 0.25, 0.5, 0.75])
          frameAt(resting, phase: phase, walked: 999),
      ];

      expect(actual, expected);
    });

    test('a worn character sets its own tempo, not the built-in one', () {
      const expected = Duration(milliseconds: 2000);
      final resting = posesOf(
        sequence: [0, 1, 2, 3, 4],
        everyMs: 400,
        strip: strip,
      );

      final actual = cycleOf(
        resting,
        Gait.idle,
        breath: const Duration(milliseconds: 2400),
        stride: const Duration(milliseconds: 520),
      );

      expect(actual, expected);
    });

    test('a bird drawing himself keeps the periods written for him', () {
      const expected = (idle: 2400, walking: 520);

      final actual = (
        idle: cycleOf(
          null,
          Gait.idle,
          breath: const Duration(milliseconds: 2400),
          stride: const Duration(milliseconds: 520),
        ).inMilliseconds,
        walking: cycleOf(
          null,
          Gait.walking,
          breath: const Duration(milliseconds: 2400),
          stride: const Duration(milliseconds: 520),
        ).inMilliseconds,
      );

      expect(actual, expected);
    });
  });

  group('the bird keeps inside his frame', () {
    /// The edge of a frame is not empty space — in a sprite sheet the next
    /// frame begins there. Ink on the outermost ring would arrive in the
    /// neighbouring bird, which is how the beak once did.
    Future<List<int>> inkOnTheEdgeOf(Gait gait, double phase, int side) async {
      final across = ui.Size(side.toDouble(), side.toDouble());
      final recorder = ui.PictureRecorder();
      paintRoac(
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
      //
      // Drawn small and large as well as at its own size, because the room
      // ink must keep is a fixed number of pixels while the bird is not: a
      // margin that suffices at one size can vanish at a smaller one.
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
