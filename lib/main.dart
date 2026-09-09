import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:auto_updater/auto_updater.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'bubble.dart';
import 'counsel.dart';
import 'l10n/words.dart';
import 'latch.dart';
import 'pack.dart';
import 'roaming.dart';
import 'saying.dart';
import 'settings.dart';
import 'settings_panel.dart';
import 'sprite.dart';
import 'update_note.dart';
import 'update_note_banner.dart';

/// Where a fresh launch's last-seen-version note is kept, so a launch that
/// landed on a newer build than the last one seen can say so once.
const _lastSeenVersionKey = 'last_seen_version';

/// `appcast.xml`, committed at the repo root and served over its raw GitHub
/// URL — no separate hosting, the same way GitHub already serves the release
/// binaries the feed points at.
const _appcastFeedUrl =
    'https://raw.githubusercontent.com/LarryHsiao/roac/main/appcast.xml';

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

/// What the running app believes about the world it stands in.
final _theWorld = Platform.environment;

/// Which of Roäc's tongues [asked] should be answered in.
///
/// [spoken] is the list Flutter offers — every tongue Roäc has words for. It
/// is not consulted: this rule names its two outright, and answering with a
/// tongue that is not in that list would be a bug in this function rather
/// than something to discover at run time. The parameter is here because
/// `localeResolutionCallback` hands it over.
///
/// Traditional Chinese, or else English — a reader whose language Roäc does
/// not speak is answered in English rather than in silence.
///
/// The choosing is done here rather than left to Flutter's own matching,
/// which would hand a Simplified reader the Traditional text on the strength
/// of a shared language code alone. Traditional and Simplified are not one
/// tongue with two spellings; a reader of one is not served by the other.
/// The Chinese strings live in `app_zh.arb` and not `app_zh_Hant.arb` because
/// the generator insists a script-coded file have a base beside it, and one
/// file of Traditional text is better than two identical ones.
Locale tongueFor(Locale? asked, Iterable<Locale> spoken) {
  const english = Locale('en');
  if (asked == null || asked.languageCode != 'zh') return english;
  // macOS names the script outright (zh-Hant-TW); where it does not, the
  // places that read Traditional say so by their region.
  const traditional = {'TW', 'HK', 'MO'};
  final isTraditional =
      asked.scriptCode == 'Hant' || traditional.contains(asked.countryCode);
  return isTraditional ? const Locale('zh') : english;
}

class Roac extends StatelessWidget {
  const Roac({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: Words.localizationsDelegates,
      supportedLocales: Words.supportedLocales,
      localeResolutionCallback: tongueFor,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Perch(environment: _theWorld),
      ),
    );
  }
}

/// How a question is put — named so a test may stand in for the real CLI, in
/// the same shape as the shell that counsel.dart stands in for.
typedef Asking = Stream<Counsel> Function(String question, {String? resuming});

/// How a check for a newer release is made — named so a test may stand in
/// for the real Sparkle/WinSparkle call, in the same shape as [Asking].
typedef CheckForUpdates = Future<void> Function({required bool inBackground});

/// How the once-per-launch update note is computed — named so a test may
/// stand in for the real prefs/package-info reads, in the same shape as
/// [Asking].
typedef UpdateNoteCheck = Future<UpdateNoteState> Function();

/// Where the sprite sits: it walks the window across the desktop, carries the
/// drag and the pin, and keeps the window's transparent margin click-through.
class Perch extends StatefulWidget {
  const Perch({
    this.asking,
    this.environment = const {},
    this.chooseFolder = fromTheFilesystem,
    this.checkForUpdates,
    this.updateNoteCheck,
    super.key,
  });

  /// How a question is put. Null in the app, which puts it to the real CLI
  /// inside whichever notes the settings name; a test stands in its own.
  final Asking? asking;

  /// What the world says about where packs are kept and which to wear. Empty
  /// by default so a test wears nothing it did not put there itself; the app
  /// hands it the real environment.
  final Map<String, String> environment;

  /// How the settings panel's folder fields are chosen. The real dialog in
  /// the app; a test stands in its own, in the same shape as [asking].
  final ChooseFolder chooseFolder;

  /// How a check for a newer release is made. Null in the app, which asks
  /// the real `auto_updater` plugin; a test stands in its own, in the same
  /// shape as [asking].
  final CheckForUpdates? checkForUpdates;

  /// How the update note is computed on launch. Null in the app, which reads
  /// the real last-seen version from local prefs and weighs it against the
  /// real running version; a test stands in its own, in the same shape as
  /// [asking].
  final UpdateNoteCheck? updateNoteCheck;

  @override
  State<Perch> createState() => _PerchState();
}

