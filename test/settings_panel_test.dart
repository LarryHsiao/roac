import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roac/l10n/words.dart';
import 'package:roac/roaming.dart';
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
    claudeConfig: null,
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
          claudeConfig: Chosen('/Users/someone/.claude-work', Told.environment),
        ),
        installedPacks: const ['crow.zip', 'magpie.zip'],
      );
      final actual =
          shown('/from/the/file') &&
          shown('crow.zip') &&
          shown('told by the settings file') &&
          shown('the built-in default') &&
          shown('set by ROAC_PACK') &&
          shown('/Users/someone/.claude-work') &&
          shown('set by ROAC_CLAUDE_CONFIG');

      expect(actual, expected);
    });

    testWidgets('empty — first run, nothing chosen, no packs installed', (
      tester,
    ) async {
      const expected = true;
      await show(tester);
      final actual =
          shown('Roäc (drawn — no packs installed)') &&
          shown("the CLI's own config");

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
          claudeConfig: null,
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

  testWidgets(
    'a fourth row still fits the real window without overflowing it',
    (tester) async {
      const expected = true;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: Words.localizationsDelegates,
          supportedLocales: Words.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              // The window's own real proportions — 420 wide, grown to
              // settingsHeight (lib/roaming.dart) tall — not the test
              // surface's default. A fourth row is exactly what overflowed
              // this panel once before; this is the case that would catch it
              // again, rather than trusting an unconstrained test surface.
              width: speakingSize.width,
              height: settingsHeight,
              child: SettingsPanel(
                settings: const Settings(
                  notes: Chosen('/Users/someone/Minerva', Told.byDefault),
                  packs: Chosen(
                    '/Users/someone/Library/Application Support/roac/packs',
                    Told.byDefault,
                  ),
                  pack: Chosen(
                    'a-rather-long-character-pack-name.zip',
                    Told.file,
                  ),
                  claudeConfig: Chosen(
                    r'C:\Users\someone\SomeVeryLongCorporateFolderName'
                    r'\NestedConfigProfiles\claude-personal-work-shared-2026',
                    Told.environment,
                  ),
                ),
                installedPacks: const ['a-rather-long-character-pack-name.zip'],
                onChanged: (_, _) {},
                onClose: () {},
                chooseFolder: (from) async => null,
              ),
            ),
          ),
        ),
      );

      final actual = tester.takeException() == null;

      expect(actual, expected);
    },
  );

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
        claudeConfig: null,
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

  testWidgets(
    'choosing a Claude config folder tells that setting, unset or not',
    (tester) async {
      const expected = ('claudeConfig', '/Users/someone/.claude-personal');
      String? toldKey;
      String? toldValue;

      await show(
        tester,
        onChanged: (key, value) {
          toldKey = key;
          toldValue = value;
        },
        chooseFolder: (from) async => '/Users/someone/.claude-personal',
      );
      // Notes, then Packs, then Claude config — Character wears a dropdown,
      // not a Choose button, so it does not count toward this index.
      await tester.tap(find.text('Choose…').at(2));
      await tester.pumpAndSettle();

      expect((toldKey, toldValue), expected);
    },
  );

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
