# Design

## Context

Мотивация — proposal.md. Уже есть common LSP/Conform, DAP config loader,
Overseer/Neotest и editor RPC harness. JS native parser входит в список, но
явно подготовлен только Go. Публичный Jest adapter поддерживает DAP/nearest,
однако его jestCommand разбивается по whitespace; нужны безопасные argv.

## Goals / Non-Goals

**Goals:** полный минимальный JS/Node сценарий в существующих панелях, project
tools и единая portable граница команд, настоящие E2E каждой новой функции.
**Non-Goals:** браузерный debug, Deno/Bun, TS transpilation/source-map матрица,
все test frameworks, node:test adapter, перестройка менеджера панелей,
Docker Desktop/WSL lifecycle и закрытие IDE-047/048 по посторонним результатам.

## Decisions

1. forge.node отвечает за Node/CLI discovery, project root, js-debug и
   public integration adapters. Native Node executable запускает JS entrypoints
   списком argv: project-local package → явно заданный shared tools → Mason/
   установленный PATH. Это исключает shell/.cmd зависимость в core workflow.
2. ts_ls использует существующий nvim-lspconfig и guarded root/cmd: при
   отсутствии tools не стартует. Prettier использует стандартные Conform args
   с Native Node executable; общий IDE-FMT-1 порядок сохраняется.
3. NodeRun/NodeRunFile создают обычные Overseer задачи; scripts picker читает
   package.json, npm CLI вызывается через Node. Существующие providers остаются.
4. js-debug из официального standalone release. Явный FORGE_JS_DEBUG_SERVER,
   затем установленный Mason path. Default pwa-node/internalConsole/outputCapture
   std; node alias нормализуется публичным enrich_config. Preflight до launch;
   missing tools не оставляют ожидание adapter. launch.json loader сохраняется.
5. Pinned neotest-jest, его публичный build_spec interface дополняется Node/Jest
   argv из package paths, без изменений upstream/private code. Native adapter
   сохраняет discovery/results/nearest; strategy config использует тот же DAP.
   Последний path regex заменяется literal --runTestsByPath (для dir --roots),
   чтобы Jest сравнивал реальные пути независимо от разделителей; DAP args
   берутся из итогового argv, а не исходного regex.
6. prepare_node.py: Node 24.11.0, TSLS 5.1.3, TS 5.9.3, Prettier 3.6.2,
   Jest 30.2.0 и js-debug 1.105.0; SDK/archive hashes и npm lock/integrity.
   JS parser из pinned Treesitter. Установка только --download, temp/cache F:.
7. Fixture копирует реальные подготовленные packages в private project,
   snapshot исключает node_modules, сохраняя manifest/lock/source/outputs.
   Windows/Ubuntu последовательны; engine сейчас отсутствует, Ubuntu задача
   остаётся открытой. Mac/GUI без запуска не считаются проверенными.

8. Найденный IDE-051: Neotest canonicalизирует явный file ID, но nearest берёт
   raw buffer path. Добавить общий realpath на этой границе через существующий
   pin/SHA backport, без OS-ветки и runtime записи plugin source. Постоянный
   Node nearest E2E использует slash/Unicode путь; source RED сохранён.

## Risks / Trade-offs

- Много JS dependencies → фиксированный npm lock, copy только нужных modules,
  очистка private runtime после snapshot, без копирования deps в artifacts.
- DAP child sessions → реальные breakpoint/eval/output E2E, не факт наличия config.
- Command quoting/working directory → Unicode/пробелы и local dependency fixture.
- Новый plugin → pinned lock/catalog/preparer и прежние Go/smoke регрессы.
- Отсутствие engine → Windows функционал продолжается, Ubuntu не подменяется PASS.
