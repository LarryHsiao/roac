import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roac/bubble.dart';
import 'package:roac/main.dart';
import 'package:roac/roaming.dart';
import 'package:roac/sprite.dart';

/// A desktop the mascot can stand on, standing in for the two plugins so the
/// perch itself may be exercised without a window or a screen.
class _Desktop {
  /// Where the window stands, kept honest across the calls that move it.
  Rect bounds = const Rect.fromLTWH(400, 300, restingSize, restingSize);

  /// Far from the sprite, so the window hands its clicks on by default.
  Offset cursor = const Offset(2000, 2000);

  static const _display = {
    'id': '1',
    'size': {'width': 1920.0, 'height': 1080.0},
    'visiblePosition': {'dx': 0.0, 'dy': 0.0},
    'visibleSize': {'width': 1920.0, 'height': 1055.0},
  };

  void stand() {
    _answer('window_manager', (call) async {
      switch (call.method) {
        case 'getBounds':
          return {
            'x': bounds.left,
            'y': bounds.top,
            'width': bounds.width,
            'height': bounds.height,
          };
        case 'setBounds':
          final given = call.arguments as Map;
          bounds = Rect.fromLTWH(
            given['x'] as double,
            given['y'] as double,
            (given['width'] ?? bounds.width) as double,
            (given['height'] ?? bounds.height) as double,
          );
          return null;
        case 'setPosition':
          final given = call.arguments as Map;
          bounds = Rect.fromLTWH(
            given['x'] as double,
            given['y'] as double,
            bounds.width,
            bounds.height,
          );
          return null;
        default:
          return null;
      }
    });
    _answer('screen_retriever', (call) async {
      return switch (call.method) {
        'getAllDisplays' => {
            'displays': [_display],
          },
        'getCursorScreenPoint' => {'dx': cursor.dx, 'dy': cursor.dy},
        _ => null,
      };
    });
  }

  void _answer(String channel, Future<Object?> Function(MethodCall) reply) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(channel), reply);
  }
}

void main() {
  setUp(() => _Desktop().stand());

  /// Lets the frames the perch schedules come through. The sprite's animation
  /// never stops, so `pumpAndSettle` would wait for a rest that never comes.
  Future<void> settle(WidgetTester tester) async {
    for (var frame = 0; frame < 8; frame++) {
      await tester.idle();
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  /// Raises the perch and lets its first placement read settle.
  Future<void> raise(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Perch())),
    );
    await settle(tester);
  }

  Gait gaitIn(WidgetTester tester) => tester.widget<Sprite>(find.byType(Sprite)).gait;

  testWidgets('a click opens the bubble and stills the mascot', (tester) async {
    const expected = (bubble: true, field: true, roaming: false);

    await raise(tester);
    await tester.tap(find.byType(Sprite));
    await settle(tester);
    final actual = (
      bubble: find.byType(Bubble).evaluate().isNotEmpty,
      field: find.byType(TextField).evaluate().isNotEmpty,
      roaming: gaitIn(tester) == Gait.walking,
    );

    expect(actual, expected);
  });

  testWidgets('the bubble keeps the mascot still however it is handled',
      (tester) async {
    const expected = Gait.idle;

    await raise(tester);
    await tester.tap(find.byType(Sprite));
    await settle(tester);
    // A drag used to arm a fresh spell of roaming, and the spell that followed
    // would set the mascot walking mid-speech. Watched across many spells, so
    // that a walk chosen at any point along the way is caught.
    await tester.drag(find.byType(Sprite), const Offset(0, -20));
    await settle(tester);
    var walked = false;
    for (var spell = 0; spell < 20; spell++) {
      await tester.pump(const Duration(seconds: 2));
      if (gaitIn(tester) == Gait.walking) walked = true;
    }

    expect(walked ? Gait.walking : gaitIn(tester), expected);
  });
}
