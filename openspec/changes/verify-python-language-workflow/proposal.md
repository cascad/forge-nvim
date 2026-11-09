# Proposal

## Why

После Go/Node матрица языков всё ещё не доказывает положительный Python workflow.
Настройки pyright/ruff/debugpy/neotest-python существуют, но выбор project venv,
семантика, форматирование и реальные pytest/debug процессы не проверены E2E.

## What Changes

- Явная подготовка pinned Python tools/wheelhouse, Pyright npm package и Python
  parser, с проверкой hashes/версий и повтором без сети. Host Python >=3.10
  предоставляется машиной; его version/architecture записываются, SDK не ставится.
- Private проект с неактивированным .venv и настоящей локальной dependency:
  multi-file LSP/rename/completion/diagnostics, Ruff manual/save и interpreter.
- Реальные F5 default/project, breakpoint/eval/stdout/stderr и pytest
  nearest/file/output/debug nearest, через обычные клавиши и панели.
- Registry/Docker explicit preparation, Windows Node/Go регресс, история/команды.

## Capabilities

### New Capabilities

Нет: skip_specs: true, проверяется существующий Python функционал. Runtime
сбои сначала получают стабильный ID, воспроизведение и отдельную delta, затем fix.

### Modified Capabilities

Нет; публичные настройки/поведение редактора в этом change не меняются.

## Impact

tests/e2e и fixtures, registry, containers и документация. Общие config/plugins
остаются исходными, тест не подменяет handlers/server/adapter. Windows caches
и venv на F:, тяжёлые suites последовательны. Ubuntu зависит от уже работающего
engine; Desktop/WSL lifecycle исключён. Mac/GUI отдельно и без ложного PASS.
