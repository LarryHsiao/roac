import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:roac/counsel.dart';

/// A stand-in for the CLI, so no test ever reaches the real shell.
class _Claude implements Process {
  _Claude({
    this.said = '',
    this.complained = '',
    this.ending = 0,
    this.lingers = false,
  });

  final String said;
  final String complained;
  final int ending;

  /// Whether it never finishes of its own accord, so the patience runs out.
  final bool lingers;

  bool killed = false;

  @override
  Stream<List<int>> get stdout => Stream.value(utf8.encode(said));

  @override
  Stream<List<int>> get stderr => Stream.value(utf8.encode(complained));

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

void main() {
  Shell shellOf(_Claude claude) =>
      (String _, List<String> _, {String? workingDirectory}) async => claude;

  test('an answer comes back with its surrounding blank space trimmed',
      () async {
    const expected = 'https://example.test/privacy-policy.html';

    final counsel = await askCounsel(
      'where is the policy?',
      shell: shellOf(_Claude(said: '  $expected\n\n')),
    );

    expect(counsel, isA<Answer>().having((a) => a.words, 'words', expected));
  });

  test('the CLI runs inside the knowledge base, its arguments never spliced',
      () async {
    const question = 'what of "; rm -rf /" then?';
    const expectedArguments = [
      '-lc',
      r'exec claude -p "$1" --add-dir "$2"',
      'roac',
      question,
      knowledgeBase,
    ];
    const expectedDirectory = knowledgeBase;
    late List<String> given;
    String? ranIn;

    await askCounsel(
      question,
      shell: (String _, List<String> arguments, {String? workingDirectory}) async {
        given = arguments;
        ranIn = workingDirectory;
        return _Claude(said: 'nothing untoward');
      },
    );

    expect(given, expectedArguments);
    expect(ranIn, expectedDirectory);
  });

  test('a failing CLI reports its own complaint', () async {
    const expected = 'claude: command not found';

    final counsel = await askCounsel(
      'anything',
      shell: shellOf(_Claude(complained: '  $expected  ', ending: 127)),
    );

    expect(counsel, isA<Trouble>().having((t) => t.reason, 'reason', expected));
  });

  test('a silent CLI is reported rather than shown as an empty answer',
      () async {
    final counsel = await askCounsel(
      'anything',
      shell: shellOf(_Claude(said: '   ')),
    );

    expect(counsel, isA<Trouble>());
  });

  test('a CLI that outlives the patience is killed, not left to burn',
      () async {
    const expected = (troubled: true, killed: true);
    final claude = _Claude(lingers: true);

    final counsel = await askCounsel(
      'anything',
      shell: shellOf(claude),
      patience: const Duration(milliseconds: 20),
    );
    final actual = (troubled: counsel is Trouble, killed: claude.killed);

    expect(actual, expected);
  });

  test('a shell that will not start is reported rather than swallowed',
      () async {
    final counsel = await askCounsel(
      'anything',
      shell: (String _, List<String> _, {String? workingDirectory}) async =>
          throw const ProcessException('/bin/zsh', [], 'no such shell'),
    );

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
    );
    final actual = (troubled: counsel is Trouble, started: started);

    expect(actual, expected);
  });
}
