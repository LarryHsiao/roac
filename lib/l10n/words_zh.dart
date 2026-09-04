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

  @override
  String get noQuestion => '問我些什麼吧。';

  @override
  String get silence => 'Roäc 久久不語，只好由他去了。';

  @override
  String noCounsel(int ending) {
    return 'Roäc 找不到答案（CLI 以代碼 $ending 結束）。';
  }

  @override
  String get surrender => 'CLI 放棄了。';
}
