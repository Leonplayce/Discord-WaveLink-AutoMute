# Builds the one-click installer (Discord-WaveLink-Mute-Setup.bat):
# takes the current engine (Mute-Discord-WaveLink.ps1) and embeds it
# between the #ENGBEGIN# and #ENGEND# markers in the batch file.
#
# Usage:  powershell -ExecutionPolicy Bypass -File .\build-installer.ps1

$ErrorActionPreference = 'Stop'
$root    = $PSScriptRoot
$batPath = Join-Path $root 'Discord-WaveLink-Mute-Setup.bat'
$engPath = Join-Path $root 'Mute-Discord-WaveLink.ps1'

$engine = [IO.File]::ReadAllText($engPath)

if ($engine -match '[^\x00-\x7F]') { throw 'The engine contains non-ASCII characters - please remove them (otherwise the batch file becomes unclean).' }
if ($engine -match '#ENG') { throw 'The engine contains the marker string #ENG... - please rename it.' }

$bat   = [IO.File]::ReadAllText($batPath)
$begin = '#ENGBEGIN#'
$end   = '#ENGEND#'
$i = $bat.IndexOf($begin)
$j = $bat.IndexOf($end, $i)
if ($i -lt 0 -or $j -le $i) { throw 'Markers #ENGBEGIN#/#ENGEND# not found in the batch file.' }

$new = $bat.Substring(0, $i + $begin.Length) + "`n" + $engine.TrimEnd() + "`n" + $bat.Substring($j)
[IO.File]::WriteAllText($batPath, $new, (New-Object System.Text.UTF8Encoding($false)))

# Verification: extract the engine from the batch file again and compare
$check = [IO.File]::ReadAllText($batPath)
$i2 = $check.IndexOf($begin)
$j2 = $check.IndexOf($end, $i2)
$extracted = $check.Substring($i2 + $begin.Length, $j2 - $i2 - $begin.Length)
if ($extracted.Trim() -ne $engine.Trim()) { throw 'Verification failed: extracted text differs from the engine.' }

Write-Host ('Installer rebuilt: ' + $batPath)
Write-Host ('Size: ' + (Get-Item $batPath).Length + ' bytes')
