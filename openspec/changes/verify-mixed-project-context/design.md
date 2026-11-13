# Design

## Context

См. proposal. Все SDK уже подготовлены. Editor сохраняет выбранный Git cwd;
готовые LSP выбирают языковые roots. Node script root и Python interpreter
должны быть вложенными проектами, даже если рабочая папка IDE общая.

## Goals / Non-Goals

Goals:6 filetypes/готовые attached LSP, стабильный cwd, Node script и Python
venv/default debug, возврат Go. Non-Goals: полная mixed Tests/rename/format/DAP
матрица, backend/parser/resolver rewrite, новая общая infra, Mac/physical.

## Decisions

- Один private repo с go.work, Cargo.toml, pyproject, web/package-lock,
  scripts и SQLite profile. Language roots ожидаются по штатной семантике.
- Готовые project-local npm dependencies — native directory link/junction,
  project snapshot пропускает node_modules. Нет download/copy всего npm tree.
- Parsers объединяются из prepared site/parser в private profile до startup.
- Offline Python .venv под nested project создаётся до запуска редактора;
  tools debugpy отдельно явно подготовлены. Пакетные установки только wheels.
- Native script picker cancel/select и F9/F5/default picker/continue;
  наблюдение реальных task output/cwd и DAP session/interpreter/output.
- Go/Rust commands ограничены двумя workers, backend tasks последовательны.

## Risks / Trade-offs

- Несколько LSP одновременно → маленькие fixtures, bounded worker env,
  не запускать параллельно Windows/Ubuntu и не повторять unchanged FAIL.
- Native POSIX cleanup может fail независимо от workflow → сохранить отдельно.
- Local directory links OS-specific → только граница fixture preparation,
  общая продуктовая логика не ветвится по ОС.

## Source defect IDE-120

Profile23787689169800: первые4 LSP attach/cwd успешны, bash.lua:38 assert
«Bash Language Server не найден». node.root(file) fallback scripts → parent
находит repo/node_modules, затем node.root(config.root_dir) fallback parent(repo)
пропускает тот же каталог. Native fs_stat различает directory/file input;
при отсутствии package marker directory сохраняется. Нет нового resolver,
OS branch, parser/cache; все прежние Node/Bash workflows проверяются вместе.
Source отказ сохранён, cleanup0/signal0/APIerrors[]/owned scope drained0.

## Cold Python IDE-122

Два Windows target failures23950668148100/24472874457100 после6 LSP roots и
успешного Node script. Native DAP timer4s следит за initialize+launch response
(adapter_responded ставится после config.request); debugpy initialized отправлен
на adapter D+4.136, Nvim уже ждёт Press ENTER после warning. Standalone stdio
initialize PASS; Ubuntu17 selected PASS. Не утверждаем дефект pipes или SDK.
Public adapter.options.initialize_timeout_sec=30 даёт cold imports/launch
ограниченный бюджет; это общий Python policy, не Windows branch, private patch
или ослабление deadline теста. Existing Python unexpected exit остаётся контролем.
