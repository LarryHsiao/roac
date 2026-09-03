# Roäc

A desktop mascot for macOS that answers questions about your own notes.

A small, faceless sprite floats above your other windows and wanders across the
screen. Click it and a speech bubble opens; type a question and it answers by
running the Claude Code CLI over a local markdown knowledge base. Nothing is
uploaded — the CLI reads the files on this machine, under your own credentials.

Named for the raven of Erebor, son of Carc, who bore tidings to Thorin.

## Requirements

| | |
|---|---|
| Flutter | The revision pinned in `.metadata` — `3b62efc2a3` — which is 3.38.7 stable. Dart SDK `^3.10.7`, from `pubspec.yaml` |
| Platform | macOS. Windows is scaffolded but unimplemented; Linux is out of scope |
| CLI | `claude` on your login shell's `PATH` and already authenticated |
| Notes | A directory of markdown, named by `knowledgeBase` in `lib/counsel.dart` |

Two packages carry the window: **`window_manager`** makes it frameless,
transparent, always-on-top and movable, and **`screen_retriever`** reports the
cursor position and the display layout. The cursor has to be read from the
screen because a window ignoring mouse events cannot report the pointer
crossing back onto the sprite.

`knowledgeBase` is currently hard-coded to `/Users/larryhsiao/Minerva`. Change
that constant to point Roäc at your own notes; there is no configuration file
yet.

## Running

```sh
flutter run -d macos          # with hot reload
flutter build macos --debug   # or build, then open build/macos/Build/Products/Debug/roac.app
flutter test                  # 33 tests
flutter analyze
```

## Using it

| Gesture | Effect |
|---|---|
| Drag the sprite | Move it. It stops roaming, then takes it up again after a moment |
| Click the sprite | Open the speech bubble; click again to close it |
| `Esc` | Close the speech bubble |
| Right-click the sprite | Pin it in place — no walking, no breathing, border turns grey. Right-click again to release |

A pinned mascot is still yours to carry: dragging one moves it and leaves it
pinned where you set it down.

**The first click on an inactive Roäc is consumed activating it.** Click once to
bring it forward, then the gesture lands. This follows from
`WindowOptions(skipTaskbar: true)` in `lib/main.dart`, which `window_manager`'s
macOS implementation carries out by setting the application's activation policy
to accessory — that part lives in the package, not in this tree.

## How it is put together

| File | Responsibility |
|---|---|
| `lib/main.dart` | `Perch` — the state machine. Walks the window across the desktop, carries the drag, the pin and the bubble, and keeps the transparent margin click-through |
| `lib/roaming.dart` | `Gait`, `Facing`, `Stance`, and the pure geometry: where the mascot may stand on its display, and how a window is put back whole when the desktop has squashed it |
| `lib/sprite.dart` | The placeholder mascot and its three looks — breathing at rest, hopping and leaning while walking, frozen when pinned. All drawn, no art assets |
| `lib/bubble.dart` | The speech bubble: what Roäc last said, and the field you ask it through |
| `lib/counsel.dart` | The subprocess. Starts the CLI, drains its pipes, kills it if it outruns its patience, and reports either an `Answer` or a `Trouble` |
| `lib/latch.dart` | A re-entrancy latch. Drops overlapping runs of one task and reports a lasting failure once, not on every tick |
| `macos/Runner/MainFlutterWindow.swift` | Makes the window see-through. Flutter's own options cannot reach these three properties |

Notable constants: the window is `160` square at rest and `420 × 300` while
speaking; the sprite within it is `120`. The mascot walks at `42` logical pixels
per second and changes its mind every 2–7 seconds. The cursor is sampled at
30 Hz. The CLI is given 2 minutes before it is killed.

## Two decisions not to undo by accident

**The macOS app sandbox is deliberately absent** from both
`macos/Runner/DebugProfile.entitlements` and `Release.entitlements`. A sandboxed
app cannot `exec` an arbitrary binary at all — there is no entitlement that
permits it — so the CLI could not be reached with the sandbox in place. Roäc
therefore holds ordinary user-level file access rather than a container, and
cannot be distributed through the Mac App Store.

**The CLI is run *inside* the knowledge base, not merely granted it.** A
windowed app inherits a working directory of `/`, and `--add-dir` widens what
the CLI may read without telling it where to look; rooted at the filesystem
root the search finds nothing and the answer comes back wrong. `askCounsel`
passes `workingDirectory: knowledgeBase` for this reason.

Two smaller choices in the same command, for the same file:

- It goes through a **login shell** (`/bin/zsh -lc`) because a windowed app
  inherits almost none of your `PATH`.
- The shell **`exec`s** the CLI, so the process handle is the CLI itself and
  killing it kills the thing that is thinking.
- The question and the directory are passed as **positional arguments**, never
  spliced into the command string, so nothing a question contains can change
  what runs.

## Testing

Pure logic — the roaming geometry, the latch, the counsel's classification of a
process result — is unit-tested directly. `test/perch_test.dart` stands a mock
desktop in for both plugins' method channels so the state machine itself can be
exercised without a window or a screen.

Two gaps worth knowing about:

- **Nothing drives the window-resize round-trip.** The mocked replies do not
  arrive within the frames a widget test pumps — which is why `perch_test.dart`
  carries its own `settle` helper rather than `pumpAndSettle` — so the tests
  reach the state machine but not the geometry that follows from it. The
  bubble's close path rests on manual checking.
- **Nothing tests the animation by eye.** Whether the mascot *looks* alive is a
  judgement no assertion makes for you.

## Not yet built

Token streaming into the bubble, conversation continuity via `--resume`, a
menu-bar quit, launch at login, and Windows support. Replies currently render as
raw markdown rather than formatted text.

The sprite is a plain rounded square with no face, on purpose — a character has
not been chosen. Its motion is drawn rather than played from frames, so real
sprite art replaces `lib/sprite.dart` and nothing else.
