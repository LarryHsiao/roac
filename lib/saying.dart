/// Turning a named cause into a sentence, in the reader's own tongue.
///
/// The files that find these causes — a subprocess reader, a pack loader —
/// do not compose sentences, because they are run where no reader's tongue is
/// known. They name what went wrong and carry the values; the saying is done
/// here, and only here.
library;

import 'counsel.dart';
import 'l10n/words.dart';
import 'pack.dart';
import 'settings.dart';

/// What a [trouble] says.
///
/// A complaint from the CLI or the shell is the exception: it is passed on in
/// its own words, whatever those are. They were not written by Roäc and are
/// not his to translate.
String saidOfTrouble(Words tongue, Trouble trouble) => switch (trouble) {
  NoQuestion() => tongue.noQuestion,
  Silence() => tongue.silence,
  NoCounsel(:final ending) => tongue.noCounsel(ending),
  Surrender() => tongue.surrender,
  Complaint(:final words) => words,
};

/// What a [flaw] in a character pack says.
///
/// The trouble a zip decoder or the filesystem reports is passed on in its own
/// words, for the same reason a CLI's complaint is: it was not written here.
String saidOfFlaw(Words tongue, Flaw flaw) => switch (flaw) {
  Unopenable(:final what, :final trouble) => tongue.packUnopenable(
    what,
    trouble,
  ),
  NotAZip(:final trouble) => tongue.packNotAZip(trouble),
  NoManifest() => tongue.packNoManifest,
  UnreadableManifest(:final trouble) => tongue.packUnreadableManifest(trouble),
  NotAManifest() => tongue.packNotAManifest,
  WrongFormat(:final found, :final readable) => tongue.packWrongFormat(
    found,
    readable,
  ),
  NoFrameSize() => tongue.packNoFrameSize,
  ZeroFrame() => tongue.packZeroFrame,
  NoGaits() => tongue.packNoGaits,
  NoKnownGaits() => tongue.packNoKnownGaits,
  NoDescription(:final gait) => tongue.packNoDescription(gait),
  NoFrameCount(:final gait) => tongue.packNoFrameCount(gait),
  UnreadableOrder(:final gait) => tongue.packUnreadableOrder(gait),
  EmptyOrder(:final gait) => tongue.packEmptyOrder(gait),
  UndrawnFrame(:final gait) => tongue.packUndrawnFrame(gait),
  NoTiming(:final gait) => tongue.packNoTiming(gait),
  TwoTimings(:final gait) => tongue.packTwoTimings(gait),
  MissingStrip(:final gait, :final image) => tongue.packMissingStrip(
    gait,
    image,
  ),
  SmallStrip(
    :final gait,
    :final image,
    :final frames,
    :final wanted,
    :final actual,
  ) =>
    tongue.packSmallStrip(
      gait,
      image,
      frames,
      wanted.width.toInt(),
      wanted.height.toInt(),
      actual.width.toInt(),
      actual.height.toInt(),
    ),
};

/// Why Roäc's settings file was passed over.
///
/// The trouble the filesystem or the JSON decoder reports is passed on in its
/// own words, for the same reason a CLI's complaint is.
String saidOfMisread(Words tongue, Misread misread) => switch (misread) {
  ShutSettings(:final trouble) => tongue.settingsShut(trouble),
  NotJson(:final trouble) => tongue.settingsNotJson(trouble),
  NotSettings() => tongue.settingsNotSettings,
};
