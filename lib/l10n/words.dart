import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'words_en.dart';
import 'words_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of Words
/// returned by `Words.of(context)`.
///
/// Applications need to include `Words.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/words.dart';
///
/// return MaterialApp(
///   localizationsDelegates: Words.localizationsDelegates,
///   supportedLocales: Words.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the Words.supportedLocales
/// property.
abstract class Words {
  Words(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static Words of(BuildContext context) {
    return Localizations.of<Words>(context, Words)!;
  }

  static const LocalizationsDelegate<Words> delegate = _WordsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// Shown in the bubble while the CLI is being waited on.
  ///
  /// In en, this message translates to:
  /// **'Roäc is thinking…'**
  String get thinking;

  /// Shown in the bubble before anything has been asked.
  ///
  /// In en, this message translates to:
  /// **'Ask me what you have written down.'**
  String get invitation;

  /// The placeholder in the field a question is typed into.
  ///
  /// In en, this message translates to:
  /// **'Ask Roäc…'**
  String get askHint;

  /// Said when a link in an answer cannot be opened, so its address was put on the clipboard instead.
  ///
  /// In en, this message translates to:
  /// **'That link would not open. Its address is on your clipboard.'**
  String get linkCopied;

  /// Said when the question put to Roäc was empty.
  ///
  /// In en, this message translates to:
  /// **'Ask me something.'**
  String get noQuestion;

  /// Said when the CLI stopped speaking for so long it was killed.
  ///
  /// In en, this message translates to:
  /// **'Roäc fell silent, and was let go.'**
  String get silence;

  /// Said when the CLI ended without a last word and complained of nothing, leaving only its exit code.
  ///
  /// In en, this message translates to:
  /// **'Roäc found no counsel (the CLI exited {ending}).'**
  String noCounsel(int ending);

  /// Said when the CLI reported a failure but named nothing that went wrong.
  ///
  /// In en, this message translates to:
  /// **'The CLI gave up.'**
  String get surrender;

  /// A flaw in a character pack: Unopenable.
  ///
  /// In en, this message translates to:
  /// **'{what} could not be read ({trouble}).'**
  String packUnopenable(String what, String trouble);

  /// A flaw in a character pack: NotAZip.
  ///
  /// In en, this message translates to:
  /// **'That pack could not be opened ({trouble}).'**
  String packNotAZip(String trouble);

  /// A flaw in a character pack: NoManifest.
  ///
  /// In en, this message translates to:
  /// **'That pack has no roac-pack.json in it.'**
  String get packNoManifest;

  /// A flaw in a character pack: UnreadableManifest.
  ///
  /// In en, this message translates to:
  /// **'That pack\'s roac-pack.json is not readable ({trouble}).'**
  String packUnreadableManifest(String trouble);

  /// A flaw in a character pack: NotAManifest.
  ///
  /// In en, this message translates to:
  /// **'That pack\'s roac-pack.json is not a manifest.'**
  String get packNotAManifest;

  /// A flaw in a character pack: WrongFormat.
  ///
  /// In en, this message translates to:
  /// **'That pack is written in format {found}; this Roäc reads {readable}.'**
  String packWrongFormat(String found, int readable);

  /// A flaw in a character pack: NoFrameSize.
  ///
  /// In en, this message translates to:
  /// **'That pack does not say how large a frame is.'**
  String get packNoFrameSize;

  /// A flaw in a character pack: EmptyFrame.
  ///
  /// In en, this message translates to:
  /// **'That pack gives its frames no size at all.'**
  String get packZeroFrame;

  /// A flaw in a character pack: NoGaits.
  ///
  /// In en, this message translates to:
  /// **'That pack names no gaits.'**
  String get packNoGaits;

  /// A flaw in a character pack: NoKnownGaits.
  ///
  /// In en, this message translates to:
  /// **'That pack draws none of the gaits Roäc has.'**
  String get packNoKnownGaits;

  /// A flaw in a character pack: NoDescription.
  ///
  /// In en, this message translates to:
  /// **'That pack\'s {gait} is not described.'**
  String packNoDescription(String gait);

  /// A flaw in a character pack: NoFrames.
  ///
  /// In en, this message translates to:
  /// **'That pack\'s {gait} has no frames.'**
  String packNoFrameCount(String gait);

  /// A flaw in a character pack: NoOrder.
  ///
  /// In en, this message translates to:
  /// **'That pack\'s {gait} names no order its frames play in.'**
  String packUnreadableOrder(String gait);

  /// A flaw in a character pack: NoPlay.
  ///
  /// In en, this message translates to:
  /// **'That pack\'s {gait} plays no frames at all.'**
  String packEmptyOrder(String gait);

  /// A flaw in a character pack: UndrawnFrame.
  ///
  /// In en, this message translates to:
  /// **'That pack\'s {gait} plays a frame it does not draw.'**
  String packUndrawnFrame(String gait);

  /// A flaw in a character pack: NoTiming.
  ///
  /// In en, this message translates to:
  /// **'That pack\'s {gait} plays several frames but says nothing of what carries them on — give it msPerFrame or pxPerFrame.'**
  String packNoTiming(String gait);

  /// A flaw in a character pack: TwoTimings.
  ///
  /// In en, this message translates to:
  /// **'That pack\'s {gait} gives both msPerFrame and pxPerFrame; it must give one or the other.'**
  String packTwoTimings(String gait);

  /// A flaw in a character pack: MissingStrip.
  ///
  /// In en, this message translates to:
  /// **'That pack\'s {gait} names {image}, which is not in it.'**
  String packMissingStrip(String gait, String image);

  /// A flaw in a character pack: SmallStrip.
  ///
  /// In en, this message translates to:
  /// **'That pack\'s {gait} says {frames} frames of {wide} by {high}, but {image} is only {actuallyWide} by {actuallyHigh}.'**
  String packSmallStrip(
    String gait,
    String image,
    int frames,
    int wide,
    int high,
    int actuallyWide,
    int actuallyHigh,
  );

  /// Why Roäc's settings file was passed over: Shut.
  ///
  /// In en, this message translates to:
  /// **'Roäc\'s settings file is there and will not open ({trouble}). What it says is passed over.'**
  String settingsShut(String trouble);

  /// Why Roäc's settings file was passed over: NotJson.
  ///
  /// In en, this message translates to:
  /// **'Roäc\'s settings file is not JSON ({trouble}). What it says is passed over.'**
  String settingsNotJson(String trouble);

  /// Why Roäc's settings file was passed over: NotSettings.
  ///
  /// In en, this message translates to:
  /// **'Roäc\'s settings file holds something that is not a set of settings. What it says is passed over.'**
  String get settingsNotSettings;

  /// Settings panel: settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Settings panel: closeSettings.
  ///
  /// In en, this message translates to:
  /// **'Close settings'**
  String get closeSettings;

  /// Settings panel: notesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesLabel;

  /// Settings panel: packsLabel.
  ///
  /// In en, this message translates to:
  /// **'Character packs'**
  String get packsLabel;

  /// Settings panel: characterLabel.
  ///
  /// In en, this message translates to:
  /// **'Character'**
  String get characterLabel;

  /// Settings panel: claudeConfigLabel.
  ///
  /// In en, this message translates to:
  /// **'Claude config'**
  String get claudeConfigLabel;

  /// Settings panel: choose.
  ///
  /// In en, this message translates to:
  /// **'Choose…'**
  String get choose;

  /// Settings panel: toldByFile.
  ///
  /// In en, this message translates to:
  /// **'told by the settings file'**
  String get toldByFile;

  /// Settings panel: toldByDefault.
  ///
  /// In en, this message translates to:
  /// **'the built-in default'**
  String get toldByDefault;

  /// Settings panel: setByEnvironment.
  ///
  /// In en, this message translates to:
  /// **'set by {name}'**
  String setByEnvironment(String name);

  /// Settings panel: drawnCharacter.
  ///
  /// In en, this message translates to:
  /// **'Roäc (drawn)'**
  String get drawnCharacter;

  /// Settings panel: drawnCharacterNoPacks.
  ///
  /// In en, this message translates to:
  /// **'Roäc (drawn — no packs installed)'**
  String get drawnCharacterNoPacks;

  /// Settings panel: claudeConfigUnset.
  ///
  /// In en, this message translates to:
  /// **'the CLI\'s own config'**
  String get claudeConfigUnset;

  /// Settings panel: settingsUnwritable.
  ///
  /// In en, this message translates to:
  /// **'Roäc\'s settings could not be saved ({trouble}).'**
  String settingsUnwritable(String trouble);
}

class _WordsDelegate extends LocalizationsDelegate<Words> {
  const _WordsDelegate();

  @override
  Future<Words> load(Locale locale) {
    return SynchronousFuture<Words>(lookupWords(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_WordsDelegate old) => false;
}

Words lookupWords(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return WordsEn();
    case 'zh':
      return WordsZh();
  }

  throw FlutterError(
    'Words.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
