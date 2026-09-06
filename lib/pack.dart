import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

import 'roaming.dart';

/// The manifest every pack carries, by the name it carries it under.
const manifestName = 'roac-pack.json';

/// The names a pack calls the ways Roäc stands.
///
/// Held apart from the Dart spelling on purpose. A pack sold today names
/// `walking`; if that enum value were ever renamed for reasons inside the
/// code, every such pack would quietly lose its walk. The wire vocabulary is
/// a promise to strangers, and it does not move when the code does.
const gaitNames = {
  'idle': Gait.idle,
  'walking': Gait.walking,
  'pinned': Gait.pinned,
};

/// The format this reader understands. A pack naming a later one is refused
/// rather than guessed at: a pack sold today must not be quietly misread by a
/// Roäc that has since learned more.
const readableFormat = 1;

/// Which of [packs] to wear, given the one [named] asks for.
///
/// A name that is there is worn. Failing that the first by name, so that a
/// mascot does not change character because a filesystem listed its files in
/// a different order today. Null when there are none, which is not a failure
/// — Roäc draws himself when he is given nobody else to be.
String? packChosenFrom(List<String> packs, String? named) {
  if (packs.isEmpty) return null;
  if (named != null && packs.contains(named)) return named;
  final byName = [...packs]..sort();
  return byName.first;
}

/// Either something read from a pack, or the reason it could not be.
///
/// The same answer-or-trouble shape [Pack] itself wears, made general: each
/// step of reading a pack either yields a value or a sentence about why not.
/// A bare `Object` said as much to a person reading the code and nothing at
/// all to the compiler, which could not then insist a caller check which it
/// had been handed.
@immutable
sealed class _Read<T> {
  const _Read();
}

/// What was read.
final class _Found<T> extends _Read<T> {
  const _Found(this.it);

  final T it;
}

/// Why nothing was.
final class _Fault<T> extends _Read<T> {
  const _Fault(this.flaw);

  final Flaw flaw;
}

/// The pack [named], or the first there is, read from the folder [from].
///
/// Null when there is none to wear, which is no failure: Roäc draws himself
/// when he is given nobody else to be. A pack that is there but will not be
/// read comes back as [Unreadable], because somebody chose it and deserves to
/// know why they are looking at the built-in bird instead.
Future<Pack?> packWorn(String from, String? named) async {
  final kept = Directory(from);
  String? chosen;
  try {
    if (!kept.existsSync()) return null;
    final packs = kept
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .where((named) => named.endsWith('.zip'))
        .toList();
    chosen = packChosenFrom(packs, named);
    if (chosen == null) return null;
    return await packFrom(await File('${kept.path}/$chosen').readAsBytes());
  } catch (trouble) {
    // The listing is inside this too, not only the reading. A folder that
    // goes away between the asking and the looking would otherwise throw
    // past every sentence this was written to give.
    return Unreadable(
      Unopenable(
        chosen == null ? kept.path : '${kept.path}/$chosen',
        '$trouble',
      ),
    );
  }
}

/// What is wrong with a pack.
///
/// Named rather than written out, so the sentence can be said in the reader's
/// own tongue. A loader has no business composing English.
@immutable
sealed class Flaw {
  const Flaw();
}

/// [what] could not be read at all — a folder that went away, a file that
/// would not open. Always a whole path, never a bare name: a message naming
/// only `broken.zip` cannot tell anyone which folder to look in. [trouble] is
/// what the system said about it, in its own words.
final class Unopenable extends Flaw {
  const Unopenable(this.what, this.trouble);

  final String what;
  final String trouble;
}

/// The bytes are not a zip. [trouble] is what the decoder said.
final class NotAZip extends Flaw {
  const NotAZip(this.trouble);

  final String trouble;
}

/// The zip holds no manifest.
final class NoManifest extends Flaw {
  const NoManifest();
}

/// The manifest is there but will not decode. [trouble] is what JSON said.
final class UnreadableManifest extends Flaw {
  const UnreadableManifest(this.trouble);

  final String trouble;
}

/// The manifest decoded to something that is not a manifest.
final class NotAManifest extends Flaw {
  const NotAManifest();
}

/// The pack is written in a format this Roäc does not read.
final class WrongFormat extends Flaw {
  const WrongFormat(this.found, this.readable);

  /// What the manifest said, whatever it said — a pack may name anything.
  final String found;
  final int readable;
}

/// The manifest says nothing of how large a frame is.
final class NoFrameSize extends Flaw {
  const NoFrameSize();
}

/// The manifest gives a frame a size, and gives it as nothing.
final class ZeroFrame extends Flaw {
  const ZeroFrame();
}

/// The manifest names no gaits.
final class NoGaits extends Flaw {
  const NoGaits();
}

/// The manifest names gaits, but none that Roäc has.
final class NoKnownGaits extends Flaw {
  const NoKnownGaits();
}

/// [gait] is named but not described.
final class NoDescription extends Flaw {
  const NoDescription(this.gait);

  final String gait;
}

