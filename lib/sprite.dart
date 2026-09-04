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

/// The mascot: a raven, drawn rather than played from frames.
///
/// Both the shape and its motion are computed, so there are no assets to load
/// and nothing to keep in step with the code. Sprite sheets, when they come,
/// replace this file and nothing else.
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
    // The drawing owns every part of the motion, rather than a transform above
    // it moving a fixed picture about. A frame of a sprite sheet carries its
    // whole pose, so the bird that will one day be drawn from frames must be
    // describable the same way — by a gait, a facing, and where it stands in
    // its cycle.
    return Center(
      child: AnimatedBuilder(
        animation: _beat,
        builder: (context, _) =>
            _Body(gait: widget.gait, facing: widget.facing, phase: _beat.value),
      ),
    );
  }
}

/// The mascot's body: Roäc himself, drawn rather than played from frames.
class _Body extends StatelessWidget {
  const _Body({required this.gait, required this.facing, required this.phase});

  final Gait gait;
  final Facing facing;
  final double phase;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(Sprite.size),
      painter: _Raven(gait: gait, facing: facing, phase: phase),
    );
  }
}

/// How far the near leg has swung at [phase] of a stride: forward at a quarter
/// through, back at three quarters, level as it passes between.
///
/// Those two quarter marks are the footfalls, and a sprite sheet of this bird
/// samples exactly there — a stride drawn as three poses, played as four
/// steps, with the passing pose serving twice.
double legSwingAt(double phase) => math.sin(phase * 2 * math.pi);

/// How low the body sits at [phase] of a stride: down at each footfall, up as
/// it passes over the standing leg. Twice a cycle, once per step.
double bodyDropAt(double phase) => legSwingAt(phase).abs();

/// How far the head is thrust forward at [phase] of a stride — the push and
/// catch-up that is a corvid's whole walk, more than the legs ever are.
double headThrustAt(double phase) => math.cos(phase * 4 * math.pi);

/// A raven in as few strokes as will still read as one across a room.
///
/// Everything is laid out on a unit square and scaled, so the bird keeps its
/// proportions whatever size it is drawn at. It is built facing right and
/// mirrored when it turns, so there is only ever one bird to get right.
///
/// Near-black would vanish against a dark desktop, so the whole silhouette
/// carries an outline in the colour that also says whether it is free to roam
/// — the same signal the placeholder's border carried, now around a bird.
class _Raven extends CustomPainter {
  const _Raven({required this.gait, required this.facing, required this.phase});

  static const Color _feather = Color(0xFF272B36);
  static const Color _wing = Color(0xFF3B4252);
  static const Color _roaming = Color(0xFF88C0D0);
  static const Color _held = Color(0xFF6B7280);
  static const Color _beak = Color(0xFF8894A6);

  static const double _outline = 2.5;

  /// How far the bird moves through its pose, as fractions of the sprite.
  static const double _breathRise = 0.015;
  static const double _bodyDrop = 0.035;
  static const double _headThrust = 0.030;
  static const double _legSwing = 0.055;

  /// How far apart the legs stand when the bird is not walking. Without it
  /// both would be drawn on the same line, and the bird would stand on one.
  static const double _legStance = 0.030;

  final Gait gait;
  final Facing facing;

  /// Where the bird stands in its cycle, from 0 to 1.
  final double phase;

