# Пути языковых сред и инструментов

2026-11-18, FIXLOG §265–276/283/287, IDE-BOOT-33/34/36/37/38/41/45/48. Python, Node, native Bash,
Bats, Sqruff, Go/Rust LSP, форматтеры и DAP. Чтение настроек ничего не устанавливает.

§289 / IDE-BOOT-49: ключ `cargo-nextest` выбирает executable для Rust Tests.
Приоритет — явный project/user path, PATH, обычный `CARGO_HOME/bin` (либо
`~/.cargo/bin`). Например, `{"tools":{"cargo-nextest":"F:/tools/nextest/cargo-nextest.exe"}}`.
Неверный явный путь блокирует запуск тестов с причиной в `:ForgeLogs`, не выбирает
другую копию и не мешает редактированию. F5/debug nearest используют штатный
Cargo/CodeLLDB и не требуют nextest. Версия не проверяется при открытии файла.

## Ошибка пути во время работы

При неверном Node/Bash, JS entrypoint или повреждённом tools.json открытие
JS/Bash файла и его сохранение остаются доступны. LSP не запускается с неверным
путём; Run/Debug выводит предупреждение без создания задачи/сессии. Полная
причина и область настройки доступны в `:ForgeLogs events:Tool paths` и общем
списке событий. Другая копия из PATH не выбирается вместо явной настройки.
Повтор одного LSP события для того же буфера/причины не повторяет предупреждение.

Исправьте tools.json или путь в настройке и повторите Run/Debug. Для не
запустившегося LSP после исправления можно выполнить `:LspStart ts_ls` /
`:LspStart bashls` либо переоткрыть файл. Неверный Node помечает Prettier
недоступным; сохранение не вызывает исключения из formatter callback.
Строгая проверка `:ForgeToolPaths`, setup/preflight и SDK picker сохранена:
ошибка не превращается в молчаливый выбор другой среды.

Native regressions: `tests/e2e/missing-tool-errors.test.lua`,7 сценариев;
Windows/Ubuntu PASS (§276). В пакет также входят прежние Node/Bash/Logs,
tool paths, Go/Rust и setup checks. Native Bash debug workflow проверен на
Ubuntu; Windows missing cases не запускают WSL, Windows native WSL acceptance
остаётся отдельным шагом. macOS проверяет владелец.

## Настройки

