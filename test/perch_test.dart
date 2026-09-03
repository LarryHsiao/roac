import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roac/bubble.dart';
import 'package:roac/counsel.dart';
import 'package:roac/main.dart';
import 'package:roac/roaming.dart';
import 'package:roac/sprite.dart';

/// A desktop the mascot can stand on, standing in for the two plugins so the
/// perch itself may be exercised without a window or a screen.
class _Desktop {
  /// Where the window stands, kept honest across the calls that move it.
  Rect bounds = const Rect.fromLTWH(400, 300, restingSize, restingSize);

  /// The desktop the tests may reach into, so a test can read what the window
  /// was told to do.
  static late _Desktop standing;

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
    _answer('dev.leanflutter.plugins/screen_retriever', (call) async {
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
  setUp(() => _Desktop.standing = _Desktop()..stand());

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

  testWidgets('the bubble takes the window room, and gives it back',
      (tester) async {
    const expected = (open: speakingSize, shut: Size(restingSize, restingSize));

    await raise(tester);
    await tester.tap(find.byType(Sprite));
    await settle(tester);
    final open = _Desktop.standing.bounds.size;
    await tester.tap(find.byType(Sprite));
    await settle(tester);
    final actual = (open: open, shut: _Desktop.standing.bounds.size);

    expect(actual, expected);
  });

  group('what Roäc is told', () {
    /// A counsel that says what it is given, and remembers how it was asked.
    ({Asking asking, List<String?> resumed, StreamController<Counsel> saying})
        counselThat() {
      final saying = StreamController<Counsel>.broadcast();
      final resumed = <String?>[];
      Stream<Counsel> asking(String question, {String? resuming}) {
        resumed.add(resuming);
        return saying.stream;
      }

      return (asking: asking, resumed: resumed, saying: saying);
    }

    Future<void> raiseAsking(WidgetTester tester, Asking asking) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Perch(asking: asking))),
      );
      await settle(tester);
      await tester.tap(find.byType(Sprite));
      await settle(tester);
    }

    testWidgets('the words are shown as they arrive, not only at the end',
        (tester) async {
      const expected = (early: true, late: true);
      final counsel = counselThat();

      await raiseAsking(tester, counsel.asking);
      await tester.enterText(find.byType(TextField), 'a question');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      counsel.saying.add(const Answer('The first'));
      await settle(tester);
      final early = find.textContaining('The first').evaluate().isNotEmpty;
      counsel.saying.add(const Answer('The first and the second'));
      await settle(tester);
      final actual = (
        early: early,
        late: find.textContaining('and the second').evaluate().isNotEmpty,
      );

      expect(actual, expected);
    });

    testWidgets('a follow-up carries the conversation the answer named on',
        (tester) async {
      const expected = [null, 'a-session'];
      final counsel = counselThat();

      await raiseAsking(tester, counsel.asking);
      await tester.enterText(find.byType(TextField), 'first');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      counsel.saying.add(const Answer('said', session: 'a-session'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'second');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      expect(counsel.resumed, expected);
    });

    testWidgets('shutting the bubble forgets the conversation', (tester) async {
      const expected = [null, null];
      final counsel = counselThat();

      await raiseAsking(tester, counsel.asking);
      await tester.enterText(find.byType(TextField), 'first');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      counsel.saying.add(const Answer('said', session: 'a-session'));
      await settle(tester);
      await tester.tap(find.byType(Sprite));
      await settle(tester);
      await tester.tap(find.byType(Sprite));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'second');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      expect(counsel.resumed, expected);
    });
  });
}
