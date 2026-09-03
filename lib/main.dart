import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'bubble.dart';
import 'counsel.dart';
import 'latch.dart';
import 'roaming.dart';
import 'sprite.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // No titleBarStyle here: setAsFrameless() below strips the title bar view
  // outright, and being applied last it overwrites whatever the option set.
  const options = WindowOptions(
    size: Size(restingSize, restingSize),
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    alwaysOnTop: true,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setAsFrameless();
    await windowManager.setHasShadow(false);
    await windowManager.setResizable(false);
    await windowManager.show();
  });

  runApp(const Roac());
}

class Roac extends StatelessWidget {
  const Roac({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Perch(),
      ),
    );
  }
}

/// Where the sprite sits: it walks the window across the desktop, carries the
/// drag and the pin, and keeps the window's transparent margin click-through.
class Perch extends StatefulWidget {
  const Perch({super.key});

  @override
  State<Perch> createState() => _PerchState();
}

class _PerchState extends State<Perch> with WindowListener {
  /// How often the cursor is sampled. While the pointer is off the sprite the
  /// window ignores mouse events outright, so its own events cannot report the
  /// crossing back — the position must be read from the screen instead.
  static const _cursorInterval = Duration(milliseconds: 33);

  /// How often a walking mascot takes a step, and how far it gets in a second.
  static const _strideInterval = Duration(milliseconds: 33);
  static const _walkSpeed = 42.0;

  /// The bounds of a spell of walking or resting, before it chooses anew.
  static const _shortestSpell = Duration(seconds: 2);
  static const _longestSpell = Duration(seconds: 7);

  final _fortune = math.Random();

  final _placement = Latch('reading where the window stands');
  final _step = Latch('taking a step');
  final _cursor = Latch('following the cursor across the sprite');
  final _room = Latch('making room for the bubble');

  Timer? _cursorWatch;
  Timer? _strideWatch;
  Timer? _spell;

  Gait _gait = Gait.idle;
  Stance _stance = const Stance(left: 0, facing: Facing.right);
  double _top = 0;
  Size _span = const Size(restingSize, restingSize);
  Roam _range = (from: 0, to: 0, ceiling: 0, floor: 0);

  bool _clicksPassThrough = false;
  bool _speaking = false;
  bool _waiting = false;
  Counsel? _counsel;

  /// Bumped whenever the window is deliberately given new room, so a placement
  /// read that began before the change cannot apply its stale reckoning after.
  int _arrangement = 0;

  /// Bumped whenever a question is asked or abandoned, so a slow answer cannot
  /// speak over the one the user is actually waiting on.
  int _asking = 0;

