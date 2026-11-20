Discord Wave Link Auto-Mute
===========================

English
-------
What it does
  Mutes Discord's audio session on the Elgato Wave Link devices on
  Windows and keeps it muted in the background. Prevents doubled voice
  audio when screen sharing with sound in Discord.

How it behaves
  - Starts at every Windows logon and runs permanently, fully invisible
    (no window, no taskbar entry).
  - Also mutes Discord audio sessions that appear later, e.g. when apps
    with sound are opened while streaming.
  - If you unmute Discord by hand (Wave Link mixer or the -Unmute
    command), the watchdog respects that and does not switch back until
    Discord opens a new audio session.
  - After the next PC restart everything starts muted again.

Good to know
  While a track is muted you will not hear the people in Discord either -
  exactly like with a manual mute.

Commands (optional)
  Unmute:
    powershell -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\DiscordMuteAutomation\Mute-Discord-WaveLink.ps1" -Unmute
  Mute again:
    powershell -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\DiscordMuteAutomation\Mute-Discord-WaveLink.ps1" -Mute
  Show status:
    powershell -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\DiscordMuteAutomation\Mute-Discord-WaveLink.ps1" -List
  Force English output (default: automatic):
    powershell -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\DiscordMuteAutomation\Mute-Discord-WaveLink.ps1" -Language en
  (On German Windows the engine reports in German, otherwise in English.)

Requirements
  Windows 10/11, Elgato Wave Link installed, Discord.

Installation
  1. Double-click Discord-WaveLink-Mute-Setup.bat
  2. Wait, read the messages, press a key.

  The package creates a scheduled task in your user context (no admin
  required). If Windows does not allow that, it falls back to a shortcut
  in the Startup folder - both work the same way.

Uninstall
    powershell -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\DiscordMuteAutomation\Mute-Discord-WaveLink.ps1" -Remove

Log
    %LOCALAPPDATA%\DiscordMuteAutomation\log.txt


Deutsch
-------
Was es macht
  Schaltet die Discord-Audiospur auf den Elgato Wave Link Geräten unter
  Windows stumm und hält sie im Hintergrund stumm. Verhindert doppelten
  Stimmen-Ton beim Bildschirmteilen mit Ton in Discord.

Verhalten
  - Startet bei jeder Windows-Anmeldung und läuft dauerhaft, komplett
    unsichtbar (kein Fenster, kein Taskleisten-Eintrag).
  - Schaltet auch Discord-Audiospuren stumm, die erst später entstehen,
    z. B. wenn Apps mit Ton geöffnet werden, während du streamst.
  - Wenn du Discord von Hand freischaltest (Wave-Link-Mixer oder der
    -Unmute-Befehl), respektiert der Watchdog das und schaltet nicht
    zurück, bis Discord eine neue Audiospur öffnet.
  - Nach dem nächsten PC-Neustart ist wieder alles stumm.

Gut zu wissen
  Solange die Spur stumm ist, hörst du die Leute in Discord ebenfalls
  nicht - genau wie beim manuellen Muten.

Befehle (optional)
  Freischalten:
    powershell -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\DiscordMuteAutomation\Mute-Discord-WaveLink.ps1" -Unmute
  Wieder stummschalten:
    powershell -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\DiscordMuteAutomation\Mute-Discord-WaveLink.ps1" -Mute
  Status anzeigen:
    powershell -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\DiscordMuteAutomation\Mute-Discord-WaveLink.ps1" -List
  Deutsch erzwingen (Standard: automatisch):
    powershell -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\DiscordMuteAutomation\Mute-Discord-WaveLink.ps1" -Language de
  (Auf deutschem Windows meldet die Engine auf Deutsch, sonst auf Englisch.)

Voraussetzungen
  Windows 10/11, Elgato Wave Link installiert, Discord.

Installation
  1. Doppelklick auf Discord-WaveLink-Mute-Setup.bat
  2. Warten, Meldungen lesen, Taste drücken.

  Das Paket richtet eine geplante Aufgabe in deinem Benutzerkontext ein
  (kein Admin nötig). Falls Windows das nicht erlaubt, wird automatisch
  eine Verknüpfung im Autostart-Ordner angelegt - beides funktioniert
  gleich gut.

Deinstallation
    powershell -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\DiscordMuteAutomation\Mute-Discord-WaveLink.ps1" -Remove

Protokoll
    %LOCALAPPDATA%\DiscordMuteAutomation\log.txt
