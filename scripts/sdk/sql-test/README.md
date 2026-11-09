# Native SQLLogicTest/SQLite runner

Спека: IDE-SQL-8. SDK — отдельный этап IDE-062; подключение к Neotest
и editor UI E2E выполняются следующей задачей. Текущий editor этот runner
автоматически не вызывает.

`forge-sqltest` использует официальный [sqllogictest-rs](https://github.com/risinglightdb/sqllogictest-rs)
0.29.1 и rusqlite 0.41.1 с bundled SQLite. Cargo.lock фиксирует registry
dependencies/checksums. SQL parser и сравнение ожидаемых данных принадлежат
библиотеке; backend переводит native SQLite values в SLT rows. Column count
проверяется, SQLite types динамические; NULL → `NULL`, empty text → `(empty)`,
real → три десятичных знака. Expected rows пишутся по одной строке на row,
значения колонок разделены пробелом, как в sqllogictest-rs.

## Явная подготовка

Нужны предоставленные Rust SDK (проверено 1.96.1) и C compiler для bundled
SQLite (Windows — установленный MSVC toolchain, Ubuntu/macOS — native CC).
Host SDK, Cargo или compiler не устанавливаются автоматически.

```sh
python -B tests/e2e/prepare_sql_test.py --download --rustc <rustc>
python -B tests/e2e/prepare_sql_test.py
<nvim> -l tests/e2e/sql-test-sdk.test.lua
```

Ubuntu/macOS: python3. `--output` задаёт другой SDK каталог, default
`.tests/sql-test-deps`; `--cc` задаёт compiler. На Windows все cache/target/
private HOME/temp остаются на диске checkout. Сборка `--locked --release -j2`,
исходники и lock проверяются после build. Manifest содержит normalized LF
source SHA, platform, binary SHA/version и сведения предоставленного Rust SDK.

Готовый `bin/forge-sqltest[.exe]` выполняет SQLite tests без Rust, Cargo,
Python и Bash. Проверка SDK без `--download` проверяет immutable manifest,
source/binary/version и настоящий SQLite assertion во временном профиле.
Ей не нужны compiler, `target`, `cargo-home` или сохранённый build scratch.
Temporary profile удаляется после успеха и отказа. Открытие Neovim ничего
из этих команд не запускает. Команды подготовки требуют Python только
на этапе подготовки/проверки SDK.

## Пример и protocol

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

```sh
forge-sqltest --report result.json -- "tests/example ü.slt"
forge-sqltest --version
```

Один process исполняет один полный script, сохраняя setup и named connections
в общей private in-memory DB. Другой process получает новую DB. `.sqls.json`
и рабочие DB не используются. `include`, условия SQLite и `sleep` обрабатывает
библиотека; `system` явно отклоняется этим native backend. Это не PostgreSQL/
MySQL runner и не Bash fallback.

JSON protocol 1: `file` — основной script, `status` passed/failed, `checks` —
число реально исполненных query/statement assertions, `errors` — file/line
(1-based)/message, `output` — обычный текст без ANSI. При `include` основной
file сохраняется, error file указывает настоящее вложение. Report пишется
до exit вне терминального PTY. Code 0 означает выполненные успешные assertions,
1 — test/parser/empty/all-skipped failure, 2 — неверный CLI/report destination.
Пропавший/повреждённый report нельзя считать passed по одному stdout.

## Проверки и границы

Windows: 12 native process E2E PASS — real setup/query/counters, Unicode/space
paths, NULL/empty/real, expected SQL error, wrong expected/точная line, parser,
empty/all-skipped, независимость scripts/named connections, include identity/
location, unsupported system, compiler-free readiness и missing/corrupt SDK.
Suite сохраняет exact SDK source/lock/preparer/test/manifest, native PID,
stdout/stderr/exit и JSON reports в `.tests/sql-test-sdk/`.

Ubuntu/macOS/ARM64 ещё не запускались. SQLite CLI PASS не означает готовность
Neotest UI или semantic references; они остаются в IDE-062/OpenSpec tasks.
