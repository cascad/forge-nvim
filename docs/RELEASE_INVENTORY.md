# Что ещё требуется для полной поставки fride

Срез2026-11-15, код694cd9e. Это состав **существующих возможностей**, а не
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
| Core | Сам по себе не требует SDK языка | lua-language-server; 23 общих parsers | Git для plugins/backports, rg для текстового поиска, tree-sitter/подготовка native parsers; stylua для Lua. Prettier для JSON/YAML/Markdown требует отдельно учесть Node. |
| Go | Go | delve, golangci-lint, gotestsum; ещё4 parsers | gopls, gofumpt, golines ожидаются в PATH, общий setup их не ставит. |
| Rust | Rust/Cargo | rust-analyzer; ещё1 parser; codelldb только POSIX | Windows codelldb исключён из Mason и ожидается извне. Rustfmt — часть обычного Rust toolchain, не private IDE SDK. |
| Python | Python + Node для pyright | pyright, ruff, debugpy; ещё1 parser | Версии SDK/venv и настоящий debug/test acceptance; наличие receipt этого не доказывает. |
| JS/Node | Node/npm | typescript-language-server, js-debug-adapter; ещё2 parsers | Prettier не входит в текущую установку tools. Project node_modules сохраняет приоритет. |
| Bash | Node; Bash runtime/backend | bash-language-server, shfmt, shellcheck, bash-debug-adapter; ещё1 parser | Подготовка закреплённого adapter patch не включена в общий setup; на Windows нужен выбранный владельцем WSL2 backend. WSL установщик не трогает. |
| SQL | Go требуется текущему sqls install recipe | sqls, sqruff; ещё1 parser | Нужны существующие patched sqls и forge-sqltest, а не один stock sqls receipt. Базы/credentials — пользовательские. |
| Terminal | — | Mason/parsers нет | Нужен native WezTerm/font artifact и проверенная private интеграция с явным config, без замены пользовательского WezTerm. |

Windows native read-only snapshot: .tests/release-inventory-windows.json,
получен самим tool_catalog в Neovim `-u NONE`, без SDK queries/сети/setup.
При полном выборе это33 различных parsers; Windows Rust строка не включает
codelldb по текущему OS guard. POSIX guard проверен чтением кода, native Mac
этим снимком не проверяется.

## Почему имеющийся setup ещё недостаточен

1. [setup-stage.lua](../nvim_forge/scripts/setup-stage.lua) подготавливает только
   выбранные plugins/parsers/Mason packages. Успешная проверка этого списка
   не обнаруживает инструмент, который вообще в него не включён.
2. [lsp.lua](../nvim_forge/lua/plugins/lsp.lua) включает Go LSP только при
   доступном gopls. [format.lua](../nvim_forge/lua/plugins/format.lua) ожидает
   внешние stylua/gofumpt/golines/prettier. Это IDE tools, а не языковые SDK.
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

1. **Закрыть существующие внешние IDE tools:** явная подготовка в fride,
   gopls/stylua/gofumpt/golines/prettier, повторно используя обычные SDK.
   Без global npm/cargo/go install и без SDK homes внутри kit. Способ/версии
   закрепить перед поставкой; не создавать второго менеджера поверх Mason.
   Учитывать Node dependency Core formatting и готовность SDK, а не только
   `--version`. Это следующий конкретный кодовый срез.
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

Этот список не меняет SDK policy и не объявляет пункты1–5 реализованными.
Они пока не заблокированы целиком Mac-проверкой: общая подготовка и Windows/
Ubuntu выполняются до неё. Публикация и непроверенные платформы отдельно открыты.
