# Design

## Context

Общий resolver уже есть. Native nvim-lspconfig задаёт roots Go/Rust функциями.
Conform поддерживает command callback; Neotest возвращает публичный RunSpec;
DAP уже имеет callback boundary. SDK metadata части adapters используют PATH.

## Goals / Non-Goals

**Goals:** явные IDE executables для правильного проекта; native roots,
callbacks/args/env, отсутствие startup/download side effects и E2E реальных tools.

**Non-Goals:** SDK wrappers, глобальный PATH, обновление SDK/pins, adapter patches.
Владелец выбрал native окружение как основу (§270). Выбор установленного SDK
и ручного пути — следующий продуктовый этап через штатную среду проекта,
с явным переоткрытием при необходимости; этот срез его не реализует.

## Decisions

- Общий executable helper использует существующий override + native exepath.
- Native LSP root callback сохраняется. Cmd callback получает executable для
  config.root_dir и сохраняет native cmd arguments/cmd_env/cmd_cwd/detached.
- Formatter command callback использует ctx.filename.
- Gotestsum override отложен: pinned neotest-golang lib/cmd.lua выполняет
  runner_fallback с проверкой PATH до RunSpec и меняет глобальный runner.
  Перезапись argv недостаточна; Go tests сохраняют исходную интеграцию.
- DAP выбирает root запуска; shared passive debug helper сохраняет CodeLLDB
  PATH/Windows/Mason fallback и legacy Delve overrides. Native Delve candidate
  version comparison остаётся в прежнем async DAP code.
- Passive Delve report показывает override/PATH availability; полный native
  candidate selection доступен в DapGoDlvInfo и записывается при debug.
- Rust warmup проверяет выбранный сервер до Cargo metadata; disabled server
  и RUSTUP_AUTO_INSTALL=0 остаются прежними. Shared SDK env не переназначается.

## Risks / Trade-offs

- SDK executable paths не поддерживаются всеми public adapters. В этом срезе
  process PATH не меняется. Следующий селектор может явно выбирать окружение
  нового процесса fride; это не изменение global PATH/SDK homes или private API.
- Active clients сохраняют старый executable → новый выбор после native restart.
- Missing/invalid path в warmup → видимая запись, metadata не запускается.
