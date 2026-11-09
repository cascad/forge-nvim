# SQLLogicTest в Tests

`.slt` scripts используют общие Tests и Test Output на Windows/macOS/Ubuntu.
Native runner выполняет SQLite assertions; рабочие `.sqls.json`/DB редактора
не используются. Каждый script получает независимую in-memory DB, а setup и
named connections внутри script разделяют состояние.

## Подготовка

Один раз после обновления выполнить `:Lazy build neotest`, затем перезапустить
редактор. Pin не менялся; companion backport исправляет native path identity
при directory/file discovery. Сборки или записи plugin при открытии нет.
Все операции подготовки выполняются явно.

Подготовить runner предоставленными Rust SDK/C compiler:

```sh
python -B tests/e2e/prepare_sql_test.py --download --rustc <rustc> --output .tools/sql-test
python -B tests/e2e/prepare_sql_test.py --output .tools/sql-test
```

На Ubuntu/macOS — python3. Добавить `.tools/sql-test/bin` в PATH либо задать
полный executable в `FORGE_SQLTEST_EXECUTABLE` или `g:forge_sqltest_executable`.
SDK не выбирается из `.tests` автоматически. [Native SDK/protocol](../scripts/sdk/sql-test/README.md)
описывает версии, зависимости и compiler-free readiness. Обычный runner
не требует Rust/Cargo/Python/Bash. Отсутствующая среда даёт failed preflight
с инструкцией в Output, без установки и без traceback «returned no data».

## Script и запуск

```text
statement ok
CREATE TABLE items (value INTEGER);

statement count 1
INSERT INTO items VALUES (42);

query I
SELECT value FROM items;
----
42
```

Expected rows соответствуют формату sqllogictest-rs: одна строка на row,
значения колонок разделены пробелом. `NULL`, `(empty)` и real с тремя
десятичными знаками описаны в native guide. `.slt` имеет filetype sqllogictest,
не отправляется SQLS/Sqruff как обычный SQL.

| Клавиши | Действие |
|---|---|
| `Space w t` / `Space T p` | Tests |
| `Space T t` | Nearest: полный текущий script |
| `Space T f` | Текущий script |
| `Space T A` | Все обнаруженные tests текущего cwd, по каждому adapter |
| `Space T s` | Остановить свой runner |
| `Space w r` / `Space T O` | Общая Test Output |
| `Space T o` | Output выбранного test |
| `F7` / `Space w 0` | Код |
| `Space w z` | Развернуть/вернуть панель |
| `q` / `?` в normal mode | Скрыть / помощь панели |
| `:cfirst`, `:cnext` | Ошибки script в quickfix |

Nearest выполняет файл целиком: отдельный query без setup может иметь другое
значение. File/all не запускают SQLRun. Run all пропускает пустые adapters и
другие открытые workspace, выполняет adapters последовательно. Внутри adapter
сохраняется его штатная настройка concurrency. При смене cwd область All
меняется вместе с ним.

Неверный expected даёт настоящий failed, сравнение expected/actual и строку
query в Test Output/quickfix. После исправления/save повторить `Space T t`.
Пустой/all-skipped/невалидный script не становится passed. Доставка result
идёт из JSON вне PTY; missing/damaged report остаётся failed даже при exit 0.
Его сообщение не смешивается с raw PTY control sequences, способными стереть
текст ошибки в terminal-based Output. SQLLogicTest DAP не создаёт; обычные
tests запускаются через Tt/Tf/TA.

`include` исполняет официальный parser/runner. Native Output содержит
настоящие file/line вложения. Текущий Neotest Error не имеет filename:
quickfix marker такого parent script указывает его начало; точная location
остаётся в Output. Обычный failed query в root script ведёт на точную строку.
`system` явно отклонён native SQLite backend, shell fallback не используется.
PostgreSQL/MySQL engines и SQL semantic references остаются отдельной работой.

## E2E

После явной подготовки общих plugins/SQL test SDK и Bash SDK для mixed-adapter
сценария:

```sh
<nvim> -l tests/e2e/sql-test-sdk.test.lua
<nvim> -l tests/e2e/sql-tests.test.lua
<nvim> -l tests/e2e/plugin-backports.test.lua
```

Windows использует Forge Neovim SDK и TEMP/TMP/TMPDIR/NVIM_LOG_FILE на диске
checkout. Для другого SDK: FORGE_E2E_SQL_TEST_DEPS; для native Bats —
FORGE_E2E_BASH_DEPS. FORGE_SQL_TEST_CASE фильтрует UI case по подстроке.

12 native process E2E SDK и 12 реальных editor UI Windows PASS. UI проверяет
discovery без исполнения, nearest/file/all и независимость DB, Unicode/space/
quote argv, fail→quickfix→edit/save→rerun, остановку живого PID, missing tools/
DAP, malformed/empty scripts, damaged real report и focus/help/zoom/hide.
Счётчики пишутся настоящим SQL, mixed case запускает настоящий Bats. Native
JSON перед повреждением сохраняется; replies и SQL результаты не подменены.
Source RED: ea63bf5 без feature, прототип с прежним All, точные upstream
Neotest companion files. Диагностический watchdog дал stack evidence,
постоянные RED/GREEN работают без него.

Ubuntu recipe содержит SDK, но build/run и Mac/ARM64/GUI ещё не проверены.
При уже доступном engine можно явно собрать image и запустить:

```sh
docker compose -f tests/containers/compose.yaml build ubuntu
docker compose -f tests/containers/compose.yaml run --rm --entrypoint nvim ubuntu -l tests/e2e/sql-tests.test.lua
```

Это не команда запуска Docker Desktop/WSL. Общий `scripts/test.ps1 full` /
`scripts/test.sh full` включает оба SQL test suites через registry.
