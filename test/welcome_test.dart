import 'package:flutter_test/flutter_test.dart';
import 'package:roac/welcome.dart';

void main() {
  /// Weighs [welcomeOwed] and reports what it said and what it wrote down.
  Future<({bool owed, List<bool> written})> weigh({
    bool? pending,
    String? lastSeen,
    bool hasSettings = false,
  }) async {
    final written = <bool>[];
    final owed = await welcomeOwed(
      pending: pending,
      lastSeenVersion: lastSeen,
      hasSettings: hasSettings,
      writePending: (it) async => written.add(it),
    );
    return (owed: owed, written: written);
  }

  group('whether the welcome is owed', () {
    test('on a fresh install, and remembered until finished', () async {
      const expected = (owed: true, written: [true]);

      final actual = await weigh();

      expect((actual.owed, actual.written.single), (expected.owed, true));
    });

    test('not to somebody who ran an earlier release', () async {
      const expected = false;

      final actual = await weigh(lastSeen: '1.0.6');

      expect(actual.owed, expected);
    });

    test('not to somebody who already wrote a settings file', () async {
      const expected = false;

      final actual = await weigh(hasSettings: true);

      expect(actual.owed, expected);
    });

    test('still, when it was quit half way', () async {
      const expected = true;

      final actual = await weigh(
        pending: true,
        lastSeen: '1.0.7',
        hasSettings: true,
      );

      expect(actual.owed, expected);
    });

    test('never again, once finished or skipped', () async {
      const expected = false;

      final actual = await weigh(pending: false);

      expect(actual.owed, expected);
    });
  });
}
