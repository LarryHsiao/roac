import 'package:flutter_test/flutter_test.dart';
import 'package:roac/main.dart';
import 'package:roac/settings.dart';

Settings _settings({String claudeConfig = '/config'}) => Settings(
  notes: const Chosen('/Minerva', Told.byDefault),
  packs: const Chosen('/packs', Told.byDefault),
  pack: null,
  claudeConfig: Chosen(claudeConfig, Told.file),
  trouble: null,
);

void main() {
  group('which settings a question in flight is asked with', () {
    test('the read begun at launch, before anything else has landed', () async {
      final expected = _settings(claudeConfig: '/launch');

      final actual = await settledFor(null, Future.value(expected));

      expect(actual, same(expected));
    });

    test('the live read, once the settings panel has refreshed one', () async {
      final expected = _settings(claudeConfig: '/changed-through-the-panel');
      final stale = _settings(claudeConfig: '/from-launch');

      final actual = await settledFor(expected, Future.value(stale));

      expect(actual, same(expected));
    });
  });
}
