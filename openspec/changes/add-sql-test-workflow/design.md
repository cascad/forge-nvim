# Design

## Context

SQL editor/query отделён от Neotest: plugins/tests.lua уже регистрирует
Go/Rust/Python/Jest/Bats, но SQL adapter отсутствует. Публичный Bats adapter
показывает pattern argv/process-report и fallback file/dir → test leaves.
Общие Tests/Test Output/control уже имеют E2E. SQLS не предоставляет references.

## Goals / Non-Goals

**Goals:** реальный переносимый SQL test workflow без новых Neovim plugins,
файловая гранулярность SQLLogicTest, ошибки по native report, изолированные
SQLite test DB и явный воспроизводимый SDK.

**Non-Goals:** PostgreSQL/MySQL test engines, SQLS semantic references,
procedural DAP, разделение зависимых record в независимые tests, изменение
SQLRun/production connections и автоустановка Rust/CC/SDK. IDE-062 остаётся
открытым до отдельной реализации references.

## Decisions

1. `.slt` получает отдельный filetype sqllogictest: test DSL не отправляется
   SQLS/Sqruff как обычный SQL. Neotest leaf — один script; nearest выполняет
   его полностью с setup. Это соответствует file-level результату официального
   CLI, не обещает per-query independence.
2. Небольшой Rust CLI использует sqllogictest =0.29.1 и rusqlite =0.41.1
   с bundled SQLite, Cargo.lock. Версии/checksums проверены по primary crates.io
   metadata 2026-11-09. Official CLI не имеет SQLite engine, External использует
   Bash, поэтому нельзя брать его как универсальный SQLite executable.
3. Parser/expected comparison выполняет официальная библиотека, не Lua regex.
   Script получает private in-memory DB; runner не читает `.sqls.json`.
   Pure SQL/conditions/sleep поддерживаются native; shell `system` явно
   отклоняется, а не эмулируется отдельным shell на Windows.
4. Report version/file/status/error location + human output сохраняются до
   exit; adapter читает JSON вне PTY и даёт Test Output обычный text artifact.
   Нет report/несогласованный exit — failed. Stop использует общий Neotest.
5. Явный preparer с --download разрешает locked native Cargo build (-j2),
   host toolchain не устанавливается. Windows F-only HOME/cache/temp/target;
   проверка готового output не требует Rust/CC/оставленного target. Executable
   задаётся PATH или FORGE_SQLTEST_EXECUTABLE/g:forge_sqltest_executable.
6. IDE-069: nt.run.run(cwd) выбирает первый adapter root, даже пустой. Общий
   consumer использует документированные Client:get_adapters/get_position/
   run_tree, выбирает непустые trees внутри cwd и запускает adapters последовательно.
   Это consumer extension API, без прямого доступа к _state/_runner/_adapters.
7. Отказ missing SDK/DAP возвращает genuine failed preflight через публичную
   custom Strategy, без OS process и без SDK JSON. Возврат nil из leaf build_spec
   создаёт лишний Neotest stacktrace «returned no data»; этот путь не используется.
8. IDE-070: Windows BufAdd directory path с `/` не совпадает с native discovery
   tree с `\`, и positions.merge бесконечно поднимается выше drive root.
   Companion существующего pinned Neotest backport приводит path через
   fs_realpath на входе _update_positions до parse_dir/file. Исправление только
   в adapter оказалось недостаточным; SDK/hash/explicit prepare покрывают
   общую границу. Диагностический watchdog служит только stack evidence;
   постоянные RED/GREEN идут без него.
   Второй companion library parent/real согласует directory lookup/open-buffer
   roots: без него separators давали дубли adapters и чужие tests в tree.
   Третий companion canonical adapter.root в adapter-group устраняет два pytest
   namespace одной папки (IDE-072). Начальная гипотеза async focus не подтвердилась;
   source test проверяет native root IDs 2→1 и настоящие pytest результаты.

## Risks / Trade-offs

- SQLLogicTest script имеет ordered state → file leaf сохраняет семантику;
  granular independent test DSL можно добавить отдельным backend позже.
- SQLite динамические types/NULL/empty/real → проверить настоящими fixtures,
  использовать публичный validator и явный column/value conversion.
- ConPTY искажает stdout → machine report проверяется отдельно от терминала.
- Сборка CC/MSVC/Rust host зависит от среды → подготовка явно диагностирует
  недостающий host SDK; runtime работает одним executable без Bash/Python.
- Source baseline ea63bf5 должен не иметь test discovery; сохраняем этот RED.
- Windows не заменяет Ubuntu/Mac: одинаковые команды, E2E сохраняют real
  platform evidence; Desktop/WSL lifecycle не меняется для прогона.

## Sources

- https://github.com/risinglightdb/sqllogictest-rs (parser/runner/engines)
- https://crates.io/crates/sqllogictest/0.29.1
- https://crates.io/crates/rusqlite/0.41.1
