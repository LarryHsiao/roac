# Releasing

Roäc checks for updates on launch and downloads them automatically via
Sparkle (macOS) / WinSparkle (Windows); Sparkle shows its own one-time
"install now?" consent alert before applying, and the settings panel's
"Check Now" button lets the same check be asked for by hand. The
build-and-publish flow below is unchanged by this — each publish script also
signs its artifact for Sparkle/WinSparkle and updates the `appcast.xml` feed
automatically, nothing manual to do after the build.

A TeamCity project (`Roac`), mirroring Orthanc's own, runs both platforms'
scripts unattended on every `v*` tag push. The same scripts also run fine by
hand for a local release — neither takes a CI-only input, and TeamCity's own
VCS root branch spec and trigger are what restrict it to tag pushes, not
anything the scripts themselves check.

## 0. One-time setup: signing keys

Both platforms need a signing keypair before the first release goes out,
generated via `dart run auto_updater:generate_keys` — run once per platform,
not once per release:

- **Windows**: writes `dsa_priv.pem` / `dsa_pub.pem` to the repo root.
  Generated. The public half, `dsa_pub.pem`, is committed and compiled into
  the `.exe` as a resource by `windows/runner/Runner.rc` — WinSparkle reads
  it from there at runtime to verify update signatures. The private half was
  moved into a Vaultwarden item named `roac-winsparkle-dsa` (the `password`
  field holding its base64) and deleted locally — the same shape as
  Orthanc's own `orthanc-winsparkle-dsa` item.
- **macOS**: an EdDSA keypair already sat in the signer's local keychain
  (generated during Orthanc's own macOS setup — Sparkle's own guidance is one
  signing key per publisher, not per app) and its public half is now in
  `macos/Runner/Info.plist` as `SUPublicEDKey`. The private half stays in the
  local keychain; a correctly single-base64-encoded backup lives in
  Vaultwarden's `sparkle-eddsa-key` item.

## 1. Build and publish

- **Windows**: `scripts/build_windows.ps1` — builds and packages
  `build\publish\roac-setup-<VERSION>.exe` (an Inno Setup installer,
  optionally Authenticode-signed if `-CertPath`/`-CertPassword` are given —
  Roäc has no code-signing certificate yet, so an unsigned build is the
  ordinary case for now) and `build\publish\roac-<VERSION>-windows.zip`.
  `scripts/release_github.ps1` then uploads both to a GitHub Release tagged
  `v<VERSION>` (created if it doesn't exist yet), signs the installer for
  WinSparkle (`dart run auto_updater:sign_update`, using the Vaultwarden-held
  private key), adds/replaces its `<item>` in `appcast.xml` via
  `scripts/update_appcast.py`, and commits and pushes the feed.
- **macOS, by hand**: `scripts/publish_macos.sh --publish` — builds, signs
  with whatever Developer ID identity is already in the local login
  keychain, notarizes via Vaultwarden's `apple-notarization` item, and
  uploads `build/publish/roac.dmg`, mirroring the Windows path exactly.
- **macOS, on CI**: `scripts/ci_build_macos_dmg.sh` is the unattended
  counterpart — a CI runner has no login keychain or Vaultwarden session, so
  every credential arrives as an env var instead: it imports the Developer
  ID certificate into a temporary keychain scoped to the build and notarizes
  via an App Store Connect API key rather than an Apple ID + app-specific
  password. Both entirely different from `publish_macos.sh`'s own
  credentials — see that script's header for the exact env var names.

## CI (TeamCity)

Project `Roac`, two build types, both triggered on `v*` tag pushes via the
same VCS root (`git@github.com:LarryHsiao/roac.git`, SSH auth through a
write-scoped deploy key registered on the repo, not a full-account
credential):

- **`Roac_DeployWindows`** — `test` (`flutter analyze` + `flutter test` +
  `scripts/build_windows.ps1`) then `release`
  (`scripts/release_github.ps1`). Needs `env.GH_TOKEN` (Password-type
  parameter, set from Vaultwarden's `github` item) — `gh` reads
  `GH_TOKEN`/`GITHUB_TOKEN` from the environment ahead of any stored login,
  and the shared agent has no persistent one.
- **`Roac_Deploy`** (macOS) — `test` (`flutter analyze` + `flutter test` +
  `scripts/ci_build_macos_dmg.sh`) then `release` (inline: `gh release`,
  `sign_update`, `scripts/update_appcast.py`). Needs `env.GH_TOKEN` (set,
  same as Windows) plus six Apple-credential parameters
  (`DEVELOPER_ID_CERT_BASE64`, `DEVELOPER_ID_CERT_PASSWORD`,
  `KEYCHAIN_PASSWORD`, `NOTARY_API_KEY_BASE64`, `NOTARY_API_KEY_ID`,
  `NOTARY_API_ISSUER_ID`) — created as empty Password-type placeholders,
  values not yet provisioned (see below). **No macOS build agent is
  currently connected to TeamCity**, so this build type sits queued
  regardless until one is.

Both build types carry an explicit OS-scoped agent requirement
(`teamcity.agent.jvm.os.name` contains `Windows` / `Mac OS X`) so a queued
build can't land on the wrong agent — TeamCity's default compatibility check
would otherwise allow it.

## How the appcast update works

Both scripts call the same `scripts/update_appcast.py`, which adds or
replaces one platform's `<item>` in `appcast.xml` — replaces, not
duplicates: re-running a publish for a platform overwrites that platform's
entry, leaving the other platform's entry untouched. `sparkle:os` is what
lets one shared feed serve both platforms — each client only installs the
item matching its own OS.

To debug a bad feed entry by hand, the script can be invoked directly:

```bash
python3 scripts/update_appcast.py \
  --appcast appcast.xml --os macos \
  --version <VERSION> --build <BUILD_NUMBER> \
  --pub-date "<RFC_2822_DATE>" \
  --url "https://github.com/LarryHsiao/roac/releases/download/v<VERSION>/roac.dmg" \
  --length <BYTES> --ed-signature "<FROM sign_update>"
```

(`--dsa-signature --full-version <VERSION>+<BUILD>` in place of
`--build`/`--ed-signature` for `--os windows` — `--full-version` must match
the built exe's `ProductVersion` string exactly, since that's what
WinSparkle compares against; a bare `<VERSION>` without the build suffix
makes it think every install is out of date.)
Always `xmllint --noout appcast.xml` after a manual edit before committing.

## What's still owed before the first real release

- **The six Apple-credential CI parameters are empty placeholders.** A
  Developer ID `.p12` (base64) and its password, an App Store Connect API
  key (base64) with its key id and issuer id, and a keychain password of
  your choosing all need pasting into `Roac_Deploy`'s parameters directly in
  the TeamCity UI — never through chat, the same discipline the WinSparkle
  key and `GH_TOKEN` were handled with.
- **No macOS build agent is connected to TeamCity** — `Roac_Deploy` will sit
  queued until one is, independent of the credentials above.
- **No release has ever been cut.** `pubspec.yaml` still reads `1.0.0+1`;
  the first real run of either pipeline is also the first real GitHub
  Release.
