# Design

## Context

Мотивация — proposal.md. Baseline be5b6bc содержит общие LSP/Conform/panels,
но SQL workflow отсутствует. Native sqls 0.2.48 на Windows реально прочитал
SQLite schema, вернул completion/definition/hover и query table. Sqruff 0.44.0
вернул настоящие diagnostics/format edits. Probes — .tests/sql-rpc-*.json.

## Goals / Non-Goals

**Goals:** единый keyboard workflow всех ОС, явная подготовка, real UI E2E;
SQLite — локальный тестовый backend без внешнего сервера. Нативные другие
SQLS drivers доступны через их configuration, без ложного DB PASS.

**Non-Goals:** SQL Neotest framework/semantic references остаются IDE-062;
procedural debugger и GUI доставки клавиш отдельно. Не строим свою SQL parser/
query engine, не меняем plugin pins, SDK на старте и пользовательские shell.

## Decisions

0. IDE-063 найден реальным SQL UI: opts.callbacks auto-save.nvim больше не
   вызываются. Публичные User AutoSaveWritePre/Post с data.saved_buffer
   помечают только сохраняемый buffer на синхронный интервал write, без
   глобального флага/таймера. Conform пропускает этот buffer; явное save
   по-прежнему форматирует. Регресс ждёт фактическую запись и завершение
   фоновых действий, затем проверяет ручное save тем же native Sqruff.
   IDE-064: Sqruff 0.44.0 LSP игнорирует parsing_errors и dialect CLI overrides
   (cli-lib Commands::Lsp передаёт только config options; Linter collect=false).
   Используем один async Sqruff lint --parsing-errors --format json по stdin
   вместо его LSP: debounce 500ms, отмена прежнего процесса, защита changedtick,
   публичный vim.diagnostic. Conform fix остаётся native. Нет второго сервера
   или двойного lint; UI проверяет настоящую parse-ошибку и её исправление.

1. Sqls 0.2.48 + sqruff 0.44.0: первый обслуживает schema/semantic actions и
   запросы, второй diagnostics/format. Npm sql-language-server 1.7.1 на Node
   24.11.0 падает ERR_PACKAGE_PATH_NOT_EXPORTED; main README описывает ещё
   не выпущенную SQLite реализацию. 704-package probe сохранён и не становится
   runtime зависимостью. Sqls/sqruff — native argv; конфиг по ОС не копируется.
2. .sqls.json содержит native SQLS connection objects (JSON подходит YAML
   parser сервера), первый connection — default; явный путь можно override.
   Frontend читает aliases/drivers для picker. Каждый SQL workspace имеет
   выбранное подключение. При переключении его SQLS client пересоздаётся с
   initializationOptions.connectionConfig; остальные workspaces и sqruff не
   останавливаются. Это позволяет выбирать доступную БД даже при недоступном
   default и не переписывать файл с credentials. Native TLS/SSH/driver fields
   передаются backend. SQLite path проверяется до подключения; memory явный.
3. Public root callback разрешает только готовые sqls + config/DB. Без БД
   работает sqruff. Metadata sqls -version запрашивается асинхронно при SQL
   attach, кешируется по executable/stat; opening не вызывает Go/установку.
   Известный 0.2.48 использует codepoints: client.offset_encoding=utf-32.
   Только его rename request получает character+1; ответ уже имеет правильные
   zero-based codepoint ranges. Остальные версии сохраняют native protocol.
4. SQLRun делает public didOpen временного in-memory document с неизменяемым
   снимком buffer/visual text, затем executeQuery и didClose. Поэтому typing
   после запуска не меняет query, не нужен собственный statement splitter,
   semicolon literals и Unicode не ломают selection. Один активный query на
   workspace. SQLStop останавливает только его backend session и защищает
   output от позднего callback; следующий запуск поднимает выбранный backend.
   IDE-065: intentional stop отмечается по client ID и потребляется on_exit,
   затем общий crash handler обслуживает только неожиданный exit. Нет global
   mute/таймера для всех серверов; stopping client не переиспользуется при reconnect.
5. SQL Results — ide.sql scratch backend в общем bottom registry/controls,
   без custom floating lifecycle. Header фиксирует profile/source/status;
   hide/show не запускает запрос. Space j q — buffer/visual, j c — connection,
   j o — results/focus, j x — stop; SQLRun/SQLConnect/SQLResults/SQLStop команды.
   Common F7/Space w q/z/? остаются едиными. Native result table сохраняется.
6. Sqruff читает .sqruff (dialect/style); при отсутствии dialect config базовый
   ANSI, явный пользовательский override допустим. Conform использует CLI,
   async save и общий fallback. Semantic rename не изменяет live DB schema.
7. Pinned preparation: official sqls amd64 assets; ARM64 native source build
   того же tag с предоставленными Go >=1.25/C compiler, GOTOOLCHAIN=local.
   Sqruff official assets/SHA пяти targets, SQL parser из pinned catalog.
   Все caches/temp/build Windows на F:, immutable manifest/readiness без download.

## Risks / Trade-offs

- Старый SQLS protocol → версия ограничивает adapter; ASCII first-character
  и emoji-before-alias UI tests плюс source RED проверяют edits целиком.
- DB state/async → настоящие file-backed SQLite, две БД, marker updates,
  snapshots и lock/stop E2E. В picker не используются DSN/password labels.
- SQL session stop → закрывается backend этого workspace, completion
  возвращается на следующем явном подключении/запуске. DB-side cancel других
  engines без настоящего сервера не объявляется проверенным.
- IDE-066: official SQLS QueryExecType берёт первый word (`--` вместо SELECT)
  и выбирает Exec. Нужен отдельный native backend fix; вариант — pinned source
  patch с явной сборкой, альтернативный — drivers' CLI. Владелец получил выбор.
  Проверяется первый вариант как отдельный SDK candidate: Go CGO probe на
  Windows с pinned Zig 0.15.2 прошёл, системный LLVM/MSVC несовместим с -mthreads.
  SQLS уже разобрал statements: patch выбирает classification prefix после
  его AST comment/whitespace nodes, БД получает прежний query string. Нет
  Lua SQL rewriting/нового splitter. Pinned source/patch/before-after SHA,
  native argv build с предоставленным Go >=1.25, GOTOOLCHAIN=local, -p=2.
  Upstream variant остаётся для исходного RED; SDK/compiler не ставятся при
  старте редактора. Пока задача 3.4 открыта, начальные 16 UI не её доказательство.
- IDE-067: прежняя readiness зависела от out/tmp и использовала build profile
  в установленном SDK. Она получает отдельный TemporaryDirectory на F: для
  Windows, native temp для POSIX. Постоянный CLI E2E использует SDK с Unicode/
  space path без tmp и отсутствующие Go/CC, проверяет native Ready/immutability
  и запрет variant switch; исходный prepare_sql.py из 79230c3 должен дать RED.
- ARM64 sqls build требует SDK/CC только в явной подготовке. На этой машине
  не выдаём source build Mac за PASS. Ubuntu Docker engine не запускается.
- Первую CLI пробу LSP записал в старый C: log, восстановлен ровно прежний
  10307-byte prefix (SHA в c-log-restoration.json); дальнейшие probes полностью
  изолированы на F:. Историю/команды этой ошибки записать вместе с результатом.

## Migration Plan

Подготовить tools явно, создать свой .sqls.json (ignored Git), указать dialect
в .sqruff и открыть SQL. Никаких миграций схемы или profile rewrite на startup.
Откат — отключить SQL registrations; пользовательские БД/config не меняются.
