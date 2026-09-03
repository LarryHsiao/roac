import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// The knowledge base Roäc answers from. Its contents are read locally by the
/// Claude Code CLI and never leave the machine.
const knowledgeBase = '/Users/larryhsiao/Minerva';

/// How long Roäc will wait on a silent CLI before giving up on it.
///
/// Measured between one line of the CLI's stream and the next — not between
/// one word and the next, since a CLI reading files says plenty that carries
/// no words — and not across the whole answer, because cutting a long answer
/// off at a total would punish exactly the questions worth asking.
const _silence = Duration(seconds: 90);

/// How long to wait for a finished CLI to be reaped before naming it lost.
const _reaping = Duration(seconds: 5);

/// The flags that make the CLI speak as it thinks rather than all at once.
const _streaming =
    '--output-format stream-json --verbose --include-partial-messages';

/// A question put afresh, and one put to a conversation already begun.
const _fresh = 'exec claude -p "\$1" --add-dir "\$2" $_streaming';
const _again =
    'exec claude -p "\$1" --add-dir "\$2" --resume "\$3" $_streaming';

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
final class Trouble extends Counsel {
  const Trouble(this.reason);

  final String reason;
}

/// Puts [question] to the Claude Code CLI, which searches and reads the
/// knowledge base locally, and yields the answer as it arrives.
///
/// Pass [resuming] the session of an earlier answer to carry that conversation
/// on, so a follow-up needs no repeating of what came before.
///
/// The CLI is reached through a login shell because a windowed app inherits
/// almost none of the user's PATH, and the question, the directory and the
/// session are passed as arguments rather than spliced into the command, so
/// nothing they happen to contain can change what runs. The shell `exec`s the
/// CLI so that it takes the shell's own place: the process held here is then
/// the CLI itself, and letting go of this stream kills the thing that thinks.
///
/// It is run *inside* the knowledge base, not merely granted it. A windowed
/// app's working directory is the filesystem root, and `--add-dir` only widens
/// what the CLI may read — it does not tell it where to look. Rooted at `/`
/// the search finds nothing; rooted at the knowledge base it finds the note.
Stream<Counsel> askCounsel(
  String question, {
  String? resuming,
  Shell shell = Process.start,
  Duration silence = _silence,
}) {
  final told = StreamController<Counsel>();
  Process? claude;
  told.onListen = () async {
    if (question.trim().isEmpty) {
      told.add(const Trouble('Ask me something.'));
      await told.close();
      return;
    }
    try {
      claude = await shell(
        '/bin/zsh',
        _command(question, resuming),
        workingDirectory: knowledgeBase,
      );
      await for (final counsel in _listenTo(claude!, silence)) {
        if (told.isClosed) return;
        told.add(counsel);
      }
    } on TimeoutException {
      _say(told, const Trouble('Roäc fell silent, and was let go.'));
    } catch (trouble) {
      _say(told, Trouble('$trouble'));
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

/// The shell's argument list. `$0` is the name the shell wears; the rest are
/// the question, the knowledge base, and the conversation being carried on.
List<String> _command(String question, String? resuming) => [
  '-lc',
  resuming == null ? _fresh : _again,
  'roac',
  question,
  knowledgeBase,
  ?resuming,
];

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
    if (told.failed != null) yield Trouble(told.failed!);
    return;
  }
  if (!ended) yield Trouble(await _wentWrong(claude, complaining));
}

/// Why a CLI that stopped without a final word stopped.
Future<String> _wentWrong(Process claude, Future<String> complaining) async {
  final complaint = (await complaining).trim();
  if (complaint.isNotEmpty) return complaint;
  // Bounded like every other wait here: a process whose output has ended but
  // which has not yet been reaped must not hold the answer open for ever.
  final ending = await claude.exitCode.timeout(_reaping, onTimeout: () => -1);
  return 'Roäc found no counsel (the CLI exited $ending).';
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
      failed: failed ? '${told['result'] ?? 'The CLI gave up.'}' : null,
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
