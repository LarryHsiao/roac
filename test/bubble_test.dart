import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roac/bubble.dart';
import 'package:roac/counsel.dart';

void main() {
  Future<void> show(
    WidgetTester tester, {
    Counsel? counsel,
    bool waiting = false,
  }) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Bubble(
              counsel: counsel,
              waiting: waiting,
              onAsk: (_) {},
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
    const expected = 1;
    final words = List.filled(60, 'a line of the answer').join('\n');

    await show(tester, counsel: Answer(words));
    final actual = find.byType(SingleChildScrollView).evaluate().length;

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
}
