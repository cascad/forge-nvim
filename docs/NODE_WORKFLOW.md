# JavaScript / Node.js

Общие команды для Windows, macOS и Ubuntu. Реальные E2E выполняются отдельно
на каждой ОС; наличие конфигурации не означает проверку на машине владельца.
Поддерживается исполняемый JS (.js/.cjs/.mjs), Jest и проектные package scripts.
Браузер, Deno/Bun и TypeScript transpilation/source maps пока вне этого шага.

## Явная подготовка

После обновления сборки выполнить `:Lazy install` для нового neotest-jest,
затем `:Lazy build neotest` и перезапустить редактор. Это явная установка
плагина и подготовка патча путей; обычный startup этого не делает.

Установить Node.js с npm и добавить `node` в PATH. В проекте явно установить
нужные инструменты, например проверенный тестами набор:

```sh
npm install --save-dev typescript@5.9.3 typescript-language-server@5.1.3 prettier@3.6.2 jest@30.2.0
```

Языковой сервер также можно установить через `:MasonInstall typescript-language-server`.
Для отладки нужен явный `:MasonInstall js-debug-adapter`. Открытие редактора,
файла или запуск F5 ничего не устанавливают. Автоматическое скачивание typings
сервером отключено; нужные `@types/*` устанавливаются в проекте явно.

Поиск CLI: ближайший package.json и родительские node_modules, затем явно
заданные общие tools, Mason и установленный PATH. Локальные инструменты имеют
приоритет. Сам процесс запускает Node с JS entrypoint списком argv, без
зависимости от Windows .cmd или POSIX shell для CLI.

Необязательные явные границы: `FORGE_NODE_EXECUTABLE` — путь к native Node,
`FORGE_NODE_TOOLS` — каталог с node_modules, `FORGE_JS_DEBUG_SERVER` — полный
путь к `js-debug/src/dapDebugServer.js`. Их `vim.g` аналоги:
`forge_node_executable`, `forge_node_tools`, `forge_js_debug_server`.
Неверный явный путь Node/debug server не подменяется инструментом из PATH.

## Работа без мыши

| Действие | Команда |
|---|---|
| Определение / ссылки / переименование | `gd` / `gr` / `F2` |
| Диагностика строки | `gl` |
| Форматирование | `Space l f`, `Shift Alt f`, `:Format`; также после сохранения |
| Текущий JS файл | `Space j N`, `:NodeRunFile` |
| Выбрать package script | `Space j n`, `:NodeRun` |
| Tasks / вывод задачи | `Space w b`, затем штатное действие Tasks `Ctrl s` |
| Debug / breakpoint / eval | `F5` / `F9` / `Space d e` |
| Locals / Debug Output / код | `Space w d` / `Space w c` / `Space w 0` или `F7` |
| Tests / Test Output | `Space w t` / `Space w r` |
| Nearest / file / debug nearest | `Space T t` / `Space T f` / `Space T d` |
| Развернуть тесты выбранного файла | `e` в Tests |
| Помощь / скрыть панель | `Space w ?` / `Space w q` |

NodeRunFile использует каталог package.json как cwd. NodeRun читает scripts
этого package.json и выполняет `npm run <имя>`: shell внутри самого npm script
остаётся ответственностью проекта. Задача показывает реальный status/stdout/stderr.

Без launch.json F5 запускает текущий JS через js-debug/internalConsole;
вывод сохраняется в существующей DAP панели. В `.vscode/launch.json`
поддерживаются Node configurations с `type: "pwa-node"` или `"node"`, program,
cwd и args. Конфигурации выбираются существующим picker. Для JSX/TS runtime
используйте подходящий package script/явный launch, а не запуск исходника Node.

Jest определяется по установленному проектному package. Nearest ограничен
выбранным тестом, file запускает файл целиком; debug использует тот же js-debug.
Другие test frameworks пока не заявлены.

## Постоянные проверки

Сначала подготовить общие плагины и Windows SDK по [инструкциям E2E](../tests/e2e/README.md).
Затем явно подготовить Node зависимости:

```sh
python -B tests/e2e/prepare_node.py --download --nvim <путь-к-nvim>
python -B tests/e2e/prepare_node.py --nvim <путь-к-nvim>
<путь-к-nvim> -l tests/e2e/node-language.test.lua
```

На Linux/macOS команда Python может называться python3. SDK Node 24.11.0,
js-debug 1.105.0, SHA256 архивов, npm lock/integrity и pinned JS parser
готовятся в `.tests/node-deps`. Повтор без --download не устанавливает tools.
Windows TEMP/TMP/TMPDIR должны указывать на `.tests/tmp` checkout; готовый SDK
выбирается через scripts/lib/nvim-sdk.ps1. Полные команды — docs/AGENT_COMMANDS.md.

Тесты вводят клавиши в настоящий private Neovim, используют реальные Node,
TSLS, Prettier, npm/Jest и js-debug; проект имеет пробел и Unicode в пути.
В snapshots сохраняются исходники/manifest/lock/output/logs, node_modules
повторно не копируются в artifacts. Зависимости восстанавливаются preparer.
`FORGE_NODE_CASE` ограничивает запуск по подстроке имени сценария.
