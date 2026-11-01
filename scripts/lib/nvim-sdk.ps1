# Один resolver для пользовательского launcher и тестов. Никаких загрузок.
function Get-ForgeFileSHA256([string]$Path) {
    $forgeStream=[IO.File]::OpenRead($Path)
    $forgeSHA=[Security.Cryptography.SHA256]::Create()
    try {return [BitConverter]::ToString($forgeSHA.ComputeHash($forgeStream)).Replace('-','')}
    finally {$forgeSHA.Dispose();$forgeStream.Dispose()}
}
function Get-ForgeNvim([string]$Root) {
    if($env:FORGE_NVIM -eq 'system'){return 'nvim'}
    if($env:FORGE_NVIM){throw 'FORGE_NVIM supports only the explicit diagnostic value: system'}
    $forgeHint='Run: powershell -NoProfile -File scripts/prepare-windows-sdk.ps1 -Download'
    $forgeSdk=Join-Path $Root '.tools/neovim/windows-x64'
    $forgeBinary=Join-Path $forgeSdk 'bin/nvim.exe'
    try {
        $forgeLock=Get-Content -Raw -LiteralPath (Join-Path $Root 'scripts/sdk/windows.json') -ErrorAction Stop|ConvertFrom-Json
        $forgeManifest=Get-Content -Raw -LiteralPath (Join-Path $forgeSdk 'forge-sdk.json') -ErrorAction Stop|ConvertFrom-Json
        if(-not $forgeManifest.Ready -or $forgeManifest.Schema -ne $forgeLock.Schema -or
           $forgeManifest.Variant -ne 'candidate' -or -not $forgeManifest.ConPTYProbe -or
           $forgeManifest.SourceRevision -ne $forgeLock.SourceRevision -or
           $forgeManifest.PatchSHA256 -ne $forgeLock.PatchSHA256 -or
           (Get-ForgeFileSHA256 (Join-Path $Root 'scripts/sdk/neovim-conpty-lifecycle.patch')) -ne $forgeLock.PatchSHA256 -or
           (Get-ForgeFileSHA256 $forgeBinary) -ne $forgeManifest.BinarySHA256) {
            throw 'SDK metadata/hash mismatch'
        }
    } catch {throw "Forge Windows SDK is missing, stale or corrupt. $forgeHint`n$($_.Exception.Message)"}
    return $forgeBinary
}
