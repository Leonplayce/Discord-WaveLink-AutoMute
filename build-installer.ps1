# Baut den Ein-Klick-Installer (Discord-WaveLink-Mute-Setup.bat) neu:
# Nimmt die aktuelle Engine (Mute-Discord-WaveLink.ps1) und bettet sie
# zwischen den Markern #ENGBEGIN# und #ENGEND# in die Batch-Datei ein.
#
# Aufruf:  powershell -ExecutionPolicy Bypass -File .\build-installer.ps1

$ErrorActionPreference = 'Stop'
$root    = $PSScriptRoot
$batPath = Join-Path $root 'Discord-WaveLink-Mute-Setup.bat'
$engPath = Join-Path $root 'Mute-Discord-WaveLink.ps1'

$engine = [IO.File]::ReadAllText($engPath)

if ($engine -match '[^\x00-\x7F]') { throw 'Die Engine enthaelt Nicht-ASCII-Zeichen - bitte entfernen (die Batch-Datei bleibt sonst unsauber).' }
if ($engine -match '#ENG') { throw 'Die Engine enthaelt den Marker-String #ENG... - bitte umbenennen.' }

$bat   = [IO.File]::ReadAllText($batPath)
$begin = '#ENGBEGIN#'
$end   = '#ENGEND#'
$i = $bat.IndexOf($begin)
$j = $bat.IndexOf($end, $i)
if ($i -lt 0 -or $j -le $i) { throw 'Marker #ENGBEGIN#/#ENGEND# in der Batch-Datei nicht gefunden.' }

$new = $bat.Substring(0, $i + $begin.Length) + "`n" + $engine.TrimEnd() + "`n" + $bat.Substring($j)
[IO.File]::WriteAllText($batPath, $new, (New-Object System.Text.UTF8Encoding($false)))

# Kontrolle: Engine wieder aus der Batch-Datei extrahieren und vergleichen
$check = [IO.File]::ReadAllText($batPath)
$i2 = $check.IndexOf($begin)
$j2 = $check.IndexOf($end, $i2)
$extracted = $check.Substring($i2 + $begin.Length, $j2 - $i2 - $begin.Length)
if ($extracted.Trim() -ne $engine.Trim()) { throw 'Kontrolle fehlgeschlagen: Extraktion weicht von der Engine ab.' }

Write-Host ('Installer neu gebaut: ' + $batPath)
Write-Host ('Groesse: ' + (Get-Item $batPath).Length + ' Bytes')
