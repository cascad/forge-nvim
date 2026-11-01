param([ValidateSet('upstream','candidate')][string]$Variant='candidate',[switch]$Download)
$ErrorActionPreference='Stop'
& (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'scripts/prepare-windows-sdk.ps1') -Variant $Variant -Download:$Download
exit $LASTEXITCODE