  /// Where the sprite is truly drawn: it always keeps the window's bottom-left
  /// resting square, which at rest is the whole window and while the bubble is
  /// open is the corner beneath it.
  Rect get _spriteOnScreen => spriteBoundsWithin(
        Rect.fromLTWH(
          _stance.left,
          _top + _span.height - restingSize,
          restingSize,
          restingSize,
        ),
      );

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    unawaited(_comeAlive());
  }

  @override
  void dispose() {
    _cursorWatch?.cancel();
    _strideWatch?.cancel();
    _spell?.cancel();
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMoved() {
    // While walking, the mascot is the only thing moving the window and it
    // already knows where it put itself. Any other move is the user's hand.
    if (_gait == Gait.walking) return;
    unawaited(_readWindowPlacement());
  }

  /// Reads where the window stands before the first sample, so that no tick
  /// ever tests the cursor or a step against the placeholder bounds.
  Future<void> _comeAlive() async {
    await _readWindowPlacement();
    if (!mounted) return;
    _cursorWatch = Timer.periodic(_cursorInterval, (_) => _followCursor());
    _strideWatch = Timer.periodic(_strideInterval, (_) => _stride());
    _armSpell();
  }

  Future<void> _readWindowPlacement() => _placement.run(() async {
        final mine = _arrangement;
        final bounds = await windowManager.getBounds();
        final displays = await ScreenRetriever.instance.getAllDisplays();
        // The window was deliberately resized while this read was in flight;
        // that change knows better than these bounds do.
        if (!mounted || mine != _arrangement) return;
        final range = roamingRangeOn(displays, bounds, _span) ?? _range;
        // A walking mascot is the authority on its own left edge: the bounds
        // just read are a step or two behind it already.
        final standing = _gait == Gait.walking
            ? Rect.fromLTWH(_stance.left, bounds.top, bounds.width, bounds.height)
            : bounds;
        final whole = wholeWithin(standing, range, _span);
        setState(() {
          _top = whole.top;
          _span = whole.size;
          _stance = Stance(left: whole.left, facing: _stance.facing);
        });
        _range = range;
        if (whole != standing) await windowManager.setBounds(whole);
      });

  /// One step of the walk. It is the window that moves, not the widget.
  Future<void> _stride() => _step.run(() async {
        if (_gait != Gait.walking || _speaking) return;
        final distance = _walkSpeed *
            _strideInterval.inMilliseconds /
            Duration.millisecondsPerSecond;
        final next = _stance.stride(distance, _range);
        if (next == _stance) return;
        await windowManager.setPosition(Offset(next.left, _top));
        // A hand may have grabbed the mascot while the window was moving, and
        // that hand has the last word on where it stands.
        if (!mounted || _gait != Gait.walking) return;
        setState(() => _stance = next);
      });

  /// Arms the next spell, putting out any that still stands.
  ///
  /// Every spell is armed here and nowhere else, so there is never more than
  /// one alive: a second, unreachable timer would go on choosing gaits that
  /// no one could stop, and would outlive [dispose]. A mascot with its bubble
  /// open attends to you and roams no further, so it is given no spell at all
  /// until the bubble is shut.
  void _armSpell() {
    _spell?.cancel();
    if (_speaking) return;
    _spell = Timer(_spellLength(), _chooseGait);
  }

  /// Picks the next spell of walking or resting, and how long it will last.
  ///
  /// The placement is read afresh each spell, so a display that has since been
  /// unplugged or rearranged cannot pen the mascot inside a range that no
  /// longer describes the desktop.
  void _chooseGait() {
    unawaited(_readWindowPlacement());
    final walking = _fortune.nextBool();
    setState(() {
      _gait = walking ? Gait.walking : Gait.idle;
      if (walking) {
        _stance = Stance(
          left: _stance.left,
          facing: Facing.values[_fortune.nextInt(Facing.values.length)],
        );
      }
    });
    _armSpell();
  }

  Duration _spellLength() {
    final span = _longestSpell.inMilliseconds - _shortestSpell.inMilliseconds;
    return Duration(
      milliseconds: _shortestSpell.inMilliseconds + _fortune.nextInt(span),
    );
  }

  /// The pin: a secondary click holds the mascot where it stands, and another
  /// sets it roaming again from there.
  void _togglePin() {
    final pinning = _gait != Gait.pinned;
    setState(() => _gait = pinning ? Gait.pinned : Gait.idle);
    if (pinning) {
      _spell?.cancel();
      return;
    }
    _armSpell();
  }

  /// A grabbed mascot stops walking, and takes up roaming again when the spell
  /// that follows begins. A pinned one is still yours to carry, and stays put
  /// wherever you set it down.
  void _grabbed() {
    unawaited(windowManager.startDragging());
    if (_gait == Gait.pinned) return;
    setState(() => _gait = Gait.idle);
    _armSpell();
  }

  /// Hands the pointer to the sprite while the cursor is over it, and to
  /// whatever lies beneath the window while it is not. An open bubble takes
  /// the whole window, so that the field and the button beneath it answer.
  Future<void> _followCursor() => _cursor.run(() async {
        final passThrough = _speaking ? false : await _cursorIsAway();
        if (passThrough == _clicksPassThrough) return;
        // Recorded only once the window has actually taken the change, so a
        // failed call leaves the two in step and the next tick tries again.
        await windowManager.setIgnoreMouseEvents(passThrough);
        _clicksPassThrough = passThrough;
      });

  /// Whether the cursor lies off the sprite, so the click belongs to whatever
  /// stands beneath the window.
  Future<bool> _cursorIsAway() async {
    final cursor = await ScreenRetriever.instance.getCursorScreenPoint();
    return !_spriteOnScreen.contains(cursor);
  }

  /// Opens the bubble, or shuts it. A click that arrives while the window is
  /// still changing size is let go rather than queued.
  void _tapped() => unawaited(
        _room.run(() => _speaking ? _closeBubble() : _openBubble()),
      );

  /// The mascot falls still and stops roaming the moment it is asked to
  /// speak, before the window is given the room to hold the bubble.
  Future<void> _openBubble() async {
    _spell?.cancel();
    setState(() {
      _speaking = true;
      if (_gait == Gait.walking) _gait = Gait.idle;
    });
    await _standAs(speakingSize);
    if (!mounted) return;
    await windowManager.focus();
  }

  Future<void> _closeBubble() async {
    _asking++;
    setState(() {
      _speaking = false;
      _waiting = false;
      _counsel = null;
    });
    await _standAs(const Size(restingSize, restingSize));
    if (_gait != Gait.pinned) _armSpell();
  }

  /// Gives the window [span], keeping the mascot's own corner where it stands:
  /// the bubble grows upward and to the side, so the sprite does not leap
  /// across the desktop merely because it began to speak.
  Future<void> _standAs(Size span) async {
    _arrangement++;
    final wanted = Rect.fromLTWH(
      _stance.left,
      _top + _span.height - span.height,
      span.width,
      span.height,
    );
    final displays = await ScreenRetriever.instance.getAllDisplays();
    if (!mounted) return;
    final range = roamingRangeOn(displays, wanted, span) ?? _range;
    final whole = wholeWithin(wanted, range, span);
    setState(() {
      _top = whole.top;
      _span = span;
      _stance = Stance(left: whole.left, facing: _stance.facing);
    });
    _range = range;
    await windowManager.setBounds(whole);
  }

  /// Puts the question to the counsel and shows whatever comes back — an
  /// answer or the plain reason there is none.
  Future<void> _ask(String question) async {
    final mine = ++_asking;
    setState(() {
      _waiting = true;
      _counsel = null;
    });
    final counsel = await askCounsel(question);
    // The user has since closed the bubble or asked something else; this
    // answer is no longer the one they are waiting on.
    if (!mounted || mine != _asking) return;
    setState(() {
      _waiting = false;
      _counsel = counsel;
    });
  }

  @override
  Widget build(BuildContext context) {
    // The gesture spans the whole resting window while the sprite fills only
    // its middle; the margin never reaches Flutter, because the window is
    // ignoring mouse events whenever the cursor is out there.
    final mascot = GestureDetector(
      onTap: _tapped,
      onPanStart: (_) => _grabbed(),
      onSecondaryTap: _togglePin,
      child: Sprite(gait: _gait, facing: _stance.facing),
    );
    return _speaking ? _bubbleAbove(mascot) : mascot;
  }

  /// The bubble is a sibling of the mascot, never its parent: a tap meant for
  /// the field must not also read as a tap on the sprite that shuts it.
  Widget _bubbleAbove(Widget mascot) {
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _tapped},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Bubble(
              counsel: _counsel,
              waiting: _waiting,
              onAsk: (question) => unawaited(_ask(question)),
            ),
          ),
          SizedBox(
            width: restingSize,
            height: restingSize,
            child: mascot,
          ),
        ],
      ),
    );
  }
}