Для Python/Node файл можно настроить через `Space l S` / `:ForgeSdk`,
выбрав существующую среду или ручной путь. Меню использует именно tools.json;
сброс удаляет ключ выбранной области и возвращает прежнее наследование.
Следующие workflow читают новый путь, работающие LSP обновляются через явное
переоткрытие проекта. [Руководство](SDK_SELECTION.md#python-и-node-через-общие-настройки).

- Пользователь: `tools.json` в `:echo stdpath('config')`. Для установленного
  приложения это config namespace fride, отдельно от обычного nvim и исходников kit.
  На каждой ОС файл свой.
- Проект: `.fride/tools.json` относительно ближайшего корня `.git`/`.fride`.
  Для вложенного самостоятельного репозитория используются его настройки.

Формат — обычный JSON, без комментариев. Пример для Windows:

```json
{
  "tools": {
    "python": "D:/SDK/Python/python.exe",
    "node": "D:/SDK/node/node.exe",
    "bash": "C:/Program Files/Git/bin/bash.exe",
    "js-debug-adapter": "D:/IDE tools/js-debug/src/dapDebugServer.js"
  }
}
```

Указываются существующие пути своей машины. На macOS/Linux пример выбора
проектной venv: `{"tools":{"python":"./.venv/bin/python"}}`; в Windows у такой
venv обычно `./.venv/Scripts/python.exe`. Настройки конкретной машины удобно
держать в пользовательском файле. Относительные проектные пути разрешаются от
корня проекта, пользовательские — от каталога tools.json. `~` поддерживается;
bare имя executable, например `python3`, ищется в PATH. Пробелы не требуют
shell-кавычек внутри значения JSON. В Windows можно использовать `/` либо
JSON-экранированный `\\`.

Создать каталог и открыть пользовательский файл штатным редактором:

```vim
:lua local d=vim.fn.stdpath('config'); vim.fn.mkdir(d,'p'); vim.cmd.edit(vim.fn.fnameescape(d..'/tools.json'))
```

Для проектного файла:

```vim
:lua local d=require('forge.tool_paths').root()..'/.fride'; vim.fn.mkdir(d,'p'); vim.cmd.edit(vim.fn.fnameescape(d..'/tools.json'))
```

Сохранение файла не устанавливает инструменты. Следующий запуск workflow читает
актуальные настройки. Уже запущенный LSP/DAP использует прежнее окружение до
штатного перезапуска. Для возврата к auto discovery удалите ключ; пустое или
неверное значение является ошибкой настройки.

## Что можно выбрать сейчас

| Ключ | Значение | Прежние настройки продолжают работать |
|---|---|---|
| `python` | Python executable проекта | `vim.g.forge_python_path`, `FORGE_PYTHON_PATH` |
| `node` | Node executable | `vim.g.forge_node_executable`, `FORGE_NODE_EXECUTABLE` |
| `bash` | Native Bash executable | `vim.g.forge_bash_executable`, `FORGE_BASH_EXECUTABLE` |
| `bats` | Файл Bats runner | `vim.g.forge_bats_executable`, `FORGE_BATS_EXECUTABLE` |
| `sqruff` | Готовый Sqruff executable, LSP и formatter | `vim.g.forge_sqruff_executable`, `FORGE_SQRUFF_EXECUTABLE` |
| `shellcheck`, `shfmt` | Native executable для Bash LSP и форматирования | PATH/Mason; явные BashLS settings и `SHELLCHECK_PATH`/`SHFMT_PATH` сохраняются |
| `gopls`, `rust-analyzer` | Executable соответствующего LSP | При отсутствии override — PATH/Mason; native workspace discovery |
| `gofumpt`, `golines`, `rustfmt` | Executable форматтера | PATH/Mason; прежние аргументы Conform |
| `dlv` | Executable Delve | `vim.g.forge_dlv_path`, `FORGE_DLV_PATH`, затем `DLV_PATH` |
| `codelldb` | Executable адаптера в готовом CodeLLDB bundle | `vim.g.forge_codelldb_path`, `FORGE_CODELLDB_PATH` |
| `js-debug-adapter` | `dapDebugServer.js` | `vim.g.forge_js_debug_server`, `FORGE_JS_DEBUG_SERVER` |
| `bash-debug-adapter` | `extension/out/bashDebug.js` | `vim.g.forge_bash_debug_adapter`, `FORGE_BASH_DEBUG_ADAPTER` |
| `pyright`, `prettier`, `jest`, `typescript-language-server`, `bash-language-server`, `npm` | Соответствующий JS entrypoint; для Pyright — `langserver.index.js` | Штатный поиск project/shared/Mason tools сохраняется |

JS entrypoint проверяется как файл и запускается выбранным Node; executable bit
ему не нужен. `.cmd` не подставляется вместо JS entrypoint. Аргументы DAP остаются
в штатных launch configurations; tools.json в этом срезе содержит только пути.

Pyright использует выбранный `node`, как TypeScript/Bash LSP и Prettier;
выбор Python для анализа и проектной venv остаётся отдельным. Для готовых
Windows Mason exports ShellCheck/shfmt/Sqruff прямой запуск использует `.exe`
из штатного receipt. Явные пользовательские пути и внешние wrappers сохраняются.
Это runtime lookup готового пакета, без registry refresh, установки или обновления.
На Windows `bash` выбирает native Bash для run/tests, не меняет Linux pathBash
WSL2 отладчика. Явная подготовка существующего Bash adapter patch остаётся прежней.

Go/Rust LSP сохраняют штатные roots `go.work`/`go.mod`/Cargo workspace,
аргументы и окружение. Форматтер выбирается по файлу, включая фоновый буфер;
DAP — по проекту запуска. Для CodeLLDB нужен целый upstream bundle с его
библиотеками; путь указывает на `adapter/codelldb[.exe]`. SDK и его DLL
перемещать не нужно. Без override CodeLLDB сохраняет PATH/Windows LOCALAPPDATA/
Mason поиск; Delve — асинхронный поиск GOBIN/GOPATH/PATH/Mason с выбором версии.

## Порядок выбора и ошибки

### Явный setup приложения

Setup учитывает **пользовательский** tools.json для уже поддерживаемых путей:
gopls/gofumpt/golines/rust-analyzer/codelldb/sqruff, dlv (Mason package delve),
JS entrypoints prettier/typescript-language-server/bash-language-server/
js-debug-adapter/bash-debug-adapter. Выбранный компонент по-прежнему определяет,
какие tools нужны. Для явно выбранного готового tool соответствующий Mason
package не устанавливается и его receipt не требуется, даже с
`--tools-versions baseline`. Остальные packages готовятся по обычной policy.

Setup проверяет executable либо JS file и готовый Node; CodeLLDB path относится
к целому готовому upstream bundle. Источник/path и число внешних tools видны в
`log/setup-tools.log` установленного комплекта. Это проверка расположения и
зависимостей entrypoint, а не обещание совместимости произвольной версии tool.
Выбранные файлы и уже существующие Mason packages сохраняются.

Неверный явный путь даёт ошибку без fallback. Путь в заменяемых `runtime`,
`config` или `bin` собственного kit не принимается: при публикации эта копия
может исчезнуть. Файл, исчезнувший во время setup, также запрещает publication.
Проектный tools.json не влияет на установку приложения; при работе в проекте
его прежний приоритет сохраняется. SDK prerequisites проекта остаются обычными.

Неподключённые runtime keys не исключают packages из установки. Эта policy
касается tools.json; прежние отдельные vim.g/env overrides остаются runtime
настройками. `:MasonInstall` остаётся прямым штатным действием менеджера.

### Работа в проекте

1. Проектный tools.json.
2. Пользовательский tools.json.
3. Прежний `vim.g`, затем переменная окружения.
4. Существующее обнаружение языка: venv/Conda, project tools, PATH, Mason и
   native Git Bash fallback на Windows — в соответствии с интеграцией.

Неверный явный путь завершает выбор ошибкой с именем инструмента и источником.
Скрытого переключения на другую копию нет. Это исправляет прежнее поведение
Python, который игнорировал неверный override. Повреждённый tools.json и файл
больше64KiB дают явную ошибку конфигурации. SDK homes, PATH пользователя,
окружение процесса и project lockfiles не меняются.

`:ForgeToolPaths` открывает IDE Logs с источником `Tool paths`. Для Python,
Node, Bash, Bats, Sqruff, Go/Rust tools и двух DAP entrypoints видны путь, источник, корень
проекта и ошибка. Из tool-панели учитывается открытый код. Версии пока не
запрашиваются: отчёт не запускает SDK CLI и не скачивает tools.
Для Delve без override это только доступность PATH/Mason; полный выбор с
сравнением версий выполняется при debug или явном `:DapGoDlvInfo`.

## Граница настройки SDK

`go`, `cargo`, `rustc`, `gotestsum` и `cargo-nextest` сейчас не являются
поддержанными ключами tools.json. SDK выбирается штатно через окружение,
Go toolchain и rustup/project overrides. Run/debug/tests сохраняют свои native
интеграции. Это не обещание одного отдельного SDK override во всех режимах.
Pinned Neotest adapters местами жёстко используют `go`/`cargo`; Go adapter
проверяет gotestsum в PATH ещё до публичного RunSpec и меняет runner при fallback.
Подмена argv после этого не решает задачу. Для независимого executable override
в каждом адаптере нужен поддержанный API. Владелец выбрал native окружение как
основу (§270); §271 реализовал [выбор установленного Go/Rust SDK](SDK_SELECTION.md):
`Space l S` / `:ForgeSdk`, ручной путь, user/project/«Авто» и явное переоткрытие
с сессией. Выбор хранится отдельно в sdk.json и применяется через штатную среду
процесса; tools.json продолжает задавать именно IDE tools.

## Проверка и оставшаяся работа

Windows: четыре редакторных E2E прошли. Проверены user/project/legacy priority,
настоящая venv, NodeRunFile и BashRunFile, JS argv с пробелами, неверные пути,
повреждённый JSON, смена проекта, обновление config и отчёт из панели.
Ubuntu: те же четыре E2E прошли (§266), включая native Python symlinks в venv.
macOS — отдельный native прогон владельцем. Подготовленные editor/Node deps и
обычные Python/Bash нужны заранее; тест не устанавливает SDK.

```powershell
$env:FORGE_TEST_ID='IDE-BOOT-33'
& .tools/neovim/windows-x64/bin/nvim.exe -l tests/e2e/tool-paths.test.lua
```

```sh
FORGE_TEST_ID=IDE-BOOT-33 nvim -l tests/e2e/tool-paths.test.lua
```

Готовый Ubuntu image, офлайн и без build/pull:

```sh
docker compose -f tests/containers/compose.yaml run --rm --no-deps --pull never --entrypoint bash ubuntu tests/containers/tool-paths.sh
```

Driver обновляет backports только в своей временной копии prepared plugins;
образ и его SDK не изменяются. Derived venv не архивируется как исходники
проекта; фактический Python/prefix сохраняется в python-selection.json.

Набор зарегистрирован в общем tests/registry.lua. Полный запуск остаётся
`scripts/test.ps1 e2e` / `scripts/test.sh e2e` в подготовленной среде.
§267: базовый SQL Sqruff подключён и имеет2 E2E на Windows и Ubuntu.
§269: семь Go/Rust IDE tools подключены. Семь новых E2E и девять native
controls прошли на Windows и Ubuntu (целевые запуски, не общий полный регресс):
реальные LSP/format, Go tests, Delve/CodeLLDB, user/project/invalid paths,
пассивный отчёт, go.work навигация, Rust warmup/disable и late Delve override.
macOS требует отдельного native прогона с заранее подготовленными tools.

```powershell
$env:FORGE_TEST_ID='IDE-BOOT-36'
& .tools/neovim/windows-x64/bin/nvim.exe -l tests/e2e/go-rust-paths.test.lua
```

```sh
FORGE_TEST_ID=IDE-BOOT-36 nvim -l tests/e2e/go-rust-paths.test.lua
# Готовый Ubuntu image без сети/build/pull:
docker compose -f tests/containers/compose.yaml run --rm --no-deps --pull never -e FORGE_TEST_ID=IDE-BOOT-36 --entrypoint bash ubuntu tests/containers/tool-paths.sh tests/e2e/go-rust-paths.test.lua
```

Далее: оставшиеся consumers, build-toolchain compatibility и установка/обновление
IDE tools. User SDK settings frontend/setup/runtime согласованы в §275;
`--sdk-path` остаётся fallback. SDK не устанавливается автоматически при чтении
tools.json. [Принятый подход](TOOLCHAIN_INSTALLATION_APPROACHES.md).
