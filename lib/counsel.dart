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

/// How long Roäc waits on the CLI's own process-bookkeeping — for a finished
/// CLI to be reaped, or for [Reap] to reach what the CLI itself spawned —
/// before moving on regardless.
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

/// The flags that keep the CLI to reading and answering, whatever the config
/// it is pointed at would otherwise let it do. A note is not something Roäc
/// trusts: it may carry an instruction meant for the CLI rather than a fact
/// meant for the reader, and the CLI has no way to tell those apart on its
/// own. This is what makes "Roäc only reads" true regardless — the door
/// [_mayAct] opens is never the default; a person opens it on purpose.
const _readOnly = [
  '--disallowedTools',
  'Edit,MultiEdit,Write,NotebookEdit,Bash',
];

/// The flags that let the CLI change what it reads, once a person has said
/// so through the settings panel. `acceptEdits` accepts a file write without
/// asking, but only inside the working directory `askCounsel` already sets
/// to the notes folder — a path outside it falls to a permission prompt
/// nothing here can answer, which is a denial, for the three file tools
/// named here. Bash is narrowed to two commands rather than closed outright
/// — `printf`, to pipe a body in, and [hook] itself — but that narrowing is
/// by command name, not by what the command then does with a shell's own
/// redirection: `printf` itself writes nowhere, yet the same permission that
/// allows the `/handoff` skill's `printf … | hook` also allows any other
/// `printf` invocation the CLI is asked to run, redirect included. The
/// working-directory bound above holds for edits; it does not reach here.
List<String> _mayAct(String hook) => [
  '--permission-mode',
  'acceptEdits',
  '--allowedTools',
  'Edit,MultiEdit,Write,NotebookEdit,Bash(printf:*),Bash($hook:*)',
];

/// The model Roäc asks the CLI to answer with, and how hard to think before
/// answering — named rather than left to whatever a config directory would
/// otherwise default to, so a question costs the same and reads the same
/// regardless of which machine or which config it is asked from.
const _model = ['--model', 'sonnet', '--effort', 'medium'];

/// The one command run on a machine that needs a shell. The question and the
/// notes travel as `$1`/`$2`, exactly as [Summons]'s own doc names; every
/// flag after them travels as `"${@:3}"`, which — kept inside its own quotes
/// — expands to each flag [summonsFor] built as its own word, the same way
/// `"$1"`/`"$2"` keep the question and the notes whole. Flags are never
/// spliced into this string, so neither [_readOnly] nor [_mayAct] can widen
/// or narrow what the CLI is allowed by a quoting mistake.
const _said = 'exec $_cli -p "\$1" --add-dir "\$2" "\${@:3}"';

/// How a command is started — named so a test may stand in for the real shell.
typedef Shell =
    Future<Process> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
      Map<String, String>? environment,
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
///
/// [claudeConfig] names a config directory for the CLI itself to use, for a
/// machine that keeps more than one — set as `CLAUDE_CONFIG_DIR` on the CLI's
/// own process rather than Roäc's, so it never leaks into anything else this
/// app might one day run. Left alone when null: the CLI then falls back on
/// whichever config it would have used had Roäc never asked.
///
/// [mayAct] opens the door [_mayAct] describes — off by default, and only
/// ever on because a person turned it on in the settings panel. [handoffHook]
/// names the `/handoff` skill's own hook script to allow through Bash when
/// the door is open; left alone, it is derived from [claudeConfig] — the same
/// config directory either way, so the skill and the hook it calls never
/// disagree — falling back to `~/.claude` when no config was named, which is
/// where the CLI's own default config lives.
///
/// The CLI is free to shell out for a tool call of its own; killing it alone
/// would orphan that rather than end it. [reap] is asked to reach for
/// whatever it spawned, every time it is killed — see [_reap] for how.
Stream<Counsel> askCounsel(
  String question, {
  required String notes,
  String? resuming,
  Shell shell = Process.start,
  Duration silence = _silence,
  bool? onWindows,
  String? claudeConfig,
  bool mayAct = false,
  String? handoffHook,
  Reap reap = _reap,
}) {
  final told = StreamController<Counsel>();
  final windows = onWindows ?? Platform.isWindows;
  Process? claude;
  // Reaps whatever the CLI spawned before ending the CLI itself — the other
  // order would let its children be reparented first, past finding. Cleared
  // first so a second call — closing this controller cancels its own
  // subscription, which asks to let go again — finds nothing left to do,
  // rather than asking `reap` and `kill` to run twice over.
  //
  // Bounded like every other wait on the CLI's own process-bookkeeping in
  // this file: `reap` shells out to the OS, and a machine where that hangs
  // must not hold the answer open for ever either.
  Future<void> letGo() async {
    final dying = claude;
    if (dying == null) return;
    claude = null;
    await reap(
      dying.pid,
      onWindows: windows,
    ).timeout(_reaping, onTimeout: () {});
    dying.kill();
  }

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
        onWindows: windows,
        mayAct: mayAct,
        hook: handoffHook ?? _handoffHookFor(claudeConfig),
      );
      claude = await shell(
        summons.executable,
        summons.arguments,
        workingDirectory: notes,
        environment: claudeConfig == null
            ? null
            : {'CLAUDE_CONFIG_DIR': claudeConfig},
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
      await letGo();
      if (!told.isClosed) await told.close();
    }
  };
  // Killed the moment the listener lets go, rather than whenever the CLI next
  // happens to speak. Cancelling a subscription does not interrupt a read
  // already in progress, so waiting for the generator to notice could mean
  // waiting out the whole silence — with the CLI thinking on, unheard.
  told.onCancel = letGo;
  return told.stream;
}

