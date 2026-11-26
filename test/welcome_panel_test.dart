import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roac/l10n/words.dart';
import 'package:roac/settings.dart';
import 'package:roac/welcome_panel.dart';

Settings _noting(String notes) => Settings(
  notes: Chosen(notes, Told.byDefault),
  packs: const Chosen('/packs', Told.byDefault),
  pack: null,
  claudeConfig: null,
  edits: const Chosen('false', Told.byDefault),
);

void main() {
  /// Raises the panel at the size the window grants it.
  Future<void> raise(
    WidgetTester tester, {
    String? notes,
    Future<bool> Function()? findCli,
    VoidCallback? onDone,
    void Function(String)? onNotes,
    String? chosen,
    Locale tongue = const Locale('en'),
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 324));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: tongue,
        localizationsDelegates: Words.localizationsDelegates,
        supportedLocales: Words.supportedLocales,
        home: Scaffold(
          body: WelcomePanel(
            settings: _noting(notes ?? Directory.systemTemp.path),
            findCli: findCli ?? () async => true,
            onNotes: onNotes ?? (_) {},
            onDone: onDone ?? () {},
            chooseFolder: (_) async => chosen,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, String words) async {
    await tester.tap(find.text(words));
    await tester.pumpAndSettle();
  }

  testWidgets('a CLI that is found is said so, with no second check', (
    tester,
  ) async {
    const expected = (found: 1, again: 0);

    await raise(tester);
    final actual = (
      found: find.textContaining('claude was found').evaluate().length,
      again: find.text('Check again').evaluate().length,
    );

    expect(actual, expected);
  });

  testWidgets('a missing CLI can be checked again', (tester) async {
    const expected = 1;
    var asked = 0;
    await raise(tester, findCli: () async => ++asked > 1);

    await press(tester, 'Check again');

    expect(find.textContaining('claude was found').evaluate().length, expected);
  });

  testWidgets('a missing notes folder holds the way forward shut', (
    tester,
  ) async {
    const expected = 'Where are your notes?';
    await raise(tester, notes: '/no/such/folder/at/all');
    await press(tester, 'Next');

    await press(tester, 'Next');

    expect(find.text(expected), findsOneWidget);
  });

  testWidgets('a chosen folder is told', (tester) async {
    const expected = ['/chosen/notes'];
    final actual = <String>[];
    await raise(tester, onNotes: actual.add, chosen: expected.single);
    await press(tester, 'Next');

    await press(tester, 'Choose…');

    expect(actual, expected);
  });

  testWidgets('the last step finishes', (tester) async {
    const expected = 1;
    var actual = 0;
    await raise(tester, onDone: () => actual++);
    await press(tester, 'Next');
    await press(tester, 'Next');

    await press(tester, 'Start asking');

    expect(actual, expected);
  });

  testWidgets('it can be skipped from the first step', (tester) async {
    const expected = 1;
    var actual = 0;
    await raise(tester, onDone: () => actual++);

    await press(tester, 'Skip setup');

    expect(actual, expected);
  });

  testWidgets('back returns to the step before', (tester) async {
    const expected = 'Welcome to Roäc';
    await raise(tester);
    await press(tester, 'Next');

    await press(tester, 'Back');

    expect(find.text(expected), findsOneWidget);
  });

  testWidgets('a long path and either tongue fit without overflow', (
    tester,
  ) async {
    const Object? expected = null;
    final long = '/Users/${'a-very-long-folder-name/' * 8}Minerva';
    for (final tongue in const [Locale('en'), Locale('zh')]) {
      await raise(
        tester,
        notes: long,
        findCli: () async => false,
        tongue: tongue,
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    }

    expect(tester.takeException(), expected);
  });
}
