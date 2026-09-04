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
}
