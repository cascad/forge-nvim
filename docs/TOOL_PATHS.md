# Пути языковых сред и инструментов

2026-11-17, FIXLOG §265, IDE-BOOT-33. Первый срез: Python, Node, native Bash,
Bats и JS entrypoints инструментов Node/Bash. Чтение настроек ничего не устанавливает.

## Настройки

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
| `js-debug-adapter` | `dapDebugServer.js` | `vim.g.forge_js_debug_server`, `FORGE_JS_DEBUG_SERVER` |
| `bash-debug-adapter` | `extension/out/bashDebug.js` | `vim.g.forge_bash_debug_adapter`, `FORGE_BASH_DEBUG_ADAPTER` |
| `prettier`, `jest`, `typescript-language-server`, `bash-language-server`, `npm` | Соответствующий JS entrypoint | Штатный поиск project/shared/Mason tools сохраняется |

JS entrypoint проверяется как файл и запускается выбранным Node; executable bit
ему не нужен. `.cmd` не подставляется вместо JS entrypoint. Аргументы DAP остаются
в штатных launch configurations; tools.json в этом срезе содержит только пути.
На Windows `bash` выбирает native Bash для run/tests, не меняет Linux pathBash
WSL2 отладчика. Явная подготовка существующего Bash adapter patch остаётся прежней.

## Порядок выбора и ошибки

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
Node, Bash, Bats и двух DAP entrypoints видны выбранный путь, источник, корень
проекта и ошибка. Из tool-панели учитывается открытый код. Версии пока не
запрашиваются: отчёт не запускает SDK CLI и не скачивает tools.

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
Далее: Go/Rust/SQL и остальные LSP/DAP/formatter consumers, согласование путей
setup/runtime, выбор версий/build toolchain и providers/update UI.
Установщик сохраняет прежний `--sdk-path`; tools.json не является настройкой
установки SDK. [Принятый подход](TOOLCHAIN_INSTALLATION_APPROACHES.md).
