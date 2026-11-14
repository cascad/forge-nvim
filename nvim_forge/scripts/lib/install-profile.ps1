# spec: IDE-BOOT-10. Native PowerShell5.1; одна таблица с POSIX/Lua.
$script:ForgeProfileRows = @([IO.File]::ReadAllLines((Join-Path $PSScriptRoot '..\components.tsv'), [Text.Encoding]::UTF8) | ForEach-Object {
    $fields = $_.Split("`t")
    if ($fields.Count -ne 5) { throw 'Invalid component table.' }
    [PSCustomObject]@{ Id=$fields[0]; Label=$fields[1]; Dependencies=$fields[2] }
})
function Resolve-ForgeProfile {
    param([Alias('Profile')][string]$Mode='Default', [string]$Components='', [bool]$Explicit=$false)
    $selected = @{}
    $visible = @($script:ForgeProfileRows | Where-Object { $_.Label -ne '-' })
    if ($Explicit) {
        foreach ($id in $Components.Split(',')) { if ($id.Trim()) { $selected[$id.Trim().ToLowerInvariant()]=$true } }
    } else {
        foreach ($row in $visible) { $selected[$row.Id]=$true }
        if ($Mode -eq 'Custom') {
            $index=0
            while ($true) {
                Write-Host (([char]27)+'[2J'+([char]27)+'[H') -NoNewline
                Write-Host 'Select components: arrows/j/k, Space, Enter; Esc/q cancels'
                for ($i=0; $i -lt $visible.Count; $i++) {
                    $row=$visible[$i]; $mark=if ($selected.ContainsKey($row.Id)) { 'x' } else { ' ' }
                    $cursor=if ($i -eq $index) { '>' } else { ' ' }
                    Write-Host "$cursor [$mark] $($row.Label)"
                }
                try { $key=$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') }
                catch { throw "Interactive console required for Custom; use -Components for unattended setup. $_" }
                if ($key.VirtualKeyCode -eq 13) { break }
                if ($key.VirtualKeyCode -eq 27 -or $key.Character -eq 'q') { throw 'Installation cancelled.' }
                if ($key.VirtualKeyCode -eq 38 -or $key.Character -eq 'k') { $index=($index+$visible.Count-1)%$visible.Count }
                if ($key.VirtualKeyCode -eq 40 -or $key.Character -eq 'j') { $index=($index+1)%$visible.Count }
                if ($key.VirtualKeyCode -eq 32 -and $visible[$index].Id -ne 'core') {
                    $id=$visible[$index].Id
                    if ($selected.ContainsKey($id)) { $selected.Remove($id) } else { $selected[$id]=$true }
                }
            }
        }
    }
    $selected['core']=$true
    foreach ($id in @($selected.Keys)) {
        if (-not @($script:ForgeProfileRows | Where-Object { $_.Id -eq $id }).Count) { throw "Unknown component: $id" }
    }
    do {
        $changed=$false
        foreach ($row in $script:ForgeProfileRows) {
            if ($selected.ContainsKey($row.Id) -and $row.Dependencies -ne '-') {
                foreach ($id in $row.Dependencies.Split(',')) {
                    if (-not $selected.ContainsKey($id)) { $selected[$id]=$true; $changed=$true }
                }
            }
        }
    } while ($changed)
    return (@($script:ForgeProfileRows | Where-Object { $selected.ContainsKey($_.Id) } | ForEach-Object { $_.Id }) -join ',')
}
function Test-ForgeComponent([string]$Id) {
    if ($env:FORGE_NVIM_COMPONENTS) { return (','+$env:FORGE_NVIM_COMPONENTS+',').Contains(','+$Id+',') }
    if ($Id -in @('core','terminal')) { return $true }
    return ($Id -in @('go','go-runtime','rust','python') -and $WithLanguages)
}