/// [gait] says nothing usable of how many frames it is drawn in.
final class NoFrameCount extends Flaw {
  const NoFrameCount(this.gait);

  final String gait;
}

/// [gait] gives an order that is not an order at all.
final class UnreadableOrder extends Flaw {
  const UnreadableOrder(this.gait);

  final String gait;
}

/// [gait] gives an order, and the order is empty.
final class EmptyOrder extends Flaw {
  const EmptyOrder(this.gait);

  final String gait;
}

/// [gait] plays a frame it does not draw.
final class UndrawnFrame extends Flaw {
  const UndrawnFrame(this.gait);

  final String gait;
}

/// [gait] plays several frames and says nothing of what carries them on.
final class NoTiming extends Flaw {
  const NoTiming(this.gait);

  final String gait;
}

/// [gait] gives both a time and a distance, where it must give one.
final class TwoTimings extends Flaw {
  const TwoTimings(this.gait);

  final String gait;
}

/// [gait] names a strip the pack does not hold.
final class MissingStrip extends Flaw {
  const MissingStrip(this.gait, this.image);

  final String gait;
  final String image;
}

/// [gait]'s strip is smaller than the frames it claims to hold.
final class SmallStrip extends Flaw {
  const SmallStrip({
    required this.gait,
    required this.image,
    required this.frames,
    required this.wanted,
    required this.actual,
  });

  final String gait;
  final String image;
  final int frames;

  /// How large one frame was said to be, and how large the strip truly is.
  final ui.Size wanted;
  final ui.Size actual;
}

/// What was made of a pack.
@immutable
sealed class Pack {
  const Pack();
}

/// A character Roäc may wear: who made it, and a strip of frames for each way
/// of standing.
final class Character extends Pack {
  const Character({
    required this.name,
    required this.author,
    required this.licence,
    required this.frame,
    required this.poses,
  });

  final String name;
  final String author;
  final String licence;

  /// How large one frame is within its strip.
  final ui.Size frame;

  final Map<Gait, Poses> poses;
}

/// Why a pack could not be worn — said plainly rather than swallowed, because
/// somebody paid for it and deserves to know what is wrong with it.
final class Unreadable extends Pack {
  const Unreadable(this.flaw);

  final Flaw flaw;
}

/// One way of standing: the strip it is drawn on, the order its frames are
/// played in, and what advances them.
@immutable
class Poses {
  const Poses({
    required this.strip,
    required this.frames,
    required this.sequence,
    this.everyMs,
    this.everyPx,
  });

  final ui.Image strip;

  /// How many frames the strip holds, left to right.
  final int frames;

  /// The frames to play, in order. A pose may appear more than once — a walk
  /// is three drawings played as four steps, the passing pose serving twice.
  final List<int> sequence;

  /// What carries the sequence on: time for a bird going nowhere, distance for
  /// one that is walking, so its feet never skate.
  final int? everyMs;
  final int? everyPx;
}

/// Reads the pack in [bytes], or says why it cannot.
///
/// Nothing here throws. A pack is a file a stranger made and a stranger may
/// have made badly, and the only useful answer to a bad one is a sentence the
/// person who installed it can act on.
Future<Pack> packFrom(Uint8List bytes) async {
  try {
    final zip = ZipDecoder().decodeBytes(bytes);
    switch (_manifestIn(zip)) {
      case _Fault(:final flaw):
        return Unreadable(flaw);
      case _Found(:final it):
        return await _characterFrom(it, zip);
    }
  } catch (trouble) {
    return Unreadable(NotAZip('$trouble'));
  }
}

/// The manifest, read and understood, or the reason it was neither.
_Read<Map<String, dynamic>> _manifestIn(Archive zip) {
  final file = zip.findFile(manifestName);
  if (file == null) {
    return const _Fault(NoManifest());
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(file.content as List<int>));
  } catch (trouble) {
    return _Fault(UnreadableManifest('$trouble'));
  }
  if (decoded is! Map<String, dynamic>) {
    return const _Fault(NotAManifest());
  }
  final format = decoded['format'];
  if (format != readableFormat) {
    return _Fault(WrongFormat('$format', readableFormat));
  }
  return _Found(decoded);
}

Future<Pack> _characterFrom(Map<String, dynamic> manifest, Archive zip) async {
  final frame = manifest['frame'];
  if (frame is! Map || frame['width'] is! num || frame['height'] is! num) {
    return const Unreadable(NoFrameSize());
  }
  final gaits = manifest['gaits'];
  if (gaits is! Map) {
    return const Unreadable(NoGaits());
  }
  final width = (frame['width'] as num).toDouble();
  final height = (frame['height'] as num).toDouble();
  if (width <= 0 || height <= 0) {
    return const Unreadable(ZeroFrame());
  }
  switch (await _allPosesIn(gaits, zip, ui.Size(width, height))) {
    case _Fault(:final flaw):
      return Unreadable(flaw);
    case _Found(:final it):
      return Character(
        name: '${manifest['name'] ?? 'a nameless character'}',
        author: '${manifest['author'] ?? 'nobody named'}',
        licence: '${manifest['licence'] ?? 'no licence given'}',
        frame: ui.Size(width, height),
        poses: it,
      );
  }
}

