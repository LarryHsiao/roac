import 'package:flutter/material.dart';

import 'l10n/words.dart';
import 'palette.dart';
import 'settings.dart';
import 'settings_panel.dart';

const double _padding = 12;
const double _cornerRadius = 16;
const double _edgeWidth = 2;
const double _saidSize = 13;
const double _hintSize = 11;
const double _dotGap = 5;
const double _gap = 8;
const double _dot = 8;

enum _Step { cli, notes, ready }

/// The first launch's three steps: find the CLI, name the notes, begin.
class WelcomePanel extends StatefulWidget {
  const WelcomePanel({
    required this.settings,
    required this.findCli,
    required this.onNotes,
    required this.onDone,
    this.chooseFolder = fromTheFilesystem,
    super.key,
  });

  /// What Roäc has been told, as it stands now.
  final Settings settings;

  /// Whether the CLI Roäc answers with can be found on this machine.
  final Future<bool> Function() findCli;

  /// Told the notes folder chosen here.
  final ValueChanged<String> onNotes;

  /// Told when the welcome is finished or skipped.
  final VoidCallback onDone;

  final ChooseFolder chooseFolder;

  @override
  State<WelcomePanel> createState() => _WelcomePanelState();
}

class _WelcomePanelState extends State<WelcomePanel> {
  _Step _step = _Step.cli;

  /// Null while the CLI is being looked for.
  bool? _found;

  @override
  void initState() {
    super.initState();
    _look();
  }

  Future<void> _look() async {
    setState(() => _found = null);
    final found = await widget.findCli();
    if (mounted) setState(() => _found = found);
  }

  void _go(_Step step) => setState(() => _step = step);

  Future<void> _choose() async {
    final path = await widget.chooseFolder(widget.settings.notes.value);
    if (path != null) widget.onNotes(path);
  }

  @override
  Widget build(BuildContext context) {
    final tongue = Words.of(context);
    return Container(
      margin: const EdgeInsets.all(_padding),
      padding: const EdgeInsets.all(_padding),
      decoration: BoxDecoration(
        color: panelFill,
        borderRadius: BorderRadius.circular(_cornerRadius),
        border: Border.all(color: panelEdge, width: _edgeWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading(tongue),
          const SizedBox(height: _padding),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: switch (_step) {
                  _Step.cli => _cli(tongue),
                  _Step.notes => _notes(tongue),
                  _Step.ready => _ready(tongue),
                },
              ),
            ),
          ),
          _footer(tongue),
        ],
      ),
    );
  }

  Widget _heading(Words tongue) => Row(
    children: [
      Expanded(
        child: Text(
          switch (_step) {
            _Step.cli => tongue.welcomeTitle,
            _Step.notes => tongue.welcomeNotesTitle,
            _Step.ready => tongue.welcomeReadyTitle,
          },
          style: const TextStyle(color: panelInk, fontWeight: FontWeight.w600),
        ),
      ),
      for (final step in _Step.values) _Dot(step.index <= _step.index),
    ],
  );

  List<Widget> _ready(Words tongue) => [
    _said(tongue.welcomeReady),
    const SizedBox(height: _gap),
    _hint(tongue.welcomeReadyHint),
  ];

  List<Widget> _cli(Words tongue) => [
    _said(tongue.welcomeCli),
    const SizedBox(height: _gap),
    _Well(switch (_found) {
      null => tongue.cliChecking,
      true => '✓ ${tongue.cliFound}',
      false => tongue.cliNotFound,
    }, color: _found == false ? panelAlarm : panelInk),
    const SizedBox(height: _gap),
    if (_found == true) _hint(tongue.cliFoundHint),
    if (_found == false) _hint(tongue.cliNotFoundHint),
  ];

  List<Widget> _notes(Words tongue) {
    final missing = widget.settings.notesMissing;
    return [
      _said(tongue.welcomeNotes),
      const SizedBox(height: _gap),
      Row(
        children: [
          Expanded(
            child: Tooltip(
              message: widget.settings.notes.value,
              child: _Well(widget.settings.notes.value, oneLine: true),
            ),
          ),
          const SizedBox(width: _gap),
          _quiet(tongue.choose, _choose),
        ],
      ),
      const SizedBox(height: _gap),
      _hint(
        missing ? tongue.folderGone : tongue.folderThere,
        color: missing ? panelAlarm : panelFaint,
      ),
    ];
  }

  /// Escape closes the bubble only if something inside it holds focus, and on
  /// a welcome that opened itself nothing does unless asked — hence the
  /// autofocus on the button that goes forward.
  Widget _footer(Words tongue) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      if (_step != _Step.ready)
        Flexible(
          child: TextButton(
            onPressed: widget.onDone,
            style: TextButton.styleFrom(foregroundColor: panelFaint),
            child: Text(tongue.skipWelcome),
          ),
        ),
      // The buttons wrap rather than run off the edge where a longer tongue
      // or a larger system font will not fit them on one line.
      Expanded(
        flex: 3,
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: _gap,
          children: [
            if (_step == _Step.cli && _found == false)
              _quiet(tongue.checkAgain, _look),
            if (_step != _Step.cli)
              _quiet(
                tongue.previousStep,
                () => _go(_Step.values[_step.index - 1]),
              ),
            _forward(tongue),
          ],
        ),
      ),
    ],
  );

  Widget _forward(Words tongue) {
    final last = _step == _Step.ready;
    final blocked = _step == _Step.notes && widget.settings.notesMissing;
    void advance() =>
        last ? widget.onDone() : _go(_Step.values[_step.index + 1]);
    return FilledButton(
      autofocus: true,
      onPressed: blocked ? null : advance,
      style: FilledButton.styleFrom(
        backgroundColor: panelEdge,
        foregroundColor: panelWell,
      ),
      child: Text(last ? tongue.startAsking : tongue.nextStep),
    );
  }

  Widget _quiet(String words, VoidCallback onPressed) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: panelInk,
      side: const BorderSide(color: panelWellEdge),
    ),
    child: Text(words),
  );

  Widget _said(String words) => Text(
    words,
    style: const TextStyle(color: panelInk, fontSize: _saidSize),
  );

  Widget _hint(String words, {Color color = panelFaint}) => Text(
    words,
    style: TextStyle(color: color, fontSize: _hintSize, height: 1.4),
  );
}

/// One step's mark, lit once reached.
class _Dot extends StatelessWidget {
  const _Dot(this.lit);

  final bool lit;

  @override
  Widget build(BuildContext context) => Container(
    width: _dot,
    height: _dot,
    margin: const EdgeInsets.only(left: _dotGap),
    decoration: BoxDecoration(
      color: lit ? panelEdge : panelWellEdge,
      shape: BoxShape.circle,
    ),
  );
}

/// The sunken well a value sits in, as in the settings panel.
class _Well extends StatelessWidget {
  const _Well(this.words, {this.color = panelInk, this.oneLine = false});

  final String words;
  final Color color;
  final bool oneLine;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: panelWell,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: panelWellEdge),
    ),
    child: Text(
      words,
      maxLines: oneLine ? 1 : null,
      overflow: oneLine ? TextOverflow.ellipsis : null,
      style: TextStyle(color: color, fontSize: 12, fontFamily: 'monospace'),
    ),
  );
}
