; Roäc — Inno Setup script
; Ported from Orthanc's installer/orthanc.iss.
; Compile from the repo root with:
;   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\roac.iss
; Output lands in build\installer\.

#define MyAppName        "Roac"
; Version is supplied by the build script via ISCC /DMyAppVersion=<pubspec version>.
; The literal below is only a fallback for a bare local compile with no define.
#ifndef MyAppVersion
  #define MyAppVersion   "1.0.0"
#endif
#define MyAppPublisher   "Larry Hsiao"
#define MyAppURL         "https://github.com/LarryHsiao/roac"
#define MyAppExeName     "roac.exe"
#define MyAppSourceDir   "..\build\windows\x64\runner\Release"
#define MyAppOutputDir   "..\build\installer"

[Setup]
; A fixed GUID — keep this constant across versions so upgrades replace cleanly.
; Distinct from every other product's own AppId.
AppId={{BFC9C802-A0F1-4AB6-8C83-D3823FAEBBD0}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}/releases
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
LicenseFile=
OutputDir={#MyAppOutputDir}
OutputBaseFilename=roac-setup-{#MyAppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoProductName={#MyAppName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#MyAppSourceDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyAppSourceDir}\*.dll";            DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyAppSourceDir}\data\*";           DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}";              Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}";    Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}";        Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
