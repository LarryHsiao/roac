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

  @override
  String packUnopenable(String what, String trouble) {
    return '$what 讀不了（$trouble）。';
  }

  @override
  String packNotAZip(String trouble) {
    return '這個角色包打不開（$trouble）。';
  }

  @override
  String get packNoManifest => '這個角色包裡沒有 roac-pack.json。';

  @override
  String packUnreadableManifest(String trouble) {
    return '這個角色包的 roac-pack.json 讀不了（$trouble）。';
  }

  @override
  String get packNotAManifest => '這個角色包的 roac-pack.json 不是一份清單。';

  @override
  String packWrongFormat(String found, int readable) {
    return '這個角色包用的是 $found 版格式，這隻 Roäc 只讀 $readable 版。';
  }

  @override
  String get packNoFrameSize => '這個角色包沒說一格畫面多大。';

  @override
  String get packZeroFrame => '這個角色包給的畫格根本沒有大小。';

  @override
  String get packNoGaits => '這個角色包沒有列出任何動作。';

  @override
  String get packNoKnownGaits => '這個角色包畫的動作，Roäc 一個也不會。';

  @override
  String packNoDescription(String gait) {
    return '這個角色包的 $gait 沒有說明。';
  }

  @override
  String packNoFrameCount(String gait) {
    return '這個角色包的 $gait 沒有畫格。';
  }

  @override
  String packUnreadableOrder(String gait) {
    return '這個角色包的 $gait 沒說畫格照什麼順序播。';
  }

  @override
  String packEmptyOrder(String gait) {
    return '這個角色包的 $gait 一格也不播。';
  }

  @override
  String packUndrawnFrame(String gait) {
    return '這個角色包的 $gait 要播一格它沒畫的畫面。';
  }

  @override
  String packNoTiming(String gait) {
    return '這個角色包的 $gait 要播好幾格，卻沒說靠什麼推進——給它 msPerFrame 或 pxPerFrame。';
  }

  @override
  String packTwoTimings(String gait) {
    return '這個角色包的 $gait 同時給了 msPerFrame 和 pxPerFrame，只能給一個。';
  }

  @override
  String packMissingStrip(String gait, String image) {
    return '這個角色包的 $gait 指名 $image，但包裡沒有這個檔案。';
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
    return '這個角色包的 $gait 說有 $frames 格、每格 $wide × $high，但 $image 只有 $actuallyWide × $actuallyHigh。';
  }

  @override
  String settingsShut(String trouble) {
    return 'Roäc 的設定檔在那裡，卻打不開（$trouble）。裡頭寫的一律略過。';
  }

  @override
  String settingsNotJson(String trouble) {
    return 'Roäc 的設定檔不是 JSON（$trouble）。裡頭寫的一律略過。';
  }

  @override
  String get settingsNotSettings => 'Roäc 的設定檔裡放的不是一組設定。裡頭寫的一律略過。';
}
