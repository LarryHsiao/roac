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
| Notes | A directory of markdown — `Minerva` under your home directory, or wherever `ROAC_NOTES` points |

Two packages carry the window: **`window_manager`** makes it frameless,
transparent, always-on-top and movable, and **`screen_retriever`** reports the
cursor position and the display layout. The cursor has to be read from the
screen because a window ignoring mouse events cannot report the pointer
crossing back onto the sprite.

A third, **`flutter_markdown_plus`**, draws the answers. It was chosen over
`gpt_markdown` — the obvious candidate for LLM output — because that package
pulls in `flutter_math_fork`, `flutter_svg` and with them `http`: a network
client, in an app whose whole claim is that nothing leaves the machine.
`flutter_markdown_plus` brings one package, `markdown`, and no network.

**`url_launcher`** opens the links inside an answer. It is a Flutter-team
package, and the eight entries it adds to `pubspec.lock` are all its own — one
per platform, plus the interface they share — not third-party weight.

Roäc reads `~/Minerva` unless the `ROAC_NOTES` environment variable names
somewhere else. It is derived rather than written into the source, because an
absolute home path is true on one machine and wrong on every other. There is no
configuration file — the environment is the whole of it.

## Running

```sh
flutter run -d macos          # with hot reload
flutter build macos --debug   # or build, then open build/macos/Build/Products/Debug/roac.app
flutter test                  # 46 tests
flutter analyze
```

## Using it

| Gesture | Effect |
|---|---|
| Drag the sprite | Move it. It stops roaming, then takes it up again after a moment |
| Click the sprite | Open the speech bubble; click again to close it |
| Ask a second question | It carries on from the first. Shutting the bubble forgets the conversation and begins again |
| Tap a link in an answer | It opens in your browser. Where it will not open, its address goes to the clipboard and the bubble says so |
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
| `lib/counsel.dart` | The subprocess. Starts the CLI, reads its streamed JSON a line at a time, yields the answer as it grows, carries the conversation's name for a follow-up, and kills it the moment nobody is listening |
| `lib/latch.dart` | A re-entrancy latch. Drops overlapping runs of one task and reports a lasting failure once, not on every tick |
| `macos/Runner/MainFlutterWindow.swift` | Makes the window see-through. Flutter's own options cannot reach these three properties |

Notable constants: the window is `160` square at rest and `420 × 300` while
speaking; the sprite within it is `120`. The mascot walks at `42` logical pixels
per second and changes its mind every 2–7 seconds. The cursor is sampled at
30 Hz. A CLI that says nothing for `90` seconds is given up on — measured
between one line of its stream and the next, so a long answer is never cut off
for being long.

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

The mock stands in for both plugins' method channels, so the window's own
round-trip is driven too: a test opens the bubble, watches the window take
420 × 300, shuts it, and watches it give the room back.

One gap worth knowing about: **nothing tests the animation by eye.** Whether the
mascot *looks* alive is a judgement no assertion makes for you.

## Not yet built

A status-bar item, launch at login, and Windows support.

One rough edge remains: **the first click on an inactive Roäc is swallowed** by
macOS activating the app, which a status-bar item would sidestep.

The sprite is a plain rounded square with no face, on purpose — a character has
not been chosen. Its motion is drawn rather than played from frames, so real
sprite art replaces `lib/sprite.dart` and nothing else.

## Licence

The code is **MIT** — see [LICENSE](LICENSE). Take it, change it, sell it.

**Sprite art is not covered by that grant.** The placeholder square in
`lib/sprite.dart` is part of the code and MIT like the rest, but any character
art distributed for Roäc carries its own licence and its own terms. Art is a
separate work; this licence says nothing about it either way.
