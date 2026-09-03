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

  group('the mascot moves as its gait says', () {
    /// The vertical offset the sprite is drawn at — the outer Transform is the
    /// translate, the rotate sits inside it.
    double riseIn(WidgetTester tester) {
      final lift = tester.widget<Transform>(find.byType(Transform).first);
      return lift.transform.storage[13];
    }

    Future<void> show(WidgetTester tester, Gait gait) => tester.pumpWidget(
      MaterialApp(
        home: Sprite(gait: gait, facing: Facing.right),
      ),
    );

    testWidgets('a pinned mascot holds perfectly still', (tester) async {
      const expected = (atFirst: 0.0, later: 0.0);

      await show(tester, Gait.pinned);
      final atFirst = riseIn(tester);
      await tester.pump(const Duration(milliseconds: 600));
      final actual = (atFirst: atFirst, later: riseIn(tester));

      expect(actual, expected);
    });

    testWidgets('an idle mascot breathes where it stands', (tester) async {
      const expected = 3.0;

      await show(tester, Gait.idle);
      await tester.pump(const Duration(milliseconds: 600));
      final actual = riseIn(tester);

      expect(actual, closeTo(expected, 0.001));
    });

    testWidgets('a walking mascot hops, rising off its ground', (tester) async {
      const expected = -10.0;

      await show(tester, Gait.walking);
      await tester.pump(const Duration(milliseconds: 130));
      final actual = riseIn(tester);

      expect(actual, closeTo(expected, 0.001));
    });
  });
}
