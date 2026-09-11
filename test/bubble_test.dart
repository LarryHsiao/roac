import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roac/bubble.dart';
import 'package:roac/counsel.dart';
import 'package:roac/l10n/words.dart';
import 'package:roac/settings.dart';

void main() {
  Future<void> show(
    WidgetTester tester, {
    Counsel? counsel,
    bool waiting = false,
    String? asked,
    Opening opening = _nowhere,
    Wanting onWanting = _grantNothing,
    ValueChanged<String> onAsk = _sayNothing,
    Settings? settings,
  }) => tester.pumpWidget(
    _speaking(
      Bubble(
        counsel: counsel,
        waiting: waiting,
        asked: asked,
        onAsk: onAsk,
        onWanting: onWanting,
        onSettings: () {},
        opening: opening,
        settings: settings,
      ),
    ),
  );

  bool shown(String words) => find.text(words).evaluate().isNotEmpty;

  /// What Roäc has been told, with [notes] and [claudeConfig] real folders
  /// unless told otherwise — [notesMissing]/[claudeConfigMissing] check the
  /// real filesystem, so a fixture that means to pass either check needs a
  /// folder that genuinely exists.
  Settings settingsWith({
    String? notes,
    String? claudeConfig,
    bool mayAct = false,
  }) => Settings(
    notes: Chosen(notes ?? Directory.systemTemp.path, Told.byDefault),
    packs: Chosen(Directory.systemTemp.path, Told.byDefault),
    pack: null,
    claudeConfig: claudeConfig == null ? null : Chosen(claudeConfig, Told.file),
    edits: Chosen(mayAct ? 'true' : 'false', Told.byDefault),
  );

  testWidgets('with nothing said yet it invites a question', (tester) async {
    const expected = true;

    await show(tester);
    final actual = shown('Ask me what you have written down.');

    expect(actual, expected);
  });

  testWidgets(
    'a notes folder that has gone missing is said instead of the invitation',
    (tester) async {
      const expected = true;

      await show(
        tester,
        settings: settingsWith(notes: '${Directory.systemTemp.path}/gone'),
      );
      final actual = shown(
        'Your notes folder is gone. Open settings (the gear) and choose one '
        'that still exists.',
      );

      expect(actual, expected);
    },
  );

  testWidgets(
    'a named Claude config that has gone missing is said too, once notes '
    'are fine',
    (tester) async {
      const expected = true;

      await show(
        tester,
        settings: settingsWith(
          claudeConfig: '${Directory.systemTemp.path}/gone',
        ),
      );
      final actual = shown(
        'The Claude config you named no longer exists. Open settings and '
        'choose one, or clear it.',
      );

      expect(actual, expected);
    },
  );

  testWidgets('the notes folder wins when both have gone missing', (
    tester,
  ) async {
    const expected = (notesSaid: true, claudeConfigSaid: false);

    await show(
      tester,
      settings: settingsWith(
        notes: '${Directory.systemTemp.path}/gone',
        claudeConfig: '${Directory.systemTemp.path}/also-gone',
      ),
    );
    final actual = (
      notesSaid: shown(
        'Your notes folder is gone. Open settings (the gear) and choose one '
        'that still exists.',
      ),
      claudeConfigSaid: shown(
        'The Claude config you named no longer exists. Open settings and '
        'choose one, or clear it.',
      ),
    );

    expect(actual, expected);
  });

  testWidgets(
    'a question answered before settings have landed invites one as usual',
    (tester) async {
      const expected = true;

      await show(tester, settings: null);
      final actual = shown('Ask me what you have written down.');

      expect(actual, expected);
    },
  );

  testWidgets('folders that are both still there invite a question as usual', (
    tester,
  ) async {
    const expected = true;

    await show(
      tester,
      settings: settingsWith(claudeConfig: Directory.systemTemp.path),
    );
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

  testWidgets('what was asked is shown beside what Roäc said back', (
    tester,
  ) async {
    const expected = true;

    await show(
      tester,
      asked: 'where did I write about the budget',
      counsel: const Answer('in a note from June'),
    );
    final actual = shown('where did I write about the budget');

    expect(actual, expected);
  });

  testWidgets('a question put through the field empties it once asked', (
    tester,
  ) async {
    const expected = '';

    var last = '';
    await show(tester, onAsk: (question) => last = question);
    await tester.enterText(find.byType(TextField), 'a question');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    final actual = tester
        .widget<TextField>(find.byType(TextField))
        .controller!
        .text;

    expect(actual, expected);
    expect(last, 'a question');
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

    // mayAct: true, so as not to entangle this with the write-toggle hint
    // below — that is its own concern, tested on its own.
    await show(
      tester,
      counsel: const Complaint(complaint),
      settings: settingsWith(mayAct: true),
    );
    final actual = shown(complaint);

    expect(actual, expected);
  });

  testWidgets(
    'a trouble is said as a missing notes folder, not the exception it '
    'actually threw',
    (tester) async {
      const expected = (settingsSaid: true, exceptionSaid: false);

      await show(
        tester,
        counsel: const Complaint(
          'ProcessException: The system cannot find the path specified.',
        ),
        settings: settingsWith(notes: '${Directory.systemTemp.path}/gone'),
      );
      final actual = (
        settingsSaid: shown(
          'Your notes folder is gone. Open settings (the gear) and choose '
          'one that still exists.',
        ),
        exceptionSaid: shown(
          'ProcessException: The system cannot find the path specified.',
        ),
      );

      expect(actual, expected);
    },
  );

  testWidgets(
    'a trouble is said as a missing Claude config, once notes are fine',
    (tester) async {
      const expected = true;

      await show(
        tester,
        counsel: const Complaint('claude: command not found'),
        settings: settingsWith(
          claudeConfig: '${Directory.systemTemp.path}/gone',
        ),
      );
      final actual = shown(
        'The Claude config you named no longer exists. Open settings and '
        'choose one, or clear it.',
      );

      expect(actual, expected);
    },
  );

  testWidgets('a trouble points at the write toggle when it was off', (
    tester,
  ) async {
    const expected = true;

    await show(
      tester,
      counsel: const Complaint('claude: command not found'),
      settings: settingsWith(mayAct: false),
    );
    final actual = shown(
      'claude: command not found\n\n'
      'If this needed a change to your notes, turn on "May write" in '
      'settings.',
    );

    expect(actual, expected);
  });

  testWidgets(
    'a trouble leans toward the hint too, before settings have landed',
    (tester) async {
      const expected = true;

      await show(
        tester,
        counsel: const Complaint('claude: command not found'),
        settings: null,
      );
      final actual = shown(
        'claude: command not found\n\n'
        'If this needed a change to your notes, turn on "May write" in '
        'settings.',
      );

      expect(actual, expected);
    },
  );

  testWidgets('a trouble says nothing of the toggle once it is already on', (
    tester,
  ) async {
    const expected = (bare: true, hinted: false);

    await show(
      tester,
      counsel: const Complaint('claude: command not found'),
      settings: settingsWith(mayAct: true),
    );
    final actual = (
      bare: shown('claude: command not found'),
      hinted: shown(
        'claude: command not found\n\n'
        'If this needed a change to your notes, turn on "May write" in '
        'settings.',
      ),
    );

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

  testWidgets('a trouble Roäc names himself is said in the reader\'s tongue', (
    tester,
  ) async {
    const expected = true;

    await show(
      tester,
      counsel: const Silence(),
      settings: settingsWith(mayAct: true),
    );
    final actual = shown('Roäc fell silent, and was let go.');

    expect(actual, expected);
  });

  testWidgets('a trouble that carries a number says the number', (
    tester,
  ) async {
    const expected = true;

    await show(tester, counsel: const NoCounsel(127));
    final actual = find.textContaining('127').evaluate().isNotEmpty;

    expect(actual, expected);
  });

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

/// Asked of nothing, for the tests that are not about asking.
void _sayNothing(String _) {}

/// The app root the widgets stand in, carrying the tongues they read their
/// words from. Without these a bubble finds no Words and will not build.
MaterialApp _speaking(Widget child) => MaterialApp(
  localizationsDelegates: Words.localizationsDelegates,
  supportedLocales: Words.supportedLocales,
  home: Scaffold(body: child),
);
