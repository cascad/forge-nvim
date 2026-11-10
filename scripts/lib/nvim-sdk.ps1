# Один resolver для пользовательского launcher и тестов. Никаких загрузок.
function Get-ForgeFileSHA256([string]$Path) {
    $forgeStream=[IO.File]::OpenRead($Path)
    $forgeSHA=[Security.Cryptography.SHA256]::Create()
    try {return [BitConverter]::ToString($forgeSHA.ComputeHash($forgeStream)).Replace('-','')}
    finally {$forgeSHA.Dispose();$forgeStream.Dispose()}
}
function Get-ForgeVerifiedNvim([string]$Root,[string]$Sdk) {
    $forgeHint='Run: powershell -NoProfile -File scripts/prepare-windows-sdk.ps1 -Download'
    $forgeBinary=Join-Path $Sdk 'bin/nvim.exe'
    try {
        $forgeLock=Get-Content -Raw -LiteralPath (Join-Path $Root 'scripts/sdk/windows.json') -ErrorAction Stop|ConvertFrom-Json
        $forgeManifest=Get-Content -Raw -LiteralPath (Join-Path $Sdk 'forge-sdk.json') -ErrorAction Stop|ConvertFrom-Json
        if($forgeLock.Schema -ne 2 -or -not $forgeManifest.Ready -or $forgeManifest.Schema -ne $forgeLock.Schema -or
           $forgeManifest.Variant -ne 'candidate' -or -not $forgeManifest.ConPTYProbe -or
           -not $forgeManifest.ProcessProbe -or -not $forgeManifest.ProcessLifecycleProbe -or
           $forgeManifest.SourceRevision -ne $forgeLock.SourceRevision -or
           $forgeManifest.PatchSHA256 -ne $forgeLock.PatchSHA256 -or
           $forgeManifest.ProcessPatchSHA256 -ne $forgeLock.ProcessPatchSHA256 -or
           $forgeManifest.ProcessSourceSHA256 -ne $forgeLock.ProcessSourceSHA256 -or
           (Get-ForgeFileSHA256 (Join-Path $Root 'scripts/sdk/neovim-conpty-lifecycle.patch')) -ne $forgeLock.PatchSHA256 -or
           (Get-ForgeFileSHA256 (Join-Path $Root 'scripts/sdk/neovim-process-ancestry.patch')) -ne $forgeLock.ProcessPatchSHA256 -or
           (Get-ForgeFileSHA256 $forgeBinary) -ne $forgeManifest.BinarySHA256) {
            throw 'SDK metadata/hash mismatch'
        }
    } catch {throw "Forge Windows SDK is missing, stale or corrupt. $forgeHint`n$($_.Exception.Message)"}
    return $forgeBinary
}
function Get-ForgeNvim([string]$Root) {
    if($env:FORGE_NVIM -eq 'system'){return 'nvim'}
    if($env:FORGE_NVIM){throw 'FORGE_NVIM supports only the explicit diagnostic value: system'}
    return Get-ForgeVerifiedNvim $Root (Join-Path $Root '.tools/neovim/windows-x64')
}

# Every move stays within this checkout; reject junctions/symlinks in all ancestors.
function Assert-ForgeSdkPath([string]$Root,[string]$Path) {
    $forgeBase=[IO.Path]::GetFullPath($Root).TrimEnd('\','/')
    $forgeFull=[IO.Path]::GetFullPath($Path).TrimEnd('\','/')
    if(-not $forgeFull.StartsWith($forgeBase+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {
        throw 'SDK path is outside checkout'
    }
    $forgeCursor=$forgeFull
    while($forgeCursor.Length -ge $forgeBase.Length) {
        if(Test-Path -LiteralPath $forgeCursor) {
            if((Get-Item -Force -LiteralPath $forgeCursor).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw 'SDK path contains a reparse point'
            }
        }
        if($forgeCursor -eq $forgeBase){break}
        $forgeCursor=Split-Path -Parent $forgeCursor
    }
    return $forgeFull
}
function Publish-ForgeNvimSDK([string]$Root,[string]$StageSdk) {
    $forgeStage=Assert-ForgeSdkPath $Root $StageSdk
    $forgeStageRoot=[IO.Path]::GetFullPath((Join-Path $Root '.tests/neovim-native'))+[IO.Path]::DirectorySeparatorChar
    if(-not $forgeStage.StartsWith($forgeStageRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'SDK candidate is outside staging area'}
    $forgeSelected=Assert-ForgeSdkPath $Root (Join-Path $Root '.tools/neovim/windows-x64')
    $forgeBackup=Assert-ForgeSdkPath $Root ($forgeSelected+'.previous-'+[Guid]::NewGuid().ToString('N'))
    $null=Get-ForgeVerifiedNvim $Root $forgeStage
    New-Item -ItemType Directory -Path (Split-Path -Parent $forgeSelected) -Force|Out-Null
    $forgeMoved=$false
    $forgeInstalled=$false
    try {
        if(Test-Path -LiteralPath $forgeSelected){[IO.Directory]::Move($forgeSelected,$forgeBackup);$forgeMoved=$true}
        [IO.Directory]::Move($forgeStage,$forgeSelected)
        $forgeInstalled=$true
        $forgeBinary=Get-ForgeVerifiedNvim $Root $forgeSelected
    } catch {
        if($forgeInstalled){[IO.Directory]::Move($forgeSelected,$forgeStage)}
        if($forgeMoved){[IO.Directory]::Move($forgeBackup,$forgeSelected)}
        throw
    }
    [pscustomobject]@{Binary=$forgeBinary;PreviousSdk=$(if($forgeMoved){$forgeBackup}else{$null})}
}
