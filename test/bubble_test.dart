import 'package:flutter/material.dart';
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
  }) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Bubble(
              counsel: counsel,
              waiting: waiting,
              onAsk: (_) {},
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

  testWidgets('while thinking it says so, and holds back the last counsel',
      (tester) async {
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

  testWidgets('a long answer is given room to scroll rather than being cut',
      (tester) async {
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

  testWidgets('an answer is drawn as markdown, not as its own source',
      (tester) async {
    const expected = (rendered: true, raw: false);
    const source = '**bold** and [a link](https://example.test)';

    await show(tester, counsel: const Answer(source));
    final actual = (
      rendered: find.byType(Markdown).evaluate().isNotEmpty,
      raw: shown(source),
    );

    expect(actual, expected);
  });

  testWidgets('a trouble is shown plainly rather than swallowed',
      (tester) async {
    const complaint = 'claude: command not found';
    const expected = true;

    await show(tester, counsel: const Trouble(complaint));
    final actual = shown(complaint);

    expect(actual, expected);
  });

  testWidgets('a tapped link is opened, not left to the reader to retype',
      (tester) async {
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
