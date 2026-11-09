# Tasks

## 1. Подготовка

- [x] 1.1 Pinned wheel/npm locks, Python tools venv/manifest, offline dependency wheel и Python parser; Windows --download и проверка без скачивания, простые команды.
- [x] 1.2 Private fixture с неактивированным .venv, src/tests/local dependency и Unicode/пробелами; сохранение evidence без копии venv/cache в snapshot.

## 2. Реальный редактор

- [x] 2.1 LSP definition/references/rename/completion/diagnostics, venv dependency и Ruff manual/on-save UI E2E. При runtime FAIL — ID/отдельная delta до исправления.
- [x] 2.2 F5 default/project, actual interpreter, breakpoint/eval/continue/stdout/stderr; pytest nearest/file/output и debug nearest, baseline и исходные FAIL.

## 3. Регресс и история

- [ ] 3.1 Registry и Ubuntu image; с работающим engine явный build и последовательные Python/Node/Go/smoke. Без engine задача остаётся открытой, Mac/GUI не PASS.
- [x] 3.2 Windows Node/Go/smoke, unit/trace/strict; FIXLOG/HISTORY/команды, матрица и roadmap с точными ограничениями; commit и переход к следующему пункту.
