# Proposal

## Why

Installed Default matrix нашёл реальные runtime gaps: Pyright запускался через
PATH wrapper вместо выбранного Node; на Ubuntu без Node в PATH wrapper падал.
На Windows BashLS не мог запустить ShellCheck за Mason .cmd export. Обычные
source tests использовали подготовленный прямой Pyright command и native binaries,
поэтому не проверяли настоящий managed layout. Это нарушает выбранные SDK paths
IDE-BOOT-38 и базовый industrial Bash/SQL scope IDE-BOOT-34.

## What Changes

- Pyright через существующий Node+JS entrypoint resolver, native roots/options и
  прежний project Python before_init. Ошибки выбранного Node/file без fallback.
- Общий read-only resolver actual .exe за Windows Mason .cmd, только по native
  InstallReceipt и только для Mason export; внешние wrappers не переписываются.
- BashLS shellcheck/shfmt settings и Conform shfmt получают native executable;
  Sqruff uses same managed boundary. На других ОС штатные пути прежние.

## Capabilities

### New Capabilities

- `managed-runtime-entrypoints`: IDE-BOOT-48.

## Impact

Node/LSP/tool_paths/Bash/SQL/format consumers, ready-path report/setup key pyright,
targeted native regressions и installed matrix. Без нового LSP, registry refresh,
manager, SDK install, wrapper generator или изменений пакетов upstream.
