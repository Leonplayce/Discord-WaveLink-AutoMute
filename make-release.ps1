# Creates a ZIP for sharing (installer + README.txt).
# Usage:  powershell -ExecutionPolicy Bypass -File .\make-release.ps1

$ErrorActionPreference = 'Stop'
$root       = $PSScriptRoot
$releaseDir = Join-Path $root 'release'
$stage      = Join-Path $env:TEMP ('DiscordWaveLinkRelease_' + [guid]::NewGuid().ToString('N'))

New-Item -ItemType Directory -Path $stage -Force | Out-Null
Copy-Item (Join-Path $root 'Discord-WaveLink-Mute-Setup.bat') $stage -Force
Copy-Item (Join-Path $root 'README.txt') $stage -Force

New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
$zip = Join-Path $releaseDir 'Discord-WaveLink-Mute.zip'
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip
Remove-Item $stage -Recurse -Force

Write-Host ('Release ZIP created: ' + $zip)
