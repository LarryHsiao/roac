import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// How long Roäc will wait on a silent CLI before giving up on it.
///
/// Measured between one line of the CLI's stream and the next — not between
/// one word and the next, since a CLI reading files says plenty that carries
/// no words — and not across the whole answer, because cutting a long answer
/// off at a total would punish exactly the questions worth asking.
const _silence = Duration(seconds: 90);

/// How long to wait for a finished CLI to be reaped before naming it lost.
const _reaping = Duration(seconds: 5);

/// The name the CLI answers to. Found on the PATH rather than written down,
/// since where it is installed is the machine's business and not this file's.
const _cli = 'claude';

/// The flags that make the CLI speak as it thinks rather than all at once.
const _streaming = [
  '--output-format',
  'stream-json',
  '--verbose',
  '--include-partial-messages',
];

/// The same flags as one line, for the shell that takes a command rather than
/// a list. Written from [_streaming] so the two cannot drift apart.
final _streamingSaid = _streaming.join(' ');

/// A question put afresh, and one put to a conversation already begun.
final _fresh = 'exec $_cli -p "\$1" --add-dir "\$2" $_streamingSaid';
final _again =
    'exec $_cli -p "\$1" --add-dir "\$2" --resume "\$3" $_streamingSaid';

/// How a command is started — named so a test may stand in for the real shell.
typedef Shell =
    Future<Process> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });

/// What Roäc came back with.
@immutable
sealed class Counsel {
  const Counsel();
}

/// What Roäc has said so far. The words grow as they arrive, and [session]
/// names the conversation they belong to so that a follow-up may resume it.
final class Answer extends Counsel {
  const Answer(this.words, {this.session});

  final String words;
  final String? session;
}

/// Why Roäc could not answer — said plainly rather than swallowed.
///
/// What went wrong is named here; the sentence that says it is written where
/// a reader's tongue is known. A file that talks to a subprocess has no
/// business composing English.
sealed class Trouble extends Counsel {
  const Trouble();
}

/// Nothing was asked.
final class NoQuestion extends Trouble {
  const NoQuestion();
}

/// The CLI said nothing for so long that it was let go.
final class Silence extends Trouble {
  const Silence();
}

/// The CLI stopped without a last word and complained of nothing, leaving
/// only the code it [ending] with to go on.
final class NoCounsel extends Trouble {
  const NoCounsel(this.ending);

  final int ending;
}

/// The CLI reported a failure and said nothing of what it was.
final class Surrender extends Trouble {
  const Surrender();
}

/// Something the CLI or the shell itself said. Passed on in its own words:
/// they are not Roäc's to translate.
final class Complaint extends Trouble {
  const Complaint(this.words);

  final String words;
}

/// Puts [question] to the Claude Code CLI, which searches and reads the
/// knowledge base locally, and yields the answer as it arrives.
///
/// Pass [resuming] the session of an earlier answer to carry that conversation
/// on, so a follow-up needs no repeating of what came before.
///
/// How the CLI is reached differs by machine — [summonsFor] holds that
/// reasoning — but on every machine the question, the directory and the
/// session travel as arguments rather than spliced into a command, so nothing
/// they happen to contain can change what runs; and on every machine the
/// process held here is the CLI itself, so letting go of this stream kills
/// the thing that thinks.
///
/// It is run *inside* the knowledge base, not merely granted it. A windowed
/// app's working directory is the filesystem root, and `--add-dir` only widens
/// what the CLI may read — it does not tell it where to look. Rooted at `/`
/// the search finds nothing; rooted at the knowledge base it finds the note.
///
/// [onWindows] is the machine to summon for, and is asked of the platform when
/// it is not named. It is a parameter so that either summons may be exercised
/// from either host: a test that could only run on the machine it was written
/// on would leave the other branch unwatched.
Stream<Counsel> askCounsel(
  String question, {
  required String notes,
  String? resuming,
  Shell shell = Process.start,
  Duration silence = _silence,
  bool? onWindows,
}) {
  final told = StreamController<Counsel>();
  Process? claude;
  told.onListen = () async {
    if (question.trim().isEmpty) {
      told.add(const NoQuestion());
      await told.close();
      return;
    }
    try {
      final summons = summonsFor(
        question,
        notes: notes,
        resuming: resuming,
        onWindows: onWindows ?? Platform.isWindows,
      );
      claude = await shell(
        summons.executable,
        summons.arguments,
        workingDirectory: notes,
      );
      await for (final counsel in _listenTo(claude!, silence)) {
        if (told.isClosed) return;
        told.add(counsel);
      }
    } on TimeoutException {
      _say(told, const Silence());
    } catch (trouble) {
      _say(told, Complaint('$trouble'));
    } finally {
      claude?.kill();
      if (!told.isClosed) await told.close();
    }
  };
  // Killed the moment the listener lets go, rather than whenever the CLI next
  // happens to speak. Cancelling a subscription does not interrupt a read
  // already in progress, so waiting for the generator to notice could mean
  // waiting out the whole silence — with the CLI thinking on, unheard.
  told.onCancel = () => claude?.kill();
  return told.stream;
}

