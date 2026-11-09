# Design

## Context

Причина/воспроизведение — proposal.md и IDE-052. Локальный package действительно
установлен в project .venv, pytest его выполняет; Pyright ищет другие paths.
DAP уже содержит переносимый selector; его алгоритм не нужно дублировать.

## Goals / Non-Goals

Устранить расхождение plain project venv в LSP/DAP и сохранить рабочую отладку.
Не менять managers Neotest, adapter protocol, панели, shell activation и
пользовательский system Python. Не обходить RED extraPaths/venv конфигом fixture.

## Decisions

1. forge.python.resolve(roots) использует существующий порядок DAP: валидный
   forge_python_path/FORGE_PYTHON_PATH, VIRTUAL_ENV, CONDA_PREFIX, project roots
   с .venv/venv/.env/env, затем python3/python PATH. expand/executable проверки
   и Windows Scripts/Conda executable против POSIX bin остаются на границе.
2. DAP передаёт прежний python_project_roots, сохраняя порядок текущего файла,
   cwd и LSP roots. Resolver не загружает DAP и ничего не устанавливает.
3. Pyright before_init выбирает Python по своему root, только если пользователь
   не передал python.pythonPath. Настройка посылается обычным LSP settings API;
   server/handlers не подменяются. Ruff продолжает собственный native workflow.
4. Положительные UI проверки и source replay используют неизменённый lock67,
   настоящий project venv/package и server. pytest/debug проходят регрессом,
   общий Node/Go/smoke — последовательно. Mac/Ubuntu без запуска не PASS.

## Risks / Trade-offs

- Переезд selector может изменить приоритет → переносим прежний алгоритм,
  DAP default/project E2E подтверждает сохранённый выбор .venv.
- Async Python debug/transient editor окна → waits на actual stopped frame,
  word-boundary locator, готовый picker, stdout и реальный итог теста.
- Разные managers → их расширение остаётся отдельным шагом, native Neotest
  конфиг не заменяется упрощённым resolver.
