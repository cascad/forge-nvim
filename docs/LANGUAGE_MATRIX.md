# Матрица языков nvim_forge

Первичный срез 2026-11-02, runtime commit `657ab41`; обновление 2026-11-03
добавляет Go language (§110), Node (§111) и Python (§112–113) E2E Windows.
Обновление 2026-11-09 добавляет Rust (§114–115) и Bash (§116–117). «Настроено» означает запись
в сборке; установленный binary, запуск server и корректность его ответа ещё
требуют E2E. Windows/macOS/Ubuntu используют одну языковую конфигурацию.

| Язык | LSP в обычном старте | Форматирование | Debug / Tests | Доказанное покрытие |
|---|---|---|---|---|
| Go | gopls, если доступен в PATH | golines → gofumpt, LSP fallback | Delve; neotest-golang/gotestsum | DAP/tests/панели Windows/Ubuntu; 6 новых LSP/format UI E2E Windows PASS. Ubuntu language ожидает engine; Mac не проверен |
| Rust | rust_analyzer, если binary доступен | rustfmt, LSP fallback | codelldb + Cargo preLaunch build; neotest-rust/nextest | 8 real UI E2E Windows PASS: cross-crate LSP, format/save, default/alternate/project debug, nearest/file/integration/debug tests и output. Ubuntu/Mac и stdlib navigation не проверены |
| Python | pyright/ruff; общий project Python selector для Pyright/DAP | ruff_organize_imports → ruff_format | debugpy default/launch.json; neotest-python/pytest | 8 real UI E2E Windows PASS: venv dependency, LSP, explicit path, format/save, default/project debug, pytest/debug, unexpected adapter exit. Ubuntu/Mac не проверены |
| JS / Node.js | ts_ls через Node/TSLS, только при доступных tools; auto typings download отключён | Project-local Prettier, LSP fallback | NodeRun/File → Tasks; js-debug default/launch.json; Neotest Jest | 8 real UI E2E Windows PASS: язык/format/run/debug/nearest/file/debug test/missing tools. Ubuntu/Mac не проверены |
| Bash | bashls через native Node/JS, guarded tools | shfmt, .editorconfig, async save | BashRunFile → Tasks; Bats public adapter; DAP открыт IDE-057 | 8 real UI E2E Windows PASS: sourced LSP/rename/completion/diagnostics, format, args/cwd/output/status, nearest/file/оба Bats syntax/regex Unicode, missing tools. Ubuntu/Mac/Bash 3.2/GUI не проверены |
| SQL | sqls, guarded tool/config/DB; schema/alias actions | Sqruff CLI diagnostics/format, project dialect/style, async explicit save | SQLRun/Connect/Results/Stop; tests/references открыты IDE-062 | Windows 16 real UI PASS: язык, Unicode rename, parse diagnostics, manual/save/autosave, настоящие SQLite queries/selection/profiles/lock/stop/panels/missing environment. IDE-066 leading-comment SELECT ещё открыт; Ubuntu/Mac/ARM64/внешние DB не проверены |

Общий cmp уже подключает LSP, snippets, buffer и path. Buffer completion
не доказывает семантический completion языка. Conform имеет общий trim
whitespace/newlines; это не языковой formatter. Наличие Prettier для JSON/YAML/
Markdown само по себе не включает его для JS: теперь есть отдельная JS запись.
Наличие Neotest/Overseer само по себе не
добавляет test/debug adapter для каждого языка. Generic задачи из tasks.json
можно запускать, но это ещё не готовые language run/test команды.

Treesitter list содержит Go/Rust/Python/JS/TS/Bash/SQL.
Это список для явной подготовки, не доказательство наличия всех parsers на
машине. Подготовка текущих test-deps собирает Go parser и gotestsum;
dap-tools готовит Go/Delve; lsp-deps — фиксированные gopls/gofumpt для language
E2E; node-deps — Node/TSLS/TypeScript/Prettier/Jest/js-debug и JS parser;
python-deps — pinned wheelhouse/tools venv, Pyright и Python parser, host SDK
предоставляет машина. Python E2E проверен с CPython 3.14.0 Windows.
Изолированные tests не подтверждают наличие
остальных инструментов в пользовательском профиле.

