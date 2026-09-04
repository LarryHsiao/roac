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
        child: _Body(gait: widget.gait, facing: widget.facing),
      ),
    );
  }
}

/// The mascot's body: Roäc himself, drawn rather than played from frames.
class _Body extends StatelessWidget {
  const _Body({required this.gait, required this.facing});

  final Gait gait;
  final Facing facing;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(Sprite.size),
      painter: _Raven(gait: gait, facing: facing),
    );
  }
}

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
  const _Raven({required this.gait, required this.facing});

  static const Color _feather = Color(0xFF272B36);
  static const Color _wing = Color(0xFF3B4252);
  static const Color _roaming = Color(0xFF88C0D0);
  static const Color _held = Color(0xFF6B7280);
  static const Color _beak = Color(0xFF8894A6);

  static const double _outline = 2.5;

  final Gait gait;
  final Facing facing;

  Color get _edge => gait == Gait.pinned ? _held : _roaming;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (facing == Facing.left) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final bird = _birdOn(size);
    final beak = _beakOn(size);
    final wing = _wingOn(size);
    _fill(canvas, bird, _feather);
    _fill(canvas, beak, _beak);
    _stroke(canvas, beak);
    _stroke(canvas, bird);
    _fill(canvas, wing, _wing);
    _stroke(canvas, wing);
    _drawFooting(canvas, size);
    _drawEye(canvas, size);
    canvas.restore();
  }

  /// Head, back, tail and breast in one unbroken line — a bird has no seam at
  /// its neck, and a tail drawn apart reads as a triangle stuck on behind.
  Path _birdOn(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.80, h * 0.26)
      ..cubicTo(w * 0.72, h * 0.10, w * 0.48, h * 0.12, w * 0.46, h * 0.28)
      ..cubicTo(w * 0.38, h * 0.34, w * 0.30, h * 0.46, w * 0.26, h * 0.60)
      ..lineTo(w * 0.03, h * 0.72)
      ..lineTo(w * 0.09, h * 0.80)
      ..lineTo(w * 0.02, h * 0.86)
      ..lineTo(w * 0.30, h * 0.84)
      ..cubicTo(w * 0.48, h * 0.90, w * 0.72, h * 0.78, w * 0.72, h * 0.58)
      ..cubicTo(w * 0.72, h * 0.46, w * 0.68, h * 0.40, w * 0.72, h * 0.36)
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
    return Path()
      ..moveTo(w * 0.78, h * 0.24)
      ..lineTo(w * 0.99, h * 0.33)
      ..lineTo(w * 0.76, h * 0.40)
      ..close();
  }

  /// Two feet, so it stands on the desktop rather than floating above it.
  ///
  /// Drawn in the outline's colour rather than the feather's: they reach below
  /// the silhouette, and near-black there would vanish on a dark desktop —
  /// leaving the bird floating, which is the one thing the feet are for.
  void _drawFooting(Canvas canvas, Size size) {
    final leg = Paint()
      ..color = _edge
      ..strokeWidth = _outline
      ..strokeCap = StrokeCap.round;
    for (final at in [0.40, 0.56]) {
      canvas.drawLine(
        Offset(size.width * at, size.height * 0.84),
        Offset(size.width * at, size.height * 0.94),
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
  bool shouldRepaint(_Raven old) => old.gait != gait || old.facing != facing;
}
