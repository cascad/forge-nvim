#Requires -Version 5.1
param([ValidateSet('Default','Custom','Choose')][string]$Profile='Choose',[switch]$NoColor)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'lib/installer-ui.ps1')
$binary=Get-ForgeInstallerUI -Source $root -CacheRoot (Join-Path $root '.tests/installer-ui/cache') -Checkout $root -ExplicitPath ''
$uiArgs=@('--preview','--source',$root)
if ($Profile -ne 'Choose') { $uiArgs+=@('--profile',$Profile.ToLowerInvariant()) }
if ($NoColor) { $uiArgs+='--no-color' }
& $binary @uiArgs
exit $LASTEXITCODE
