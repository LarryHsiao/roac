import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:roac/roaming.dart';
import 'package:screen_retriever/screen_retriever.dart';

void main() {
  const restingSquare = Size(restingSize, restingSize);
  const range = (from: 0.0, to: 1000.0, ceiling: 0.0, floor: 800.0);

  group('Stance.stride', () {
    test('carries the mascot on where the range holds it', () {
      const expected = Stance(left: 510, facing: Facing.right);

      final actual =
          const Stance(left: 500, facing: Facing.right).stride(10, range);

      expect(actual, expected);
    });

    test('turns the mascot about at the far edge', () {
      const expected = Stance(left: 1000, facing: Facing.left);

      final actual =
          const Stance(left: 995, facing: Facing.right).stride(10, range);

      expect(actual, expected);
    });

    test('turns the mascot about at the near edge', () {
      const expected = Stance(left: 0, facing: Facing.right);

      final actual =
          const Stance(left: 5, facing: Facing.left).stride(10, range);

      expect(actual, expected);
    });
  });

  group('roamingRangeOn', () {
    const primary = Display(
      id: '1',
      size: Size(1920, 1080),
      visiblePosition: Offset.zero,
      visibleSize: Size(1920, 1055),
    );
    const second = Display(
      id: '2',
      size: Size(1440, 900),
      visiblePosition: Offset(1920, 0),
      visibleSize: Size(1440, 900),
    );

    test('spans the visible area of the display the mascot stands on', () {
      const window = Rect.fromLTWH(2000, 300, restingSize, restingSize);
      const expected = (
        from: 1920.0,
        to: 3360.0 - restingSize,
        ceiling: 0.0,
        floor: 900.0 - restingSize,
      );

      final actual = roamingRangeOn(const [primary, second], window, restingSquare);

      expect(actual, expected);
    });

    test('draws every edge in by the window\'s intended size', () {
      const window = Rect.fromLTWH(400, 300, restingSize, restingSize);
      const expected = (
        from: 0.0,
        to: 1920.0 - restingSize,
        ceiling: 0.0,
        floor: 1055.0 - restingSize,
      );

      final actual = roamingRangeOn(const [primary, second], window, restingSquare);

      expect(actual, expected);
    });

    test('measures a squashed window by the size it ought to be', () {
      const squashed = Rect.fromLTWH(400, 927, restingSize, 128);
      const expected = 1055.0 - restingSize;

      final actual = roamingRangeOn(const [primary, second], squashed, restingSquare)?.floor;

      expect(actual, expected);
    });

    test('yields nothing when no display is known', () {
      const window = Rect.fromLTWH(400, 300, restingSize, restingSize);
      const Roam? expected = null;

      final actual = roamingRangeOn(const [], window, restingSquare);

      expect(actual, expected);
    });
  });

  group('wholeWithin', () {
    const room = (from: 0.0, to: 1760.0, ceiling: 0.0, floor: 895.0);

    test('lifts a window the desktop has squashed back to its whole size', () {
      const squashed = Rect.fromLTWH(400, 927, restingSize, 128);
      const expected = Rect.fromLTWH(400, 895, restingSize, restingSize);

      final actual = wholeWithin(squashed, room, restingSquare);

      expect(actual, expected);
    });

    test('draws a window back inside a range that has since narrowed', () {
      const stranded = Rect.fromLTWH(1900, 400, restingSize, restingSize);
      const expected = Rect.fromLTWH(1760, 400, restingSize, restingSize);

      final actual = wholeWithin(stranded, room, restingSquare);

      expect(actual, expected);
    });

    test('leaves an axis where it stands when the range cannot hold it', () {
      const cramped = (from: 0.0, to: -40.0, ceiling: 0.0, floor: -40.0);
      const bounds = Rect.fromLTWH(30, 50, restingSize, restingSize);
      const expected = Rect.fromLTWH(30, 50, restingSize, restingSize);

      final actual = wholeWithin(bounds, cramped, restingSquare);

      expect(actual, expected);
    });
  });

  group('the room the bubble takes', () {
    const lone = Display(
      id: '1',
      size: Size(1920, 1080),
      visiblePosition: Offset.zero,
      visibleSize: Size(1920, 1055),
    );

    test('the range narrows to hold the larger speaking window', () {
      const window = Rect.fromLTWH(400, 300, restingSize, restingSize);
      const expected = (
        from: 0.0,
        to: 1920.0 - 420,
        ceiling: 0.0,
        floor: 1055.0 - 300,
      );

      final actual = roamingRangeOn(const [lone], window, speakingSize);

      expect(actual, expected);
    });

    test('a window grown near an edge is drawn back inside whole', () {
      const range = (from: 0.0, to: 1500.0, ceiling: 0.0, floor: 755.0);
      const grown = Rect.fromLTWH(1700, 800, 420, 300);
      const expected = Rect.fromLTWH(1500, 755, 420, 300);

      final actual = wholeWithin(grown, range, speakingSize);

      expect(actual, expected);
    });
  });
}
