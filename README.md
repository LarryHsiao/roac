# Roäc

A desktop mascot for macOS that answers questions about your own notes.

A small raven floats above your other windows and wanders across the screen. Click it and a speech bubble opens; type a question and it answers by
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
flutter test                  # 116 tests
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
| `lib/sprite.dart` | The raven and its three looks — breathing at rest, hopping and leaning while walking, still with its eye shut when pinned. All drawn, no art assets |
| `lib/bubble.dart` | The speech bubble: what Roäc last said, and the field you ask it through |
| `lib/saying.dart` | The one place a named cause becomes a sentence. Everything else names what went wrong and carries the values |
| `lib/l10n/` | The words Roäc speaks. `app_en.arb` and `app_zh.arb` are written by hand; `words*.dart` beside them are generated from those and committed, so a fresh clone analyses and tests without a generation step |
| `lib/counsel.dart` | The subprocess. Starts the CLI, reads its streamed JSON a line at a time, yields the answer as it grows, carries the conversation's name for a follow-up, and kills it the moment nobody is listening |
| `lib/pack.dart` | The character-pack format and its loader: reads a pack zip, or says plainly why it will not |
| `lib/latch.dart` | A re-entrancy latch. Drops overlapping runs of one task and reports a lasting failure once, not on every tick |
| `macos/Runner/MainFlutterWindow.swift` | Makes the window see-through. Flutter's own options cannot reach these three properties |

Notable constants: the window is `160` square at rest and opens at `420 × 300`
to speak, growing from there as an answer needs it, up to `0.8` of the
display's visible height; the sprite within it is `120`. The mascot walks at `42` logical pixels
per second and changes its mind every 2–7 seconds. The cursor is sampled at
30 Hz. A CLI that says nothing for `90` seconds is given up on — measured
between one line of its stream and the next, so a long answer is never cut off
for being long.

## The tongues he speaks

English and Traditional Chinese, chosen by the system and never asked about.
A reader whose language Roäc does not speak is answered in English rather
than in silence.

Traditional and Simplified are not one tongue with two spellings, so a
Simplified reader is given English too. Flutter's own matching would hand
them the Traditional text on the strength of a shared language code, which is
why `tongueFor` in `lib/main.dart` does the choosing instead: the script
decides, and where a system names no script, the regions that read
Traditional — `TW`, `HK`, `MO` — stand in for it.

The Chinese strings live in `app_zh.arb` rather than `app_zh_Hant.arb`
because the generator insists a script-coded file have a base beside it, and
one file of Traditional text is better than two identical ones.

**The answers themselves are not translated.** They come back in whatever
language the CLI answers in, which is the language your notes are written in.
A complaint from the CLI or the shell passes through in its own words for the
same reason — `Complaint` in `lib/counsel.dart` is the trouble that carries
foreign words, and the only one the render does not translate.

Roäc's own troubles do not travel as sentences. `Trouble` in
`lib/counsel.dart` and `Flaw` in `lib/pack.dart` are sealed sets naming *what
went wrong* — nothing was asked, the CLI fell silent, a pack names a strip it
does not hold — each carrying the values its sentence needs. `lib/saying.dart`
is the one place that turns a named cause into a sentence, and the only place
that knows a reader's tongue at all. A file that talks to a subprocess, or
reads a stranger's zip, has no business composing English.

Because both sets are `sealed`, adding a cause without a sentence for it is a
compile error rather than a blank line at run time.

**One caveat about the pack flaws.** They are handed to
`FlutterError.reportError`, which reaches a debug console and nothing else. A
release build has no console, so today a person who installs a bad pack sees
the built-in bird and no explanation. The sentences exist and are translated;
what is missing is a place to show them.

To see either tongue without changing your system, launch him with one named:

```sh
build/macos/Build/Products/Debug/roac.app/Contents/MacOS/roac -AppleLanguages "(zh-Hant-TW)"
```

## Character packs

Roäc draws himself, and needs no pack to work. A pack is an optional
replacement, kept in `~/Library/Application Support/roac/packs` — or wherever
`ROAC_PACKS` points — and chosen by `ROAC_PACK`, or else the first by name.

One is a zip holding a manifest and a PNG strip for each gait:

```json
{
  "format": 1,
  "name": "Roäc", "author": "...", "licence": "...",
  "frame": { "width": 120, "height": 120 },
  "gaits": {
    "idle":    { "image": "idle.png",    "frames": 4, "sequence": [0,1,2,3], "msPerFrame": 600 },
    "walking": { "image": "walking.png", "frames": 3, "sequence": [0,1,0,2], "pxPerFrame": 5 },
    "pinned":  { "image": "pinned.png",  "frames": 1 }
  }
}
```

Three things about that are worth an artist's attention:

- **A `sequence` may play a frame twice**, which is why a walk is three
  drawings and not four: passing, near footfall, passing, far footfall.
- **Idle counts milliseconds; walking counts pixels travelled.** A walk timed
  by the clock would skate whenever the speed changed.
- **Only one direction is drawn.** Roäc mirrors it when he turns.

`packs/roac-raven.zip` is Roäc himself, written out by

```sh
flutter test tool/make_pack.dart
```

It is committed so that it can be opened and copied — the format's worked
example, made by the same code that draws the bird on screen.

**Roäc wears the installed copy, not this one.** Regenerating the pack changes
the file in the repo and nothing else, so after running the tool, install it
again or you will go on looking at the pack you had before:

```sh
cp packs/roac-raven.zip ~/Library/Application\ Support/roac/packs/
```

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

## Licence

The code is **MIT** — see [LICENSE](LICENSE). Take it, change it, sell it.

**The raven in `lib/sprite.dart` is code, and MIT like the rest** — it is drawn
in Dart, not shipped as an image, so the grant above covers it entirely.

Any character art distributed *for* Roäc — a sprite sheet, an image pack — is a
separate work and carries its own licence and its own terms. This grant says
nothing about such art either way, and none is distributed here.
