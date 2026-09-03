import 'package:flutter/material.dart';

import 'counsel.dart';

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
    required this.onAsk,
    super.key,
  });

  /// What Roäc last said, or null while it has said nothing yet.
  final Counsel? counsel;

  /// Whether Roäc is presently thinking.
  final bool waiting;

  final ValueChanged<String> onAsk;

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
          Expanded(child: _Said(counsel: counsel, waiting: waiting)),
          const SizedBox(height: _padding),
          _Asking(onAsk: onAsk),
        ],
      ),
    );
  }
}

/// What Roäc is saying: nothing yet, thinking, an answer, or a plain trouble.
///
/// An answer scrolls and may be selected rather than being cut, because it
/// carries exact values — a URL, a path, an identifier — that mean nothing
/// once truncated.
class _Said extends StatelessWidget {
  const _Said({required this.counsel, required this.waiting});

  final Counsel? counsel;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    if (waiting) {
      return const Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: _padding),
          Text('Roäc is thinking…', style: TextStyle(color: _faint)),
        ],
      );
    }
    return switch (counsel) {
      null => const Text(
          'Ask me what you have written down.',
          style: TextStyle(color: _faint),
        ),
      Answer(:final words) => _Scroll(words: words, colour: _ink),
      Trouble(:final reason) => _Scroll(words: reason, colour: _alarm),
    };
  }
}

/// Words given room to run on rather than being cut short.
class _Scroll extends StatelessWidget {
  const _Scroll({required this.words, required this.colour});

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
class _Asking extends StatelessWidget {
  const _Asking({required this.onAsk});

  final ValueChanged<String> onAsk;

  @override
  Widget build(BuildContext context) {
    return TextField(
      autofocus: true,
      style: const TextStyle(color: _ink),
      cursorColor: _edge,
      decoration: const InputDecoration(
        isDense: true,
        hintText: 'Ask Roäc…',
        hintStyle: TextStyle(color: _faint),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: _faint),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: _edge),
        ),
      ),
      onSubmitted: onAsk,
    );
  }
}
