# Proposal

## Why

Следующий этап IDE_ROADMAP/LANGUAGE_MATRIX — JS/Node. Сейчас JS подсвечивается,
но ts_ls, JavaScript formatter, Node DAP/default и тестовый adapter отсутствуют.
Нужен полный минимальный пользовательский сценарий с постоянными E2E.

## What Changes

- JS/JSX LSP через TypeScript Language Server и Prettier; локальные project
  tools имеют приоритет, запуск не устанавливает инструменты.
- Node run current file/package scripts в существующем Overseer/Tasks.
- Официальный js-debug DAP: F5 без launch.json и проектный launch.json,
  breakpoint/eval/stdout/stderr, понятная ошибка отсутствующего инструмента.
- Neotest Jest: nearest/file/results/output/debug, локальный Jest и аргументы
  без shell-разбиения путей. У просмотренного node:test adapter найден broken
  import и отсутствует nearest; native node:test в этот change не входит.
- Явная pinned подготовка Node/tools/parser, Windows/Ubuntu E2E, история/docs.

## Capabilities

### New Capabilities

- `node-workflow`: IDE-NODE-1…4 — язык, запуск, отладка и Jest тесты.

### Modified Capabilities

Нет. IDE-FMT-1 сохраняется; новые JS filetype mappings используют общую политику.

## Impact

Общий forge.node для portable CLI/path discovery и интеграция существующих
LSP/Conform/DAP/Overseer/Neotest. Один pinned plugin neotest-jest; SDK/остальные
пины не меняются. Тестовые Node/npm зависимости готовятся явно, Windows temp
на F:. Mac/GUI отдельно, Docker lifecycle не входит; недоступный engine не PASS.
