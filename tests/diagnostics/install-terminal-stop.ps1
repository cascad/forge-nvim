# Only the private executable of this one disposable E2E kit, never name-wide kill.
param([Parameter(Mandatory=$true)][string]$BinaryPath)
$ErrorActionPreference='Stop'
$frideBinary=[IO.Path]::GetFullPath($BinaryPath)
if (-not $frideBinary.EndsWith('\runtime\terminal\wezterm\wezterm-gui.exe',[StringComparison]::OrdinalIgnoreCase)) { throw 'Expected private GUI executable.' }
Get-CimInstance Win32_Process -Filter "Name='wezterm-gui.exe'" | Where-Object { $_.ExecutablePath -eq $frideBinary } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
