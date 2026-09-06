import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'l10n/words.dart';
import 'saying.dart';
import 'settings.dart';

// Mirrors bubble.dart's palette — the panel stands in the bubble's own place
// while it is open, and must wear the same chrome. Kept apart rather than
// shared, since neither file is more than one recurrence of the other; a
// third surface wanting this look would be the moment to lift it.
const Color _fill = Color(0xFF2E3440);
const Color _edge = Color(0xFF88C0D0);
const Color _ink = Color(0xFFECEFF4);
const Color _faint = Color(0xFF8894A6);
const Color _alarm = Color(0xFFD08770);
const Color _well = Color(0xFF1A1E29);
const Color _wellEdge = Color(0xFF3A4256);

const double _cornerRadius = 16;
const double _edgeWidth = 2;
const double _padding = 12;

/// How a folder is chosen, given where to start looking. Named so a test may
/// stand in for the native dialog, in the same shape as every other seam.
typedef ChooseFolder = Future<String?> Function(String from);

/// A folder chosen through the real, native dialog.
Future<String?> fromTheFilesystem(String from) =>
    getDirectoryPath(initialDirectory: from);

/// What Roäc has been told, and where to tell him something else.
///
/// Stands in the bubble's own place while it is open — the mascot keeps its
/// footing below, exactly as it does under the bubble.
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({
    required this.settings,
    required this.installedPacks,
    required this.onChanged,
    required this.onClose,
    this.chooseFolder = fromTheFilesystem,
    super.key,
  });

  /// What Roäc has been told, as it stands now.
  final Settings settings;

  /// The packs found in the folder [Settings.packs] names, by file name.
  final List<String> installedPacks;

  /// Told when a setting is changed here: the key that changed, and its new
  /// value — null to let the tier beneath it stand again.
  final void Function(String key, String? value) onChanged;

  final VoidCallback onClose;

  final ChooseFolder chooseFolder;

  @override
  Widget build(BuildContext context) {
    final tongue = Words.of(context);
    final trouble = settings.trouble;
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
          Row(
            children: [
              Expanded(
                child: Text(
                  tongue.settingsTitle,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                // The bubble it replaces holds keyboard focus on its field
                // by default; nothing here does unless asked. Without it,
                // Escape and the settings shortcut have nothing to bubble
                // up from, and neither closes the panel they are meant to.
                autofocus: true,
                icon: const Icon(Icons.close, color: _faint, size: 18),
                tooltip: tongue.closeSettings,
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: _padding),
          // The window is grown tall enough to hold this without scrolling
          // in the ordinary case — see settingsHeight. Scrolling stands as
          // the safety net for whatever that leaves no room for, the same
          // way the answer above the ask field scrolls rather than being cut.
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Folder(
                    label: tongue.notesLabel,
                    chosen: settings.notes,
                    variable: 'ROAC_NOTES',
                    onChoose: () async {
                      final path = await chooseFolder(settings.notes.value);
                      if (path != null) onChanged('notes', path);
                    },
                  ),
                  const SizedBox(height: _padding),
                  _Folder(
                    label: tongue.packsLabel,
                    chosen: settings.packs,
                    variable: 'ROAC_PACKS',
                    onChoose: () async {
                      final path = await chooseFolder(settings.packs.value);
                      if (path != null) onChanged('packs', path);
                    },
                  ),
                  const SizedBox(height: _padding),
                  _Character(
                    chosen: settings.pack,
                    installed: installedPacks,
                    onChosen: (name) => onChanged('pack', name),
                  ),
                  const SizedBox(height: _padding),
                  _Folder(
                    label: tongue.claudeConfigLabel,
                    chosen: settings.claudeConfig,
                    variable: 'ROAC_CLAUDE_CONFIG',
                    whenUnset: tongue.claudeConfigUnset,
                    onChoose: () async {
                      final path = await chooseFolder(
                        settings.claudeConfig?.value ?? '',
                      );
                      if (path != null) onChanged('claudeConfig', path);
                    },
                  ),
                  if (trouble != null) ...[
                    const SizedBox(height: _padding),
                    _Trouble(text: saidOfMisread(tongue, trouble)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What a [Chosen] value's tier reads as, naming [variable] where the
/// environment is the one that spoke.
String _toldLine(Words tongue, Told told, String variable) => switch (told) {
  Told.environment => tongue.setByEnvironment(variable),
  Told.file => tongue.toldByFile,
  Told.byDefault => tongue.toldByDefault,
};

/// One folder setting: its value, a way to change it, and where it came from.
///
/// [chosen] is null where nothing names one and there is no default to fall
/// back to — unlike Notes and Packs, which always have one. [whenUnset] is
/// what the well shows then, and the tier line is left off entirely: there is
/// no tier to name when nothing was told.
class _Folder extends StatelessWidget {
  const _Folder({
    required this.label,
    required this.chosen,
    required this.variable,
    required this.onChoose,
    this.whenUnset,
  });

  final String label;
  final Chosen? chosen;
  final String variable;
  final VoidCallback onChoose;
  final String? whenUnset;

  @override
  Widget build(BuildContext context) {
    final shown = chosen?.value ?? whenUnset ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Tooltip(
                message: shown,
                child: _Well(
                  child: Text(
                    shown,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onChoose,
              style: OutlinedButton.styleFrom(
                foregroundColor: _ink,
                side: const BorderSide(color: _wellEdge),
              ),
              child: Text(Words.of(context).choose),
            ),
          ],
        ),
        if (chosen != null) ...[
          const SizedBox(height: 2),
          Text(
            _toldLine(Words.of(context), chosen!.told, variable),
            style: const TextStyle(color: _faint, fontSize: 10),
          ),
        ],
      ],
    );
  }
}

/// Which character is worn: the built-in raven, or one of [installed].
class _Character extends StatelessWidget {
  const _Character({
    required this.chosen,
    required this.installed,
    required this.onChosen,
  });

  final Chosen? chosen;
  final List<String> installed;
  final ValueChanged<String?> onChosen;

  @override
  Widget build(BuildContext context) {
    final tongue = Words.of(context);
    // A pack once chosen and since removed is not offered back: the drawn
    // raven is what is actually worn then, and the dropdown should say so.
    final worn = chosen != null && installed.contains(chosen!.value)
        ? chosen!.value
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(tongue.characterLabel),
        const SizedBox(height: 4),
        _Well(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: worn,
              isExpanded: true,
              dropdownColor: _well,
              icon: const Icon(Icons.arrow_drop_down, color: _faint),
              style: const TextStyle(
                color: _ink,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(
                    installed.isEmpty
                        ? tongue.drawnCharacterNoPacks
                        : tongue.drawnCharacter,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                for (final name in installed)
                  DropdownMenuItem(
                    value: name,
                    child: Text(name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: onChosen,
            ),
          ),
        ),
        if (worn != null) ...[
          const SizedBox(height: 2),
          Text(
            _toldLine(tongue, chosen!.told, 'ROAC_PACK'),
            style: const TextStyle(color: _faint, fontSize: 10),
          ),
        ],
      ],
    );
  }
}

/// A field's name, set apart from its value the same way in every row.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      color: _faint,
      fontSize: 11,
      letterSpacing: 0.4,
      fontWeight: FontWeight.w600,
    ),
  );
}

/// The sunken well a value or a dropdown sits in.
class _Well extends StatelessWidget {
  const _Well({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: _well,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: _wellEdge),
    ),
    child: DefaultTextStyle.merge(
      style: const TextStyle(
        color: _ink,
        fontSize: 12,
        fontFamily: 'monospace',
      ),
      child: child,
    ),
  );
}

/// Why the settings file could not be used, named plainly beneath the
/// settings it left unchanged.
class _Trouble extends StatelessWidget {
  const _Trouble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: const Color(0xFF2F2A1E),
      border: Border.all(color: const Color(0xFF5A4A2A)),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(text, style: const TextStyle(color: _alarm, height: 1.4)),
  );
}