/// Says [counsel] on, unless nobody is listening for it any longer.
void _say(StreamController<Counsel> told, Counsel counsel) {
  if (!told.isClosed) told.add(counsel);
}

/// What to run, and what to hand it.
typedef Summons = ({String executable, List<String> arguments});

/// How [question] is put on this machine, carrying [resuming] where a
/// conversation is being taken up again.
///
/// **Windows is given no shell.** A windowed app there inherits the whole of
/// the user's PATH from the registry, and inheriting almost none of it is the
/// only reason a shell is used at all. Worse, Windows has no `exec`: a
/// `cmd /c claude ...` would leave `cmd` holding the handle, so killing it
/// would reap the wrapper and leave the CLI thinking on — unheard, unreaped,
/// and once for every question anybody walked away from. Summoned directly,
/// the handle is the CLI itself and letting go of it kills the thing that
/// thinks. This is not an oversight to be tidied into a shell later; the
/// shell is what would break it.
///
/// **Elsewhere a login shell is needed**, because a windowed app inherits
/// almost none of the user's PATH and would not find the CLI at all. It
/// `exec`s the CLI so that the CLI takes the shell's own place, which buys
/// back the same handle Windows gets for nothing. `$0` is the name the shell
/// wears; the question, [notes] and the session follow it.
///
/// Neither form ever splices. The question is an argument in both, so nothing
/// it contains — a quote, a semicolon, an `rm -rf` — can change what runs.
Summons summonsFor(
  String question, {
  required String notes,
  String? resuming,
  required bool onWindows,
}) {
  if (onWindows) {
    return (
      executable: _cli,
      arguments: [
        '-p',
        question,
        '--add-dir',
        notes,
        if (resuming != null) ...['--resume', resuming],
        ..._streaming,
      ],
    );
  }
  return (
    executable: '/bin/zsh',
    arguments: [
      '-lc',
      resuming == null ? _fresh : _again,
      'roac',
      question,
      notes,
      ?resuming,
    ],
  );
}

/// Reads what the CLI says, and says it on as it comes.
///
/// Its complaints are drained from the moment it starts: a CLI whose output
/// filled the buffer while nobody was reading would never finish at all.
Stream<Counsel> _listenTo(Process claude, Duration silence) async* {
  // Its complaint is worth having but never worth failing over: a CLI is free
  // to write bytes that are not text, and that must not become a stray error
  // in a corner where nothing can turn it into something the user reads.
  final complaining = claude.stderr
      .transform(utf8.decoder)
      .join()
      .catchError((Object _) => '');
  final said = StringBuffer();
  String? session;
  var ended = false;
  final lines = claude.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .timeout(silence);
  await for (final line in lines) {
    final told = _read(line);
    if (told == null) continue;
    session ??= told.session;
    if (told.words != null) {
      said.write(told.words);
      yield Answer('$said', session: session);
    }
    if (!told.ended) continue;
    ended = true;
    final failed = told.failed;
    if (failed != null) {
      yield failed.isEmpty ? const Surrender() : Complaint(failed);
    }
    return;
  }
  if (!ended) yield await _wentWrong(claude, complaining);
}

/// Why a CLI that stopped without a final word stopped.
Future<Trouble> _wentWrong(Process claude, Future<String> complaining) async {
  final complaint = (await complaining).trim();
  if (complaint.isNotEmpty) return Complaint(complaint);
  // Bounded like every other wait here: a process whose output has ended but
  // which has not yet been reaped must not hold the answer open for ever.
  final ending = await claude.exitCode.timeout(_reaping, onTimeout: () => -1);
  return NoCounsel(ending);
}

/// Reads one line of the CLI's stream for the little Roäc needs of it: the
/// conversation it belongs to, any words that arrived with it, and whether it
/// was the last — with the reason, where it ended badly.
///
/// A line that is not the JSON we expect is passed over rather than treated as
/// a failure: the CLI is entitled to say things this reader was not written for.
({String? session, String? words, bool ended, String? failed})? _read(
  String line,
) {
  final Object? told;
  try {
    told = jsonDecode(line);
  } catch (_) {
    return null;
  }
  if (told is! Map) return null;
  final session = told['session_id'] as String?;
  if (told['type'] == 'result') {
    final failed = told['is_error'] == true || told['subtype'] != 'success';
    return (
      session: session,
      words: null,
      ended: true,
      // Empty rather than null when it failed but named nothing: null means it
      // did not fail at all, and the two must not be read as one.
      failed: failed ? '${told['result'] ?? ''}'.trim() : null,
    );
  }
  return (
    session: session,
    words: _textIn(told['event']),
    ended: false,
    failed: null,
  );
}

/// The text a stream event carried, if it carried any.
String? _textIn(Object? event) {
  if (event is! Map) return null;
  final delta = event['delta'];
  if (delta is! Map || delta['type'] != 'text_delta') return null;
  return delta['text'] as String?;
}
