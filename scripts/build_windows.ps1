<#
.SYNOPSIS
  Roac - build a Windows installer and raw zip.

.DESCRIPTION
  Ported from Orthanc's scripts/build_windows.ps1. Runs both by hand, on the
  machine doing a local release, and unattended on TeamCity's "test" step for
  Roac_DeployWindows (v* tag pushes) - the same script either way, since it
  takes no CI-only inputs and code-signing is opt-in rather than required.

  Code-signing (Authenticode, via signtool) is OPTIONAL here, unlike
  Orthanc's script, which requires it - Roac has no code-signing certificate
  yet. Pass -CertPath/-CertPassword to sign; omit them and the build proceeds
  unsigned, with a warning. This is a separate concern from WinSparkle's own
  update-signature check (the DSA keypair scripts/release_github.ps1 signs
  with), which is not optional and does not depend on Authenticode at all.

  Prerequisites:
    - FVM on PATH (to reach the pinned Flutter/Dart SDK)
    - Inno Setup 6 (ISCC.exe at default path or on PATH)
    - signtool.exe on PATH, only if signing

  Outputs:
    $OutputDir\roac-setup-<version>.exe   installer (signed, if asked)
    $OutputDir\roac-<version>-windows.zip raw Release folder, zipped

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build_windows.ps1
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build_windows.ps1 -CertPath windows-codesign.pfx -CertPassword $env:CERT_PASSWORD
#>
param(
  [string]$CertPath,
  [string]$CertPassword,
  [string]$TimestampUrl = 'http://timestamp.digicert.com',
  [string]$OutputDir = 'build\publish'
)
$ErrorActionPreference = 'Stop'

$AppName = 'roac'
$Sign = -not [string]::IsNullOrEmpty($CertPath)
if ($Sign -and [string]::IsNullOrEmpty($CertPassword)) {
  throw "-CertPath given without -CertPassword"
}

$versionLine = Select-String -Path pubspec.yaml -Pattern '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)' |
  Select-Object -First 1
if (-not $versionLine) {
  throw "could not read version from pubspec.yaml"
}
$Version = $versionLine.Matches.Groups[1].Value
Write-Host "==> Version: $Version"

$DefaultIscc = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if (Test-Path $DefaultIscc) {
  $Iscc = $DefaultIscc
} else {
  $cmd = Get-Command ISCC -ErrorAction SilentlyContinue
  if (-not $cmd) {
    throw "ISCC.exe not found at $DefaultIscc or on PATH"
  }
  $Iscc = $cmd.Source
}

if ($Sign) {
  $onPath = Get-Command signtool -ErrorAction SilentlyContinue
  if ($onPath) {
    $SignTool = $onPath.Source
  } else {
    $kitBin = "C:\Program Files (x86)\Windows Kits\10\bin"
    $candidate = Get-ChildItem $kitBin -Recurse -Filter signtool.exe -ErrorAction SilentlyContinue |
      Where-Object { $_.FullName -match '\\x64\\' } |
      Sort-Object FullName -Descending |
      Select-Object -First 1
    if (-not $candidate) {
      throw "signtool.exe not found on PATH or under $kitBin"
    }
    $SignTool = $candidate.FullName
  }
}

Write-Host "==> Resolving Flutter dependencies"
& fvm flutter pub get
if ($LASTEXITCODE -ne 0) { throw "fvm flutter pub get exited $LASTEXITCODE" }

Write-Host "==> Building Windows release"
& fvm flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw "fvm flutter build windows exited $LASTEXITCODE" }

$ReleaseDir = "build\windows\x64\runner\Release"
$AppExe = Join-Path $ReleaseDir "$AppName.exe"
if (-not (Test-Path $AppExe)) {
  throw "built app not found at $AppExe"
}

if ($Sign) {
  Write-Host "==> Signing $AppExe"
  & $SignTool sign /f $CertPath /p $CertPassword `
    /tr $TimestampUrl /td sha256 /fd sha256 $AppExe
  if ($LASTEXITCODE -ne 0) { throw "signtool (app) exited $LASTEXITCODE" }
} else {
  Write-Host "==> Skipping Authenticode signing (no -CertPath given) - the installer will show an unknown-publisher warning until Roac has a code-signing certificate"
}

Write-Host "==> Compiling Inno installer"
& $Iscc "/DMyAppVersion=$Version" 'installer\roac.iss'
if ($LASTEXITCODE -ne 0) { throw "ISCC exited $LASTEXITCODE" }
$InstallerSrc = "build\installer\$AppName-setup-$Version.exe"
if (-not (Test-Path $InstallerSrc)) {
  throw "installer not produced at $InstallerSrc"
}

if ($Sign) {
  Write-Host "==> Signing $InstallerSrc"
  & $SignTool sign /f $CertPath /p $CertPassword `
    /tr $TimestampUrl /td sha256 /fd sha256 $InstallerSrc
  if ($LASTEXITCODE -ne 0) { throw "signtool (installer) exited $LASTEXITCODE" }
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$InstallerOut = Join-Path $OutputDir "$AppName-setup-$Version.exe"
Copy-Item -Force $InstallerSrc $InstallerOut

Write-Host "==> Zipping raw Release folder"
$ZipOut = Join-Path $OutputDir "$AppName-$Version-windows.zip"
if (Test-Path $ZipOut) { Remove-Item -Force $ZipOut }
Compress-Archive -Path "$ReleaseDir\*" -DestinationPath $ZipOut

Write-Host "==> Done."
Write-Host "    Installer: $InstallerOut"
Write-Host "    Zip:       $ZipOut"