/// Every gait the pack draws, or the reason one of them could not be read.
Future<_Read<Map<Gait, Poses>>> _allPosesIn(
  Map gaits,
  Archive zip,
  ui.Size frame,
) async {
  final poses = <Gait, Poses>{};
  for (final named in gaitNames.entries) {
    final given = gaits[named.key];
    if (given == null) continue;
    switch (await _posesFrom(given, zip, named.key, frame)) {
      case _Fault(:final flaw):
        return _Fault(flaw);
      case _Found(:final it):
        poses[named.value] = it;
    }
  }
  if (poses.isEmpty) {
    return const _Fault(NoKnownGaits());
  }
  return _Found(poses);
}

Future<_Read<Poses>> _posesFrom(
  Object named,
  Archive zip,
  String gait,
  ui.Size frame,
) async {
  if (named is! Map) return _Fault(NoDescription(gait));
  final frames = named['frames'];
  if (frames is! int || frames < 1) {
    return _Fault(NoFrameCount(gait));
  }
  final Running running;
  switch (_runningIn(named, gait, frames)) {
    case _Fault(:final flaw):
      return _Fault(flaw);
    case _Found(:final it):
      running = it;
  }
  switch (await _stripFor(named, zip, gait, frame, frames)) {
    case _Fault(:final flaw):
      return _Fault(flaw);
    case _Found(:final it):
      return _Found(
        Poses(
          strip: it,
          frames: frames,
          sequence: running.sequence,
          everyMs: running.everyMs,
          everyPx: running.everyPx,
        ),
      );
  }
}

/// How a gait's frames run: the order they play in, and what carries them on.
typedef Running = ({List<int> sequence, int? everyMs, int? everyPx});

/// [named]'s running, read and agreed, or the reason it is neither.
_Read<Running> _runningIn(Map named, String gait, int frames) {
  final List<int> sequence;
  switch (_sequenceIn(named['sequence'], frames, gait)) {
    case _Fault(:final flaw):
      return _Fault(flaw);
    case _Found(:final it):
      sequence = it;
  }
  final everyMs = _whole(named['msPerFrame']);
  final everyPx = _whole(named['pxPerFrame']);
  final timing = _timingRead(everyMs, everyPx, sequence, gait);
  if (timing != null) return _Fault(timing.flaw);
  return _Found((sequence: sequence, everyMs: everyMs, everyPx: everyPx));
}

/// The strip a gait is drawn on, once it is found and once it is large enough
/// to hold what the manifest says is drawn there.
Future<_Read<ui.Image>> _stripFor(
  Map named,
  Archive zip,
  String gait,
  ui.Size frame,
  int frames,
) async {
  final image = zip.findFile('${named['image']}');
  if (image == null) {
    return _Fault(MissingStrip(gait, '${named['image']}'));
  }
  final strip = await _decode(Uint8List.fromList(image.content as List<int>));
  if (strip.width < frame.width * frames || strip.height < frame.height) {
    return _Fault(
      SmallStrip(
        gait: gait,
        image: '${named['image']}',
        frames: frames,
        wanted: frame,
        actual: ui.Size(strip.width.toDouble(), strip.height.toDouble()),
      ),
    );
  }
  return _Found(strip);
}

/// A whole number however the manifest wrote it, or null where it wrote none.
///
/// JSON has one kind of number, and plenty of tools spell six hundred `600.0`.
/// A pack is not malformed for having been written by such a tool.
int? _whole(Object? given) => given is num ? given.round() : null;

/// Why the timing will not do, or null where it will.
///
/// Several frames must say what carries them on, and must say it once: time
/// for a bird going nowhere, distance for one that is walking. Left to a
/// renderer to guess, whichever it guessed would become the rule for every
/// pack ever sold — a contract settled by accident.
_Fault<Running>? _timingRead(
  int? ms,
  int? px,
  List<int> sequence,
  String gait,
) {
  if (sequence.length < 2) return null;
  if (ms == null && px == null) {
    return _Fault(NoTiming(gait));
  }
  if (ms != null && px != null) {
    return _Fault(TwoTimings(gait));
  }
  return null;
}

/// The order the frames play in, or what is wrong with the order given.
/// Absent, the frames simply play in the order they were drawn.
_Read<List<int>> _sequenceIn(Object? given, int frames, String gait) {
  if (given == null) {
    return _Found([for (var frame = 0; frame < frames; frame++) frame]);
  }
  if (given is! List) return _Fault(UnreadableOrder(gait));
  if (given.isEmpty) return _Fault(EmptyOrder(gait));
  final sequence = <int>[];
  for (final step in given) {
    final at = _whole(step);
    if (at == null || at < 0 || at >= frames) {
      return _Fault(UndrawnFrame(gait));
    }
    sequence.add(at);
  }
  return _Found(sequence);
}

Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}
