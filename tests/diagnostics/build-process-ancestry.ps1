# Compile/run только private native fixture; установленный Neovim не меняется.
param([string]$Source,[string]$Output)
$ErrorActionPreference='Stop'
if($env:OS -ne 'Windows_NT'){throw 'Native ancestry fixture запускается только на Windows.'}
$forgeAncestryRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$forgeAncestryTemp=Join-Path $forgeAncestryRoot '.tests/tmp'
New-Item -ItemType Directory -Path $forgeAncestryTemp -Force | Out-Null
$env:TEMP=$forgeAncestryTemp; $env:TMP=$forgeAncestryTemp; $env:TMPDIR=$forgeAncestryTemp
$forgeAncestryVswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$forgeAncestryVs=(& $forgeAncestryVswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath).Trim()
if(-not $forgeAncestryVs){throw 'Нужны MSVC C++ Build Tools для native fixture.'}
Import-Module (Join-Path $forgeAncestryVs 'Common7/Tools/Microsoft.VisualStudio.DevShell.dll')
Enter-VsDevShell -VsInstallPath $forgeAncestryVs -SkipAutomaticLocation -DevCmdArguments '-arch=x64 -host_arch=x64' | Out-Null
$forgeAncestryArgs=@('-B',(Join-Path $PSScriptRoot 'process-ancestry.py'))
if($Source){$forgeAncestryArgs+=@('--source',$Source)}
if($Output){$forgeAncestryArgs+=@('--output',$Output)}
& python @forgeAncestryArgs
exit $LASTEXITCODE
