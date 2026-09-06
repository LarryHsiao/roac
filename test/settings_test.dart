import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:roac/settings.dart';

void main() {
  late Directory kept;
  late Map<String, String> world;

  setUp(() async {
    kept = await Directory.systemTemp.createTemp('roac-settings');
    world = {
      'HOME': '/Users/someone',
      'ROAC_SETTINGS': '${kept.path}/$settingsName',
    };
  });

  tearDown(() => kept.deleteSync(recursive: true));

  /// Writes [told] as the settings file this run reads.
  Future<void> write(Object told) =>
      File(world['ROAC_SETTINGS']!).writeAsString(jsonEncode(told));

  /// Writes [written] verbatim, however malformed.
  Future<void> writeRaw(String written) =>
      File(world['ROAC_SETTINGS']!).writeAsString(written);

  group('what Roäc has been told', () {
    test('what he was born knowing, when nothing else says', () async {
      const expected = (
        notes: '/Users/someone/Minerva',
        packs: '/Users/someone/Library/Application Support/roac/packs',
        pack: null,
        claudeConfig: null,
        told: Told.byDefault,
      );

      final settings = await settingsIn(world);
      final actual = (
        notes: settings.notes.value,
        packs: settings.packs.value,
        pack: settings.pack,
        claudeConfig: settings.claudeConfig,
        told: settings.notes.told,
      );

      expect(actual, expected);
    });

    test('what the file says, over what he was born knowing', () async {
      const expected = (notes: '/elsewhere/notes', told: Told.file);
      await write({'notes': expected.notes});

      final settings = await settingsIn(world);
      final actual = (notes: settings.notes.value, told: settings.notes.told);

      expect(actual, expected);
    });

    test('what the environment says, over what the file says', () async {
      const expected = (notes: '/from/the/shell', told: Told.environment);
      await write({'notes': '/from/the/file'});

      final settings = await settingsIn({
        ...world,
        'ROAC_NOTES': expected.notes,
      });
      final actual = (notes: settings.notes.value, told: settings.notes.told);

      expect(actual, expected);
    });

    test('each setting is told separately, not all from one place', () async {
      // Nothing names a pack, and nothing stands in for one: unlike the two
      // paths, a character has no default to fall back to.
      const expected = (
        notes: Told.environment,
        packs: Told.file,
        pack: null,
        claudeConfig: null,
      );
      await write({'packs': '/elsewhere/packs'});

      final settings = await settingsIn({
        ...world,
        'ROAC_NOTES': '/from/the/shell',
      });
      final actual = (
        notes: settings.notes.told,
        packs: settings.packs.told,
        pack: settings.pack?.told,
        claudeConfig: settings.claudeConfig?.told,
      );

      expect(actual, expected);
    });

    test(
      'an empty value says nothing, and the tier beneath it stands',
      () async {
        const expected = (notes: '/from/the/file', told: Told.file);
        await write({'notes': expected.notes});

        final settings = await settingsIn({...world, 'ROAC_NOTES': '   '});
        final actual = (notes: settings.notes.value, told: settings.notes.told);

        expect(actual, expected);
      },
    );

    test('which pack to wear, when the file names one', () async {
      const expected = (value: 'crow.zip', told: Told.file);
      await write({'pack': expected.value});

      final settings = await settingsIn(world);
      final actual = (value: settings.pack!.value, told: settings.pack!.told);

      expect(actual, expected);
    });

    test('which Claude config to use, when the file names one', () async {
      const expected = (value: '/Users/someone/.claude-work', told: Told.file);
      await write({'claudeConfig': expected.value});

      final settings = await settingsIn(world);
      final actual = (
        value: settings.claudeConfig!.value,
        told: settings.claudeConfig!.told,
      );

      expect(actual, expected);
    });

    test(
      'which Claude config to use, when the environment names one over the file',
      () async {
        const expected = (
          value: '/from/the/shell/.claude-personal',
          told: Told.environment,
        );
        await write({'claudeConfig': '/from/the/file/.claude-work'});

        final settings = await settingsIn({
          ...world,
          'ROAC_CLAUDE_CONFIG': expected.value,
        });
        final actual = (
          value: settings.claudeConfig!.value,
          told: settings.claudeConfig!.told,
        );

        expect(actual, expected);
      },
    );
  });

  group('a settings file that will not do', () {
    test('no file at all is no fault, and nothing is said of it', () async {
      const Misread? expected = null;

      final settings = await settingsIn(world);

      expect(settings.trouble, expected);
    });

    test('one that is not JSON is named, not silently replaced', () async {
      const expected = (troubled: true, notes: '/Users/someone/Minerva');
      await writeRaw('{ this is not json');

      final settings = await settingsIn(world);
      final actual = (
        troubled: settings.trouble is NotJson,
        notes: settings.notes.value,
      );

      expect(actual, expected);
    });

    test('one holding something that is not settings is named', () async {
      const expected = true;
      await write(['a list, of all things']);

      final settings = await settingsIn(world);

      expect(settings.trouble is NotSettings, expected);
    });

    test('one that will not open is named', () async {
      const expected = true;
      await write({'notes': '/elsewhere'});
      await Process.run('chmod', ['000', world['ROAC_SETTINGS']!]);
      addTearDown(
        () => Process.runSync('chmod', ['644', world['ROAC_SETTINGS']!]),
      );

      final settings = await settingsIn(world);

      expect(settings.trouble is ShutSettings, expected);
    });
  });

  group('where the settings file is', () {
    test('beside the packs, in the folder macOS keeps them in', () {
      const expected =
          '/Users/someone/Library/Application Support/roac/config.json';

      final actual = settingsPathIn({'HOME': '/Users/someone'});

      expect(actual, expected);
    });

    test('wherever ROAC_SETTINGS names, when it names anywhere', () {
      const expected = '/elsewhere/roac.json';

      final actual = settingsPathIn({
        'HOME': '/Users/someone',
        'ROAC_SETTINGS': expected,
      });

      expect(actual, expected);
    });
  });

  group('telling Roäc something new', () {
    test('is read back the next time he is asked', () async {
      const expected = '/from/the/panel';

      await settingsWrite({'notes': expected}, world);
      final settings = await settingsIn(world);

      expect(settings.notes.value, expected);
    });

    test('is written beside whatever was already there', () async {
      const expected = (notes: '/kept/from/before', packs: '/just/written');
      await write({'notes': expected.notes});

      await settingsWrite({'packs': expected.packs}, world);
      final settings = await settingsIn(world);

      expect((
        notes: settings.notes.value,
        packs: settings.packs.value,
      ), expected);
    });

    test('a value of null lets the tier beneath it stand again', () async {
      const expected = (value: '/Users/someone/Minerva', told: Told.byDefault);
      await write({'notes': '/from/the/file'});

      await settingsWrite({'notes': null}, world);
      final settings = await settingsIn(world);

      expect((
        value: settings.notes.value,
        told: settings.notes.told,
      ), expected);
    });

    test(
      'heals a file that would not read, rather than preserving it',
      () async {
        const expected = (troubled: false, notes: '/mended');
        await writeRaw('{ not json at all');

        await settingsWrite({'notes': expected.notes}, world);
        final settings = await settingsIn(world);

        expect((
          troubled: settings.trouble != null,
          notes: settings.notes.value,
        ), expected);
      },
    );

    test('a folder that cannot be made is named, not swallowed', () async {
      const expected = true;
      // A settings path standing where a plain file already sits: no
      // directory can ever be made there.
      final blocked = '${kept.path}/blocks-the-way';
      await File(blocked).writeAsString('in the way');

      final trouble = await settingsWrite(
        {'notes': '/anything'},
        {...world, 'ROAC_SETTINGS': '$blocked/config.json'},
      );

      expect(trouble != null, expected);
    });
  });
}
