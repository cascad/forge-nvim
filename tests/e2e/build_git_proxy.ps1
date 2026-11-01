# Встроенный Windows PowerShell/.NET компилирует только launcher тестового argv.
param([Parameter(Mandatory=$true)][string]$Output)
$ErrorActionPreference='Stop'
if(-not [IO.Path]::IsPathRooted($Output) -or [IO.Path]::GetExtension($Output) -ne '.exe') {
    throw 'Output must be an absolute .exe path'
}
if(Test-Path -LiteralPath $Output) { throw 'Launcher already exists' }
$forgeSource=Join-Path $PSScriptRoot 'git_proxy_launcher.cs'
Add-Type -TypeDefinition ([IO.File]::ReadAllText($forgeSource)) -OutputAssembly $Output -OutputType ConsoleApplication