/// Which settings a question in flight is asked with: [live] once there is
/// one, falling back to [begunAtLaunch] only until it lands.
///
/// A question asked before the first read completes must still be asked with
/// something rather than nothing, so the read begun at launch stands in. But
/// once a read has landed — including one refreshed after the settings panel
/// writes a change — that is the one worth trusting: it is the only copy the
/// settings panel ever updates, so reading it live is what lets a changed
/// `claudeConfig` or `notes` reach the very next question with nothing to
/// restart.
Future<Settings> settledFor(Settings? live, Future<Settings> begunAtLaunch) =>
    live == null ? begunAtLaunch : Future.value(live);

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
  final _growing = Latch('giving the bubble more room');

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

  /// What Roäc is presently being told, if anything. Letting go of it kills
  /// the CLI, so an abandoned question stops costing the moment it is dropped.
  StreamSubscription<Counsel>? _listening;

  /// The conversation the last answer belonged to, so a follow-up carries on
  /// from it rather than beginning again. Forgotten when the bubble shuts.
  String? _conversation;

  /// The question [_counsel] or [_waiting] answers, so the bubble can show it
  /// beside what came back. Null before the first question of a fresh bubble.
  String? _asked;

  /// The character being worn, if a pack was found and could be read.
  Character? _worn;

  /// What Roäc has been told about the world, once it has been read.
  ///
  /// Begun the moment the perch is raised, and awaited by everything that
  /// needs it — so there is no instant in which a question could be asked
  /// with nowhere to ask it. [_settings] is the same thing once it has
  /// landed, kept for the things that must read it without waiting.
  late final Future<Settings> _told = settingsIn(widget.environment);
  Settings? _settings;

  /// The packs found in whatever folder [Settings.packs] currently names —
  /// what the settings panel offers, kept alongside the pack actually worn
  /// rather than read afresh each time the panel opens.
  List<String> _installedPacks = const [];

  /// Whether the settings panel stands in the bubble's own place.
  bool _settingsOpen = false;

  /// What to say about a launch that landed on a newer version than the last
  /// one seen — null once said, once there was nothing to say, or once
  /// dismissed. Shown the next time the bubble opens, since the resting
  /// mascot alone has no chrome to say it in.
  UpdateNoteState? _note;

  /// Every pixel of ground walked since Roäc woke. A packed walk steps by
  /// this rather than by the clock, so the legs keep pace with the body.
  double _walked = 0;

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
    unawaited(_showUpdateNoteIfAny());
    unawaited(_checkForUpdate(inBackground: true));
  }

  /// Weighs the update note against local prefs, and holds onto it — shown
  /// once the bubble is next opened — if there is one worth saying.
  Future<void> _showUpdateNoteIfAny() async {
    try {
      final state = await (widget.updateNoteCheck ?? _realUpdateNoteCheck)();
      if (state.shouldShow && mounted) setState(() => _note = state);
    } catch (_) {
      // Best-effort, the same as the check itself: a prefs or package-info
      // read that fails must never stand between the mascot and its window.
    }
  }

  /// The real update-note check: the running version against the last one
  /// local prefs remember, via [updateNoteOnLaunch].
  Future<UpdateNoteState> _realUpdateNoteCheck() async {
    final info = await PackageInfo.fromPlatform();
    return updateNoteOnLaunch(
      readLastSeenVersion: () async {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(_lastSeenVersionKey);
      },
      writeLastSeenVersion: (version) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastSeenVersionKey, version);
      },
      currentVersion: info.version,
    );
  }

  /// Asks for a newer release. [inBackground] true is the silent launch-time
  /// check; false is the settings panel's manual one, which lets
  /// Sparkle/WinSparkle raise their own "up to date" or "update found"
  /// dialog rather than Roäc inventing a status of its own.
  ///
  /// Fails silent by design: a missing feed or a network hiccup is not worth
  /// surfacing, on launch or on a manual ask alike — the next check tries
  /// again.
  Future<void> _checkForUpdate({required bool inBackground}) async {
    try {
      final custom = widget.checkForUpdates;
      if (custom != null) {
        await custom(inBackground: inBackground);
        return;
      }
      await autoUpdater.setFeedURL(_appcastFeedUrl);
      await autoUpdater.checkForUpdates(inBackground: inBackground);
    } catch (_) {
      // Fail silent by design — see the doc comment above.
    }
  }

  @override
  void dispose() {
    _cursorWatch?.cancel();
    _strideWatch?.cancel();
    _spell?.cancel();
    unawaited(_listening?.cancel());
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
    await _beTold();
    await _wearAPack();
    await _readWindowPlacement();
    if (!mounted) return;
    _cursorWatch = Timer.periodic(_cursorInterval, (_) => _followCursor());
    _strideWatch = Timer.periodic(_strideInterval, (_) => _stride());
    _armSpell();
  }

  /// Reads what Roäc has been told about the world, before anything is done
  /// that depends on it.
  ///
  /// A settings file that will not read is said aloud rather than quietly
  /// replaced by the defaults: somebody wrote it, and would otherwise be left
  /// wondering why it is being ignored.
  Future<void> _beTold() async {
    final told = await _told;
    if (!mounted) return;
    setState(() => _settings = told);
    final trouble = told.trouble;
    if (trouble == null) return;
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: saidOfMisread(Words.of(context), trouble),
        library: 'roac',
        context: ErrorDescription('reading what Roäc has been told'),
      ),
    );
  }

  /// Reads what Roäc has been told, afresh — called after a write, since an
  /// environment variable may still outrank what was just written.
  Future<void> _refreshSettings() async {
    final told = await settingsIn(widget.environment);
    if (!mounted) return;
    setState(() => _settings = told);
  }

  /// Tells Roäc one thing: writes it to the settings file, then reads
  /// everything afresh and re-wears a pack where what changed could change
  /// which one is worn.
  ///
  /// A write that fails is said to the console rather than swallowed — the
  /// same debt the README already names for a pack that will not read: this
  /// app has nowhere else to say it yet.
  Future<void> _tellSettings(String key, String? value) async {
    final trouble = await settingsWrite({key: value}, widget.environment);
    if (!mounted) return;
    if (trouble != null) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: Words.of(context).settingsUnwritable(trouble),
          library: 'roac',
          context: ErrorDescription('writing what Roäc was told'),
        ),
      );
    }
    await _refreshSettings();
    if (key == 'packs' || key == 'pack') await _wearAPack();
  }

  /// Opens the settings panel in the bubble's place, once something is known
  /// to show it.
  void _openSettings() {
    if (_settings == null) return;
    setState(() => _settingsOpen = true);
    // Never shrinks: a bubble already grown tall for a long answer keeps
    // that room, exactly as _grantRoom itself never gives room back.
    if (_span.height < settingsHeight) {
      unawaited(_standAs(Size(_span.width, settingsHeight)));
    }
  }

  void _closeSettings() => setState(() => _settingsOpen = false);

  void _toggleSettings() {
    if (_settingsOpen) {
      _closeSettings();
    } else {
      _openSettings();
    }
  }

  /// How a question is put: whatever a test handed over, or the real CLI run
  /// inside whichever notes Roäc has been told of.
  Stream<Counsel> _asking(String question, {String? resuming}) {
    final asking = widget.asking;
    if (asking != null) return asking(question, resuming: resuming);
    // Waits on the reading rather than guessing at an empty path. A CLI run
    // with nowhere to run would fail with a complaint about a directory,
    // which says nothing to the person who only asked a question.
    return Stream.fromFuture(settledFor(_settings, _told)).asyncExpand(
      (told) => askCounsel(
        question,
        resuming: resuming,
        notes: told.notes.value,
        claudeConfig: told.claudeConfig?.value,
      ),
    );
  }

  /// Wears whichever pack is chosen, if one can be read, and keeps the
  /// roster of installed packs current — the settings panel's own dropdown.
  ///
  /// A pack that is there and will not read is said aloud rather than passed
  /// over: somebody chose it, and would otherwise be left wondering why they
  /// are looking at the built-in bird.
  Future<void> _wearAPack() async {
    final settings = _settings;
    if (settings == null) return;
    final installed = await packsAvailableIn(settings.packs.value);
    if (!mounted) return;
    setState(() => _installedPacks = installed);
    final pack = await packWorn(settings.packs.value, settings.pack?.value);
    if (!mounted) return;
    switch (pack) {
      case null:
        // Nothing is chosen — because nothing names one, or because what was
        // chosen is no longer among the installed packs — so the drawn raven
        // is what is actually worn now, whatever stood before this reading.
        setState(() => _worn = null);
        return;
      case Unreadable(:final flaw):
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: saidOfFlaw(Words.of(context), flaw),
            library: 'roac',
            context: ErrorDescription('wearing a character pack'),
          ),
        );
      case Character():
        setState(() => _worn = pack);
    }
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
    final distance =
        _walkSpeed *
        _strideInterval.inMilliseconds /
        Duration.millisecondsPerSecond;
    final next = _stance.stride(distance, _range);
    if (next == _stance) return;
    await windowManager.setPosition(Offset(next.left, _top));
    // A hand may have grabbed the mascot while the window was moving, and
    // that hand has the last word on where it stands.
    if (!mounted || _gait != Gait.walking) return;
    setState(() {
      _walked += (next.left - _stance.left).abs();
      _stance = next;
    });
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
  void _tapped() =>
      unawaited(_room.run(() => _speaking ? _closeBubble() : _openBubble()));

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
    // Let go without waiting: killing the CLI is not something the click that
    // shut the bubble should be held up by.
    unawaited(_listening?.cancel());
    _listening = null;
    _conversation = null;
    setState(() {
      _speaking = false;
      _waiting = false;
      _counsel = null;
      _asked = null;
      _settingsOpen = false;
    });
    await _standAs(const Size(restingSize, restingSize));
    if (_gait != Gait.pinned) _armSpell();
  }

  /// Gives the bubble [more] room than it has, so far as the display allows.
  ///
  /// Never less than it stands at: an answer arriving should not make the
  /// window jump smaller. Dropped rather than queued while a resize is in
  /// flight, since a streamed answer asks again a moment later anyway.
  void _grantRoom(double more) => unawaited(
    _growing.run(() async {
      if (!_speaking) return;
      final wanted = heightGrownTo(
        wanted: _span.height + more,
        standing: _span.height,
        range: _range,
        span: _span,
      );
      if (wanted <= _span.height) return;
      await _standAs(Size(_span.width, wanted));
    }),
  );

  /// Gives the window [span], keeping the mascot's own corner where it stands:
  /// the bubble grows upward and to the side, so the sprite does not leap
  /// across the desktop merely because it began to speak.
  Future<void> _standAs(Size span) async {
    final mine = ++_arrangement;
    final wanted = Rect.fromLTWH(
      _stance.left,
      _top + _span.height - span.height,
      span.width,
      span.height,
    );
    final displays = await ScreenRetriever.instance.getAllDisplays();
    // Another size was called for while this one was in flight — the bubble
    // shut, say, while it was still being given room. Without this the window
    // is left at whichever resize *finished* last rather than the one last
    // asked for, and a shut bubble can be found standing in a tall window.
    if (!mounted || mine != _arrangement) return;
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

  /// Puts the question to the counsel and shows the answer as it arrives.
  ///
  /// A question already in flight is let go first, which kills the CLI behind
  /// it: whatever it was going to say, nobody is waiting for it now.
  void _ask(String question) {
    unawaited(_listening?.cancel());
    setState(() {
      _waiting = true;
      _counsel = null;
      _asked = question;
    });
    _listening = _asking(question, resuming: _conversation).listen(_heard);
  }

  /// Takes down what Roäc has said so far, and the conversation it belongs to.
  void _heard(Counsel counsel) {
    if (!mounted) return;
    setState(() {
      _waiting = false;
      _counsel = counsel;
      if (counsel is Answer) _conversation = counsel.session ?? _conversation;
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
      child: Sprite(
        gait: _gait,
        facing: _stance.facing,
        worn: _worn,
        walked: _walked,
      ),
    );
    return _speaking ? _bubbleAbove(mascot) : mascot;
  }

  /// Escape closes whichever is open — the settings panel first, since it
  /// stands on top of the ask that would otherwise be shut.
  void _escaped() {
    if (_settingsOpen) {
      _closeSettings();
    } else {
      _tapped();
    }
  }

  /// The settings panel in the bubble's own place, or the bubble itself.
  Widget _bubbleOrSettings() {
    final settings = _settings;
    if (_settingsOpen && settings != null) {
      return SettingsPanel(
        settings: settings,
        installedPacks: _installedPacks,
        onChanged: _tellSettings,
        onClose: _closeSettings,
        onCheckForUpdates: () =>
            unawaited(_checkForUpdate(inBackground: false)),
        chooseFolder: widget.chooseFolder,
      );
    }
    return Bubble(
      counsel: _counsel,
      waiting: _waiting,
      asked: _asked,
      onAsk: _ask,
      onWanting: _grantRoom,
      onSettings: _openSettings,
    );
  }

  /// The bubble is a sibling of the mascot, never its parent: a tap meant for
  /// the field must not also read as a tap on the sprite that shuts it.
  Widget _bubbleAbove(Widget mascot) {
    final note = _note;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _escaped,
        const SingleActivator(LogicalKeyboardKey.comma, meta: true):
            _toggleSettings,
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (note != null)
            UpdateNoteBanner(
              version: note.version,
              onDismiss: () => setState(() => _note = null),
            ),
          Expanded(child: _bubbleOrSettings()),
          SizedBox(width: restingSize, height: restingSize, child: mascot),
        ],
      ),
    );
  }
}
