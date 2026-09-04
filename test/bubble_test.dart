import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roac/bubble.dart';
import 'package:roac/counsel.dart';

void main() {
  Future<void> show(
    WidgetTester tester, {
    Counsel? counsel,
    bool waiting = false,
    Opening opening = _nowhere,
    Wanting onWanting = _grantNothing,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Bubble(
          counsel: counsel,
          waiting: waiting,
          onAsk: (_) {},
          onWanting: onWanting,
          opening: opening,
        ),
      ),
    ),
  );

  bool shown(String words) => find.text(words).evaluate().isNotEmpty;

  testWidgets('with nothing said yet it invites a question', (tester) async {
    const expected = true;

    await show(tester);
    final actual = shown('Ask me what you have written down.');

    expect(actual, expected);
  });

  testWidgets('while thinking it says so, and holds back the last counsel', (
    tester,
  ) async {
    const expected = (thinking: true, stillShowing: false);

    await show(
      tester,
      waiting: true,
      counsel: const Answer('what it said before'),
    );
    final actual = (
      thinking: shown('Roäc is thinking…'),
      stillShowing: shown('what it said before'),
    );

    expect(actual, expected);
  });

  testWidgets('a long answer is given room to scroll rather than being cut', (
    tester,
  ) async {
    const expected = true;
    final words = List.filled(60, 'a line of the answer').join('\n');

    await show(tester, counsel: Answer(words));
    final actual = find
        .descendant(
          of: find.byType(Markdown),
          matching: find.byType(Scrollable),
        )
        .evaluate()
        .isNotEmpty;

    expect(actual, expected);
  });

  testWidgets('an answer is drawn as markdown, not as its own source', (
    tester,
  ) async {
    const expected = (rendered: true, raw: false);
    const source = '**bold** and [a link](https://example.test)';

    await show(tester, counsel: const Answer(source));
    final actual = (
      rendered: find.byType(Markdown).evaluate().isNotEmpty,
      raw: shown(source),
    );

    expect(actual, expected);
  });

  testWidgets('a trouble is shown plainly rather than swallowed', (
    tester,
  ) async {
    const complaint = 'claude: command not found';
    const expected = true;

    await show(tester, counsel: const Trouble(complaint));
    final actual = shown(complaint);

    expect(actual, expected);
  });

  testWidgets(
    'a link that will not open says so, rather than copying in silence',
    (tester) async {
      const address = 'https://example.test/policy.html';
      const expected = (
        said: 'That link would not open. Its address is on your clipboard.',
        copied: address,
      );
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await show(
        tester,
        counsel: const Answer('see [the policy]($address) now'),
        opening: (_) async => false,
      );
      tester.widget<Markdown>(find.byType(Markdown)).onTapLink!(
        'the policy',
        address,
        '',
      );
      await tester.pump();
      await tester.pump();
      final actual = (
        said:
            find
                .textContaining('Its address is on your clipboard')
                .evaluate()
                .isNotEmpty
            ? expected.said
            : 'nothing was said',
        copied: copied,
      );

      expect(actual, expected);
    },
  );

  testWidgets('an answer with more to show than room asks for more', (
    tester,
  ) async {
    const expected = true;
    var asked = 0.0;

    await show(
      tester,
      counsel: Answer(List.filled(80, 'a line of the answer').join('\n')),
      onWanting: (more) => asked = more,
    );
    await tester.pump();

    expect(asked > 0, expected);
  });

  testWidgets('an answer that fits asks for nothing', (tester) async {
    const expected = 0.0;
    var asked = 0.0;

    await show(
      tester,
      counsel: const Answer('short'),
      onWanting: (more) => asked = more,
    );
    await tester.pump();

    expect(asked, expected);
  });

  testWidgets('an answer still overrunning after room was given asks again', (
    tester,
  ) async {
    // The room granted is itself a rebuild bearing the same words. Asking
    // only when words arrive let a part-granted answer fall silent, still cut.
    const expected = true;
    final asked = <double>[];
    final words = List.filled(80, 'a line of the answer').join('\n');

    await show(tester, counsel: Answer(words), onWanting: asked.add);
    await tester.pump();
    final first = asked.length;
    await show(tester, counsel: Answer(words), onWanting: asked.add);
    await tester.pump();

    expect(asked.length > first, expected);
  });

  testWidgets('a tapped link is opened, not left to the reader to retype', (
    tester,
  ) async {
    const expected = 'https://example.test/policy.html';
    Uri? followed;

    await show(
      tester,
      counsel: const Answer('see [the policy]($expected) for more'),
      opening: (link) async {
        followed = link;
        return true;
      },
    );
    // Tapped through the handler the rendered answer installs: the gesture
    // that reaches it belongs to the markdown package, not to this app.
    tester.widget<Markdown>(find.byType(Markdown)).onTapLink!(
      'the policy',
      expected,
      '',
    );
    await tester.pump();

    expect(followed.toString(), expected);
  });
}

/// A browser that opens nothing, for the tests that are not about links.
Future<bool> _nowhere(Uri _) async => false;

/// A window that grants no room, for the tests that are not about room.
void _grantNothing(double _) {}
