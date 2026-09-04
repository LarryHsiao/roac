import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'pack.dart';
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
  const Sprite({
    required this.gait,
    required this.facing,
    this.worn,
    this.walked = 0,
    super.key,
  });

  /// Edge length of the drawn sprite, in logical pixels.
  static const double size = 120;

  final Gait gait;
  final Facing facing;

  /// The character being worn, if any. None, and Roäc draws himself.
  final Character? worn;

  /// How much ground has been walked altogether, in logical pixels. A packed
  /// walk steps by this rather than by the clock, so its feet never skate.
  final double walked;

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
    if (old.gait != widget.gait || old.worn != widget.worn) _keepTime();
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
    _beat.duration = _cycleOf(widget.worn?.poses[widget.gait]);
    _beat.repeat();
  }

  Duration _cycleOf(Poses? poses) =>
      cycleOf(poses, widget.gait, breath: _breathPeriod, stride: _stridePeriod);

  @override
  Widget build(BuildContext context) {
    // The drawing owns every part of the motion, rather than a transform above
    // it moving a fixed picture about. A frame of a sprite sheet carries its
    // whole pose, and so does the drawn bird — which is what lets a pack step
    // into its place with nothing above either of them to keep in step.
    return Center(
      child: AnimatedBuilder(
        animation: _beat,
        builder: (context, _) => _Body(
          gait: widget.gait,
          facing: widget.facing,
          phase: _beat.value,
          worn: widget.worn,
          walked: widget.walked,
        ),
      ),
    );
  }
}

/// The mascot's body: Roäc himself, drawn rather than played from frames.
class _Body extends StatelessWidget {
  const _Body({
    required this.gait,
    required this.facing,
    required this.phase,
    required this.worn,
    required this.walked,
  });

  final Gait gait;
  final Facing facing;
  final double phase;
  final Character? worn;
  final double walked;

  @override
  Widget build(BuildContext context) {
    final character = worn;
    final poses = character?.poses[gait];
    return CustomPaint(
      size: const Size.square(Sprite.size),
      painter: poses == null
          ? _Raven(gait: gait, facing: facing, phase: phase)
          : _Worn(
              poses: poses,
              frame: character!.frame,
              facing: facing,
              at: frameAt(poses, phase: phase, walked: walked),
            ),
    );
  }
}

/// Which frame of [poses] to show.
///
/// A walk counts the ground it has covered, so the legs keep step with the
/// body however fast it goes. Everything else counts time, and there the
/// controller's own turning through its cycle is the count already made.
int frameAt(Poses poses, {required double phase, required double walked}) {
  final everyPx = poses.everyPx;
  final step = everyPx == null
      ? (phase * poses.sequence.length).floor()
      : (walked / everyPx).floor();
  return poses.sequence[step % poses.sequence.length];
}

/// A character worn in Roäc's place: one frame of its strip, laid where the
/// drawn bird would have stood.
class _Worn extends CustomPainter {
  const _Worn({
    required this.poses,
    required this.frame,
    required this.facing,
    required this.at,
  });

  final Poses poses;
  final Size frame;
  final Facing facing;
  final int at;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (facing == Facing.left) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    canvas.drawImageRect(
      poses.strip,
      Rect.fromLTWH(frame.width * at, 0, frame.width, frame.height),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Worn old) =>
      old.at != at || old.facing != facing || old.poses != poses;
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

/// How long one turn of a gait's cycle takes.
///
/// A worn character sets its own tempo: the manifest says how long a frame is
/// held, and there are as many frames as its sequence plays. Only a bird
/// drawing himself falls back on the periods given here, having no manifest
/// to be asked. A gait carried by distance rather than time has no cycle in
/// the clock at all, so it too takes the fallback and is simply left turning.
Duration cycleOf(
  Poses? poses,
  Gait gait, {
  required Duration breath,
  required Duration stride,
}) {
  final everyMs = poses?.everyMs;
  if (everyMs != null) {
    return Duration(milliseconds: everyMs * poses!.sequence.length);
  }
  return gait == Gait.walking ? stride : breath;
}

/// Draws Roäc as he stands at [phase] of his [gait].
///
/// The widget reaches the same drawing through its painter; this door exists
/// for `tool/make_pack.dart`, which needs a frame of him outside any widget
/// at all. Both go to the one painter, so there is never a second bird to
/// keep in step with this one.
void paintRoac(
  Canvas canvas,
  Size size, {
  required Gait gait,
  required Facing facing,
  required double phase,
}) => _Raven(gait: gait, facing: facing, phase: phase).paint(canvas, size);

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

  /// How far ink must keep from a frame's edge: half the outline it is drawn
  /// with, and a little besides for antialiasing to fall into.
  ///
  /// In pixels, and not as a fraction of the frame. The outline is a fixed
  /// width whatever size the bird is drawn at, so a fraction that leaves
  /// room enough at one size leaves too little at a smaller one.
  ///
  /// It matters because the pixel past a frame's edge is not empty: in a
  /// sprite sheet it is the next frame's first column, and ink that oversteps
  /// arrives inside the neighbouring bird.
  static const double _room = _outline / 2 + 2;

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
  ///
  /// The tail's points are held off the near edge by the same room the beak
  /// keeps from the far one: it is the same sharp, stroked vertex, and would
  /// overstep first if the outline were ever drawn heavier.
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
      ..lineTo(math.max(w * 0.03, _room), h * 0.72)
      ..lineTo(w * 0.09, h * 0.80)
      ..lineTo(math.max(w * 0.02, _room), h * 0.86)
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
  ///
  /// Its tip stops short of the edge by the head's furthest thrust and the
  /// room ink must keep, so it stays inside however far the head pushes. The
  /// base was drawn back with it, to keep the wedge's heft rather than leave
  /// a stub.
  Path _beakOn(Size size) {
    final w = size.width;
    final h = size.height;
    final ahead = w * _leading;
    return Path()
      ..moveTo(w * 0.76 + ahead, h * 0.24)
      ..lineTo(w - w * _headThrust - _room + ahead, h * 0.33)
      ..lineTo(w * 0.74 + ahead, h * 0.40)
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
