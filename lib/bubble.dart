import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'counsel.dart';
import 'l10n/words.dart';
import 'saying.dart';
import 'settings.dart';

/// How a link is followed — named so a test may stand in for the browser, in
/// the same shape as the shell and the counsel this app already stands in for.
typedef Opening = Future<bool> Function(Uri link);

/// How the bubble asks for more room: [more] pixels than it has, to show the
/// answer whole. Whoever grants it decides how much of that it can spare.
typedef Wanting = void Function(double more);

const Color _fill = Color(0xFF2E3440);
const Color _edge = Color(0xFF88C0D0);
const Color _ink = Color(0xFFECEFF4);
const Color _faint = Color(0xFF8894A6);
const Color _alarm = Color(0xFFD08770);

const double _cornerRadius = 16;
const double _edgeWidth = 2;
const double _padding = 12;

/// The speech bubble: what Roäc last said, and the field you ask it through.
class Bubble extends StatelessWidget {
  const Bubble({
    required this.counsel,
    required this.waiting,
    required this.asked,
    required this.onAsk,
    required this.onWanting,
    required this.onSettings,
    this.settings,
    this.opening = launchUrl,
    super.key,
  });

  /// What Roäc last said, or null while it has said nothing yet.
  final Counsel? counsel;

  /// What Roäc has been told, so the bubble may say plainly when the notes
  /// folder or a named Claude config has gone missing, and whether a trouble
  /// is worth pointing at the write toggle. Null only in a test that has no
  /// business with either.
  final Settings? settings;

  /// Whether Roäc is presently thinking.
  final bool waiting;

  /// The question [counsel] or [waiting] answers, so the reader sees what was
  /// asked beside what came back rather than the answer alone. Null before
  /// the first question of a fresh bubble.
  final String? asked;

  final ValueChanged<String> onAsk;

  /// Told when the answer has more to show than there is room for.
  final Wanting onWanting;

  /// Told when the gear beside the field is tapped.
  final VoidCallback onSettings;

  /// What follows a link the reader taps.
  final Opening opening;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(_padding),
      padding: const EdgeInsets.all(_padding),
      decoration: BoxDecoration(
        color: _fill,
        borderRadius: BorderRadius.circular(_cornerRadius),
        border: Border.all(color: _edge, width: _edgeWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Said(
              counsel: counsel,
              waiting: waiting,
              asked: asked,
              opening: opening,
              onWanting: onWanting,
              settings: settings,
            ),
          ),
          const SizedBox(height: _padding),
          Row(
            children: [
              Expanded(child: _Asking(onAsk: onAsk)),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(
                  Icons.settings_outlined,
                  color: _faint,
                  size: 18,
                ),
                tooltip: Words.of(context).settingsTitle,
                onPressed: onSettings,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What stands before anything has been asked: the plain invitation, unless
/// a folder Roäc was told about has gone missing since — the notes folder
/// first, since nothing can be answered without it, then a named Claude
/// config, which is optional but wrong if it names nowhere real.
String _invitation(Words tongue, Settings? settings) => switch (settings) {
  Settings(notesMissing: true) => tongue.notesMissing,
  Settings(claudeConfigMissing: true) => tongue.claudeConfigMissing,
  _ => tongue.invitation,
};

/// A trouble, in the reader's tongue.
///
/// A missing notes folder or Claude config is said plainly as that, in place
/// of whatever the trouble itself carries — not a guess: a working directory
/// that does not exist fails the CLI's own launch every time, so a trouble
/// arriving while either is missing is this, and naming the true cause beats
/// passing on the `ProcessException` it surfaces as.
///
/// Otherwise, a nudge toward the write toggle stands beneath it when Roäc
/// could not act and that toggle was off — this one genuinely is a guess,
/// since the CLI's own words are not read to confirm it, only a reminder of
/// where the door is, offered wherever a question might have wanted it open.
///
/// Null [settings] — a question answered before the first read has landed —
/// leans toward showing the write-toggle hint rather than not: wrongly
/// withholding it costs a reader the one nudge that might have explained
/// their trouble, where wrongly showing it costs nothing worse than an
/// unneeded suggestion.
String _troubled(Words tongue, Trouble trouble, Settings? settings) {
  if (settings?.notesMissing ?? false) return tongue.notesMissing;
  if (settings?.claudeConfigMissing ?? false) return tongue.claudeConfigMissing;
  final said = saidOfTrouble(tongue, trouble);
  if (settings?.mayAct ?? false) return said;
  return '$said\n\n${tongue.writeHint}';
}

/// What Roäc is saying: nothing yet, thinking, an answer, or a plain trouble.
///
/// An answer scrolls and may be selected rather than being cut, because it
/// carries exact values — a URL, a path, an identifier — that mean nothing
/// once truncated.
class _Said extends StatelessWidget {
  const _Said({
    required this.counsel,
    required this.waiting,
    required this.asked,
    required this.opening,
    required this.onWanting,
    required this.settings,
  });

  final Counsel? counsel;
  final bool waiting;
  final String? asked;
  final Opening opening;
  final Wanting onWanting;
  final Settings? settings;

  @override
  Widget build(BuildContext context) {
    final tongue = Words.of(context);
    final said = waiting
        ? Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: _padding),
              Text(tongue.thinking, style: const TextStyle(color: _faint)),
            ],
          )
        : switch (counsel) {
            null => Text(
              _invitation(tongue, settings),
              style: const TextStyle(color: _faint),
            ),
            Answer(:final words) => _Rendered(
              words: words,
              opening: opening,
              onWanting: onWanting,
            ),
            final Trouble trouble => _Plain(
              words: _troubled(tongue, trouble, settings),
              colour: _alarm,
            ),
          };
    final asked = this.asked;
    if (asked == null) return said;
    // The bubble's own Expanded already gives [said] the room it wants when
    // there is nothing above it; once [_Asked] takes a line of that room,
    // [said] needs its own Expanded to still claim what is left, inside the
    // Column that now stands between it and the bubble's.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Asked(asked),
        const SizedBox(height: _padding / 2),
        Expanded(child: said),
      ],
    );
  }
}

