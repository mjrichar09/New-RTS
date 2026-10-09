# Starts a local BAR Weather skirmish without the lobby.
# Usage: powershell -ExecutionPolicy Bypass -File tools\run_skirmish.ps1
param(
	[string]$DataDir = "M:\BAR\Beyond-All-Reason\data",
	[string]$Engine = "recoil_2026.07.04"
)

$spring = Join-Path $DataDir "engine\$Engine\spring.exe"
$script = Join-Path $PSScriptRoot "skirmish.txt"

if (-not (Test-Path $spring)) { throw "Engine not found: $spring" }

& $spring --isolation --write-dir $DataDir $script
