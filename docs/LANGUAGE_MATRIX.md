# Матрица языков nvim_forge

Первичный срез 2026-11-02, runtime commit `657ab41`; обновление 2026-11-03
добавляет реальные Go language E2E Windows (§110). «Настроено» означает запись
в сборке; установленный binary, запуск server и корректность его ответа ещё
требуют E2E. Windows/macOS/Ubuntu используют одну языковую конфигурацию.

| Язык | LSP в обычном старте | Форматирование | Debug / Tests | Доказанное покрытие |
|---|---|---|---|---|
| Go | gopls, если доступен в PATH | golines → gofumpt, LSP fallback | Delve; neotest-golang/gotestsum | DAP/tests/панели Windows/Ubuntu; 6 новых LSP/format UI E2E Windows PASS. Ubuntu language ожидает engine; Mac не проверен |
| Rust | rust_analyzer, если binary доступен | rustfmt, LSP fallback | codelldb + cargo build; neotest-rust | Отсутствующий codelldb проверен; положительный Rust debug/test и семантический LSP ещё не покрыты |
| Python | pyright и ruff, если binaries доступны | ruff_organize_imports → ruff_format | debugpy; neotest-python/pytest | Есть настройка project Python/venv; положительные Python LSP/debug/test E2E ещё не покрыты |
| JS / Node.js | Явной активации JS/TS server нет | Языкового formatter для javascript/typescript нет | Node adapter/default launch и Neotest adapter не настроены | Семантического Node workflow E2E нет |
| Bash | Явной активации shell server нет | Языкового formatter для sh/bash нет | Shell debug/test adapter не настроен | Проверки наших shell scripts не являются Bash IDE E2E |
| SQL | Явной активации SQL server нет | Языкового SQL formatter нет | Выполнение запросов и test adapter не настроены | SQL IDE E2E нет; dialect/connection workflow ещё не определён |

Общий cmp уже подключает LSP, snippets, buffer и path. Buffer completion
не доказывает семантический completion языка. Conform имеет общий trim
whitespace/newlines; это не языковой formatter. Наличие Prettier для JSON/YAML/
Markdown не включает его для JS. Наличие Neotest/Overseer само по себе не
добавляет test/debug adapter для каждого языка. Generic задачи из tasks.json
можно запускать, но это ещё не готовые language run/test команды.

Treesitter list содержит Go/Rust/Python/JS/TS/Bash; SQL в явном списке нет.
Это список для явной подготовки, не доказательство наличия всех parsers на
машине. Подготовка текущих test-deps собирает Go parser и gotestsum;
dap-tools готовит Go/Delve; lsp-deps — фиксированные gopls/gofumpt для language
E2E. Изолированные tests не подтверждают наличие
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
2. JS/Node.js: добавить недостающие LSP/format/run/debug/test в отдельном
   OpenSpec change с минимальным проектом и постоянным UI регрессом.
   Проверить package scripts, локальные зависимости и launch.json.
3. Rust/Python: подтвердить уже имеющийся функционал положительными
   Cargo workspace и venv/pytest сценариями, затем исправлять доказанные сбои.
4. Bash и SQL: добавить минимальные рабочие сценарии с E2E. У SQL отдельно
   определить dialect/профиль выполнения; DAP не является обязательным
   аналогом отладки исполняемой программы. До выбора инструментов сверить
   официальную документацию и системные границы.

Для каждого изменения: spec до кода, исходный RED для бага, постоянный E2E,
последовательные Windows/Ubuntu прогоны, FIXLOG с причиной и отдельный commit.
Mac выполняется отдельно на машине владельца; headless Ubuntu не заменяет
проверку clipboard/физических клавиш/GUI. Большой рефакторинг ядра остаётся
после функциональной матрицы. Остаток controls Terminal/Trouble и IDE-047/048
сохраняются в очереди, не смешиваются с языковым шагом.
