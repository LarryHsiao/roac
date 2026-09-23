import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'roaming.dart';
import 'sprite.dart' show bodyDropAt, legSwingAt;

/// Draws TARS — the block-built robot of *Interstellar* — as he stands at
/// [phase] of his [gait].
///
/// The door `tool/make_tars_pack.dart` walks through to draw him outside any
/// widget at all, exactly as `paintRoac` does for the raven: both go to the
/// one painter below, so there is never a second TARS to keep in step with
/// this one.
void paintTars(
  Canvas canvas,
  Size size, {
  required Gait gait,
  required Facing facing,
  required double phase,
}) => _Tars(gait: gait, facing: facing, phase: phase).paint(canvas, size);

/// TARS in as few strokes as will still read as one across a room: a
/// four-segment torso carried on two legs, with two arms hanging at its
/// sides — arms and legs both ending in a wider cap so hand and foot read
/// apart from the limb that carries them.
///
/// Built facing right and mirrored when he turns, laid out on a unit square
/// so he keeps his proportions at any size. Unlike the raven, he keeps clear
/// of his frame's edge through generous fixed margins rather than the
/// raven's `_room`-clamped vertices — his blockier shape has no near-edge
/// point that needs one. His outline carries the same meaning the raven's
/// does: cyan when he is free to roam, grey when he is held where he stands.
class _Tars extends CustomPainter {
  const _Tars({required this.gait, required this.facing, required this.phase});

  static const Color _chassis = Color(0xFF23262E);
  static const Color _panel = Color(0xFF3A3F4B);
  static const Color _amber = Color(0xFFE0A458);
  static const Color _roaming = Color(0xFF88C0D0);
  static const Color _held = Color(0xFF6B7280);

  static const double _outline = 2.5;

  /// How far he moves through his pose, as fractions of the sprite.
  static const double _breathRise = 0.012;
  static const double _bodyDrop = 0.03;

  /// How far a leg swings at the full point of a stride, in radians. An arm
  /// swings by the same clock a half-cycle apart, the opposition an
  /// ordinary stride carries — front leg, back arm, on the same side.
  static const double _legSwingAngle = 0.28;
  static const double _armSwingAngle = 0.35;

  final Gait gait;
  final Facing facing;

  /// Where he stands in his cycle, from 0 to 1.
  final double phase;

