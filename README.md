# Discord WaveLink AutoMute

Automatically mutes Discord's audio session on Elgato Wave Link devices on Windows — permanently in the background. Prevents doubled voice audio when screen sharing with sound.

**English** · **Deutsch**

## English

### The problem

If you use Elgato Wave Link and share your screen **with sound** in Discord, this is familiar:

- Discord captures the audio of the Windows default output device while sharing.
- On Wave Link setups that is often the local monitor mix – which also carries the Discord voices.
- The other people in the call therefore hear the voices twice: once normally, once through the stream.

The manual workaround is to mute the Discord track in the Windows volume mixer (or Wave Link mixer) – but that mute is lost on every reboot and has to be set again.

### The solution

A small watchdog (PowerShell + WASAPI/COM, no third-party software):

- mutes all Discord audio sessions on devices named „Elgato Virtual Audio" automatically at every logon,
- keeps running permanently in the background and also catches sessions that appear later (e.g. when apps with sound are opened while streaming),
- runs completely invisible (scheduled task + VBS launcher, no window, no taskbar entry),
- respects a manual unmute (Wave Link mixer or `-Unmute`) and does not switch back,
- needs **no admin rights** and no drivers.

After the next PC start everything is muted again – exactly as intended.

### Installation

1. Download the [release](https://github.com/Leonplayce/Discord-WaveLink-AutoMute/releases) (`Discord-WaveLink-Mute.zip`) and extract it.
2. Double-click `Discord-WaveLink-Mute-Setup.bat`.
3. Done. The installer checks whether Wave Link is installed, sets up autostart and applies the first mute.

**Requirements:** Windows 10/11, Elgato Wave Link installed, Discord.

> Windows SmartScreen may warn about unknown `.bat`/`.ps1` files ("More info" → "Run anyway"). The script is plain, fully visible PowerShell code in this repository.

### Commands

The installed engine lives at `%LOCALAPPDATA%\DiscordMuteAutomation\Mute-Discord-WaveLink.ps1`.

| Command | Effect |
|---|---|
| `... -Mute` | Mute Discord now (e.g. before sharing with sound) |
| `... -Unmute` | Unmute Discord now (the watchdog respects that) |
| `... -List` | Show devices + running audio sessions |
| `... -Install` | Set up autostart (the installer does this automatically) |
| `... -Remove` | Remove autostart and watchdog (uninstall) |
| `... -Language en` / `... -Language de` | Force the output language (default: automatic) |

The output language is automatic: German on German Windows, English otherwise. Use `-Language en` or `-Language de` to force one.

Example:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\DiscordMuteAutomation\Mute-Discord-WaveLink.ps1" -Unmute
```

### How it works

- The engine enumerates all active render devices whose name contains „Elgato Virtual Audio" via the Windows Core Audio API (WASAPI).
- For each device `IAudioSessionManager2` is activated and every session whose process is `Discord`, `DiscordCanary` or `DiscordPTB` is muted through `ISimpleAudioVolume.SetMute`.
- The COM interfaces are embedded as C# interop directly in the PowerShell script (`Add-Type`) – no DLLs, no installation.
- A background loop checks every 5 seconds; new sessions are detected and muted (watchdog mode).
- Autostart uses a scheduled task in the user context (no admin). If registration fails, a shortcut in the Startup folder is created automatically.
- A VBS launcher starts PowerShell windowless so nothing flashes at logon.

### Project structure

```
Mute-Discord-WaveLink.ps1          Engine (source, usable standalone)
Discord-WaveLink-Mute-Setup.bat    One-click installer (engine embedded)
README.txt                         Short guide for the release ZIP
build-installer.ps1                Rebuilds the .bat from the engine
make-release.ps1                   Builds the distribution ZIP
```

### Development

1. Edit the engine in `Mute-Discord-WaveLink.ps1`.
2. Run `powershell -ExecutionPolicy Bypass -File .\build-installer.ps1` – re-embeds the engine into the `.bat` and verifies the result.
3. Test: `powershell -ExecutionPolicy Bypass -File .\Mute-Discord-WaveLink.ps1 -List`

### Troubleshooting

- Log file: `%LOCALAPPDATA%\DiscordMuteAutomation\log.txt`
- „No devices matching 'Elgato Virtual Audio' found" → Wave Link is not installed or the virtual devices are disabled.
- No mute after logon → check the log for „Watchdog started"; re-run `-Install` if needed.
- Installer exit codes: `3` = no Wave Link devices, `4` = autostart could not be configured.

### License

MIT – see [LICENSE](LICENSE). Unofficial project, not affiliated with Elgato or Discord. Use at your own risk.

---

## Deutsch

### Das Problem

Wer Elgato Wave Link nutzt und in Discord den Bildschirm **mit Ton** teilt, kennt das:

- Discord nimmt beim Teilen den Ton des Windows-Standard-Ausgabegeräts auf.
- Bei Wave-Link-Setups ist das oft der Local-Mix (Monitor) – dort laufen aber auch die Discord-Stimmen.
- Die anderen im Call hören die Stimmen dadurch doppelt: einmal normal, einmal über den Stream.

Manuell löst man das, indem man im Windows-Lautstärkemixer (bzw. Wave-Link-Mixer) die Discord-Spur stummschaltet – aber der Mute geht bei jedem Neustart verloren und muss neu gesetzt werden.

### Die Lösung

Ein kleiner Watchdog (PowerShell + WASAPI/COM, ohne Zusatzsoftware):

- schaltet bei jeder Anmeldung automatisch alle Discord-Audiositzungen auf den Geräten mit „Elgato Virtual Audio" stumm,
- bleibt dauerhaft im Hintergrund aktiv und erfasst auch Spuren, die erst später entstehen (z. B. wenn Apps mit Ton geöffnet werden),
- läuft komplett unsichtbar (geplante Aufgabe + VBS-Starter, kein Fenster, kein Taskleisten-Eintrag),
- respektiert eine manuelle Freischaltung (Wave-Link-Mixer oder `-Unmute`) und schaltet sie nicht zurück,
- braucht **keine Admin-Rechte** und keine Treiber.

Nach dem nächsten PC-Start ist wieder alles stumm – genau wie gewünscht.

### Installation

1. [Release](https://github.com/Leonplayce/Discord-WaveLink-AutoMute/releases) herunterladen (`Discord-WaveLink-Mute.zip`) und entpacken.
2. Doppelklick auf `Discord-WaveLink-Mute-Setup.bat`.
3. Fertig. Der Installer prüft, ob Wave Link installiert ist, richtet den Autostart ein und setzt den ersten Mute.

**Voraussetzungen:** Windows 10/11, Elgato Wave Link installiert, Discord.

> Windows SmartScreen kann bei unbekannten `.bat`/`.ps1`-Dateien warnen („Weitere Informationen" → „Trotzdem ausführen"). Das Skript ist reiner, hier vollständig einsehbarer PowerShell-Code.

### Befehle

Die installierte Engine liegt unter `%LOCALAPPDATA%\DiscordMuteAutomation\Mute-Discord-WaveLink.ps1`.

| Befehl | Wirkung |
|---|---|
| `... -Mute` | Discord jetzt stummschalten (z. B. bevor du mit Ton teilst) |
| `... -Unmute` | Discord jetzt freischalten (der Watchdog respektiert das) |
| `... -List` | Geräte + laufende Audio-Sitzungen anzeigen |
| `... -Install` | Autostart einrichten (macht der Installer automatisch) |
| `... -Remove` | Autostart und Watchdog entfernen (Deinstallation) |
| `... -Language en` / `... -Language de` | Sprache der Ausgaben erzwingen (Standard: automatisch) |

Die Sprache der Ausgaben ist automatisch: Deutsch auf deutschem Windows, sonst Englisch. Mit `-Language en` oder `-Language de` lässt sich eine Sprache erzwingen.

Beispiel:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\DiscordMuteAutomation\Mute-Discord-WaveLink.ps1" -Unmute
```

### Wie es funktioniert

- Die Engine zählt über das Windows Core Audio API (WASAPI) alle aktiven Render-Geräte auf, deren Name „Elgato Virtual Audio" enthält.
- Pro Gerät wird `IAudioSessionManager2` aktiviert und jede Sitzung mit Prozessname `Discord`, `DiscordCanary` oder `DiscordPTB` über `ISimpleAudioVolume.SetMute` stummgeschaltet.
- Die COM-Interfaces sind als C#-Interop direkt im PowerShell-Skript eingebettet (`Add-Type`) – keine DLLs, keine Installation.
- Ein Hintergrund-Loop prüft alle 5 Sekunden; neue Sitzungen werden erkannt und stummgeschaltet (Watchdog-Modus).
- Der Autostart läuft über eine geplante Aufgabe im Benutzerkontext (ohne Admin). Scheitert die Registrierung, wird automatisch eine Verknüpfung im Autostart-Ordner angelegt.
- Ein VBS-Starter startet PowerShell fensterlos, damit beim Login nichts aufblitzt.

### Projektstruktur

```
Mute-Discord-WaveLink.ps1          Engine (Quelle, standalone nutzbar)
Discord-WaveLink-Mute-Setup.bat    Ein-Klick-Installer (Engine eingebettet)
README.txt                         Kurzanleitung für das Release-ZIP
build-installer.ps1                Baut die .bat aus der Engine neu
make-release.ps1                   Erstellt das Weitergabe-ZIP
```

### Entwicklung

1. Engine in `Mute-Discord-WaveLink.ps1` anpassen.
2. `powershell -ExecutionPolicy Bypass -File .\build-installer.ps1` ausführen – bettet die Engine neu in die `.bat` ein und prüft das Ergebnis.
3. Testen: `powershell -ExecutionPolicy Bypass -File .\Mute-Discord-WaveLink.ps1 -List`

### Fehlersuche

- Protokoll: `%LOCALAPPDATA%\DiscordMuteAutomation\log.txt`
- „No devices matching 'Elgato Virtual Audio' found" → Wave Link ist nicht installiert oder die virtuellen Geräte sind deaktiviert.
- Kein Mute nach dem Start → im Protokoll prüfen, ob „Watchdog started" steht; ggf. `-Install` erneut ausführen.
- Exit-Codes des Installers: `3` = keine Wave-Link-Geräte, `4` = Autostart konnte nicht eingerichtet werden.

### Lizenz

MIT – siehe [LICENSE](LICENSE). Inoffizielles Projekt, nicht mit Elgato oder Discord verbunden. Nutzung auf eigene Gefahr.
