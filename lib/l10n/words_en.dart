// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'words.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class WordsEn extends Words {
  WordsEn([String locale = 'en']) : super(locale);

  @override
  String get thinking => 'Roäc is thinking…';

  @override
  String get invitation => 'Ask me what you have written down.';

  @override
  String get askHint => 'Ask Roäc…';

  @override
  String get linkCopied =>
      'That link would not open. Its address is on your clipboard.';

  @override
  String get noQuestion => 'Ask me something.';

  @override
  String get silence => 'Roäc fell silent, and was let go.';

  @override
  String noCounsel(int ending) {
    return 'Roäc found no counsel (the CLI exited $ending).';
  }

  @override
  String get surrender => 'The CLI gave up.';

  @override
  String packUnopenable(String what, String trouble) {
    return '$what could not be read ($trouble).';
  }

  @override
  String packNotAZip(String trouble) {
    return 'That pack could not be opened ($trouble).';
  }

  @override
  String get packNoManifest => 'That pack has no roac-pack.json in it.';

  @override
  String packUnreadableManifest(String trouble) {
    return 'That pack\'s roac-pack.json is not readable ($trouble).';
  }

  @override
  String get packNotAManifest =>
      'That pack\'s roac-pack.json is not a manifest.';

  @override
  String packWrongFormat(String found, int readable) {
    return 'That pack is written in format $found; this Roäc reads $readable.';
  }

  @override
  String get packNoFrameSize => 'That pack does not say how large a frame is.';

  @override
  String get packZeroFrame => 'That pack gives its frames no size at all.';

  @override
  String get packNoGaits => 'That pack names no gaits.';

  @override
  String get packNoKnownGaits => 'That pack draws none of the gaits Roäc has.';

  @override
  String packNoDescription(String gait) {
    return 'That pack\'s $gait is not described.';
  }

  @override
  String packNoFrameCount(String gait) {
    return 'That pack\'s $gait has no frames.';
  }

  @override
  String packUnreadableOrder(String gait) {
    return 'That pack\'s $gait names no order its frames play in.';
  }

  @override
  String packEmptyOrder(String gait) {
    return 'That pack\'s $gait plays no frames at all.';
  }

  @override
  String packUndrawnFrame(String gait) {
    return 'That pack\'s $gait plays a frame it does not draw.';
  }

  @override
  String packNoTiming(String gait) {
    return 'That pack\'s $gait plays several frames but says nothing of what carries them on — give it msPerFrame or pxPerFrame.';
  }

  @override
  String packTwoTimings(String gait) {
    return 'That pack\'s $gait gives both msPerFrame and pxPerFrame; it must give one or the other.';
  }

  @override
  String packMissingStrip(String gait, String image) {
    return 'That pack\'s $gait names $image, which is not in it.';
  }

  @override
  String packSmallStrip(
    String gait,
    String image,
    int frames,
    int wide,
    int high,
    int actuallyWide,
    int actuallyHigh,
  ) {
    return 'That pack\'s $gait says $frames frames of $wide by $high, but $image is only $actuallyWide by $actuallyHigh.';
  }

  @override
  String settingsShut(String trouble) {
    return 'Roäc\'s settings file is there and will not open ($trouble). What it says is passed over.';
  }

  @override
  String settingsNotJson(String trouble) {
    return 'Roäc\'s settings file is not JSON ($trouble). What it says is passed over.';
  }

  @override
  String get settingsNotSettings =>
      'Roäc\'s settings file holds something that is not a set of settings. What it says is passed over.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get closeSettings => 'Close settings';

  @override
  String get notesLabel => 'Notes';

  @override
  String get packsLabel => 'Character packs';

  @override
  String get characterLabel => 'Character';

  @override
  String get claudeConfigLabel => 'Claude config';

  @override
  String get choose => 'Choose…';

  @override
  String get toldByFile => 'told by the settings file';

  @override
  String get toldByDefault => 'the built-in default';

  @override
  String setByEnvironment(String name) {
    return 'set by $name';
  }

  @override
  String get drawnCharacter => 'Roäc (drawn)';

  @override
  String get drawnCharacterNoPacks => 'Roäc (drawn — no packs installed)';

  @override
  String get claudeConfigUnset => 'the CLI\'s own config';

  @override
  String settingsUnwritable(String trouble) {
    return 'Roäc\'s settings could not be saved ($trouble).';
  }
}