  Color get _edge => gait == Gait.pinned ? _held : _roaming;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (facing == Facing.left) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    canvas.translate(0, -_settling * size.height);
    _drawLegs(canvas, size);
    _drawArms(canvas, size);
    final body = _bodyOn(size);
    _fill(canvas, body, _chassis);
    _stroke(canvas, body);
    _drawSegments(canvas, size);
    _drawSensor(canvas, size);
    canvas.restore();
  }

  /// How far he sits from where he would stand at rest, as a fraction of the
  /// sprite. A walking TARS drops at each footfall; a resting one breathes.
  double get _settling => switch (gait) {
    Gait.pinned => 0,
    Gait.walking => bodyDropAt(phase) * _bodyDrop,
    Gait.idle => math.sin(phase * 2 * math.pi) * _breathRise,
  };

  /// How far a limb on [leading]'s side has swung, in radians. Only a
  /// walking TARS swings his limbs; the rest hold them plumb. An arm swings
  /// opposite the leg on its own side — [forArm] flips the sign for it.
  double _swingOf(int leading, double maxAngle, {bool forArm = false}) {
    if (gait != Gait.walking) return 0;
    final swing = legSwingAt(phase) * leading;
    return (forArm ? -swing : swing) * maxAngle;
  }

  /// The monolith itself — one rounded slab, the segments drawn over it.
  Path _bodyOn(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()..addRRect(
      RRect.fromLTRBR(
        w * 0.32,
        h * 0.10,
        w * 0.68,
        h * 0.80,
        Radius.circular(w * 0.035),
      ),
    );
  }

  /// The three seams that split him into four blocks.
  void _drawSegments(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const top = 0.10;
    const bottom = 0.80;
    final seam = Paint()
      ..color = _panel
      ..strokeWidth = _outline * 0.7
      ..strokeCap = StrokeCap.round;
    for (final at in [0.25, 0.5, 0.75]) {
      final y = h * (top + (bottom - top) * at);
      canvas.drawLine(Offset(w * 0.34, y), Offset(w * 0.66, y), seam);
    }
  }

  /// His one visible sensor — lit amber when he is about, a shut grey line
  /// when he is held, the same telling the raven's eye does.
  void _drawSensor(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final at = (Offset(w * 0.38, h * 0.20), Offset(w * 0.62, h * 0.20));
    if (gait == Gait.pinned) {
      canvas.drawLine(
        at.$1,
        at.$2,
        Paint()
          ..color = _held
          ..strokeWidth = _outline
          ..strokeCap = StrokeCap.round,
      );
      return;
    }
    final glow = gait == Gait.idle
        ? 0.55 + 0.45 * (math.sin(phase * 2 * math.pi) * 0.5 + 0.5)
        : 1.0;
    canvas.drawLine(
      at.$1,
      at.$2,
      Paint()
        ..color = _amber.withValues(alpha: glow)
        ..strokeWidth = _outline
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Two legs, each a thigh and a foot, swinging opposite one another so he
  /// strides rather than hops — the same reasoning the raven's legs carry.
  /// The foot is drawn in the outline colour so it does not vanish against a
  /// dark desktop; the thigh carries the same panel colour the torso's own
  /// seams do.
  void _drawLegs(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const hip = 0.80;
    const knee = 0.90;
    const sole = 0.955;
    for (final leading in [1, -1]) {
      final hipAt = Offset(w * (0.5 + 0.14 * leading), h * hip);
      canvas.save();
      canvas.translate(hipAt.dx, hipAt.dy);
      canvas.rotate(_swingOf(leading, _legSwingAngle));
      canvas.translate(-hipAt.dx, -hipAt.dy);
      final thigh = Path()
        ..addRRect(
          RRect.fromLTRBR(
            hipAt.dx - w * 0.045,
            h * hip,
            hipAt.dx + w * 0.045,
            h * knee,
            Radius.circular(w * 0.015),
          ),
        );
      _fill(canvas, thigh, _panel);
      _stroke(canvas, thigh);
      final foot = Path()
        ..addRRect(
          RRect.fromLTRBR(
            hipAt.dx - w * 0.075,
            h * knee,
            hipAt.dx + w * 0.075,
            h * sole,
            Radius.circular(w * 0.02),
          ),
        );
      _fill(canvas, foot, _edge);
      canvas.restore();
    }
  }

  /// Two arms hanging at his sides, each an upper arm and a hand, swinging
  /// opposite the leg on the same side. Otherwise built the same way the
  /// legs are — a panel-coloured limb ending in an edge-coloured cap.
  void _drawArms(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const shoulder = 0.33;
    const wrist = 0.62;
    const handEnd = 0.68;
    for (final leading in [1, -1]) {
      final shoulderAt = Offset(w * (0.5 + 0.29 * leading), h * shoulder);
      canvas.save();
      canvas.translate(shoulderAt.dx, shoulderAt.dy);
      canvas.rotate(_swingOf(leading, _armSwingAngle, forArm: true));
      canvas.translate(-shoulderAt.dx, -shoulderAt.dy);
      final upper = Path()
        ..addRRect(
          RRect.fromLTRBR(
            shoulderAt.dx - w * 0.038,
            h * shoulder,
            shoulderAt.dx + w * 0.038,
            h * wrist,
            Radius.circular(w * 0.02),
          ),
        );
      _fill(canvas, upper, _panel);
      _stroke(canvas, upper);
      final hand = Path()
        ..addRRect(
          RRect.fromLTRBR(
            shoulderAt.dx - w * 0.055,
            h * wrist,
            shoulderAt.dx + w * 0.055,
            h * handEnd,
            Radius.circular(w * 0.018),
          ),
        );
      _fill(canvas, hand, _edge);
      canvas.restore();
    }
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
  bool shouldRepaint(_Tars old) =>
      old.phase != phase || old.gait != gait || old.facing != facing;
}
