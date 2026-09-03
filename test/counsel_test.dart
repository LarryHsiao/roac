import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:roac/counsel.dart';

/// A stand-in for the CLI, so no test ever reaches the real shell.
class _Claude implements Process {
  _Claude({
    List<String> says = const [],
    this.complains = '',
    this.ending = 0,
    this.lingers = false,
  })  : _lines = says,
        _saying = null;

  /// A CLI that speaks on [saying] as a real one does — a line at a time, with
  /// whatever gaps it likes between them.
  _Claude.speaking(Stream<List<int>> saying)
      : _lines = const [],
        _saying = saying,
        complains = '',
        ending = 0,
        lingers = false;

  final List<String> _lines;
  final Stream<List<int>>? _saying;
  final String complains;
  final int ending;

  /// Whether it says nothing and never finishes, so the silence runs out.
  final bool lingers;

  bool killed = false;

  /// Open and empty, so a lingering CLI neither speaks nor finishes.
  final _quiet = StreamController<List<int>>();

  @override
  Stream<List<int>> get stdout =>
      _saying ??
      (lingers ? _quiet.stream : Stream.value(utf8.encode(_lines.join('\n'))));

  @override
  Stream<List<int>> get stderr => Stream.value(utf8.encode(complains));

  @override
  Future<int> get exitCode =>
      lingers ? Completer<int>().future : Future.value(ending);

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    return true;
  }

  @override
  int get pid => 1;

  @override
  IOSink get stdin => throw UnimplementedError();
}

/// The CLI's own line shapes, so the tests speak what it speaks.
String delta(String text, {String session = 'a-session'}) => jsonEncode({
      'type': 'stream_event',
      'session_id': session,
      'event': {
        'type': 'content_block_delta',
        'delta': {'type': 'text_delta', 'text': text},
      },
    });

String finished({
  String session = 'a-session',
  bool failed = false,
  String result = 'all done',
}) =>
    jsonEncode({
      'type': 'result',
      'session_id': session,
      'subtype': failed ? 'error_during_execution' : 'success',
      'is_error': failed,
      'result': result,
    });

void main() {
  Shell shellOf(_Claude claude) =>
      (String _, List<String> _, {String? workingDirectory}) async => claude;

  test('the words arrive a piece at a time, each carrying all said so far',
      () async {
    const expected = ['The ', 'The policy ', 'The policy is here.'];
    final claude = _Claude(
      says: [delta('The '), delta('policy '), delta('is here.'), finished()],
    );

    final said = await askCounsel('where?', shell: shellOf(claude))
        .where((counsel) => counsel is Answer)
        .cast<Answer>()
        .map((answer) => answer.words)
        .toList();

    expect(said, expected);
  });

  test('the conversation is named, so a follow-up may carry it on', () async {
    const expected = 'a-session';
    final claude = _Claude(says: [delta('hello'), finished()]);

    final answers =
        await askCounsel('hello?', shell: shellOf(claude)).toList();

    expect((answers.last as Answer).session, expected);
  });

  test('a fresh question and a resumed one are put differently', () async {
    const expected = (fresh: false, resumed: true, carried: 'an-old-session');
    late List<String> fresh;
    late List<String> resumed;
    Shell watching(void Function(List<String>) note) =>
        (String _, List<String> arguments, {String? workingDirectory}) async {
          note(arguments);
          return _Claude(says: [finished()]);
        };

    await askCounsel('a', shell: watching((a) => fresh = a)).drain<void>();
    await askCounsel(
      'a',
      resuming: 'an-old-session',
      shell: watching((a) => resumed = a),
    ).drain<void>();

    final actual = (
      fresh: fresh[1].contains('--resume'),
      resumed: resumed[1].contains('--resume'),
      carried: resumed.last,
    );

    expect(actual, expected);
  });

  test('the question and the directory go as arguments, never spliced',
      () async {
    const question = 'what of "; rm -rf /" then?';
    const expectedArguments = ['roac', question, knowledgeBase];
    late List<String> given;

    await askCounsel(
      question,
      shell: (String _, List<String> arguments, {String? workingDirectory}) async {
        given = arguments;
        return _Claude(says: [finished()]);
      },
    ).drain<void>();

    expect(given.sublist(2), expectedArguments);
  });

  test('a CLI that ends badly reports what it said, not an empty answer',
      () async {
    const expected = 'the model refused';
    final claude = _Claude(
      says: [finished(failed: true, result: expected)],
    );

    final counsel = await askCounsel('anything', shell: shellOf(claude)).last;

    expect(counsel, isA<Trouble>().having((t) => t.reason, 'reason', expected));
  });

  test('a CLI that stops without a last word reports its complaint', () async {
    const expected = 'claude: command not found';
    final claude = _Claude(says: const [], complains: '  $expected  ', ending: 127);

    final counsel = await askCounsel('anything', shell: shellOf(claude)).last;

    expect(counsel, isA<Trouble>().having((t) => t.reason, 'reason', expected));
  });

  test('a CLI that falls silent is killed, not left to burn', () async {
    const expected = (troubled: true, killed: true);
    final claude = _Claude(lingers: true);

    final counsel = await askCounsel(
      'anything',
      shell: shellOf(claude),
      silence: const Duration(milliseconds: 20),
    ).last;
    final actual = (troubled: counsel is Trouble, killed: claude.killed);

    expect(actual, expected);
  });

  test('letting go of the answer kills the CLI at once, not at its next word',
      () async {
    // A real CLI leaves long gaps between lines while it reads and thinks.
    // The kill must not wait on the next one — that is the whole point.
    const expected = (killed: true, waited: false);
    final saying = StreamController<List<int>>();
    final claude = _Claude.speaking(saying.stream);
    var spoke = false;

    final listening = askCounsel('anything', shell: shellOf(claude)).listen(
      (_) {},
    );
    saying.add(utf8.encode('${delta('one')}\n'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await listening.cancel();
    final actual = (killed: claude.killed, waited: spoke);
    saying.add(utf8.encode('${delta('two')}\n'));
    spoke = true;
    await saying.close();

    expect(actual, expected);
  });

  test('a shell that will not start is reported rather than swallowed',
      () async {
    final counsel = await askCounsel(
      'anything',
      shell: (String _, List<String> _, {String? workingDirectory}) async =>
          throw const ProcessException('/bin/zsh', [], 'no such shell'),
    ).last;

    expect(counsel, isA<Trouble>());
  });

  test('an empty question is refused without starting anything', () async {
    const expected = (troubled: true, started: false);
    var started = false;

    final counsel = await askCounsel(
      '   ',
      shell: (String _, List<String> _, {String? workingDirectory}) async {
        started = true;
        return _Claude();
      },
    ).last;
    final actual = (troubled: counsel is Trouble, started: started);

    expect(actual, expected);
  });
}
