# spec: IDE-BOOT-12. Общий resolver SDK и восстановление окружения.
& (Join-Path $PSScriptRoot 'scripts/launch-forge.ps1') @args
exit $LASTEXITCODE
