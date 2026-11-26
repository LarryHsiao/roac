# Changelog

All notable changes to Roäc are recorded here, starting from this release —
earlier versions shipped without one, and this file does not attempt to
reconstruct their history.

The format follows [Keep a Changelog](https://keepachangelog.com/), and
version numbers follow the `major.minor.patch` scheme named in `pubspec.yaml`.

## 1.0.7

### Added

- A fresh install opens a three-step welcome: find the `claude` CLI, choose
  the notes folder, begin. It can be skipped, and is not shown to anyone who
  ran an earlier release.
- A first-run setup guide in Traditional Chinese, `docs/setup.md`.

### Fixed

- On Windows the default notes folder, packs folder and settings file are now
  found under the user's own folders (`%USERPROFILE%` and `%APPDATA%`).
  What an earlier release wrote elsewhere is still used while the new place
  is empty.

## 1.0.6

### Added

- A TARS companion pack, `packs/tars-robot.zip`.

## 1.0.5

### Fixed

- Tables, quotes and headings in an answer are now drawn in the bubble's
  own light ink — they had been falling to the light theme's near-black on
  the dark fill, and were all but invisible.
- Answers read a size larger, table columns take the width their words
  need (a long URL scrolls sideways instead of breaking mid-word), and the
  faint hint text meets the WCAG AA contrast bar.

## 1.0.4

### Fixed

- A manual "Check for updates" no longer buries Sparkle/WinSparkle's own
  native dialog beneath the settings panel — Roäc's always-on-top window
  now steps aside for the check, and steps back once the window is
  genuinely focused again.

### Added

- The settings panel names the version currently running, beside the
  "Check now" button.
