# IDE-BOOT-21. Execute the exact UI recipe against local cmdlet doubles only.
param([Parameter(Mandatory)][string]$ScriptPath,
      [Parameter(Mandatory)][string]$TracePath,
      [ValidateSet('missing','module','provider','failure')][string]$Mode='missing')
$ErrorActionPreference='Stop'
$calls=[Collections.Generic.List[string]]::new()
function Get-Module {
    param([switch]$ListAvailable,[string]$Name)
    if ($Name -ne 'Microsoft.WinGet.Client') { throw 'Unexpected module query' }
    if ($Mode -eq 'module') { [pscustomobject]@{Name=$Name} }
}
function Get-PackageProvider {
    [CmdletBinding()]param([switch]$ListAvailable,[string]$Name)
    if ($Name -ne 'NuGet') { throw 'Unexpected provider query' }
    if ($Mode -eq 'provider') { [pscustomobject]@{Name=$Name} }
}
function Install-PackageProvider {
    param([string]$Name,[string]$Scope,[switch]$Force)
    if ($Name -ne 'NuGet' -or $Scope -ne 'CurrentUser' -or !$Force) { throw 'Unexpected provider install' }
    $calls.Add('provider')
}
function Install-Module {
    param([string]$Name,[string]$Scope,[string]$Repository,[switch]$Force)
    if ($Name -ne 'Microsoft.WinGet.Client' -or $Scope -ne 'CurrentUser' -or $Repository -ne 'PSGallery' -or !$Force) { throw 'Unexpected module install' }
    $calls.Add('module')
    if ($Mode -eq 'failure') { throw 'fixture module download failure' }
}
function Import-Module {
    [CmdletBinding()]param([string]$Name)
    if ($Name -ne 'Microsoft.WinGet.Client') { throw 'Unexpected import' }
    $calls.Add('import')
}
function Repair-WinGetPackageManager {
    [CmdletBinding()]param([switch]$Force,[switch]$Latest,[switch]$AllUsers)
    if (!$Force -or !$Latest -or $AllUsers) { throw 'Unexpected manager bootstrap' }
    $calls.Add('repair')
}
try {
    & ([scriptblock]::Create([IO.File]::ReadAllText($ScriptPath)))
} finally {
    [IO.File]::WriteAllText($TracePath,(ConvertTo-Json -InputObject @($calls)),[Text.UTF8Encoding]::new($false))
}
