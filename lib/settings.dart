import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// The file Roäc is told things in, kept beside the packs he wears.
const settingsName = 'config.json';

/// Where a value came from, so that a reader may be told.
enum Told {
  /// An environment variable named it.
  environment,

  /// The settings file named it.
  file,

  /// Nothing named it, and Roäc fell back on what he was born knowing.
  byDefault,
}

/// A value, and where Roäc was told it.
@immutable
final class Chosen {
  const Chosen(this.value, this.told);

  final String value;
  final Told told;
}

/// Why the settings file could not be used.
///
/// Named rather than written out, like every other trouble in this tree: the
/// sentence is said where a reader's tongue is known.
@immutable
sealed class Misread {
  const Misread();
}

/// The file is there and would not open. [trouble] is what the system said.
final class ShutSettings extends Misread {
  const ShutSettings(this.trouble);

  final String trouble;
}

/// The file opened and is not JSON. [trouble] is what the decoder said.
final class NotJson extends Misread {
  const NotJson(this.trouble);

  final String trouble;
}

/// The file is JSON, and is not a set of settings.
final class NotSettings extends Misread {
  const NotSettings();
}

/// What Roäc has been told about the world he stands in.
///
/// Three tiers, and the order is the whole of it: an environment variable
/// wins, then the settings file, then what he was born knowing. The
/// environment is first so that a test or a terminal may say something for
/// one run without writing it down; the file is there at all because a
/// windowed app launched from the Dock inherits almost no environment, and a
/// variable exported in a shell profile never reaches it.
@immutable
final class Settings {
  const Settings({
    required this.notes,
    required this.packs,
    required this.pack,
    this.trouble,
  });

  /// Where the notes are kept, and Roäc's questions are asked.
  final Chosen notes;

  /// The folder character packs are kept in.
  final Chosen packs;

  /// Which pack to wear. Null when nothing names one, which is no failure —
  /// the first by name is then worn, and Roäc draws himself if there is none.
  final Chosen? pack;

  /// Why the settings file was passed over, where there was one to pass over.
  ///
  /// Null when it read cleanly, and null when there was none at all: a file
  /// that was never written is not a fault. A file that is there and will not
  /// read is said aloud rather than quietly replaced by the defaults.
  final Misread? trouble;
}

/// Where the settings file is looked for.
///
/// Beside the packs, in the folder macOS keeps an application's own files in,
/// so that everything Roäc owns is in one place. `ROAC_SETTINGS` names it
/// elsewhere, for a test or a second Roäc on one machine.
String settingsPathIn(Map<String, String> environment) {
  final named = environment['ROAC_SETTINGS'];
  if (named != null && named.trim().isNotEmpty) return named;
  return '${environment['HOME'] ?? ''}/Library/Application Support/roac/'
      '$settingsName';
}

/// Everything Roäc has been told, read from [environment] and the file it
/// points at.
///
/// Nothing here throws. A settings file is a file a person edits by hand, and
/// the only useful answer to a bad one is to say what is wrong with it and
/// carry on with what was known before.
Future<Settings> settingsIn(Map<String, String> environment) async {
  final (told, trouble) = switch (await _fileIn(environment)) {
    _Kept(:final it) => (it, null),
    _Fumbled(:final why) => (const <String, Object?>{}, why),
  };
  return Settings(
    notes: _chosen(
      environment['ROAC_NOTES'],
      told['notes'],
      '${environment['HOME'] ?? ''}/Minerva',
    ),
    packs: _chosen(
      environment['ROAC_PACKS'],
      told['packs'],
      '${environment['HOME'] ?? ''}/Library/Application Support/roac/packs',
    ),
    pack: _chosenOrNot(environment['ROAC_PACK'], told['pack']),
    trouble: trouble,
  );
}

/// The three tiers, applied to one setting.
Chosen _chosen(String? said, Object? written, String born) =>
    _chosenOrNot(said, written) ?? Chosen(born, Told.byDefault);

/// The two tiers that may say nothing at all, applied to one setting.
Chosen? _chosenOrNot(String? said, Object? written) {
  if (said != null && said.trim().isNotEmpty) {
    return Chosen(said, Told.environment);
  }
  if (written is String && written.trim().isNotEmpty) {
    return Chosen(written, Told.file);
  }
  return null;
}

/// What the settings file held, or why it held nothing usable.
sealed class _Read {
  const _Read();
}

final class _Kept extends _Read {
  const _Kept(this.it);

  final Map<String, Object?> it;
}

final class _Fumbled extends _Read {
  const _Fumbled(this.why);

  final Misread why;
}

/// The settings file, read and understood.
///
/// A file that is not there is no fault: Roäc has never been told anything,
/// which is the ordinary case and not worth a word.
Future<_Read> _fileIn(Map<String, String> environment) async {
  final kept = File(settingsPathIn(environment));
  if (!kept.existsSync()) return const _Kept({});
  final String written;
  try {
    written = await kept.readAsString();
  } catch (trouble) {
    return _Fumbled(ShutSettings('$trouble'));
  }
  final Object? told;
  try {
    told = jsonDecode(written);
  } catch (trouble) {
    return _Fumbled(NotJson('$trouble'));
  }
  if (told is! Map<String, Object?>) return const _Fumbled(NotSettings());
  return _Kept(told);
}

/// Writes [changes] into the settings file, merging with what is there
/// already. A value of null drops that key, letting the tier beneath it
/// stand again.
///
/// Returns the trouble as its own words when the file could not be written,
/// or null when it was. Not wrapped in [Misread]: that sealed set names why
/// a *read* failed, at a moment nothing else is known about it; a write is
/// one person's own action, taken just now, and its own words already say
/// enough of what went wrong.
///
/// A file that is there and will not read is not preserved — writing over it
/// with what was just told is a fresh, deliberate telling, not a negotiation
/// with whatever came before. Its trouble is healed by the same stroke: what
/// is written back is always valid JSON.
///
/// A known cost of that healing: a file broken by one stray character, but
/// otherwise holding settings a person meant to keep, loses all of them the
/// moment any one setting is changed through the panel — the syntax error and
/// the good values it sat beside are indistinguishable once parsing has
/// failed. Worth naming; not worth solving for a fault a hand-edited file is
/// rarely in.
Future<String?> settingsWrite(
  Map<String, String?> changes,
  Map<String, String> environment,
) async {
  final kept = File(settingsPathIn(environment));
  var told = <String, Object?>{};
  if (kept.existsSync()) {
    try {
      final decoded = jsonDecode(await kept.readAsString());
      if (decoded is Map<String, Object?>) told = decoded;
    } catch (_) {
      // Left empty on purpose — see the doc comment above.
    }
  }
  for (final MapEntry(:key, :value) in changes.entries) {
    if (value == null) {
      told.remove(key);
    } else {
      told[key] = value;
    }
  }
  try {
    await kept.parent.create(recursive: true);
    await kept.writeAsString(const JsonEncoder.withIndent('  ').convert(told));
    return null;
  } catch (trouble) {
    return '$trouble';
  }
}
