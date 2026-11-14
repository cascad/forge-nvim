# Design

## Context

См. proposal.md. CLI +command errors могут оставить native exit0. Существуют
public backports.all/apply/check и ForgeTreesitterInstall/MasonToolsInstallSync.
Повторять patch logic или собственный plugin manager не требуется.

## Goals / Non-Goals

**Goals:** один Lua stage runner, явный exit и fresh process между stages,
correct XDG/NVIM_APPNAME на трёх ОС, restore вместо sync, весь existing applier.
**Non-Goals:** Default/Custom menu, installation каждого SDK/полный readiness,
обход внутренних package errors, которые native command сам не сообщает,
изменение startup или новый LSP/process manager.

## Decisions

setup-stage.lua получает plugins/parsers/tools; native vim.cmd в xpcall,
cquit1 при ошибке. Plugins stage после restore вызывает existing backports
apply/check. Fresh parser/tool process загружает config с подготовленными
payloads. POSIX shell glue общее для Mac/Linux; PowerShell использует тот же
Lua stage. Config context задаётся временно, рабочий каталог не является selector.

Stand копирует маленький профиль с fixture Lazy/TS/Mason commands; исполняет
настоящие installer и Neovim, actual public applier на private копиях16
проверенных plugin files. Packages/network не запускаются. Это regression
orchestration, не новая полная native install acceptance. Source snapshot
старых installers сохраняется, native outcomes не заменяются mocks.

## Risks / Trade-offs

Native command может сообщить package failure без exception → полный package
readiness остаётся следующим отдельным этапом, этот narrow contract его не
объявляет пройденным. Native Mac отдельно; Mac shell path можно прогнать как
contract на Ubuntu, но это не проверка macOS prerequisites.
