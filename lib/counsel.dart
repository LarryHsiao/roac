import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// The knowledge base Roäc answers from. Its contents are read locally by the
/// Claude Code CLI and never leave the machine.
const knowledgeBase = '/Users/larryhsiao/Minerva';

/// How long Roäc will think before giving up — and letting the CLI go with it.
const _patience = Duration(minutes: 2);

/// How a command is started — named so a test may stand in for the real shell.
///
/// Started rather than run to its end, so that a question which outlives the
/// patience can have its process killed. A CLI left orphaned would go on
/// spending time and API calls on an answer nobody will ever read.
typedef Shell = Future<Process> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
});

/// What Roäc came back with.
@immutable
sealed class Counsel {
  const Counsel();
}

/// What Roäc found in the knowledge base.
final class Answer extends Counsel {
  const Answer(this.words);

  final String words;
}

/// Why Roäc could not answer — said plainly rather than swallowed.
final class Trouble extends Counsel {
  const Trouble(this.reason);

  final String reason;
}

/// Puts [question] to the Claude Code CLI, which searches and reads the
/// knowledge base locally and answers from it.
///
/// The CLI is reached through a login shell because a windowed app inherits
/// almost none of the user's PATH, and the question and the directory are
/// passed as arguments rather than spliced into the command, so nothing a
/// question happens to contain can change what runs. The shell `exec`s the
/// CLI so that it takes the shell's own place: the process this holds is then
/// the CLI itself, and killing it kills the thing that is thinking.
///
/// It is run *inside* the knowledge base, not merely granted it. A windowed
/// app's working directory is the filesystem root, and `--add-dir` only widens
/// what the CLI may read — it does not tell it where to look. Rooted at `/`
/// the search finds nothing; rooted at the knowledge base it finds the note.
Future<Counsel> askCounsel(
  String question, {
  Shell shell = Process.start,
  Duration patience = _patience,
}) async {
  if (question.trim().isEmpty) {
    return const Trouble('Ask me something.');
  }
  try {
    final claude = await shell(
      '/bin/zsh',
      [
        '-lc',
        r'exec claude -p "$1" --add-dir "$2"',
        'roac',
        question,
        knowledgeBase,
      ],
      workingDirectory: knowledgeBase,
    );
    return _listenTo(claude, patience);
  } catch (trouble) {
    return Trouble('$trouble');
  }
}

/// Waits on [claude] for [patience], then reads what it said.
///
/// Both pipes are drained from the moment it starts: a CLI whose output filled
/// the buffer while nobody was reading would never finish at all.
Future<Counsel> _listenTo(Process claude, Duration patience) async {
  final saying = claude.stdout.transform(utf8.decoder).join();
  final complaining = claude.stderr.transform(utf8.decoder).join();
  try {
    return await _hearOut(claude, saying, complaining).timeout(patience);
  } on TimeoutException {
    // The patience covers the pipes and not the exit alone: a process the CLI
    // spawned may hold them open long after the CLI itself has finished, and
    // waiting on that would put the whole point of the patience back at risk.
    claude.kill();
    saying.ignore();
    complaining.ignore();
    return const Trouble('Roäc thought too long, and was let go.');
  }
}

/// Waits for the CLI to finish, and for everything it said to arrive.
Future<Counsel> _hearOut(
  Process claude,
  Future<String> saying,
  Future<String> complaining,
) async {
  final ending = await claude.exitCode;
  return _weigh(ending, (await saying).trim(), (await complaining).trim());
}

/// Reads the CLI's ending as either an answer or a plain trouble.
Counsel _weigh(int ending, String said, String complained) {
  if (ending != 0) {
    return Trouble(
      complained.isEmpty
          ? 'Roäc found no counsel (the CLI exited $ending).'
          : complained,
    );
  }
  if (said.isEmpty) {
    return const Trouble('Roäc came back with nothing to say.');
  }
  return Answer(said);
}
