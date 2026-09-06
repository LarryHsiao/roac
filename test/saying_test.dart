import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roac/counsel.dart';
import 'package:roac/l10n/words.dart';
import 'package:roac/pack.dart';
import 'package:roac/saying.dart';

/// Every flaw a pack may carry, each with values a sentence can be checked
/// against.
///
/// Kept by hand: nothing compels a new flaw to be added here. What the
/// compiler does insist on is the switch in `saidOfFlaw`, which cannot omit
/// one — so a flaw with no sentence is caught there, and this roster is what
/// proves the sentences that do exist are not empty in either tongue.
const _everyFlaw = <Flaw>[
  Unopenable('/somewhere/packs', 'no such folder'),
  NotAZip('not an archive'),
  NoManifest(),
  UnreadableManifest('unexpected character'),
  NotAManifest(),
  WrongFormat('2', 1),
  NoFrameSize(),
  ZeroFrame(),
  NoGaits(),
  NoKnownGaits(),
  NoDescription('walking'),
  NoFrameCount('walking'),
  UnreadableOrder('walking'),
  EmptyOrder('walking'),
  UndrawnFrame('walking'),
  NoTiming('walking'),
  TwoTimings('walking'),
  MissingStrip('walking', 'walk.png'),
  SmallStrip(
    gait: 'walking',
    image: 'walk.png',
    frames: 3,
    wanted: Size(120, 120),
    actual: Size(240, 120),
  ),
];

const _everyTrouble = <Trouble>[
  NoQuestion(),
  Silence(),
  NoCounsel(127),
  Surrender(),
  Complaint('claude: command not found'),
];

void main() {
  /// The words of a tongue, got the way a widget gets them.
  Future<Words> tongueOf(WidgetTester tester, Locale locale) async {
    late Words got;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: Words.localizationsDelegates,
        supportedLocales: Words.supportedLocales,
        home: Builder(
          builder: (context) {
            got = Words.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    return got;
  }

  for (final locale in const [Locale('en'), Locale('zh')]) {
    testWidgets('every flaw has something to say in ${locale.languageCode}', (
      tester,
    ) async {
      const expected = <String>[];
      final tongue = await tongueOf(tester, locale);

      final silent = [
        for (final flaw in _everyFlaw)
          if (saidOfFlaw(tongue, flaw).trim().isEmpty) '$flaw',
      ];

      expect(silent, expected);
    });

    testWidgets(
      'every trouble has something to say in ${locale.languageCode}',
      (tester) async {
        const expected = <String>[];
        final tongue = await tongueOf(tester, locale);

        final silent = [
          for (final trouble in _everyTrouble)
            if (saidOfTrouble(tongue, trouble).trim().isEmpty) '$trouble',
        ];

        expect(silent, expected);
      },
    );
  }

  testWidgets('a flaw says the values it carries, not just its kind', (
    tester,
  ) async {
    const expected = true;
    final tongue = await tongueOf(tester, const Locale('en'));

    final said = saidOfFlaw(
      tongue,
      const SmallStrip(
        gait: 'walking',
        image: 'walk.png',
        frames: 3,
        wanted: Size(120, 120),
        actual: Size(240, 120),
      ),
    );
    final actual = [
      'walking',
      'walk.png',
      '3',
      '120',
      '240',
    ].every(said.contains);

    expect(actual, expected);
  });

  testWidgets('the CLI keeps its own words, whatever tongue Roäc has', (
    tester,
  ) async {
    const expected = 'claude: command not found';
    final tongue = await tongueOf(tester, const Locale('zh'));

    final actual = saidOfTrouble(tongue, const Complaint(expected));

    expect(actual, expected);
  });
}
