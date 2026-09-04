import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roac/roaming.dart';
import 'package:roac/sprite.dart';

void main() {
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
}
