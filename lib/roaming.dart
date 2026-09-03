import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:screen_retriever/screen_retriever.dart';

/// What the mascot is doing.
enum Gait {
  /// Held where it stands by the user; it neither walks nor breathes.
  pinned,

  /// At rest, but alive — it breathes where it stands.
  idle,

  /// Pacing along its display.
  walking,
}

/// Which way the mascot looks, and therefore which way it walks.
enum Facing {
  left(-1),
  right(1);

  const Facing(this.stride);

  /// The sign a step carries along the horizontal.
  final int stride;

  /// The way it looks once it has turned about.
  Facing get turned => this == left ? right : left;
}

/// Edge length of the window at rest, in logical pixels.
///
/// The window is deliberately larger than the sprite: the difference is a
/// transparent margin that clicks pass straight through.
const double restingSize = 160;

/// The room the window takes while the bubble is open — the mascot keeps its
/// resting corner and the bubble fills what is added above and to the side.
const Size speakingSize = Size(420, 300);

/// Where the mascot may stand on its display: the span its left edge may pace,
/// and the band its top edge must keep to.
typedef Roam = ({double from, double to, double ceiling, double floor});

/// Where the mascot stands along its range, and which way it looks.
@immutable
class Stance {
  const Stance({required this.left, required this.facing});

  /// The window's left edge, in logical pixels across the desktop.
  final double left;

  final Facing facing;

  /// Advances by [distance], turning about where [range] would not hold the
  /// mascot — so it paces the span rather than walking off the end of it.
  Stance stride(double distance, Roam range) {
    final next = left + facing.stride * distance;
    if (next < range.from) {
      return Stance(left: range.from, facing: facing.turned);
    }
    if (next > range.to) {
      return Stance(left: range.to, facing: facing.turned);
    }
    return Stance(left: next, facing: facing);
  }

  @override
  bool operator ==(Object other) =>
      other is Stance && other.left == left && other.facing == facing;

  @override
  int get hashCode => Object.hash(left, facing);

  @override
  String toString() => 'Stance(left: $left, facing: $facing)';
}

/// The part of [display] the desktop actually shows — menu bar and dock taken
/// out of it.
Rect visibleBoundsOf(Display display) {
  final position = display.visiblePosition ?? Offset.zero;
  final size = display.visibleSize ?? display.size;
  return position & size;
}

/// Where the mascot may stand on the display [window] occupies: that display's
/// visible area, drawn in by [span] so that the window always shows whole. The
/// bottom edge matters as much as the sides — macOS squashes a window pushed
/// past the visible area rather than letting it hang over.
///
/// Measured against the room the window means to take, never the size it
/// currently reports, so a window already squashed is not held to its squashed
/// shape and one about to grow is judged by what it will become.
///
/// Null when no display is known, which leaves the caller's range as it was
/// rather than penning the mascot inside a made-up boundary.
Roam? roamingRangeOn(List<Display> displays, Rect window, Size span) {
  if (displays.isEmpty) return null;
  final home = displays.firstWhere(
    (display) => visibleBoundsOf(display).overlaps(window),
    orElse: () => displays.first,
  );
  final visible = visibleBoundsOf(home);
  return (
    from: visible.left,
    to: visible.right - span.width,
    ceiling: visible.top,
    floor: visible.bottom - span.height,
  );
}

/// [bounds] as the window ought to stand: taking its full [span], and inside
/// [range] on both axes so that the desktop's edge does not squash it. macOS
/// shrinks a window pushed past the visible area rather than letting it hang
/// over, and a squashed window cuts the mascot's hop short and skews where the
/// sprite catches the pointer.
///
/// A range too narrow to hold the window leaves that axis where it stands,
/// rather than clamping to a bound that has crossed its opposite.
Rect wholeWithin(Rect bounds, Roam range, Size span) {
  final left = range.to >= range.from
      ? bounds.left.clamp(range.from, range.to).toDouble()
      : bounds.left;
  final top = range.floor >= range.ceiling
      ? bounds.top.clamp(range.ceiling, range.floor).toDouble()
      : bounds.top;
  return Rect.fromLTWH(left, top, span.width, span.height);
}