/// Says [counsel] on, unless nobody is listening for it any longer.
void _say(StreamController<Counsel> told, Counsel counsel) {
  if (!told.isClosed) told.add(counsel);
}

/// How Roäc reaches for whatever the CLI itself may have spawned — named so
/// a test may stand in for the real process table, the same seam [Shell]
/// gives the real shell.
typedef Reap = Future<void> Function(int pid, {required bool onWindows});

/// Best-effort only: a machine whose PATH lacks `taskkill`/`pkill` loses only
/// this extra reach, since [pid] itself is still killed by the caller
/// regardless of what happens here. Reaches one level deep — the CLI's own
/// direct children — not their children in turn.
Future<void> _reap(int pid, {required bool onWindows}) async {
  try {
    if (onWindows) {
      await Process.run('taskkill', ['/PID', '$pid', '/T', '/F']);
    } else {
      await Process.run('pkill', ['-TERM', '-P', '$pid']);
    }
  } catch (_) {
    // Swallowed on purpose — see the doc comment above.
  }
}

/// What to run, and what to hand it.
typedef Summons = ({String executable, List<String> arguments});

/// Where the `/handoff` mailbox's hook lives, so a note may be let post to
/// it once [mayAct] is open. Follows [claudeConfig] — the same config
/// directory the CLI itself is pointed at, so the skill and the hook it
/// calls never disagree — falling back to `~/.claude`, the CLI's own
/// default, when nothing names one.
String _handoffHookFor(String? claudeConfig) {
  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
  return '${claudeConfig ?? '$home/.claude'}/hooks/handoff.sh';
}

/// How [question] is put on this machine, carrying [resuming] where a
/// conversation is being taken up again, and open to change what it reads —
/// bounded to [notes] and to the `/handoff` mailbox at [hook] — wherever
/// [mayAct] says so.
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
/// back the same handle Windows gets for nothing — see [_said]. `$0` is the
/// name the shell wears; the question and [notes] follow it, then every flag
/// this machine and [mayAct] call for.
///
/// Neither form ever splices. The question is an argument in both, and so is
/// every flag, so nothing any of them contain — a quote, a semicolon, an
/// `rm -rf` — can change what runs.
Summons summonsFor(
  String question, {
  required String notes,
  String? resuming,
  required bool onWindows,
  bool mayAct = false,
  String hook = '',
}) {
  final flags = [
    if (resuming != null) ...['--resume', resuming],
    ..._model,
    ...(mayAct ? _mayAct(hook) : _readOnly),
    ..._streaming,
  ];
  if (onWindows) {
    return (
      executable: _cli,
      arguments: ['-p', question, '--add-dir', notes, ...flags],
    );
  }
  return (
    executable: '/bin/zsh',
    arguments: ['-lc', _said, 'roac', question, notes, ...flags],
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
