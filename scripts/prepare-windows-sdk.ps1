# Explicit SDK preparation; selected SDK is preserved until all native probes pass.
param(
    [ValidateSet('upstream','candidate')][string]$Variant='candidate',
    [switch]$Download,
    [switch]$StageOnly
)
$ErrorActionPreference='Stop'
$forgeRepo=Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'lib/nvim-sdk.ps1')
$forgeWork=Assert-ForgeSdkPath $forgeRepo (Join-Path $forgeRepo '.tests/neovim-native')
$forgeSource=Assert-ForgeSdkPath $forgeRepo (Join-Path $forgeWork 'v0.12.2-src')
$forgeStage=Assert-ForgeSdkPath $forgeRepo (Join-Path $forgeWork ('stage-'+[Guid]::NewGuid().ToString('N')))
$forgeInstall=Join-Path $forgeStage 'sdk'
$forgeLock=Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'sdk/windows.json')|ConvertFrom-Json
$forgePatches=@(
    @{Path=(Join-Path $PSScriptRoot 'sdk/neovim-conpty-lifecycle.patch');Hash=$forgeLock.PatchSHA256;Source='src/nvim/os/pty_proc_win.c'},
    @{Path=(Join-Path $PSScriptRoot 'sdk/neovim-process-ancestry.patch');Hash=$forgeLock.ProcessPatchSHA256;Source='src/nvim/os/proc.c'}
)
$forgeBuildLock=$null
$forgeSaved=@{TEMP=$env:TEMP;TMP=$env:TMP;TMPDIR=$env:TMPDIR;NVIM_LOG_FILE=$env:NVIM_LOG_FILE}
function Invoke-ForgeBuildStep([string]$Program,[string[]]$Arguments) {
    & $Program @Arguments
    if($LASTEXITCODE -ne 0){throw "Build step failed ($LASTEXITCODE): $Program"}
}
try {
    if($env:OS -ne 'Windows_NT'){throw 'Windows SDK preparation requires Windows.'}
    New-Item -ItemType Directory -Path (Join-Path $forgeRepo '.tests/tmp') -Force|Out-Null
    $env:TEMP=Join-Path $forgeRepo '.tests/tmp';$env:TMP=$env:TEMP;$env:TMPDIR=$env:TEMP
    $env:NVIM_LOG_FILE=Join-Path $env:TEMP 'sdk-build-nvim.log'
    foreach($forgePatch in $forgePatches){
        if((Get-ForgeFileSHA256 $forgePatch.Path) -ne $forgePatch.Hash){throw 'SDK patch hash mismatch'}
    }
    New-Item -ItemType Directory -Path $forgeWork -Force|Out-Null
    $forgeBuildLock=[IO.File]::Open((Join-Path $forgeWork '.build-lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    if(-not (Test-Path -LiteralPath $forgeSource)) {
        if(-not $Download){throw 'Source/dependencies require explicit -Download.'}
        Invoke-ForgeBuildStep 'git' @('clone','--depth','1','--branch',$forgeLock.Version,'https://github.com/neovim/neovim.git',$forgeSource)
    }
    $forgeRevision=(& git -C $forgeSource rev-parse HEAD).Trim()
    if($forgeRevision -ne $forgeLock.SourceRevision){throw 'SDK source revision mismatch'}
    $forgeChanged=@(& git -C $forgeSource diff --name-only)
    if(@($forgeChanged|Where-Object {$_ -notin $forgePatches.Source}).Count){throw 'Unrecognized SDK source edits'}
    # Validate both files before applying either patch. Do not discard local edits.
    foreach($forgePatch in $forgePatches) {
        $forgePreviousAction=$ErrorActionPreference
        try {
            $ErrorActionPreference='Continue'
            & git -C $forgeSource apply --check $forgePatch.Path 2>$null
            $forgePatch.Upstream=$LASTEXITCODE -eq 0
            & git -C $forgeSource apply --reverse --check $forgePatch.Path 2>$null
            $forgePatch.Candidate=$LASTEXITCODE -eq 0
        } finally {$ErrorActionPreference=$forgePreviousAction}
        if(-not $forgePatch.Upstream -and -not $forgePatch.Candidate){throw 'SDK source is neither expected upstream nor exact candidate'}
        $forgeDiff=(& git -C $forgeSource diff --no-ext-diff --no-color --abbrev=7 -- $forgePatch.Source) -join "`n"
        $forgeExpected=([IO.File]::ReadAllText($forgePatch.Path) -replace "`r`n","`n").TrimEnd()
        if(($forgePatch.Upstream -and $forgeDiff) -or ($forgePatch.Candidate -and $forgeDiff.TrimEnd() -ne $forgeExpected)){throw 'Unrecognized edits in SDK patched source'}
    }
    foreach($forgePatch in $forgePatches) {
        if($Variant -eq 'candidate' -and $forgePatch.Upstream){Invoke-ForgeBuildStep 'git' @('-C',$forgeSource,'apply',$forgePatch.Path)}
        if($Variant -eq 'upstream' -and $forgePatch.Candidate){Invoke-ForgeBuildStep 'git' @('-C',$forgeSource,'apply','--reverse',$forgePatch.Path)}
    }
    $forgeVswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
    $forgeVs=(& $forgeVswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath).Trim()
    if(-not $forgeVs){throw 'Visual Studio C++ Build Tools required on builder.'}
    Import-Module (Join-Path $forgeVs 'Common7/Tools/Microsoft.VisualStudio.DevShell.dll')
    Enter-VsDevShell -VsInstallPath $forgeVs -SkipAutomaticLocation -DevCmdArguments '-arch=x64 -host_arch=x64'
    if($Download){
        Invoke-ForgeBuildStep 'cmake' @('-S',(Join-Path $forgeSource 'cmake.deps'),'-B',(Join-Path $forgeSource '.deps'),'-G','Ninja','-DCMAKE_BUILD_TYPE=Release','-DCMAKE_C_COMPILER=cl')
        Invoke-ForgeBuildStep 'cmake' @('--build',(Join-Path $forgeSource '.deps'),'--config','Release','--parallel','2')
    } elseif(-not (Test-Path -LiteralPath (Join-Path $forgeSource '.deps/usr/include/uv.h'))) {
        throw 'SDK dependencies missing. Run with explicit -Download.'
    }
    New-Item -ItemType Directory -Path $forgeInstall -Force|Out-Null
    Invoke-ForgeBuildStep 'cmake' @('-S',$forgeSource,'-B',(Join-Path $forgeSource 'build'),'-G','Ninja','-DCMAKE_BUILD_TYPE=RelWithDebInfo','-DCMAKE_C_COMPILER=cl',('-DCMAKE_INSTALL_PREFIX='+$forgeInstall))
    Invoke-ForgeBuildStep 'cmake' @('--build',(Join-Path $forgeSource 'build'),'--config','RelWithDebInfo','--parallel','2')
    Invoke-ForgeBuildStep 'cmake' @('--install',(Join-Path $forgeSource 'build'),'--config','RelWithDebInfo')
    $forgeBinary=Join-Path $forgeInstall 'bin/nvim.exe'
    if($Variant -eq 'candidate') {
        Invoke-ForgeBuildStep 'python' @('-X','utf8','-B',(Join-Path $forgeRepo 'tests/diagnostics/process-ancestry.py'),'--source',$forgeSource,'--output',(Join-Path $forgeStage 'ancestry'),'--sdk-candidate')
        Invoke-ForgeBuildStep $forgeBinary @('-l',(Join-Path $forgeRepo 'tests/e2e/process-lifecycle.test.lua'))
        Invoke-ForgeBuildStep $forgeBinary @('-l',(Join-Path $forgeRepo 'tests/diagnostics/terminal-resize.lua'),'--nvim',$forgeBinary)
    }
    [pscustomobject]@{Ready=$true;Schema=$forgeLock.Schema;Variant=$Variant;SourceRevision=$forgeRevision;
        PatchSHA256=$forgeLock.PatchSHA256;ProcessPatchSHA256=$forgeLock.ProcessPatchSHA256;
        ProcessSourceSHA256=$(if($Variant -eq 'candidate'){$forgeLock.ProcessSourceSHA256}else{$null});
        Binary='bin/nvim.exe';BinarySHA256=(Get-ForgeFileSHA256 $forgeBinary);
        ConPTYProbe=($Variant -eq 'candidate');ProcessProbe=($Variant -eq 'candidate');ProcessLifecycleProbe=($Variant -eq 'candidate')}|
        ConvertTo-Json|Set-Content -LiteralPath (Join-Path $forgeInstall 'forge-sdk.json')
    if($Variant -eq 'candidate' -and -not $StageOnly){Publish-ForgeNvimSDK $forgeRepo $forgeInstall}
    else {Write-Output "SDK staged: $forgeBinary"}
} finally {
    if($forgeBuildLock){$forgeBuildLock.Dispose()}
    foreach($forgeKey in $forgeSaved.Keys){[Environment]::SetEnvironmentVariable($forgeKey,$forgeSaved[$forgeKey],'Process')}
}
