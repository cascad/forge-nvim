# Proposal

## Why

WF-04/05/10 требуют работы со смесью языков в одном repo. Отдельные workflows
не доказывают, что выбранный cwd, language roots и запуск не перетекают между ними.
После Go.work debug/Tests/LSP проверяем один конкретный mixed context cycle.
Source23787689169800 выявил IDE-120: Bash LSP найден из файла, но не запускается
из config root. forge.node.root без package.json принимает каталог за файл,
возвращает parent и пропускает root/node_modules. Спека: IDE-NODE-5 ADDED.
После исправления source24472874457100 показал IDE-122: default4s nvim-dap
покрывает initialize+launch; холодный debugpy доходит до initialized позже,
предупреждение Press ENTER блокирует обработку ответа. Нужен native Python budget30s.

## What Changes

- Fixture Go/Rust/Python/JS/Bash/SQL в одном Git root.
- Native E2E: открыть все6 filetypes, дождаться готовых LSP с нужными roots,
  сохранить cwd; Node package script из web, Python default debug из nested venv.
- Вернуться к Go после запусков и проверить прежний server/root.
- Windows/Ubuntu один прогон, точная история/границы; без развития общей infra.
- Исправить fallback для directory input Node tools: сохранить сам каталог.
- Задать Python adapter public initialize_timeout_sec=30, сохранив быстрые ошибки.

## Capabilities

### New Capabilities

- `node-tool-context`: IDE-NODE-5, корректный directory/file input общего поиска.
- `python-cold-debug`: IDE-DAP-8, ограниченное ожидание cold initialize+launch.

### Modified Capabilities

Прежние Node/Bash требования сохраняются; найденный случай выделен отдельно.

## Impact

forge/node.lua fallback, fixture/E2E/registry/docs/history. Backend/SDK/pins и общий
workspace owner прежние. Не вся mixed Tests/debug/rename матрица; Mac/physical
отдельно. Данные из прежних SDK, без download и Docker Desktop lifecycle.
