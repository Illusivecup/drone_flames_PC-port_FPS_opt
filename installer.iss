; Inno Setup 6 Script
; DroneFlames Reborn Installer

#define MyAppName "DroneFlames Reborn"
#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif
#define MyAppPublisher "Reborn Team"
#define MyAppURL "https://github.com/Illusivecup/drone_flames_PC-port_FPS_opt"
#define MyAppExeName "DroneFlames.exe"
#define MyAppId "{{9F5C24D1-A12E-4D78-831C-6BE3E71AA190}}"

#ifndef SourceDir
  #define SourceDir "build\DroneFlames_Reborn_PC_v1.0.0"
#endif

#ifndef OutDir
  #define OutDir "dist"
#endif

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} v{#MyAppVersion}
AppPublisher=Reborn Team
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\DroneFlames Reborn
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir={#OutDir}
OutputBaseFilename=DroneFlames_Reborn_PC_Setup_v{#MyAppVersion}
SetupIconFile=app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog commandline

; Auto-Update and In-Place Upgrade Settings
UsePreviousAppDir=yes
UsePreviousGroup=yes
UsePreviousTasks=yes
DisableDirPage=auto
CloseApplications=yes
CloseApplicationsFilter=DroneFlames.exe,DroneFlames_Debug.exe
RestartApplications=no
AppMutex=DroneFlames_Reborn

; UI Styling
WizardStyle=modern
WizardImageFile=installer_banner.bmp
WizardSmallImageFile=installer_small.bmp
InfoBeforeFile=installer_info.txt
DisableWelcomePage=no
UninstallDisplayIcon={app}\app_icon.ico
UninstallDisplayName={#MyAppName} v{#MyAppVersion}

; File metadata
VersionInfoVersion={#MyAppVersion}.0
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription=DroneFlames Reborn Installer
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}
VersionInfoCopyright=Reborn Team

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
russian.LaunchProgramTitle=Запустить DroneFlames Reborn
russian.CreditsTitle=О проекте DroneFlames Reborn
russian.DebugModeTitle=DroneFlames (Консоль и логи отладки)
russian.DesktopShortcut=Создать ярлык на Рабочем столе
russian.WelcomeTitle=Вас приветствует установка DroneFlames Reborn
russian.WelcomeSubtitle=Программа установит DroneFlames Reborn v{#MyAppVersion} на ваш компьютер.%n%n• Реальный экспорт игры: exe + pck, никаких архивов с исходниками%n• Отказоустойчивый мультиплеер: релей, реконнект, позднее подключение%n• Поддержка F11, WASD, плавного зума, модов%n%nДля продолжения нажмите «Далее».

english.LaunchProgramTitle=Launch DroneFlames Reborn
english.CreditsTitle=About DroneFlames Reborn
english.DebugModeTitle=DroneFlames (Debug Console Mode)
english.DesktopShortcut=Create a desktop shortcut
english.WelcomeTitle=Welcome to DroneFlames Reborn Setup
english.WelcomeSubtitle=This will install DroneFlames Reborn v{#MyAppVersion} on your computer.%n%n• Real game export: exe + pck, no more sources-only archives%n• Resilient multiplayer: relay server, reconnect, late join%n• F11 fullscreen, WASD, smooth zoom, mod support%n%nClick Next to continue.

[Messages]
russian.WelcomeLabel1={cm:WelcomeTitle}
russian.WelcomeLabel2={cm:WelcomeSubtitle}
english.WelcomeLabel1={cm:WelcomeTitle}
english.WelcomeLabel2={cm:WelcomeSubtitle}

[Tasks]
Name: "desktopicon"; Description: "{cm:DesktopShortcut}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Main application shortcut
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Parameters: "--path ""{app}"""; WorkingDir: "{app}"; IconFilename: "{app}\app_icon.ico"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Parameters: "--path ""{app}"""; WorkingDir: "{app}"; IconFilename: "{app}\app_icon.ico"; Tasks: desktopicon

; Debug Console Launcher (verbose log -> debug.log)
Name: "{group}\{cm:DebugModeTitle}"; Filename: "{app}\DroneFlames_Debug.bat"; WorkingDir: "{app}"; IconFilename: "{app}\app_icon.ico"

; Credits & Release info

; Native Uninstall Shortcut
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Parameters: "--path ""{app}"""; WorkingDir: "{app}"; Description: "{cm:LaunchProgramTitle}"; Flags: nowait postinstall skipifsilent

[Code]
// Функция проверки установленной предыдущей версии игры
function GetInstalledVersion(): String;
var
  InstalledVer: String;
begin
  InstalledVer := '';
  if not RegQueryStringValue(HKEY_CURRENT_USER, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{#MyAppId}_is1', 'DisplayVersion', InstalledVer) then
    RegQueryStringValue(HKEY_LOCAL_MACHINE, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{#MyAppId}_is1', 'DisplayVersion', InstalledVer);
  Result := InstalledVer;
end;

function IsUpgrade(): Boolean;
begin
  Result := (GetInstalledVersion() <> '');
end;

procedure InitializeWizard();
var
  OldVer: String;
begin
  OldVer := GetInstalledVersion();
  if OldVer <> '' then
  begin
    WizardForm.Caption := 'Обновление DroneFlames (Reborn)';
    WizardForm.WelcomeLabel1.Caption := 'Обновление DroneFlames (Reborn)';
    WizardForm.WelcomeLabel2.Caption := 
      'На компьютере обнаружена установленная версия игры (' + OldVer + ').' + #13#10 + #13#10 +
      'Этот установщик обновит существующую версию DroneFlames до актуальной v{#MyAppVersion}.' + #13#10 + #13#10 +
      '• Все файлы игры будут безопасно заменены на новые.' + #13#10 +
      '• Ваши сохранения, статистика профиля и прогресс останутся нетронутыми.' + #13#10 +
      '• Переустанавливать игру заново не требуется.' + #13#10 + #13#10 +
      'Нажмите «Далее», чтобы применить обновление.';
  end;
end;
