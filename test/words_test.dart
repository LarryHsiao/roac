import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roac/bubble.dart';
import 'package:roac/l10n/words.dart';
import 'package:roac/main.dart';

void main() {
  group('which tongue a reader is answered in', () {
    test('Traditional Chinese, when the system names that script', () {
      const expected = Locale('zh');

      final actual = tongueFor(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        Words.supportedLocales,
      );

      expect(actual, expected);
    });

    test('and where the script is unsaid, by the places that read it', () {
      const expected = [Locale('zh'), Locale('zh'), Locale('zh')];

      final actual = [
        for (final where in ['TW', 'HK', 'MO'])
          tongueFor(Locale('zh', where), Words.supportedLocales),
      ];

      expect(actual, expected);
    });

    test('English for a Simplified reader, who is not served by the other', () {
      const expected = Locale('en');

      final actual = tongueFor(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
        Words.supportedLocales,
      );

      expect(actual, expected);
    });

    test('English for a tongue Roäc does not speak at all', () {
      const expected = Locale('en');

      final actual = tongueFor(const Locale('fr'), Words.supportedLocales);

      expect(actual, expected);
    });

    test('English when the system names no tongue whatever', () {
      const expected = Locale('en');

      final actual = tongueFor(null, Words.supportedLocales);

      expect(actual, expected);
    });
  });

  testWidgets('the bubble greets a Chinese reader in Chinese', (tester) async {
    const expected = (chinese: true, english: false);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: Words.localizationsDelegates,
        supportedLocales: Words.supportedLocales,
        home: const Scaffold(
          body: Bubble(
            counsel: null,
            waiting: false,
            onAsk: _asks,
            onWanting: _wants,
            onSettings: _settled,
          ),
        ),
      ),
    );
    final actual = (
      chinese: find.text('問我你寫下的事。').evaluate().isNotEmpty,
      english: find
          .text('Ask me what you have written down.')
          .evaluate()
          .isNotEmpty,
    );

    expect(actual, expected);
  });
}

void _asks(String _) {}
void _wants(double _) {}

/// A gear that goes nowhere, for the tests that are not about the panel.
void _settled() {}
