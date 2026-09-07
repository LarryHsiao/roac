<#
.SYNOPSIS
  Roac - publish built artifacts to a GitHub Release and update the update feed.

.DESCRIPTION
  Adapted from Orthanc's scripts/release_github.ps1, run after
  scripts/build_windows.ps1 - both by hand for a local release, and
  unattended on TeamCity's "release" step for Roac_DeployWindows (v* tag
  pushes). No -Branch gate either way: TeamCity's own VCS root branchSpec
  and trigger already restrict this build type to tag pushes, so the script
  itself has no CI-only input to read.

  Requires:
    - gh CLI on PATH. Locally, whatever `gh auth login` already stored;
      on TeamCity, the env.GH_TOKEN build parameter (Password type) - gh
      reads GH_TOKEN/GITHUB_TOKEN from the environment ahead of any stored
      login
    - Built artifacts at build\publish\roac-setup-<version>.exe and
      build\publish\roac-<version>-windows.zip (scripts\build_windows.ps1's
      output)
    - FVM on PATH (to reach the pinned Dart SDK for auto_updater:sign_update)
    - bash on PATH and Vaultwarden reachable via
      ~/.claude/hooks/secret.sh, item "roac-winsparkle-dsa" (password field
      = base64 of dsa_priv.pem, the WinSparkle signing key)

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\release_github.ps1
#>
$ErrorActionPreference = 'Stop'

$versionLine = Select-String -Path pubspec.yaml -Pattern '^version:\s*(\S+)' | Select-Object -First 1
if (-not $versionLine) { throw "could not read version from pubspec.yaml" }
$fullVersion = $versionLine.Matches.Groups[1].Value
$version = $fullVersion.Split('+')[0]
$tag = "v$version"

$installer = Get-ChildItem "build\publish\roac-setup-*.exe" -ErrorAction Stop | Select-Object -First 1
$zip       = Get-ChildItem "build\publish\roac-*-windows.zip" -ErrorAction Stop | Select-Object -First 1

Write-Host "==> Ensuring release exists for $tag"
# gh writes "already exists" to stderr on repeat runs; don't capture it with 2>&1 —
# under EAP='Stop' that wraps it into a terminating NativeCommandError.
& gh release create $tag --title $tag --generate-notes --repo LarryHsiao/roac | Out-Null

Write-Host "==> Uploading $($installer.Name) and $($zip.Name)"
& gh release upload $tag $installer.FullName $zip.FullName --clobber --repo LarryHsiao/roac
if ($LASTEXITCODE -ne 0) { throw "gh release upload exited $LASTEXITCODE" }

Write-Host "==> Resolving WinSparkle signing key from Vaultwarden"
$dsaKeyB64 = & bash "$env:USERPROFILE\.claude\hooks\secret.sh" roac-winsparkle-dsa password
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($dsaKeyB64)) {
  throw "could not resolve WinSparkle signing key from Vaultwarden (item: roac-winsparkle-dsa)"
}
$dsaKeyPath = Join-Path (Get-Location) 'dsa_priv.pem'
[IO.File]::WriteAllBytes($dsaKeyPath, [Convert]::FromBase64String($dsaKeyB64))

Write-Host "==> Signing update for WinSparkle"
try {
  $signOutput = & fvm dart run auto_updater:sign_update $installer.FullName
  if ($LASTEXITCODE -ne 0) { throw "auto_updater:sign_update exited $LASTEXITCODE" }
  if ($signOutput -notmatch 'sparkle:dsaSignature="([^"]+)"' -or $signOutput -notmatch 'length="([0-9]+)"') {
    throw "could not parse sign_update output: $signOutput"
  }
} finally {
  Remove-Item -Force $dsaKeyPath -ErrorAction SilentlyContinue
}
$dsaSignature = ($signOutput | Select-String -Pattern 'sparkle:dsaSignature="([^"]+)"').Matches.Groups[1].Value
# auto_updater:sign_update hardcodes length="0" on Windows (it never computes
# the real size there, unlike its macOS path) - use the installer's actual
# byte size instead of trusting that always-zero value.
$length = $installer.Length

Write-Host "==> Updating appcast.xml"
$pubDate = (Get-Date).ToUniversalTime().ToString("ddd, dd MMM yyyy HH:mm:ss +0000")

& git fetch origin main
if ($LASTEXITCODE -ne 0) { throw "git fetch origin main exited $LASTEXITCODE" }

# The macOS deploy path updates the same file and can win the push race.
# update_appcast.py replaces only this OS's <item>, so on a lost race we
# reset to the winner's commit and regenerate on top of it rather than
# rebasing a stale edit into a conflict.
$maxAttempts = 5
$pushed = $false
for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
  & git reset --hard origin/main
  if ($LASTEXITCODE -ne 0) { throw "git reset to origin/main exited $LASTEXITCODE" }

  & python3 scripts/update_appcast.py `
    --appcast appcast.xml `
    --os windows `
    --version $version `
    --full-version $fullVersion `
    --pub-date $pubDate `
    --url "https://github.com/LarryHsiao/roac/releases/download/$tag/$($installer.Name)" `
    --length $length `
    --dsa-signature $dsaSignature
  if ($LASTEXITCODE -ne 0) { throw "update_appcast.py exited $LASTEXITCODE" }

  & xmllint --noout appcast.xml
  if ($LASTEXITCODE -ne 0) { throw "appcast.xml is not valid XML after update" }
  & git add appcast.xml
  & git commit -m "chore: publish $tag to the update feed"
  if ($LASTEXITCODE -ne 0) { throw "git commit exited $LASTEXITCODE" }

  & git push origin HEAD:main
  if ($LASTEXITCODE -eq 0) { $pushed = $true; break }

  Write-Host "==> push race on attempt $attempt/$maxAttempts - refetching origin/main and retrying"
  Start-Sleep -Seconds 5
  & git fetch origin main
  if ($LASTEXITCODE -ne 0) { throw "git fetch origin main exited $LASTEXITCODE" }
}
if (-not $pushed) { throw "git push to main failed after $maxAttempts attempts - appcast.xml needs manual reconciliation" }
Write-Host "==> appcast.xml published for $tag"
