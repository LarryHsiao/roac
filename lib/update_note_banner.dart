import 'package:flutter/material.dart';

import 'l10n/words.dart';

// Mirrors settings_panel.dart's palette — the banner sits above whichever
// chrome the bubble holds, and must wear the bubble's own Nord look rather
// than a color of its own. Kept apart rather than shared for the same reason
// settings_panel.dart gives: neither file is more than one recurrence of the
// other yet.
const Color _fill = Color(0xFF2E3440);
const Color _edge = Color(0xFF88C0D0);
const Color _ink = Color(0xFFECEFF4);
const Color _faint = Color(0xFF8894A6);

/// A one-time, non-blocking note that Roäc updated himself since the last
/// launch. Purely informational — it never intercepts keyboard input, so it
/// must not sit in the focus chain the ask field or the settings panel rely
/// on.
class UpdateNoteBanner extends StatelessWidget {
  const UpdateNoteBanner({
    super.key,
    required this.version,
    required this.onDismiss,
  });

  final String version;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final tongue = Words.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const BoxDecoration(
        color: _fill,
        border: Border(bottom: BorderSide(color: _edge)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tongue.updatedTo(version),
              style: const TextStyle(color: _ink, fontSize: 11),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: _faint, size: 14),
            tooltip: tongue.dismissNote,
            onPressed: onDismiss,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
