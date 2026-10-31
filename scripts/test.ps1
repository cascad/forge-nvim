# Единая точка входа внутри Windows VM; зависимости готовятся отдельно.
param(
    [ValidateSet('quick', 'e2e', 'full')]
    [string] $Mode = 'full'
)
$ErrorActionPreference = 'Stop'
$forgeTestRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $forgeTestRoot
try {
    if (-not (Get-Command nvim -ErrorAction SilentlyContinue)) {
        throw 'Neovim is required. Prepare this VM before running tests.'
    }
    [string[]] $forgeTestSuites = switch ($Mode) {
        'quick' { @('unit') }
        'e2e'   { @('e2e') }
        'full'  { @('unit', 'e2e', 'wezterm', 'install', 'trace', 'conpty') }
    }
    & nvim -l tests/run.lua @forgeTestSuites
    $forgeTestExit = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $forgeTestExit
