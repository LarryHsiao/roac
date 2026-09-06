import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roac/l10n/words.dart';
import 'package:roac/settings.dart';
import 'package:roac/settings_panel.dart';

void main() {
  const plain = Settings(
    notes: Chosen('/Users/someone/Minerva', Told.byDefault),
    packs: Chosen(
      '/Users/someone/Library/Application Support/roac/packs',
      Told.byDefault,
    ),
    pack: null,
  );

  Future<void> show(
    WidgetTester tester, {
    Settings settings = plain,
    List<String> installedPacks = const [],
    void Function(String key, String? value)? onChanged,
    VoidCallback? onClose,
    ChooseFolder? chooseFolder,
  }) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: Words.localizationsDelegates,
      supportedLocales: Words.supportedLocales,
      home: Scaffold(
        body: SettingsPanel(
          settings: settings,
          installedPacks: installedPacks,
          onChanged: onChanged ?? (_, _) {},
          onClose: onClose ?? () {},
          chooseFolder: chooseFolder ?? (from) async => null,
        ),
      ),
    ),
  );

  bool shown(String words) => find.text(words).evaluate().isNotEmpty;

  group('three states', () {
    testWidgets('populated — settings told from a mix of sources', (
      tester,
    ) async {
      const expected = true;
      await show(
        tester,
        settings: const Settings(
          notes: Chosen('/from/the/file', Told.file),
          packs: Chosen('/the/default/packs', Told.byDefault),
          pack: Chosen('crow.zip', Told.environment),
        ),
        installedPacks: const ['crow.zip', 'magpie.zip'],
      );
      final actual =
          shown('/from/the/file') &&
          shown('crow.zip') &&
          shown('told by the settings file') &&
          shown('the built-in default') &&
          shown('set by ROAC_PACK');

      expect(actual, expected);
    });

    testWidgets('empty — first run, nothing chosen, no packs installed', (
      tester,
    ) async {
      const expected = true;
      await show(tester);
      final actual = shown('Roäc (drawn — no packs installed)');

      expect(actual, expected);
    });

    testWidgets('overflow — a misread file is said aloud, in full', (
      tester,
    ) async {
      const expected = true;
      await show(
        tester,
        settings: const Settings(
          notes: Chosen('/Users/someone/Minerva', Told.byDefault),
          packs: Chosen(
            '/Users/someone/Library/Application Support/roac/packs',
            Told.byDefault,
          ),
          pack: null,
          trouble: NotJson('unexpected character at line 3'),
        ),
      );
      final actual = shown(
        "Roäc's settings file is not JSON (unexpected character at line 3). "
        'What it says is passed over.',
      );

      expect(actual, expected);
    });
  });

  testWidgets('a pack once chosen and since removed is not offered back', (
    tester,
  ) async {
    const expected = true;
    await show(
      tester,
      settings: const Settings(
        notes: Chosen('/Users/someone/Minerva', Told.byDefault),
        packs: Chosen(
          '/Users/someone/Library/Application Support/roac/packs',
          Told.byDefault,
        ),
        pack: Chosen('gone.zip', Told.file),
      ),
      installedPacks: const ['crow.zip'],
    );
    final actual = shown('Roäc (drawn)') && !shown('gone.zip');

    expect(actual, expected);
  });

  testWidgets('choosing a folder tells what was chosen, and which setting', (
    tester,
  ) async {
    const expected = ('notes', '/a/chosen/folder');
    String? toldKey;
    String? toldValue;

    await show(
      tester,
      onChanged: (key, value) {
        toldKey = key;
        toldValue = value;
      },
      chooseFolder: (from) async => '/a/chosen/folder',
    );
    await tester.tap(find.text('Choose…').first);
    await tester.pumpAndSettle();

    expect((toldKey, toldValue), expected);
  });

  testWidgets('declining the folder dialog tells nothing at all', (
    tester,
  ) async {
    const expected = false;
    var told = false;

    await show(
      tester,
      onChanged: (_, _) => told = true,
      chooseFolder: (from) async => null,
    );
    await tester.tap(find.text('Choose…').first);
    await tester.pumpAndSettle();

    expect(told, expected);
  });

  testWidgets('choosing a character tells its file name', (tester) async {
    const expected = ('pack', 'magpie.zip');
    String? toldKey;
    String? toldValue;

    await show(
      tester,
      installedPacks: const ['crow.zip', 'magpie.zip'],
      onChanged: (key, value) {
        toldKey = key;
        toldValue = value;
      },
    );
    await tester.tap(find.byType(DropdownButton<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('magpie.zip').last);
    await tester.pumpAndSettle();

    expect((toldKey, toldValue), expected);
  });

  testWidgets('the close button is told, not the panel itself', (tester) async {
    const expected = true;
    var closed = false;

    await show(tester, onClose: () => closed = true);
    await tester.tap(find.byIcon(Icons.close));

    expect(closed, expected);
  });
}
