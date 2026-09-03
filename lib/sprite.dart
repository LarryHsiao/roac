import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'roaming.dart';

/// The rectangle the pointer must fall within for the sprite to catch it,
/// given where the window currently sits on screen.
///
/// Taken from the window as it truly stands rather than the size it was asked
/// for, so a window the desktop has resized still hands over the pointer where
/// the sprite is actually drawn.
Rect spriteBoundsWithin(Rect window) => Rect.fromCenter(
  center: window.center,
  width: Sprite.size,
  height: Sprite.size,
);

/// The placeholder mascot — a plain rounded square with no face and no
/// character. Its motion is drawn rather than animated from art; real sprite
/// frames replace the whole of this file once a character is chosen.
class Sprite extends StatefulWidget {
  const Sprite({required this.gait, required this.facing, super.key});

  /// Edge length of the drawn sprite, in logical pixels.
  static const double size = 120;

  final Gait gait;
  final Facing facing;

  @override
  State<Sprite> createState() => _SpriteState();
}

class _SpriteState extends State<Sprite> with SingleTickerProviderStateMixin {
  /// One full breath at rest, and one full stride while walking.
  static const _breathPeriod = Duration(milliseconds: 2400);
  static const _stridePeriod = Duration(milliseconds: 520);

  /// How far the body rises at the crest of a beat, in logical pixels, and how
  /// far it leans into its walk, in radians.
  static const _breathRise = 3.0;
  static const _hopRise = 10.0;
  static const _lean = 0.1;

  late final AnimationController _beat = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    _keepTime();
  }

  @override
  void didUpdateWidget(Sprite old) {
    super.didUpdateWidget(old);
    if (old.gait != widget.gait) _keepTime();
  }

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  /// A pinned mascot holds perfectly still; the rest keep their own tempo.
  void _keepTime() {
    if (widget.gait == Gait.pinned) {
      _beat.stop();
      _beat.value = 0;
      return;
    }
    _beat.duration = widget.gait == Gait.walking
        ? _stridePeriod
        : _breathPeriod;
    _beat.repeat();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _beat,
        builder: (context, child) {
          final beat = math.sin(_beat.value * 2 * math.pi);
          final walking = widget.gait == Gait.walking;
          final rise = walking ? -beat.abs() * _hopRise : beat * _breathRise;
          final lean = walking
              ? widget.facing.stride * beat.abs() * _lean
              : 0.0;
          return Transform.translate(
            offset: Offset(0, rise),
            child: Transform.rotate(angle: lean, child: child),
          );
        },
        child: _Body(gait: widget.gait),
      ),
    );
  }
}

/// The mascot's body: a faceless rounded square, its edge marking whether it
/// is free to roam or held in place.
class _Body extends StatelessWidget {
  const _Body({required this.gait});

  static const Color _fill = Color(0xFF3B4252);
  static const Color _roamingEdge = Color(0xFF88C0D0);
  static const Color _pinnedEdge = Color(0xFF6B7280);

  static const double _cornerRadius = 24;
  static const double _edgeWidth = 3;

  final Gait gait;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Sprite.size,
      height: Sprite.size,
      decoration: BoxDecoration(
        color: _fill,
        borderRadius: BorderRadius.circular(_cornerRadius),
        border: Border.all(
          color: gait == Gait.pinned ? _pinnedEdge : _roamingEdge,
          width: _edgeWidth,
        ),
      ),
    );
  }
}