/// The question a shown answer, trouble, or "still thinking" belongs to.
///
/// Dimmer than what Roäc says himself, and quoted by a rule at its side
/// rather than by punctuation, so it reads as what was put to him rather than
/// as more of his own words.
class _Asked extends StatelessWidget {
  const _Asked(this.words);

  final String words;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: _padding * 2 / 3),
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: _edge, width: _edgeWidth),
        ),
      ),
      child: Text(
        words,
        style: const TextStyle(
          color: _faint,
          fontStyle: FontStyle.italic,
          height: 1.35,
        ),
      ),
    );
  }
}

/// An answer, drawn as the markdown the CLI writes rather than its source.
///
/// It arrives a word at a time, so it is rendered half-written — an unclosed
/// emphasis reads as its own characters until its closing pair arrives, which
/// is a moment's flicker rather than a broken page.
///
/// A link hides the address beneath its label, and an address is an exact
/// value that must stay reachable: tapping one opens it, and where it cannot
/// be opened the address goes to the clipboard rather than nowhere at all.
///
/// The view follows the words down as they arrive, so an answer still being
/// written does not appear to stop after its first three lines — unless the
/// reader has scrolled up, in which case they are reading, and are left be.
class _Rendered extends StatefulWidget {
  const _Rendered({
    required this.words,
    required this.opening,
    required this.onWanting,
  });

  final String words;
  final Opening opening;
  final Wanting onWanting;

  @override
  State<_Rendered> createState() => _RenderedState();
}

class _RenderedState extends State<_Rendered> {
  /// How near the end the view must be for the words to carry it along.
  static const _following = 40.0;

  /// The least shortfall worth asking to have made up.
  static const _byTheStep = 24.0;

  /// How long an aside stays before it gives the answer its room back.
  static const _aWhile = Duration(seconds: 6);

  final _view = ScrollController();

  String? _aside;
  Timer? _asideEnds;

  @override
  void initState() {
    super.initState();
    // An answer that arrives whole never grows, and so would never once be
    // measured. The room it wants is wanted from its first laying out.
    _reckonRoom(carryOn: false);
  }

  @override
  void didUpdateWidget(_Rendered old) {
    super.didUpdateWidget(old);
    // Measured on every rebuild, not only when words arrive. Room granted is
    // itself a rebuild, and an answer that still overruns after being given
    // some must be able to ask for the rest — tying the asking to the words
    // alone let it ask once and then fall silent, still cut off.
    //
    // Whether to carry the reader along is a different question, and asked
    // before the arriving words are laid out, so it still describes where
    // they stood when those words came: at the end, or up in the text.
    _reckonRoom(carryOn: widget.words.length > old.words.length && _atTheEnd);
  }

