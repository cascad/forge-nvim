# spec: IDE-BOOT-28. Explicit binary/config/new process; caller environment untouched.
$ErrorActionPreference='Stop'
$frideKit=Split-Path -Parent $PSScriptRoot
$frideWezTerm=Join-Path $frideKit 'runtime/terminal/wezterm/wezterm.exe'
if (-not (Test-Path -LiteralPath $frideWezTerm -PathType Leaf)) { throw 'Terminal component unavailable.' }
& $frideWezTerm --config-file (Join-Path $frideKit 'config/fride-wezterm.lua') start --always-new-process --cwd (Get-Location).Path -- powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'fride.ps1') @args
exit $LASTEXITCODE
