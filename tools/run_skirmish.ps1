# Starts a local BAR Weather skirmish without the lobby.
# Usage: powershell -ExecutionPolicy Bypass -File tools\run_skirmish.ps1
# Multiplayer: pass -Script tools\mp_host.txt (host) or -Script tools\mp_join.txt (friend).
param(
	[string]$Script = (Join-Path $PSScriptRoot "skirmish.txt"),
	[string]$DataDir = "M:\BAR\Beyond-All-Reason\data",
	[string]$Engine = "recoil_2026.07.04"
)

$spring = Join-Path $DataDir "engine\$Engine\spring.exe"

if (-not (Test-Path $spring)) { throw "Engine not found: $spring" }

if (-not (Test-Path $Script)) { throw "Start script not found: $Script" }

& $spring --isolation --write-dir $DataDir (Resolve-Path $Script)