  /// Whether the reader stands at the end of what has arrived, and so would
  /// have the newest words carried to them rather than be pulled from where
  /// they were reading.
  bool get _atTheEnd =>
      !_view.hasClients ||
      _view.position.maxScrollExtent - _view.offset <= _following;

  @override
  void dispose() {
    _asideEnds?.cancel();
    _view.dispose();
    super.dispose();
  }

  /// Reckons the room the words want, after the frame — they have not been
  /// laid out yet, and the end of the view is not where it is about to be.
  /// Carries the reader down to it when [carryOn] says they were reading there.
  ///
  /// How far the words run past their room is exactly how much more room they
  /// want — no measuring of the text is needed, the scroll has measured it
  /// already. Asked for in steps, since a streamed answer lays out many times
  /// a second and a window resized that often shakes.
  void _reckonRoom({required bool carryOn}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_view.hasClients) return;
      final over = _view.position.maxScrollExtent;
      if (carryOn) _view.jumpTo(over);
      if (over >= _byTheStep) widget.onWanting(over);
    });
  }

  /// Opens [href], and keeps it reachable by other means if it will not open.
  Future<void> _open(String? href) async {
    if (href == null) return;
    final link = Uri.tryParse(href);
    if (link != null && await widget.opening(link)) return;
    await Clipboard.setData(ClipboardData(text: href));
    // The address is not lost — it is on the clipboard — but a reader told
    // nothing would never know that. Said in their own tongue, which is why
    // it is read here and not held as a constant.
    if (!mounted) return;
    _sayAside(Words.of(context).linkCopied);
  }

  /// Says something beneath the answer for a moment. The answer gives up the
  /// room rather than being covered by it: a note that hides the very line it
  /// is about would be worse than the silence it replaced.
  void _sayAside(String words) {
    if (!mounted) return;
    setState(() => _aside = words);
    _asideEnds?.cancel();
    _asideEnds = Timer(_aWhile, () {
      if (mounted) setState(() => _aside = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final aside = _aside;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _answer()),
        if (aside != null) ...[
          const SizedBox(height: 4),
          Text(aside, style: const TextStyle(color: _alarm)),
        ],
      ],
    );
  }

  Widget _answer() {
    return Markdown(
      controller: _view,
      data: widget.words,
      selectable: true,
      padding: EdgeInsets.zero,
      onTapLink: (_, href, _) => unawaited(_open(href)),
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(color: _ink, height: 1.4),
        listBullet: const TextStyle(color: _ink, height: 1.4),
        a: const TextStyle(color: _edge, decoration: TextDecoration.underline),
        code: const TextStyle(color: _edge, fontFamily: 'monospace'),
        codeblockDecoration: const BoxDecoration(color: Color(0xFF3B4252)),
        blockquoteDecoration: const BoxDecoration(color: Color(0xFF3B4252)),
      ),
    );
  }
}

/// Words that are not Roäc's own — a complaint from the CLI, shown as it came.
class _Plain extends StatelessWidget {
  const _Plain({required this.words, required this.colour});

  final String words;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SelectableText(
        words,
        style: TextStyle(color: colour, height: 1.4),
      ),
    );
  }
}

/// The field the question is put through.
///
/// Empties itself once a question is put — it has already been asked, and is
/// on its way into the bubble above; keeping it there would only leave the
/// reader to clear it themselves before the next one.
class _Asking extends StatefulWidget {
  const _Asking({required this.onAsk});

  final ValueChanged<String> onAsk;

  @override
  State<_Asking> createState() => _AskingState();
}

class _AskingState extends State<_Asking> {
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  void _submit(String question) {
    widget.onAsk(question);
    _typed.clear();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _typed,
      autofocus: true,
      style: const TextStyle(color: _ink),
      cursorColor: _edge,
      decoration: InputDecoration(
        isDense: true,
        hintText: Words.of(context).askHint,
        hintStyle: const TextStyle(color: _faint),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: _faint),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: _edge),
        ),
      ),
      onSubmitted: _submit,
    );
  }
}
