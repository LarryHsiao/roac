# Changelog

All notable changes to Roäc are recorded here, starting from this release —
earlier versions shipped without one, and this file does not attempt to
reconstruct their history.

The format follows [Keep a Changelog](https://keepachangelog.com/), and
version numbers follow the `major.minor.patch` scheme named in `pubspec.yaml`.

## 1.0.4

### Fixed

- A manual "Check for updates" no longer buries Sparkle/WinSparkle's own
  native dialog beneath the settings panel — Roäc's always-on-top window
  now steps aside for the check, and steps back once the window is
  genuinely focused again.

### Added

- The settings panel names the version currently running, beside the
  "Check now" button.
