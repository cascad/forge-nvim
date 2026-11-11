# Матрица языков nvim_forge

Первичный срез 2026-11-02, runtime commit `657ab41`; обновление 2026-11-03
добавляет Go language (§110), Node (§111) и Python (§112–113) E2E Windows.
Обновление 2026-11-09 добавляет Rust (§114–115) и Bash (§116–117). «Настроено» означает запись
в сборке; установленный binary, запуск server и корректность его ответа ещё
требуют E2E. Windows/macOS/Ubuntu используют одну языковую конфигурацию.

| Язык | LSP в обычном старте | Форматирование | Debug / Tests | Доказанное покрытие |
|---|---|---|---|---|
| Go | gopls, если доступен в PATH | golines → gofumpt, LSP fallback | Delve; neotest-golang/gotestsum | DAP/tests/панели Windows/Ubuntu; 6 LSP/format UI E2E Windows/Ubuntu PASS; Mac не проверен |
| Rust | rust_analyzer, если binary доступен | rustfmt, LSP fallback | codelldb + Cargo preLaunch build; neotest-rust/nextest | 8 real UI E2E Windows/Ubuntu PASS: cross-crate LSP, format/save, default/alternate/project debug, nearest/file/integration/debug tests и output. Mac и stdlib navigation не проверены |
| Python | pyright/ruff; общий project Python selector для Pyright/DAP | ruff_organize_imports → ruff_format | debugpy default/launch.json; neotest-python/pytest | 8 real UI E2E Windows/Ubuntu PASS: venv dependency, LSP, explicit path, format/save, default/project debug, pytest/debug, unexpected adapter exit. Mac не проверен |
| JS / Node.js | ts_ls через Node/TSLS, только при доступных tools; auto typings download отключён | Project-local Prettier, LSP fallback | NodeRun/File → Tasks; js-debug default/launch.json; Neotest Jest | 8 real UI E2E Windows/Ubuntu PASS: язык/format/run/debug/nearest/file/debug test/missing tools. Mac не проверен |
| Bash | bashls через native Node/JS, guarded tools | shfmt, .editorconfig, async save | BashRunFile → Tasks; Bats public adapter; DAP открыт IDE-057 | 8 real UI E2E Windows/Ubuntu PASS: sourced LSP/rename/completion/diagnostics, format, args/cwd/output/status, nearest/file/оба Bats syntax/regex Unicode, missing tools. Mac/Bash 3.2/GUI не проверены |
| SQL | sqls, guarded tool/config/DB; schema/alias actions | Sqruff CLI diagnostics/format, project dialect/style, async explicit save | SQLRun/Connect/Results/Stop; SQLLogicTest/SQLite в Neotest; semantic references открыты IDE-062 | Windows/Ubuntu 20 query UI + 12 test UI, 2 SQL SDK CLI + 12 test SDK process checks PASS. Native SQLS comments/readiness/cache fixes (IDE-066–068), multi-adapter All и path identity (IDE-069/070). Mac/ARM64/внешние DB не проверены |

Go metadata/Delve (IDE-082): label читает режим/последнюю явно полученную
версию; GoVersion/GoToolchain действуют явно, Delve выбирается при запуске.
Готовый gopls и SDK для реальной работы сохраняют обычное окружение.
[Команды и границы](GO_TOOLS.md), regression — go-passive.test.lua.

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

1. Go language Windows/Ubuntu проверен после явного build образа.
   Windows/Ubuntu: по 6 UI PASS — настоящий gopls, completion, definition/references,
   rename, diagnostics, внешний/LSP format, save/health и отсутствие tools.
   Исправлен IDE-050: trim блокировал fallback. Module path содержит пробелы/
   Unicode; Go.work с несколькими модулями и Mac остаются отдельными сценариями.
   Явная подготовка фиксирует versions/sources, обычный старт ничего не ставит.
2. JS/Node.js: Windows/Ubuntu минимальный workflow реализован и проверен 8 UI E2E.
   [Команды и явная подготовка](NODE_WORKFLOW.md), change add-node-language-workflow.
   Native argv/literal test paths и canonical Neotest nearest исправляют
   Windows пути без отдельного runtime под ОС;
   Mac/браузер/TS transpilation/source maps/другие test frameworks не проверены.
3. Python Windows/Ubuntu проверен: [venv/LSP/debug/pytest](PYTHON_WORKFLOW.md), 8 UI PASS.
   IDE-052 согласует Pyright и DAP interpreter; IDE-053 убирает ложный WARN
   после client-initiated adapter close, неожиданный exit 23/stderr остаётся видим.
   Mac и managers Poetry/Pipenv/Conda остаются отдельной проверкой.
   Rust Windows/Ubuntu также проверен: [Cargo workspace workflow](RUST_WORKFLOW.md),
   8 UI PASS. IDE-054 исправляет native path/argv/JSON adapter, IDE-055 сохраняет
   настоящий debug test output. Прежний регресс 37 UI + 9 backports и 364 checks PASS.
   Mac/GUI/stdlib navigation/cross-compile остаются отдельной проверкой.
4. Bash Windows/Ubuntu edit/run/tests проверен: [команды и границы](BASH_WORKFLOW.md).
   DAP отдельно IDE-057; Mac ждёт реального прогона.
5. SQL Windows/Ubuntu edit/query: [команды и подготовка](SQL_WORKFLOW.md), 20 real UI
   PASS. SQLS schema, Sqruff CLI, exact snapshots, профили двух workspace,
   Results/common controls, lock/stop/reconnect и missing environment проверены.
   IDE-066 исправлен малым pinned native SQLS source patch, исходный backend
   сохраняет RED. 2 SDK CLI E2E проверяют readiness/variant guard (IDE-067).
   IDE-068: три UI проверяют видимый cache/пустой root/late reply без rerun.
   [SQLLogicTest в Tests](SQL_TESTS.md): 12 native SDK checks + 12 editor UI
   PASS, общий Run all и native discovery paths. IDE-062 semantic references
   остаются обязательными; SDK и editor evidence разделены.
   Mac/ARM64/внешние DB и procedural debugger не объявляются PASS.

2026-11-09: native Ubuntu общий набор 119 PASS/1 Windows-only SKIP, 365 unit/trace;
IDE-077 process groups и IDE-078/079 observers — §137–139. Это attached UI/RPC,
не GUI/WezTerm доказательство. Product Lua и 67 pins не менялись.

Для каждого изменения: spec до кода, исходный RED для бага, постоянный E2E,
последовательные Windows/Ubuntu прогоны, FIXLOG с причиной и отдельный commit.
Mac выполняется отдельно на машине владельца; headless Ubuntu не заменяет
проверку clipboard/физических клавиш/GUI. Большой рефакторинг ядра остаётся
после функциональной матрицы. Controls Terminal/Trouble проверены Windows/Ubuntu
(§172); Mac/GUI и IDE-047/048
сохраняются в очереди, не смешиваются с языковым шагом.