Источники: [LSP](../nvim_forge/lua/plugins/lsp.lua),
[completion](../nvim_forge/lua/plugins/completion.lua),
[format](../nvim_forge/lua/plugins/format.lua),
[debug/default launch](../nvim_forge/lua/plugins/dap.lua),
[tests](../nvim_forge/lua/plugins/tests.lua),
[tasks](../nvim_forge/lua/plugins/tasks.lua),
[Treesitter](../nvim_forge/lua/plugins/treesitter.lua),
[реестр проверок](../tests/registry.lua),
[подготовка Go DAP](../tests/e2e/prepare_dap.py),
[подготовка Go tests](../tests/e2e/prepare_tests.py).

## Следующие законченные шаги

1. Завершить Go language прогон Ubuntu после явного build с работающим engine.
   Windows: 6 UI PASS — настоящий gopls, completion, definition/references,
   rename, diagnostics, внешний/LSP format, save/health и отсутствие tools.
   Исправлен IDE-050: trim блокировал fallback. Module path содержит пробелы/
   Unicode; Go.work с несколькими модулями и Mac остаются отдельными сценариями.
   Явная подготовка фиксирует versions/sources, обычный старт ничего не ставит.
2. JS/Node.js: Windows минимальный workflow реализован и проверен 8 UI E2E.
   [Команды и явная подготовка](NODE_WORKFLOW.md), change add-node-language-workflow.
   Native argv/literal test paths и canonical Neotest nearest исправляют
   Windows пути без отдельного runtime под ОС. Ubuntu ожидает engine;
   Mac/браузер/TS transpilation/source maps/другие test frameworks не проверены.
3. Python Windows проверен: [venv/LSP/debug/pytest](PYTHON_WORKFLOW.md), 8 UI PASS.
   IDE-052 согласует Pyright и DAP interpreter; IDE-053 убирает ложный WARN
   после client-initiated adapter close, неожиданный exit 23/stderr остаётся видим.
   Ubuntu/Mac и managers Poetry/Pipenv/Conda остаются отдельной проверкой.
   Rust Windows также проверен: [Cargo workspace workflow](RUST_WORKFLOW.md),
   8 UI PASS. IDE-054 исправляет native path/argv/JSON adapter, IDE-055 сохраняет
   настоящий debug test output. Прежний регресс 37 UI + 9 backports и 364 checks PASS.
   Ubuntu/Mac/GUI/stdlib navigation/cross-compile остаются отдельной проверкой.
4. Bash Windows edit/run/tests проверен: [команды и границы](BASH_WORKFLOW.md).
   DAP отдельно IDE-057; Ubuntu/Mac ждут реального прогона.
5. SQL Windows edit/query: [команды и подготовка](SQL_WORKFLOW.md), 16 real UI
   PASS. SQLS schema, Sqruff CLI, exact snapshots, профили двух workspace,
   Results/common controls, lock/stop/reconnect и missing environment проверены.
   IDE-066: native SQLS теряет rows у SELECT после комментария — нужен отдельный
   backend fix с RED/GREEN. IDE-062: SQL tests/references остаются обязательными.
   Ubuntu/Mac/ARM64/внешние DB и procedural debugger не объявляются PASS.

Для каждого изменения: spec до кода, исходный RED для бага, постоянный E2E,
последовательные Windows/Ubuntu прогоны, FIXLOG с причиной и отдельный commit.
Mac выполняется отдельно на машине владельца; headless Ubuntu не заменяет
проверку clipboard/физических клавиш/GUI. Большой рефакторинг ядра остаётся
после функциональной матрицы. Остаток controls Terminal/Trouble и IDE-047/048
сохраняются в очереди, не смешиваются с языковым шагом.
