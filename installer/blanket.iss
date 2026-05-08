; Blanket Windows Installer Script
; Compiled with Inno Setup 6.x

#define AppName      "Blanket"
#define AppVersion   "0.8.0"
#define AppPublisher "Rafael Mardojai CM"
#define AppURL       "https://github.com/rafaelmardojai/blanket"
#define AppExeName   "Blanket.exe"
#define SourceRoot   ".."

[Setup]
AppId={{A3F8C2E1-4D7B-4F9A-8C3D-2E1F5A6B7C8D}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
AllowNoIcons=yes
LicenseFile={#SourceRoot}\COPYING
OutputDir={#SourceRoot}\dist
OutputBaseFilename=Blanket-{#AppVersion}-setup
SetupIconFile={#SourceRoot}\build\blanket.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}
VersionInfoVersion={#AppVersion}
VersionInfoDescription=Blanket Installer

[Languages]
Name: "turkish";  MessagesFile: "compiler:Languages\Turkish.isl"
Name: "english";  MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; App source & launchers
Source: "{#SourceRoot}\blanket\*";        DestDir: "{app}\blanket";      Flags: ignoreversion recursesubdirs
Source: "{#SourceRoot}\run_windows.py";   DestDir: "{app}";              Flags: ignoreversion
Source: "{#SourceRoot}\setup_windows.py"; DestDir: "{app}";              Flags: ignoreversion

; Compiled resources
Source: "{#SourceRoot}\build\blanket.gresource"; DestDir: "{app}\build"; Flags: ignoreversion
Source: "{#SourceRoot}\build\gschemas.compiled";  DestDir: "{app}\build"; Flags: ignoreversion
Source: "{#SourceRoot}\build\com.rafaelmardojai.Blanket.gschema.xml"; DestDir: "{app}\build"; Flags: ignoreversion

; Launcher executable (with icon)
Source: "{#SourceRoot}\installer\Blanket.exe"; DestDir: "{app}"; Flags: ignoreversion

; App icon
Source: "{#SourceRoot}\build\blanket.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}";              Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\blanket.ico"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}";        Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\blanket.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\build"
Type: filesandordirs; Name: "{app}\__pycache__"
Type: filesandordirs; Name: "{app}\blanket\__pycache__"
