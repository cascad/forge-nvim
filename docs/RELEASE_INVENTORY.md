# Что ещё требуется для полной поставки fride

Исходный срез2026-11-15, код694cd9e, обновления §251–256. Это состав **существующих возможностей**, а не
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
| Core | Сам по себе не требует SDK языка | lua-language-server, stylua; 23 общих parsers | §253: готовый site с33 native libraries, выбранный каталог проверяется без сборки; Windows/Ubuntu PASS, native Mac открыт. §256: pinned rg15.2.0 с лицензиями/real picker PASS Windows/Ubuntu. Git и общий source/license inventory ещё нужны. Prettier для JSON/YAML/Markdown принадлежит Node компоненту. |
| Go | Go | delve, golangci-lint, gotestsum, gopls, gofumpt, golines; ещё4 parsers | При необходимости сборки новых tools требуется обычный Go1.26.0+; готовые packages переиспользуются со старым SDK. |
| Rust | Rust/Cargo | rust-analyzer, codelldb1.12.2 на Windows/POSIX; ещё1 parser | §252: собственный LLDB/Python bundle; реальные breakpoint/continue/output проверены Windows/Ubuntu. Rustfmt — часть обычного Rust toolchain. |
| Python | Python + Node для pyright | pyright, ruff, debugpy; ещё1 parser | Версии SDK/venv и настоящий debug/test acceptance; наличие receipt этого не доказывает. |
| JS/Node | Node/npm | typescript-language-server, js-debug-adapter, prettier; ещё2 parsers | Prettier3.9.10 включён §251, в том числе для JSON/YAML/Markdown. Project node_modules сохраняет приоритет. |
| Bash | Node; Bash runtime/backend | bash-language-server, shfmt, shellcheck, pinned bash-debug-adapter; ещё1 parser | §252: принятый adapter patch применяется явным setup. Ubuntu launch проверен; Windows launch требует существующего WSL2 и здесь не проверен. |
| SQL | Для готовых native tools SDK компилятора не нужен | sqruff; ещё1 parser; sqls/forge-sqltest из native SQL part | §252: publisher/delivery/query/Neotest проверены Windows/Ubuntu без Go/Rust в PATH. Базы/credentials пользовательские; опубликованных release URLs пока нет. |
| Terminal | — | Mason/parsers нет | Нужен native WezTerm/font artifact и проверенная private интеграция с явным config, без замены пользовательского WezTerm. |

Исходный Windows read-only snapshot: .tests/release-inventory-windows.json,
получен самим tool_catalog в Neovim `-u NONE`, без SDK queries/сети/setup.
При полном выборе это33 различных parsers. Snapshot предшествует §252,
который снял Windows codelldb guard; native Mac этим снимком не проверяется.

## Почему имеющийся setup ещё недостаточен

1. [setup-stage.lua](../nvim_forge/scripts/setup-stage.lua) подготавливает только
   выбранные plugins/parsers/Mason packages. Успешная проверка этого списка
   не обнаруживает инструмент, который вообще в него не включён.
2. §251 закрыл gopls/stylua/gofumpt/golines/prettier через тот же Mason;
   [lsp.lua](../nvim_forge/lua/plugins/lsp.lua) и
   [format.lua](../nvim_forge/lua/plugins/format.lua) используют готовые bin/JS.
   Это IDE tools, а не языковые SDK. Их версии и postconditions теперь общие.
3. §252: [dap.lua](../nvim_forge/lua/plugins/dap.lua) использует подготовленный
   Mason codelldb на всех ОС. Native Win/Ubuntu приняли bundle без отдельного
   пользовательского Python SDK. Mac и полный Default acceptance остаются.
4. §252: [bash_debug.lua](../nvim_forge/lua/forge/bash_debug.lua) имеет строгую
   owned подготовку в tools stage; SQL native part содержит принятые
   [sqls](../scripts/sdk/sqls.json) и [forge-sqltest](../scripts/sdk/sql-test/README.md).
   Runtime versions/выбор собственного бинарника проверяются; source builds
   принадлежат publisher. WSL2 на Windows остаётся runtime prerequisite.
5. §253: managed setup проверяет готовый native site из Core, без CLI/compiler.
   Publisher использует уже собранные libraries с pinned revisions и выполняет
   native ABI/query probe. Windows/Ubuntu проверены; Mac и полный Default открыты.
   Обычная явная команда source preparation сохраняется для publisher/unmanaged.

## Следующая очередь реализации

1. **Готово §251 — пять существующих IDE tools:** pinned Mason packages в
   штатном fride data, без установки в пользовательские global prefixes и без
   SDK homes внутри kit. Core-only не требует Node; галочка Node включает
   shared JSON/YAML/Markdown formatting. Сборка Go tools проверяет Go1.26.0+,
   готовые packages этого SDK для повторной сборки не требуют. Реальные
   format/LSP/repeat/failure cases прошли Windows/Ubuntu; native Mac открыт.
2. **Готово §252 — существующие debug/test tools:** codelldb/Bash через Mason,
   owned hash-checked patch, native SQL artifact/publisher и проверки versions.
   SDK компилятора для SQL убран из managed prerequisites. Реальные debug/query/
   test consumers проверены Windows/Ubuntu; Mac, Windows Bash launch и publication открыты.
3. **Собрать Core/Terminal artifacts:** Git/search/parser dependencies и
   WezTerm/font, platform manifests, source/version/SHA/license inventory.
   fd и native fzf — ускорители с существующим fallback, не скрытые обязательные SDK.
   §253–254 закрыли Windows/Ubuntu parser delivery в указанных границах.
   §255 снял long-path Lua cache blocker штатной policy; полный editor E2E Windows/Ubuntu прошёл.
   §256 доставляет native rg15.2.0/Core с лицензиями; real Telescope поиск/переход проверен Windows/Ubuntu.
4. **Настоящий Default/Custom из архива:** отдельный чистый профиль, реальные
   config/plugins/tools, launch → open/search → LSP → debug/tests → format,
   затем repeat/cancel/upgrade. Одна целевая тестовая итерация на изменение.
5. **Native Mac и публикация:** владелец прогоняет ту же native команду на Mac;
   только проверенные artifacts попадают в production catalog. Затем публичные
   one-liners, без ручного поиска/скачивания binaries пользователем.

Пункты1–2 реализованы в указанных границах; пункт3 начат, пункты4–5 ещё не реализованы.
Они пока не заблокированы целиком Mac-проверкой: общая подготовка и Windows/
Ubuntu выполняются до неё. Публикация и непроверенные платформы отдельно открыты.

Версии/команды/границы §251 — [managed IDE tools](INSTALLATION_PLAN.md#подготовка-существующих-ide-tools--251).
Native SDK TUI пока не возвращает пользователя к выбору SDK по build minimum;
backend выдаёт раннюю ошибку. Эту совместимость и все prerequisites надо закрыть
до full Default acceptance, включая случай версии Go из штатного APT.
