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