  Color get _edge => gait == Gait.pinned ? _held : _roaming;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (facing == Facing.left) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    // The whole bird settles and rises; the head runs ahead of it and waits.
    canvas.translate(0, _settling * size.height);
    final bird = _birdOn(size);
    final beak = _beakOn(size);
    final wing = _wingOn(size);
    _drawLegs(canvas, size);
    _fill(canvas, bird, _feather);
    _fill(canvas, beak, _beak);
    _stroke(canvas, beak);
    _stroke(canvas, bird);
    _fill(canvas, wing, _wing);
    _stroke(canvas, wing);
    _drawEye(canvas, size);
    canvas.restore();
  }

  /// How far the body sits from where it would stand at rest, as a fraction of
  /// the sprite. A walking bird drops at each footfall; a resting one breathes.
  double get _settling => switch (gait) {
    Gait.pinned => 0,
    Gait.walking => bodyDropAt(phase) * _bodyDrop,
    Gait.idle => math.sin(phase * 2 * math.pi) * _breathRise,
  };

  /// How far ahead of the body the head is carried. Only a walking bird
  /// pushes; the rest hold it where it sits.
  double get _leading =>
      gait == Gait.walking ? headThrustAt(phase) * _headThrust : 0;

  /// Head, back, tail and breast in one unbroken line — a bird has no seam at
  /// its neck, and a tail drawn apart reads as a triangle stuck on behind.
  Path _birdOn(Size size) {
    final w = size.width;
    final h = size.height;
    final ahead = w * _leading;
    return Path()
      ..moveTo(w * 0.80 + ahead, h * 0.26)
      ..cubicTo(
        w * 0.72 + ahead,
        h * 0.10,
        w * 0.48 + ahead,
        h * 0.12,
        w * 0.46 + ahead * 0.5,
        h * 0.28,
      )
      ..cubicTo(w * 0.38, h * 0.34, w * 0.30, h * 0.46, w * 0.26, h * 0.60)
      ..lineTo(w * 0.03, h * 0.72)
      ..lineTo(w * 0.09, h * 0.80)
      ..lineTo(w * 0.02, h * 0.86)
      ..lineTo(w * 0.30, h * 0.84)
      ..cubicTo(w * 0.48, h * 0.90, w * 0.72, h * 0.78, w * 0.72, h * 0.58)
      ..cubicTo(
        w * 0.72,
        h * 0.46,
        w * 0.68 + ahead * 0.5,
        h * 0.40,
        w * 0.72 + ahead,
        h * 0.36,
      )
      ..close();
  }

  /// Folded along the back, the one shape that keeps the body from reading
  /// as a single dark mass.
  Path _wingOn(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.40, h * 0.46)
      ..cubicTo(w * 0.62, h * 0.44, w * 0.68, h * 0.58, w * 0.56, h * 0.76)
      ..cubicTo(w * 0.38, h * 0.78, w * 0.32, h * 0.60, w * 0.40, h * 0.46)
      ..close();
  }

  /// Heavy and wedge-shaped, as a raven's is — a thin one reads as a sparrow.
  Path _beakOn(Size size) {
    final w = size.width;
    final h = size.height;
    final ahead = w * _leading;
    return Path()
      ..moveTo(w * 0.78 + ahead, h * 0.24)
      ..lineTo(w * 0.99 + ahead, h * 0.33)
      ..lineTo(w * 0.76 + ahead, h * 0.40)
      ..close();
  }

  /// Two legs, swinging opposite one another so the bird strides rather than
  /// hops. They stay planted on the ground the body rises from, so the walk
  /// reads as the body moving over the feet and not the feet moving with it.
  ///
  /// Drawn in the outline's colour rather than the feather's: they reach below
  /// the silhouette, and near-black there would vanish on a dark desktop —
  /// leaving the bird floating, which is the one thing the legs are for.
  void _drawLegs(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final swing = gait == Gait.walking ? legSwingAt(phase) * _legSwing : 0.0;
    final ground = h * 0.94 - h * _settling;
    final leg = Paint()
      ..color = _edge
      ..strokeWidth = _outline
      ..strokeCap = StrokeCap.round;
    for (final leading in [1, -1]) {
      final hip = 0.48 + _legStance * leading * 0.5;
      canvas.drawLine(
        Offset(w * hip, h * 0.84),
        Offset(w * (hip + _legStance * leading + swing * leading), ground),
        leg,
      );
    }
  }

  /// Open when it is about, shut when it is held — the one place the bird
  /// looks back at you.
  void _drawEye(Canvas canvas, Size size) {
    final at = Offset(size.width * 0.66, size.height * 0.25);
    final look = size.width * 0.045;
    if (gait == Gait.pinned) {
      canvas.drawLine(
        at.translate(-look, 0),
        at.translate(look, 0),
        Paint()
          ..color = _held
          ..strokeWidth = _outline
          ..strokeCap = StrokeCap.round,
      );
      return;
    }
    canvas.drawCircle(at, look, Paint()..color = _roaming);
  }

  void _fill(Canvas canvas, Path path, Color colour) =>
      canvas.drawPath(path, Paint()..color = colour);

  void _stroke(Canvas canvas, Path path) => canvas.drawPath(
    path,
    Paint()
      ..color = _edge
      ..style = PaintingStyle.stroke
      ..strokeWidth = _outline
      ..strokeJoin = StrokeJoin.round,
  );

  @override
  bool shouldRepaint(_Raven old) =>
      old.phase != phase || old.gait != gait || old.facing != facing;
}
