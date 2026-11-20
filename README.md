# Discord WaveLink AutoMute

**Deutsch** · [English](#english)

Mutet die Discord-Audiospur auf den Elgato Wave Link Geräten unter Windows automatisch – dauerhaft im Hintergrund. Verhindert den doppelten Stimmen-Ton beim Bildschirmteilen mit Audio.

## Das Problem

Wer Elgato Wave Link nutzt und in Discord den Bildschirm **mit Ton** teilt, kennt das:

- Discord nimmt beim Teilen den Ton des Windows-Standard-Ausgabegeräts auf.
- Bei Wave-Link-Setups ist das oft der Local-Mix (Monitor) – dort laufen aber auch die Discord-Stimmen.
- Die anderen im Call hören die Stimmen dadurch doppelt: einmal normal, einmal über den Stream.

Manuell löst man das, indem man im Windows-Lautstärkemixer (bzw. Wave-Link-Mixer) die Discord-Spur stummschaltet – aber der Mute geht bei jedem Neustart verloren und muss neu gesetzt werden.

## Die Lösung

Ein kleiner Watchdog (PowerShell + WASAPI/COM, ohne Zusatzsoftware):

- schaltet bei jeder Anmeldung automatisch alle Discord-Audiositzungen auf den Geräten mit „Elgato Virtual Audio" stumm,
- bleibt dauerhaft im Hintergrund aktiv und erfasst auch Spuren, die erst später entstehen (z. B. wenn Apps mit Ton geöffnet werden),
- läuft komplett unsichtbar (geplante Aufgabe + VBS-Starter, kein Fenster, kein Taskleisten-Eintrag),
- respektiert eine manuelle Freischaltung (Wave-Link-Mixer oder `-Unmute`) und schaltet sie nicht zurück,
- braucht **keine Admin-Rechte** und keine Treiber.

Nach dem nächsten PC-Start ist wieder alles stumm – genau wie gewünscht.

## Installation

1. [Release](https://github.com/Leonplayce/Discord-WaveLink-AutoMute/releases) herunterladen (`Discord-WaveLink-Mute.zip`) und entpacken.
2. Doppelklick auf `Discord-WaveLink-Mute-Setup.bat`.
3. Fertig. Der Installer prüft, ob Wave Link installiert ist, richtet den Autostart ein und setzt den ersten Mute.

**Voraussetzungen:** Windows 10/11, Elgato Wave Link installiert, Discord.

> Windows SmartScreen kann bei unbekannten `.bat`/`.ps1`-Dateien warnen („Weitere Informationen" → „Trotzdem ausführen"). Das Skript ist reiner, hier vollständig einsehbarer PowerShell-Code.

## Befehle

Die installierte Engine liegt unter `%LOCALAPPDATA%\DiscordMuteAutomation\Mute-Discord-WaveLink.ps1`.

| Befehl | Wirkung |
|---|---|
| `... -Mute` | Discord jetzt stummschalten (z. B. bevor du mit Ton teilst) |
| `... -Unmute` | Discord jetzt freischalten (der Watchdog respektiert das) |
| `... -List` | Geräte + laufende Audio-Sitzungen anzeigen |
| `... -Install` | Autostart einrichten (macht der Installer automatisch) |
| `... -Remove` | Autostart und Watchdog entfernen (Deinstallation) |

Beispiel:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\DiscordMuteAutomation\Mute-Discord-WaveLink.ps1" -Unmute
```

## Wie es funktioniert

- Die Engine zählt über das Windows Core Audio API (WASAPI) alle aktiven Render-Geräte auf, deren Name „Elgato Virtual Audio" enthält.
- Pro Gerät wird `IAudioSessionManager2` aktiviert und jede Sitzung mit Prozessname `Discord`, `DiscordCanary` oder `DiscordPTB` über `ISimpleAudioVolume.SetMute` stummgeschaltet.
- Die COM-Interfaces sind als C#-Interop direkt im PowerShell-Skript eingebettet (`Add-Type`) – keine DLLs, keine Installation.
- Ein Hintergrund-Loop prüft alle 5 Sekunden; neue Sitzungen werden erkannt und stummgeschaltet (Watchdog-Modus).
- Der Autostart läuft über eine geplante Aufgabe im Benutzerkontext (ohne Admin). Scheitert die Registrierung, wird automatisch eine Verknüpfung im Autostart-Ordner angelegt.
- Ein VBS-Starter startet PowerShell fensterlos, damit beim Login nichts aufblitzt.

## Projektstruktur

```
Mute-Discord-WaveLink.ps1          Engine (Quelle, standalone nutzbar)
Discord-WaveLink-Mute-Setup.bat    Ein-Klick-Installer (Engine eingebettet)
LIESMICH.txt                       Kurzanleitung für die Weitergabe
build-installer.ps1                Baut die .bat aus der Engine neu
make-release.ps1                   Erstellt das Weitergabe-ZIP
```

## Entwicklung

1. Engine in `Mute-Discord-WaveLink.ps1` anpassen.
2. `powershell -ExecutionPolicy Bypass -File .\build-installer.ps1` ausführen – bettet die Engine neu in die `.bat` ein und prüft das Ergebnis.
3. Testen: `powershell -ExecutionPolicy Bypass -File .\Mute-Discord-WaveLink.ps1 -List`

## Fehlersuche

- Protokoll: `%LOCALAPPDATA%\DiscordMuteAutomation\log.txt`
- „KEINE 'Elgato Virtual Audio'-Geräte gefunden" → Wave Link ist nicht installiert oder die virtuellen Geräte sind deaktiviert.
- Kein Mute nach dem Start → im Protokoll prüfen, ob „Watchdog gestartet" steht; ggf. `-Install` erneut ausführen.
- Exit-Codes des Installers: `3` = keine Wave-Link-Geräte, `4` = Autostart konnte nicht eingerichtet werden.

## Lizenz

MIT – siehe [LICENSE](LICENSE). Inoffizielles Projekt, nicht mit Elgato oder Discord verbunden. Nutzung auf eigene Gefahr.

---

## English

**Discord WaveLink AutoMute** automatically mutes Discord's audio session on Elgato Wave Link devices on Windows. This prevents doubled voice audio when screen sharing **with sound** in Discord: Discord captures the default output device, which on Wave Link setups is often the local monitor mix that already contains the call voices.

- Permanent background watchdog (checks every 5 s) – also mutes sessions that appear later, e.g. when apps with audio are opened while streaming.
- Completely invisible autostart (scheduled task + VBS launcher, no window, no taskbar entry).
- Respects manual unmute (Wave Link mixer or `-Unmute`) and does not switch back.
- No admin rights, no drivers, no third-party tools – pure PowerShell + WASAPI COM interop.

**Install:** download the release ZIP, extract it, double-click `Discord-WaveLink-Mute-Setup.bat`.

**Commands:** `-Mute`, `-Unmute`, `-List`, `-Install`, `-Remove`

**Log:** `%LOCALAPPDATA%\DiscordMuteAutomation\log.txt`

**License:** MIT. Unofficial project, not affiliated with Elgato or Discord. Use at your own risk.
