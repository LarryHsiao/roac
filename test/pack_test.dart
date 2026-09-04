import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roac/pack.dart';
import 'package:roac/roaming.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A strip eight pixels wide, so a pack under test carries a real image and
  /// one large enough to hold the four two-pixel frames the fixtures claim.
  Future<Uint8List> aPicture() async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(
      recorder,
    ).drawPaint(ui.Paint()..color = const ui.Color(0xFF000000));
    final drawn = await recorder.endRecording().toImage(8, 8);
    final bytes = await drawn.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  /// A pack zipped from [manifest] and whatever images it names.
  Future<Uint8List> packOf(
    Object? manifest, {
    List<String> images = const ['idle.png'],
    bool withManifest = true,
  }) async {
    final zip = Archive();
    if (withManifest) {
      final written = utf8.encode(
        manifest is String ? manifest : jsonEncode(manifest),
      );
      zip.addFile(ArchiveFile(manifestName, written.length, written));
    }
    final picture = await aPicture();
    for (final name in images) {
      zip.addFile(ArchiveFile(name, picture.length, picture));
    }
    return Uint8List.fromList(ZipEncoder().encode(zip));
  }

  Map<String, Object?> wellFormed({Object? gaits}) => {
    'format': readableFormat,
    'name': 'Roäc the raven',
    'author': 'Larry Hsiao',
    'licence': 'MIT',
    'frame': {'width': 2, 'height': 2},
    'gaits':
        gaits ??
        {
          'idle': {
            'image': 'idle.png',
            'frames': 4,
            'sequence': [0, 1, 2, 3],
            'msPerFrame': 600,
          },
        },
  };

  group('a pack that is well made', () {
    test('is read whole — who made it, and how it stands', () async {
      const expected = (
        name: 'Roäc the raven',
        author: 'Larry Hsiao',
        licence: 'MIT',
        frame: ui.Size(2, 2),
        gaits: 'idle',
      );

      final pack = await packFrom(await packOf(wellFormed()));

      final worn = pack as Character;
      final actual = (
        name: worn.name,
        author: worn.author,
        licence: worn.licence,
        frame: worn.frame,
        gaits: worn.poses.keys.map((gait) => gait.name).join(','),
      );
      expect(actual, expected);
    });

    test(
      'plays its frames in the order it asks for, repeats and all',
      () async {
        const expected = [0, 1, 0, 2];

        final pack = await packFrom(
          await packOf(
            wellFormed(
              gaits: {
                'walking': {
                  'image': 'idle.png',
                  'frames': 3,
                  'sequence': [0, 1, 0, 2],
                  'pxPerFrame': 14,
                },
              },
            ),
          ),
        );

        expect((pack as Character).poses[Gait.walking]!.sequence, expected);
      },
    );

    test('counts pixels for a walk and milliseconds for a rest', () async {
      const expected = (walkPx: 14, walkMs: null, restMs: 600, restPx: null);

      final pack = await packFrom(
        await packOf(
          wellFormed(
            gaits: {
              'idle': {'image': 'idle.png', 'frames': 1, 'msPerFrame': 600},
              'walking': {'image': 'idle.png', 'frames': 1, 'pxPerFrame': 14},
            },
          ),
        ),
      );

      final worn = pack as Character;
      final actual = (
        walkPx: worn.poses[Gait.walking]!.everyPx,
        walkMs: worn.poses[Gait.walking]!.everyMs,
        restMs: worn.poses[Gait.idle]!.everyMs,
        restPx: worn.poses[Gait.idle]!.everyPx,
      );
      expect(actual, expected);
    });

    test('plays its frames in the drawn order when it asks for none', () async {
      const expected = [0, 1, 2];

      final pack = await packFrom(
        await packOf(
          wellFormed(
            gaits: {
              'idle': {'image': 'idle.png', 'frames': 3, 'msPerFrame': 600},
            },
          ),
        ),
      );

      expect((pack as Character).poses[Gait.idle]!.sequence, expected);
    });
  });

  group('a pack that is not', () {
    Future<String> refusalOf(Future<Uint8List> bytes) async =>
        ((await packFrom(await bytes)) as Unreadable).reason;

    test('with no manifest at all', () async {
      final said = await refusalOf(packOf(null, withManifest: false));
      expect(said, contains(manifestName));
    });

    test('with a manifest that is not JSON', () async {
      final said = await refusalOf(packOf('this is not a manifest'));
      expect(said, contains('not readable'));
    });

    test('written in a format this Roäc does not read', () async {
      final said = await refusalOf(
        packOf({...wellFormed(), 'format': readableFormat + 1}),
      );
      expect(said, contains('format'));
    });

    test('that does not say how large a frame is', () async {
      final manifest = wellFormed()..remove('frame');
      final said = await refusalOf(packOf(manifest));
      expect(said, contains('how large a frame is'));
    });

    test('naming an image it does not carry', () async {
      final said = await refusalOf(
        packOf(
          wellFormed(
            gaits: {
              'idle': {'image': 'missing.png', 'frames': 1},
            },
          ),
        ),
      );
      expect(said, contains('missing.png'));
    });

    test('playing a frame it does not draw', () async {
      final said = await refusalOf(
        packOf(
          wellFormed(
            gaits: {
              'idle': {
                'image': 'idle.png',
                'frames': 2,
                'sequence': [0, 5],
              },
            },
          ),
        ),
      );
      expect(said, contains('does not draw'));
    });

    test('drawing none of the gaits Roäc has', () async {
      final said = await refusalOf(
        packOf(wellFormed(gaits: {'flying': <String, Object?>{}})),
      );
      expect(said, contains('none of the gaits'));
    });

    // Bytes that are not a zip decode as an archive holding nothing, rather
    // than throwing — so the refusal that reaches the user is the honest one
    // about a missing manifest, which is what an empty archive truly lacks.
    test(
      'whose timing is written as a float, as many tools write it',
      () async {
        const expected = (ms: 600, px: null);

        final pack = await packFrom(
          await packOf(
            wellFormed(
              gaits: {
                'idle': {'image': 'idle.png', 'frames': 2, 'msPerFrame': 600.0},
              },
            ),
          ),
        );

        final worn = pack as Character;
        final actual = (
          ms: worn.poses[Gait.idle]!.everyMs,
          px: worn.poses[Gait.idle]!.everyPx,
        );
        expect(actual, expected);
      },
    );

    test('saying nothing of what carries its frames on', () async {
      final said = await refusalOf(
        packOf(
          wellFormed(
            gaits: {
              'idle': {'image': 'idle.png', 'frames': 2},
            },
          ),
        ),
      );
      expect(said, contains('carries them on'));
    });

    test('saying both what carries them on', () async {
      final said = await refusalOf(
        packOf(
          wellFormed(
            gaits: {
              'idle': {
                'image': 'idle.png',
                'frames': 2,
                'msPerFrame': 600,
                'pxPerFrame': 14,
              },
            },
          ),
        ),
      );
      expect(said, contains('one or the other'));
    });

    test('whose strip is smaller than the frames it claims', () async {
      final said = await refusalOf(
        packOf({
          ...wellFormed(
            gaits: {
              'idle': {'image': 'idle.png', 'frames': 1},
            },
          ),
          'frame': {'width': 100, 'height': 100},
        }),
      );
      expect(said, contains('is only'));
    });

    test('whose gaits are not a map at all', () async {
      final said = await refusalOf(packOf(wellFormed(gaits: 'idle')));
      expect(said, contains('names no gaits'));
    });

    test('whose gait is not described', () async {
      final said = await refusalOf(
        packOf(wellFormed(gaits: {'idle': 'four frames or so'})),
      );
      expect(said, contains('not described'));
    });

    test('whose frame count is not a count', () async {
      final said = await refusalOf(
        packOf(
          wellFormed(
            gaits: {
              'idle': {'image': 'idle.png', 'frames': 0},
            },
          ),
        ),
      );
      expect(said, contains('no frames'));
    });

    test('whose frame size is not a size', () async {
      final said = await refusalOf(
        packOf({
          ...wellFormed(),
          'frame': {'width': 'wide', 'height': 2},
        }),
      );
      expect(said, contains('how large a frame is'));
    });

    test('whose frame size is nothing at all', () async {
      final said = await refusalOf(
        packOf({
          ...wellFormed(),
          'frame': {'width': 0, 'height': 2},
        }),
      );
      expect(said, contains('no size at all'));
    });

    test('whose sequence is not a list', () async {
      final said = await refusalOf(
        packOf(
          wellFormed(
            gaits: {
              'idle': {'image': 'idle.png', 'frames': 2, 'sequence': 'first'},
            },
          ),
        ),
      );
      expect(said, contains('names no order'));
    });

    test('whose sequence plays nothing', () async {
      final said = await refusalOf(
        packOf(
          wellFormed(
            gaits: {
              'idle': {'image': 'idle.png', 'frames': 2, 'sequence': <int>[]},
            },
          ),
        ),
      );
      expect(said, contains('plays no frames at all'));
    });

    test('that is not a zip at all', () async {
      final said = await refusalOf(
        Future.value(Uint8List.fromList(utf8.encode('not a zip'))),
      );
      expect(said, contains(manifestName));
    });
  });

  group('where the packs are, and which is worn', () {
    test('under Application Support by default', () async {
      const expected = '/Users/someone/Library/Application Support/roac/packs';

      final actual = packsIn({'HOME': '/Users/someone'});

      expect(actual, expected);
    });

    test('wherever ROAC_PACKS names, when it names anywhere', () async {
      const expected = '/elsewhere/packs';

      final actual = packsIn({
        'HOME': '/Users/someone',
        'ROAC_PACKS': expected,
      });

      expect(actual, expected);
    });

    test('the one ROAC_PACK names, when it names one that is there', () {
      const expected = 'crow.zip';

      final actual = packChosenFrom(
        ['raven.zip', 'crow.zip'],
        {'ROAC_PACK': expected},
      );

      expect(actual, expected);
    });

    test('otherwise the first by name, never by the order of a listing', () {
      const expected = 'crow.zip';

      final actual = packChosenFrom([
        'raven.zip',
        'crow.zip',
        'magpie.zip',
      ], {});

      expect(actual, expected);
    });

    test('and nobody at all when there are none, which is no failure', () {
      const String? expected = null;

      final actual = packChosenFrom([], {});

      expect(actual, expected);
    });
  });
}
