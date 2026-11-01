# Изолированная проверка upstream/candidate SDK. Установленный Neovim не меняется.
param(
    [ValidateSet('upstream','candidate')][string]$Variant='candidate',
    [switch]$Download
)
$ErrorActionPreference='Stop'
$forgeRepo=Split-Path -Parent $PSScriptRoot
$forgeWork=Join-Path $forgeRepo '.tests/neovim-native'
$forgeSource=Join-Path $forgeWork 'v0.12.2-src'
$forgeInstall=if($Variant -eq 'candidate'){Join-Path $forgeRepo '.tools/neovim/windows-x64'}else{Join-Path $forgeWork 'upstream'}
$forgePatch=Join-Path $PSScriptRoot 'sdk/neovim-conpty-lifecycle.patch'
$forgeLock=Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'sdk/windows.json')|ConvertFrom-Json
. (Join-Path $PSScriptRoot 'lib/nvim-sdk.ps1')
$forgeBuildLock=$null
$forgeSaved=@{TEMP=$env:TEMP;TMP=$env:TMP;TMPDIR=$env:TMPDIR;NVIM_LOG_FILE=$env:NVIM_LOG_FILE}
New-Item -ItemType Directory -Path (Join-Path $forgeRepo '.tests/tmp') -Force|Out-Null
$env:TEMP=Join-Path $forgeRepo '.tests/tmp';$env:TMP=$env:TEMP;$env:TMPDIR=$env:TEMP
$env:NVIM_LOG_FILE=Join-Path $env:TEMP 'sdk-build-nvim.log'
function Invoke-ForgeBuildStep([string]$Program,[string[]]$Arguments) {
    & $Program @Arguments
    if($LASTEXITCODE -ne 0){throw "Build step failed ($LASTEXITCODE): $Program"}
}
try {
    if($env:OS -ne 'Windows_NT'){throw 'Этот SDK probe собирается на Windows; Lua repro общий для ОС.'}
    if((Get-ForgeFileSHA256 $forgePatch) -ne $forgeLock.PatchSHA256){throw 'SDK patch hash mismatch'}
    New-Item -ItemType Directory -Path $forgeWork -Force|Out-Null
    $forgeBuildLock=[IO.File]::Open((Join-Path $forgeWork '.build-lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    if(-not (Test-Path -LiteralPath $forgeSource)) {
        if(-not $Download){throw 'Нужен явный -Download для source/dependencies.'}
        New-Item -ItemType Directory -Path $forgeWork -Force|Out-Null
        Invoke-ForgeBuildStep 'git' @('clone','--depth','1','--branch','v0.12.2','https://github.com/neovim/neovim.git',$forgeSource)
    }
    $forgeResolved=(Resolve-Path -LiteralPath $forgeSource).Path
    if(-not $forgeResolved.StartsWith(([IO.Path]::GetFullPath($forgeWork)+[IO.Path]::DirectorySeparatorChar),[StringComparison]::OrdinalIgnoreCase)) {throw 'Unexpected SDK source path'}
    if((Get-Item -LiteralPath $forgeSource).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'SDK source cannot be a reparse point'}
    $forgeRevision=(& git -C $forgeSource rev-parse HEAD).Trim()
    if($forgeRevision -ne $forgeLock.SourceRevision){throw 'SDK source revision mismatch'}
    $forgeChanged=@(& git -C $forgeSource diff --name-only)
    if(@($forgeChanged|Where-Object {$_ -ne 'src/nvim/os/pty_proc_win.c'}).Count){throw 'Unrecognized SDK source edits'}
    # Одна из двух проверок обязана отказать; WinPS 5.1 считает stderr ошибкой.
    $forgePreviousAction=$ErrorActionPreference
    try {
        $ErrorActionPreference='Continue'
        & git -C $forgeSource apply --check $forgePatch 2>$null
        $forgeIsUpstream=$LASTEXITCODE -eq 0
        & git -C $forgeSource apply --reverse --check $forgePatch 2>$null
        $forgeIsCandidate=$LASTEXITCODE -eq 0
    } finally {$ErrorActionPreference=$forgePreviousAction}
    if(-not $forgeIsUpstream -and -not $forgeIsCandidate){throw 'SDK source is neither expected upstream nor exact candidate'}
    $forgeDiff=(& git -C $forgeSource diff -- src/nvim/os/pty_proc_win.c) -join "`n"
    $forgeExpected=([IO.File]::ReadAllText($forgePatch) -replace "`r`n","`n").TrimEnd()
    if(($forgeIsUpstream -and $forgeDiff) -or ($forgeIsCandidate -and $forgeDiff.TrimEnd() -ne $forgeExpected)){throw 'Unrecognized edits in SDK terminal source'}
    if($Variant -eq 'candidate' -and $forgeIsUpstream){Invoke-ForgeBuildStep 'git' @('-C',$forgeSource,'apply',$forgePatch)}
    if($Variant -eq 'upstream' -and $forgeIsCandidate){Invoke-ForgeBuildStep 'git' @('-C',$forgeSource,'apply','--reverse',$forgePatch)}
    $forgeVswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
    $forgeVs=(& $forgeVswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath).Trim()
    if(-not $forgeVs){throw 'Нужен Visual Studio C++ Build Tools на builder-машине.'}
    Import-Module (Join-Path $forgeVs 'Common7/Tools/Microsoft.VisualStudio.DevShell.dll')
    Enter-VsDevShell -VsInstallPath $forgeVs -SkipAutomaticLocation -DevCmdArguments '-arch=x64 -host_arch=x64'
    if($Download){
        Invoke-ForgeBuildStep 'cmake' @('-S',(Join-Path $forgeSource 'cmake.deps'),'-B',(Join-Path $forgeSource '.deps'),'-G','Ninja','-DCMAKE_BUILD_TYPE=Release','-DCMAKE_C_COMPILER=cl')
        Invoke-ForgeBuildStep 'cmake' @('--build',(Join-Path $forgeSource '.deps'),'--config','Release','--parallel','8')
    } elseif(-not (Test-Path -LiteralPath (Join-Path $forgeSource '.deps/usr/include/uv.h'))) {
        throw 'Не подготовлены зависимости SDK. Выполни с явным -Download.'
    }
    New-Item -ItemType Directory -Path $forgeInstall -Force|Out-Null
    '{"Ready":false}'|Set-Content -LiteralPath (Join-Path $forgeInstall 'forge-sdk.json')
    Invoke-ForgeBuildStep 'cmake' @('-S',$forgeSource,'-B',(Join-Path $forgeSource 'build'),'-G','Ninja','-DCMAKE_BUILD_TYPE=RelWithDebInfo','-DCMAKE_C_COMPILER=cl',('-DCMAKE_INSTALL_PREFIX='+$forgeInstall))
    Invoke-ForgeBuildStep 'cmake' @('--build',(Join-Path $forgeSource 'build'),'--config','RelWithDebInfo','--parallel','8')
    Invoke-ForgeBuildStep 'cmake' @('--install',(Join-Path $forgeSource 'build'),'--config','RelWithDebInfo')
    $forgeBinary=Join-Path $forgeInstall 'bin/nvim.exe'
    $forgePatchHash=Get-ForgeFileSHA256 $forgePatch
    if($Variant -eq 'candidate') {
        Invoke-ForgeBuildStep $forgeBinary @('-l',(Join-Path $forgeRepo 'tests/diagnostics/terminal-resize.lua'),'--nvim',$forgeBinary)
    }
    [pscustomobject]@{Ready=$true;Schema=1;Variant=$Variant;SourceRevision=$forgeRevision;PatchSHA256=$forgePatchHash;Binary='bin/nvim.exe';BinarySHA256=(Get-ForgeFileSHA256 $forgeBinary);ConPTYProbe=($Variant -eq 'candidate')}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $forgeInstall 'forge-sdk.json')
    Write-Output "SDK ready: $forgeBinary"
} finally {
    if($forgeBuildLock){$forgeBuildLock.Dispose()}
    foreach($forgeKey in $forgeSaved.Keys){[Environment]::SetEnvironmentVariable($forgeKey,$forgeSaved[$forgeKey],'Process')}
}
