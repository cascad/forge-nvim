# Единая точка входа внутри Windows VM; зависимости готовятся отдельно.
param(
    [ValidateSet('quick', 'e2e', 'acceptance', 'full', 'regression')]
    [string] $Mode = 'full',
    [string[]] $Files = @(),
    [switch] $Plan,
    [switch] $Prepare
)
$ErrorActionPreference = 'Stop'
$forgeTestRoot = Split-Path -Parent $PSScriptRoot
$forgeSavedTemp = $env:TEMP
$forgeSavedTmp = $env:TMP
$forgeSavedTmpDir = $env:TMPDIR
$forgeSavedNvimLog = $env:NVIM_LOG_FILE
$forgeTestTemp = Join-Path $forgeTestRoot '.tests/tmp'
New-Item -ItemType Directory -Path $forgeTestTemp -Force | Out-Null
$env:TEMP = $forgeTestTemp
$env:TMP = $forgeTestTemp
$env:TMPDIR = $forgeTestTemp
$env:NVIM_LOG_FILE = Join-Path $forgeTestTemp 'runner-nvim.log'
Push-Location -LiteralPath $forgeTestRoot
try {
    . (Join-Path $PSScriptRoot 'lib/nvim-sdk.ps1')
    $forgeTestNvim = Get-ForgeNvim $forgeTestRoot
    if (-not (Get-Command $forgeTestNvim -ErrorAction SilentlyContinue)) {
        throw 'Neovim is required. Prepare this VM before running tests.'
    }
    [string[]] $forgeTestSuites = switch ($Mode) {
        'quick' { @('unit') }
        'e2e'   { @('e2e') }
        'full'  { @('unit', 'e2e', 'wezterm', 'install', 'trace', 'conpty') }
    }
    if ($Files.Count -gt 0 -or $Plan -or $Prepare -or $Mode -in @('acceptance', 'regression')) {
        $forgeBatchArgs=@('-B','scripts/test-batch.py','--nvim',$forgeTestNvim,'--mode',$Mode)
        foreach ($forgeFile in $Files) { $forgeBatchArgs+=@('--file',$forgeFile) }
        if ($Plan) { $forgeBatchArgs+='--plan' }
        if ($Prepare) { $forgeBatchArgs+='--prepare' }
        & python @forgeBatchArgs
    } else {
        & $forgeTestNvim -l tests/run.lua @forgeTestSuites
    }
    $forgeTestExit = $LASTEXITCODE
} finally {
    Pop-Location
    $env:TEMP = $forgeSavedTemp
    $env:TMP = $forgeSavedTmp
    $env:TMPDIR = $forgeSavedTmpDir
    $env:NVIM_LOG_FILE = $forgeSavedNvimLog
}
exit $forgeTestExit
