# Что ещё требуется для полной поставки fride

Исходный срез2026-11-15, код694cd9e, обновление §251. Это состав **существующих возможностей**, а не
предложение новых LSP. Полного Default release пока нет: production
[artifacts.tsv](../scripts/runtime/artifacts.tsv) не содержит ни одной строки.
Готовность транспорта и отдельных стендов не равна готовности такой поставки.

## Что уже определено

- Свой Neovim0.12.2: Windows — существующий patched SDK/receipt из
  [windows.json](../scripts/sdk/windows.json), POSIX — официальный native binary.
- 67 plugin pins в [lazy-lock](../nvim_forge/lazy-lock.json), 6 backports в
  [plugins.json](../nvim_forge/patches/plugins.json). Состав не изменялся.
- Plugins, Mason packages и состояние принадлежат штатному NVIM_APPNAME=fride;
  setup выполняет restore/backports → parsers → tools/readiness. Наличие файла
  проверяется отдельно от фактической работы редактора/языка.
- Go/Rust/Cargo/Node/npm/Python остаются **обычными SDK пользователя**. Их
  settings/auth/cache/venv не включаются в архив IDE. Missing SDK/manager требует
  выбора пользователя; bootstrap менеджера реализован §249.

## Компоненты и текущая автоматическая подготовка

Источник: [components.tsv](../nvim_forge/scripts/components.tsv),
[tool_catalog](../nvim_forge/lua/forge/tool_catalog.lua),
[sdks.rs](../installer-ui/src/sdks.rs). В каждой строке, кроме Core, указаны
добавочные Mason packages; Core включается всегда.

| Компонент | Обычные SDK | Mason в текущем managed setup | Пробел поставки |
|---|---|---|---|
| Core | Сам по себе не требует SDK языка | lua-language-server, stylua; 23 общих parsers | Git для plugins/backports, rg для текстового поиска, tree-sitter/подготовка native parsers. Prettier для JSON/YAML/Markdown принадлежит Node компоненту. |
| Go | Go | delve, golangci-lint, gotestsum, gopls, gofumpt, golines; ещё4 parsers | При необходимости сборки новых tools требуется обычный Go1.26.0+; готовые packages переиспользуются со старым SDK. |
| Rust | Rust/Cargo | rust-analyzer; ещё1 parser; codelldb только POSIX | Windows codelldb исключён из Mason и ожидается извне. Rustfmt — часть обычного Rust toolchain, не private IDE SDK. |
| Python | Python + Node для pyright | pyright, ruff, debugpy; ещё1 parser | Версии SDK/venv и настоящий debug/test acceptance; наличие receipt этого не доказывает. |
| JS/Node | Node/npm | typescript-language-server, js-debug-adapter, prettier; ещё2 parsers | Prettier3.9.10 включён §251, в том числе для JSON/YAML/Markdown. Project node_modules сохраняет приоритет. |
| Bash | Node; Bash runtime/backend | bash-language-server, shfmt, shellcheck, bash-debug-adapter; ещё1 parser | Подготовка закреплённого adapter patch не включена в общий setup; на Windows нужен выбранный владельцем WSL2 backend. WSL установщик не трогает. |
| SQL | Go требуется текущему sqls install recipe | sqls, sqruff; ещё1 parser | Нужны существующие patched sqls и forge-sqltest, а не один stock sqls receipt. Базы/credentials — пользовательские. |
| Terminal | — | Mason/parsers нет | Нужен native WezTerm/font artifact и проверенная private интеграция с явным config, без замены пользовательского WezTerm. |

Исходный Windows read-only snapshot: .tests/release-inventory-windows.json,
получен самим tool_catalog в Neovim `-u NONE`, без SDK queries/сети/setup.
При полном выборе это33 различных parsers; Windows Rust строка не включает
codelldb по текущему OS guard. POSIX guard проверен чтением кода, native Mac
этим снимком не проверяется.

## Почему имеющийся setup ещё недостаточен

1. [setup-stage.lua](../nvim_forge/scripts/setup-stage.lua) подготавливает только
   выбранные plugins/parsers/Mason packages. Успешная проверка этого списка
   не обнаруживает инструмент, который вообще в него не включён.
2. §251 закрыл gopls/stylua/gofumpt/golines/prettier через тот же Mason;
   [lsp.lua](../nvim_forge/lua/plugins/lsp.lua) и
   [format.lua](../nvim_forge/lua/plugins/format.lua) используют готовые bin/JS.
   Это IDE tools, а не языковые SDK. Их версии и postconditions теперь общие.
3. [dap.lua](../nvim_forge/lua/plugins/dap.lua) ищет Windows codelldb через PATH,
   пользовательский LocalAppData и Mason fallback. Существующая подготовка
   debugger SDK проверялась отдельно, в published private kit её ещё нет.
4. [bash_debug.lua](../nvim_forge/lua/forge/bash_debug.lua) требует подготовленный
   patch; [sqls.json](../scripts/sdk/sqls.json) описывает уже существующий SQL
   patch, [sql_tests.lua](../nvim_forge/lua/forge/sql_tests.lua) требует отдельный
   forge-sqltest executable. Общий managed setup эти шаги не выполняет.
5. [treesitter.lua](../nvim_forge/lua/plugins/treesitter.lua) вызывает native
   install API; необходима рабочая подготовка CLI/compiler либо готовых parser
   libraries для платформы. Docker image содержит инструменты сборки и потому
   сам по себе не доказывает установку на чистой пользовательской ОС.

## Следующая очередь реализации

1. **Готово §251 — пять существующих IDE tools:** pinned Mason packages в
   штатном fride data, без установки в пользовательские global prefixes и без
   SDK homes внутри kit. Core-only не требует Node; галочка Node включает
   shared JSON/YAML/Markdown formatting. Сборка Go tools проверяет Go1.26.0+,
   готовые packages этого SDK для повторной сборки не требуют. Реальные
   format/LSP/repeat/failure cases прошли Windows/Ubuntu; native Mac открыт.
2. **Доставить уже принятые debug/test components:** Windows codelldb, штатная
   подготовка существующих Bash/SQL patches, forge-sqltest. Не добавлять LSP
   и новые adapter implementations; использовать имеющиеся provider boundaries.
3. **Собрать Core/Terminal artifacts:** Git/search/parser dependencies и
   WezTerm/font, platform manifests, source/version/SHA/license inventory.
   fd и native fzf — ускорители с существующим fallback, не скрытые обязательные SDK.
4. **Настоящий Default/Custom из архива:** отдельный чистый профиль, реальные
   config/plugins/tools, launch → open/search → LSP → debug/tests → format,
   затем repeat/cancel/upgrade. Одна целевая тестовая итерация на изменение.
5. **Native Mac и публикация:** владелец прогоняет ту же native команду на Mac;
   только проверенные artifacts попадают в production catalog. Затем публичные
   one-liners, без ручного поиска/скачивания binaries пользователем.

Пункт1 реализован в указанной границе; пункты2–5 ещё не реализованы.
Они пока не заблокированы целиком Mac-проверкой: общая подготовка и Windows/
Ubuntu выполняются до неё. Публикация и непроверенные платформы отдельно открыты.

Версии/команды/границы §251 — [managed IDE tools](INSTALLATION_PLAN.md#подготовка-существующих-ide-tools--251).
Native SDK TUI пока не возвращает пользователя к выбору SDK по build minimum;
backend выдаёт раннюю ошибку. Эту совместимость и все prerequisites надо закрыть
до full Default acceptance, включая случай версии Go из штатного APT.
