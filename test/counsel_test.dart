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
  }) : _lines = says,
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
}) => jsonEncode({
  'type': 'result',
  'session_id': session,
  'subtype': failed ? 'error_during_execution' : 'success',
  'is_error': failed,
  'result': result,
});

/// Somewhere for the CLI to be run, which these tests never reach.
const _notes = '/somewhere/notes';

/// Reaps nothing. Every test but the ones about reaping itself has no
/// business spawning a real `taskkill` or `pkill`.
Future<void> _noReap(int _, {required bool onWindows}) async {}

void main() {
  Shell shellOf(_Claude claude) =>
      (
        String _,
        List<String> _, {
        String? workingDirectory,
        Map<String, String>? environment,
      }) async => claude;

  test(
    'the words arrive a piece at a time, each carrying all said so far',
    () async {
      const expected = ['The ', 'The policy ', 'The policy is here.'];
      final claude = _Claude(
        says: [delta('The '), delta('policy '), delta('is here.'), finished()],
      );

      final said =
          await askCounsel(
                'where?',
                notes: _notes,
                shell: shellOf(claude),
                reap: _noReap,
              )
              .where((counsel) => counsel is Answer)
              .cast<Answer>()
              .map((answer) => answer.words)
              .toList();

      expect(said, expected);
    },
  );

  test('the conversation is named, so a follow-up may carry it on', () async {
    const expected = 'a-session';
    final claude = _Claude(says: [delta('hello'), finished()]);

    final answers = await askCounsel(
      'hello?',
      notes: _notes,
      shell: shellOf(claude),
      reap: _noReap,
    ).toList();

    expect((answers.last as Answer).session, expected);
  });

  test('a fresh question and a resumed one are put differently', () async {
    const expected = (fresh: false, resumed: true, carried: 'an-old-session');
    late List<String> fresh;
    late List<String> resumed;
    Shell watching(void Function(List<String>) note) =>
        (
          String _,
          List<String> arguments, {
          String? workingDirectory,
          Map<String, String>? environment,
        }) async {
          note(arguments);
          return _Claude(says: [finished()]);
        };

    await askCounsel(
      'a',
      notes: _notes,
      shell: watching((a) => fresh = a),
      onWindows: false,
      reap: _noReap,
    ).drain<void>();
    await askCounsel(
      'a',
      notes: _notes,
      resuming: 'an-old-session',
      shell: watching((a) => resumed = a),
      onWindows: false,
      reap: _noReap,
    ).drain<void>();

    final at = resumed.indexOf('--resume');
    final actual = (
      fresh: fresh.contains('--resume'),
      resumed: resumed.contains('--resume'),
      carried: at < 0 ? '' : resumed[at + 1],
    );

    expect(actual, expected);
  });

  test(
    'the question and the directory go as arguments, never spliced',
    () async {
      const question = 'what of "; rm -rf /" then?';
      final expectedArguments = ['roac', question, _notes];
      late List<String> given;

      await askCounsel(
        question,
        notes: _notes,
        onWindows: false,
        reap: _noReap,
        shell:
            (
              String _,
              List<String> arguments, {
              String? workingDirectory,
              Map<String, String>? environment,
            }) async {
              given = arguments;
              return _Claude(says: [finished()]);
            },
      ).drain<void>();

      expect(given.sublist(2, 5), expectedArguments);
    },
  );

  group('which Claude config the CLI itself is given', () {
    test(
      'CLAUDE_CONFIG_DIR is set on the CLI, when Roäc is told one',
      () async {
        const expected = {'CLAUDE_CONFIG_DIR': '/Users/someone/.claude-work'};
        Map<String, String>? given;

        await askCounsel(
          'where?',
          notes: _notes,
          claudeConfig: '/Users/someone/.claude-work',
          reap: _noReap,
          shell:
              (
                String _,
                List<String> _, {
                String? workingDirectory,
                Map<String, String>? environment,
              }) async {
                given = environment;
                return _Claude(says: [finished()]);
              },
        ).drain<void>();

        expect(given, expected);
      },
    );

    test('nothing is set when Roäc was told no config at all', () async {
      const Map<String, String>? expected = null;
      Map<String, String>? given;

      await askCounsel(
        'where?',
        notes: _notes,
        reap: _noReap,
        shell:
            (
              String _,
              List<String> _, {
              String? workingDirectory,
              Map<String, String>? environment,
            }) async {
              given = environment;
              return _Claude(says: [finished()]);
            },
      ).drain<void>();

      expect(given, expected);
    });
  });

  group('the handoff hook, when the door is open', () {
    test('follows the Claude config Roäc was told', () async {
      const expected = [
        'Bash(printf:*)',
        'Bash(/Users/someone/.claude-work/hooks/handoff.sh:*)',
      ];
      final claude = _Claude(says: [finished()]);
      late List<String> given;

      await askCounsel(
        'where?',
        notes: _notes,
        claudeConfig: '/Users/someone/.claude-work',
        mayAct: true,
        onWindows: true,
        reap: _noReap,
        shell:
            (
              String _,
              List<String> arguments, {
              String? workingDirectory,
              Map<String, String>? environment,
            }) async {
              given = arguments;
              return claude;
            },
      ).drain<void>();
      final at = given.indexOf('--allowedTools');
      final actual = at < 0 ? '' : given[at + 1];

      expect(expected.every(actual.contains), true);
    });

    test('a hook path bearing a space reaches the CLI whole', () {
      const hook =
          r'C:\Users\someone\Library\Application Support\claude'
          r'\hooks\handoff.sh';
      const expected = true;

      final arguments = summonsFor(
        'where?',
        notes: _notes,
        onWindows: false,
        mayAct: true,
        hook: hook,
      ).arguments;
      final actual = arguments.any(
        (argument) => argument.contains('Bash($hook:*)'),
      );

      expect(actual, expected);
      // The command template itself never carries the hook path — it is
      // passed as its own argument, so a space in it cannot be split apart
      // by the shell before it reaches "${@:3}".
      expect(arguments[1].contains(hook), false);
    });
  });

  group('how the CLI is summoned, machine by machine', () {
    test('Windows is given the CLI itself, with no shell between', () {
      const expectedExecutable = 'claude';
      final expectedArguments = [
        '-p',
        'where?',
        '--add-dir',
        _notes,
        '--model',
        'sonnet',
        '--effort',
        'medium',
        '--disallowedTools',
        'Edit,MultiEdit,Write,NotebookEdit,Bash',
        '--output-format',
        'stream-json',
        '--verbose',
        '--include-partial-messages',
      ];

      final actual = summonsFor('where?', notes: _notes, onWindows: true);

      expect(actual.executable, expectedExecutable);
      expect(actual.arguments, expectedArguments);
    });

    test('elsewhere a login shell is given, and execs the CLI', () {
      const expected = (executable: '/bin/zsh', wears: 'roac', execs: true);

      final summons = summonsFor('where?', notes: _notes, onWindows: false);
      final actual = (
        executable: summons.executable,
        wears: summons.arguments[2],
        execs: summons.arguments[1].startsWith('exec claude'),
      );

      expect(actual, expected);
    });

    test('a resumed conversation is named on Windows too', () {
      const expected = ['--resume', 'an-old-session'];

      final arguments = summonsFor(
        'where?',
        notes: _notes,
        resuming: 'an-old-session',
        onWindows: true,
      ).arguments;
      final named = arguments.indexOf('--resume');
      final actual = named < 0
          ? const <String>[]
          : arguments.sublist(named, named + 2);

      expect(actual, expected);
    });

    test('a fresh question names no conversation on Windows', () {
      const expected = false;

      final actual = summonsFor(
        'where?',
        notes: _notes,
        onWindows: true,
      ).arguments.contains('--resume');

      expect(actual, expected);
    });

    test('the question is an argument on Windows, never spliced', () {
      const question = 'what of "; rm -rf /" then?';
      const expected = (carried: true, spliced: false);

      final arguments = summonsFor(
        question,
        notes: _notes,
        onWindows: true,
      ).arguments;
      final actual = (
        carried: arguments.contains(question),
        spliced: arguments.any(
          (argument) => argument != question && argument.contains('rm -rf'),
        ),
      );

      expect(actual, expected);
    });

    test('both machines ask for the same streaming flags', () {
      const expected = [
        '--output-format',
        'stream-json',
        '--verbose',
        '--include-partial-messages',
      ];

      final windows = summonsFor(
        'where?',
        notes: _notes,
        onWindows: true,
      ).arguments;
      final elsewhere = summonsFor(
        'where?',
        notes: _notes,
        onWindows: false,
      ).arguments;

      expect(windows.sublist(windows.length - expected.length), expected);
      expect(elsewhere.sublist(elsewhere.length - expected.length), expected);
    });

    test(
      'both machines keep the CLI to reading, whatever the config allows',
      () {
        const expected = [
          '--disallowedTools',
          'Edit,MultiEdit,Write,NotebookEdit,Bash',
        ];

        for (final onWindows in [true, false]) {
          final arguments = summonsFor(
            'where?',
            notes: _notes,
            onWindows: onWindows,
          ).arguments;
          final at = arguments.indexOf('--disallowedTools');
          final actual = at < 0
              ? const <String>[]
              : arguments.sublist(at, at + expected.length);

          expect(actual, expected, reason: 'onWindows: $onWindows');
        }
      },
    );

    test('the open door lets the CLI change what it reads, bounded to notes '
        'and the handoff hook', () {
      const expected = [
        '--permission-mode',
        'acceptEdits',
        '--allowedTools',
        'Edit,MultiEdit,Write,NotebookEdit,'
            'Bash(printf:*),Bash(/some/hook.sh:*)',
      ];

      for (final onWindows in [true, false]) {
        final arguments = summonsFor(
          'where?',
          notes: _notes,
          onWindows: onWindows,
          mayAct: true,
          hook: '/some/hook.sh',
        ).arguments;
        final at = arguments.indexOf('--permission-mode');
        final actual = at < 0
            ? const <String>[]
            : arguments.sublist(at, at + expected.length);

        expect(actual, expected, reason: 'onWindows: $onWindows');
        expect(
          arguments.contains('--disallowedTools'),
          false,
          reason: 'onWindows: $onWindows',
        );
      }
    });

    test('both machines are asked for the same model and effort', () {
      const expected = ['--model', 'sonnet', '--effort', 'medium'];

      for (final onWindows in [true, false]) {
        final arguments = summonsFor(
          'where?',
          notes: _notes,
          onWindows: onWindows,
        ).arguments;
        final at = arguments.indexOf('--model');
        final actual = at < 0
            ? const <String>[]
            : arguments.sublist(at, at + expected.length);

        expect(actual, expected, reason: 'onWindows: $onWindows');
      }
    });
  });

  test(
    'a CLI that ends badly reports what it said, not an empty answer',
    () async {
      const expected = 'the model refused';
      final claude = _Claude(says: [finished(failed: true, result: expected)]);

      final counsel = await askCounsel(
        'anything',
        notes: _notes,
        shell: shellOf(claude),
        reap: _noReap,
      ).last;

      expect(
        counsel,
        isA<Complaint>().having((t) => t.words, 'words', expected),
      );
    },
  );

  test('a CLI that stops without a last word reports its complaint', () async {
    const expected = 'claude: command not found';
    final claude = _Claude(
      says: const [],
      complains: '  $expected  ',
      ending: 127,
    );

    final counsel = await askCounsel(
      'anything',
      notes: _notes,
      shell: shellOf(claude),
      reap: _noReap,
    ).last;

    expect(counsel, isA<Complaint>().having((t) => t.words, 'words', expected));
  });

  test(
    'a CLI that fails and says nothing of why is not made to say something',
    () async {
      const expected = true;
      final claude = _Claude(says: [finished(failed: true, result: '   ')]);

      final counsel = await askCounsel(
        'anything',
        notes: _notes,
        shell: shellOf(claude),
        reap: _noReap,
      ).last;

      expect(counsel is Surrender, expected);
    },
  );

  test('a CLI that ends with no word at all is named by its ending', () async {
    const expected = 127;
    final claude = _Claude(says: const [], ending: expected);

    final counsel = await askCounsel(
      'anything',
      notes: _notes,
      shell: shellOf(claude),
      reap: _noReap,
    ).last;

    expect(
      counsel,
      isA<NoCounsel>().having((t) => t.ending, 'ending', expected),
    );
  });

  test('a CLI that falls silent is killed, not left to burn', () async {
    const expected = (troubled: true, killed: true);
    final claude = _Claude(lingers: true);

    final counsel = await askCounsel(
      'anything',
      notes: _notes,
      shell: shellOf(claude),
      silence: const Duration(milliseconds: 20),
      reap: _noReap,
    ).last;
    final actual = (troubled: counsel is Silence, killed: claude.killed);

    expect(actual, expected);
  });

  test(
    'letting go of the answer kills the CLI at once, not at its next word',
    () async {
      // A real CLI leaves long gaps between lines while it reads and thinks.
      // The kill must not wait on the next one — that is the whole point.
      const expected = (killed: true, waited: false);
      final saying = StreamController<List<int>>();
      final claude = _Claude.speaking(saying.stream);
      var spoke = false;

      final listening = askCounsel(
        'anything',
        notes: _notes,
        shell: shellOf(claude),
        reap: _noReap,
      ).listen((_) {});
      saying.add(utf8.encode('${delta('one')}\n'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await listening.cancel();
      final actual = (killed: claude.killed, waited: spoke);
      saying.add(utf8.encode('${delta('two')}\n'));
      spoke = true;
      await saying.close();

      expect(actual, expected);
    },
  );

  test(
    'a shell that will not start is reported rather than swallowed',
    () async {
      final counsel = await askCounsel(
        'anything',
        notes: _notes,
        reap: _noReap,
        shell:
            (
              String _,
              List<String> _, {
              String? workingDirectory,
              Map<String, String>? environment,
            }) async =>
                throw const ProcessException('/bin/zsh', [], 'no such shell'),
      ).last;

      expect(counsel, isA<Complaint>());
    },
  );

  test('an empty question is refused without starting anything', () async {
    const expected = (troubled: true, started: false);
    var started = false;

    final counsel = await askCounsel(
      '   ',
      notes: _notes,
      reap: _noReap,
      shell:
          (
            String _,
            List<String> _, {
            String? workingDirectory,
            Map<String, String>? environment,
          }) async {
            started = true;
            return _Claude();
          },
    ).last;
    final actual = (troubled: counsel is NoQuestion, started: started);

    expect(actual, expected);
  });

  group('what the CLI itself may have spawned', () {
    test(
      'is reaped, on the pid and machine the CLI was actually run on',
      () async {
        const expected = (pid: 1, onWindows: true);
        final claude = _Claude(says: [finished()]);
        int? reapedPid;
        bool? reapedOnWindows;

        await askCounsel(
          'anything',
          notes: _notes,
          onWindows: true,
          shell: shellOf(claude),
          reap: (pid, {required onWindows}) async {
            reapedPid = pid;
            reapedOnWindows = onWindows;
          },
        ).drain<void>();

        expect((pid: reapedPid, onWindows: reapedOnWindows), expected);
      },
    );

    test(
      'is reaped before the CLI itself is killed, not after, and only once',
      () async {
        const expected = (killed: true, killedAlready: false, calls: 1);
        final claude = _Claude(says: [finished()]);
        var killedAlready = false;
        var calls = 0;

        await askCounsel(
          'anything',
          notes: _notes,
          onWindows: false,
          shell: shellOf(claude),
          reap: (pid, {required onWindows}) async {
            calls++;
            killedAlready = claude.killed;
          },
        ).drain<void>();

        expect((
          killed: claude.killed,
          killedAlready: killedAlready,
          calls: calls,
        ), expected);
      },
    );

    test('is reaped on cancel too, not only once the CLI finishes', () async {
      const expected = (pid: 1, onWindows: false);
      final saying = StreamController<List<int>>();
      final claude = _Claude.speaking(saying.stream);
      int? reapedPid;
      bool? reapedOnWindows;

      final listening = askCounsel(
        'anything',
        notes: _notes,
        onWindows: false,
        shell: shellOf(claude),
        reap: (pid, {required onWindows}) async {
          reapedPid = pid;
          reapedOnWindows = onWindows;
        },
      ).listen((_) {});
      saying.add(utf8.encode('${delta('one')}\n'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await listening.cancel();
      await saying.close();

      expect((pid: reapedPid, onWindows: reapedOnWindows), expected);
    });
  });
}
