// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'words.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class WordsZh extends Words {
  WordsZh([String locale = 'zh']) : super(locale);

  @override
  String get thinking => 'Roäc 正在思考…';

  @override
  String get invitation => '問我你寫下的事。';

  @override
  String get askHint => '問 Roäc…';

  @override
  String get linkCopied => '這個連結打不開，網址已複製到剪貼簿。';
}
