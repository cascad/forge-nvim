# IDE-080 — Git, корни проектов и границы инструментов

2026-11-10. Source review runtime `6054b40`; поведение не менялось.
Продолжение [общего обзора](FEATURE_REVIEW.md) и
[карты DAP/panels](PANEL_OWNERSHIP_REVIEW.md).

IDE-082 после этого исходного review реализован отдельным change
fix-passive-go-discovery; актуальная семантика и команды — [GO_TOOLS](GO_TOOLS.md),
результаты/gates — PROBLEMS/roadmap. Исходные observations ниже сохраняют контекст.

## Актуальный проход инструментов — 2026-11-12

Source `3d0e6b7`. Проверено чтением текущих Lua/helpers/fixtures; новых native
Mason-запусков этот review не подтверждает. Панели/DAP/normal order уже прошли
отдельные изменения §187–194; здесь следующий участок, общие tools/OS boundaries.

| Владелец | Фактическая политика | Решение |
|---|---|---|
| `forge.python.resolve` | Валидный explicit → active venv → conda → project venv → PATH; invalid explicit допускает fallback | Сохранить порядок. Conda Windows использует env/python.exe, обычный venv — Scripts/python.exe |
| Python DAP | Adapter explicit → project venv → PATH → Mason; Python adapter explicit → Mason → project Python | Adapter и debuggee имеют разные роли; один interpreter resolver их не заменяет |
| `forge.node` | Node отдельно от настоящего JS entrypoint; project parents → shared → Mason → PATH package → Node globals | Сохранить Node+script argv без .cmd; Bash LS уже использует эту границу |
| `forge.bash_host`/`forge.bats` | Native Bash с исключением WSL launcher на Windows; Bats script из project/PATH, MSYS/cygpath и child env отдельно | Не заменять native checks простым exepath; startup scripts не читать |
| `forge.sql.tool`/SQL Tests | Invalid explicit блокирует PATH fallback; SQL Tests ищет forge-sqltest при собственных override keys | Четыре похожие строки не оправдывают связь Tests с SQL LSP module или новый framework |
| Delve/codelldb | Delve выбирает versioned candidates по явному debug; codelldb имеет PATH/Mason/Windows guess | Сохранить backend-specific порядок; по внешнему сходству с Python не объединять |
| Terminal/Treesitter | pwsh только на Windows; WinGet tree-sitter lookup только Windows и только в явной install command | Уже системные границы. Прежняя строка review про POSIX pwsh историческая, не текущий дефект |

Общие `forge/platform.lua`/`forge/tools.lua` в архитектурном плане были
предложением. В текущем runtime их нет; создавать обязательный слой с
параметрами для всех перечисленных исключений сейчас не нужно. Политики
остаются в имеющихся небольших языковых модулях; hotkeys/panels общие.

Есть точное совпадение primitive `executable_path` в dap.lua и private
`executable` в forge.python: type/string/expand/executable. Вынос этих строк
сам по себе не устраняет Windows-only путь и добавляет публичный API/alias.
Сначала исправляется доказанный workflow; общий primitive можно пересмотреть
в том же участке, если от этого уменьшится ответственность, а не только LOC.

### Следующий кандидат: IDE-119, managed debugpy venv

В `plugins/dap.lua` проектный adapter использует уже существующий
debugpy_adapter_in_env с Windows/POSIX layout. Два Mason fallback ниже
жёстко указывают venv/Scripts/debugpy-adapter.exe и venv/Scripts/python.exe
без OS branch. Это статическое наблюдение; native Mason failure на Unix
ещё не воспроизводился. Статус — PROBLEMS IDE-119.

Existing python_project fixture устанавливает locked Python tools в project
.venv, поэтому обычный Python workflow не доказывает выбор managed fallback.
Нужен отдельный настоящий debugpy сценарий: adapter только в частном managed
venv, project Python отдельно, без adapter в project/PATH. Проверить F5,
breakpoint/eval42/stdout/continue, фактические выбранные adapter/interpreter,
explicit overrides и отсутствие установки при открытии файла. Source/target
Windows/Ubuntu, Mac отдельно. Не строить ради этого общий tools framework.

До native source RED поведение этих resolvers не меняется. SQL backend,
private language servers и UI/plugins не заменяются. Историческая причина
IDE-117 ps failure остаётся неизвестной; Docker Desktop/WSL для review не нужны.

## Что оставлять раздельным

| Понятие | Текущий владелец/правило | Почему это отдельная задача |
|---|---|---|
| Выбранная рабочая папка | config.start, project.nvim manual_mode, явные open folder/worktree/ProjectRoot | Фокус старого файла не должен отменять выбранный cwd |
| История проектов | project.nvim history + DirChanged; Alpha и pickers читают её | Recent Projects не равен автоматическому определению root на BufEnter |
| Сессия | persistence по cwd/branch; config.start сохраняет/восстанавливает | Окна, несохранённый текст и запущенный debug требуют согласованного переключения |
| Git/worktree | Git, Neogit, Gitsigns, Diffview | У файла, выбранного cwd и job cwd могут быть разные каталоги |
| LSP/module root | Правила готового сервера/языка, например go.work/go.mod и package.json | В монорепозитории ближайший package может быть глубже выбранного workspace |
| SQL connection/results | .sqls.json root, выбранное подключение, запись результатов по root/tab | Смена workspace не должна отправлять запрос в прежнюю DB |
| Task/test cwd | tasks.json/launch config, Cargo target, adapter root | Запуск конкретной цели не обязан менять workspace редактора |

`config.start.open_project` для другого root использует native `:restart`:
сначала запись modified buffers, остановка DAP, сохранение сессии и затем
открытие нового проекта. Neogit worktree visit меняет cwd и сохраняет старые
буферы; это другой пользовательский переход. Объединять их одной функцией
«сменить root» без отдельного решения о поведении нельзя.

`project.nvim` работает в manual_mode, поэтому его BufEnter auto-detection
выключен. LSP-root override не обязательно мёртвый: явный `:ProjectRoot`
в pinned plugin вызывает тот же resolver. Сначала проверить этот маршрут,
затем решать, нужен ли override или достаточно готовой реализации.

Источники: [config.start](../nvim_forge/lua/config/start.lua),
[project/session setup](../nvim_forge/lua/plugins/editor.lua),
[Git](../nvim_forge/lua/plugins/git.lua),
[Gitsigns/Neogit patches](../nvim_forge/patches/README.md),
[tasks](../nvim_forge/lua/plugins/tasks.lua),
[SQL state](../nvim_forge/lua/ide/sql.lua).

## Git: три интерфейса, разные действия

| Компонент | Рабочая роль | Решение для review |
|---|---|---|
| Gitsigns | Hunks/signs, stage/reset/preview без ухода из файла | Сохранить. Не заменяет branch/commit/worktree |
| Neogit | Status/index/commit/push/ветки/worktree и Git ошибки | Сохранить. Общий Space w и ясное владение cwd важнее числа плагинов |
| Diffview | Несколько файлов diff, история, native diff panes/merge | Сохранить до сравнения этих сценариев с Neogit; интеграция уже включена |

Удаление одного Git-плагина сейчас не доказано эквивалентным. В исходниках
есть дополнительный UI glue: перевод normal/insert mode, согласованный scroll,
возврат файла/дерева, подсветка и закрытие загружающейся view. При упрощении
проверять именно эти действия, а не только успешный `require`.

Существующие постоянные E2E: git-workflow (6 сценариев, включая hunk,
branch/commit/local push/worktree и root старого файла), diffview lifecycle,
worktree/object-read races и Git errors/conflicts. Прежние Windows/Ubuntu
результаты перечислены в roadmap/FIXLOG; в этом срезе Git-наборы заново не
запускались. Credentials/исходный редкий IDE-038/Mac/GUI остаются открытыми.

## Tools: общие принципы и настоящие системные границы

Установка Mason/registry/tools остаётся явной: Mason-команды, setup scripts,
отдельная подготовка тестовых SDK. `ensure_installed={}` у LSP bridge,
tool-installer run_on_start=false, Treesitter automatic list пуст. Это не
гарантия отсутствия работы, которую самостоятельно запускает язык или plugin.

| Область | Граница сейчас | Что можно унифицировать / что сохранить |
|---|---|---|
| Node/JS и Bash LS | node executable + настоящий JS entrypoint, project/shared/Mason/PATH | Готовый server и argv без .cmd wrapper; не новый language server |
| Python | Явный path, active virtualenv/conda, project venv, PATH | Согласованность LSP/run/debug/test interpreter. Не подменять generic exepath resolver |
| Bash | Native executable; Windows launcher WSL исключён, cygpath/MSYS на границе | Общий Bash workflow и штатный shell каждой ОС; startup scripts не читать ради Bats |
| SQL | Явный executable/PATH, .sqls.json profile, готовые SQLS/Sqruff | Backend/protocol/version readiness и DB lifecycle отделить от установки |
| Go/Delve | PATH/override/Mason/GOBIN/GOPATH, version candidates, GOTOOLCHAIN | Найден eager subprocess на открытии файла: IDE-082 ниже |
| Терминал | ToggleTerm предпочитает pwsh при его наличии, иначе vim.o.shell | Условие сейчас не ограничено Windows. Перед изменением проверить ожидаемый POSIX shell при установленном pwsh |

Разница в override policy тоже требует осознанности: Python может продолжить
fallback после невалидного explicit path; Node/Bash/SQL обычно возвращают
отсутствие инструмента. Это не основание автоматически сделать все helpers
одинаковыми. Windows .exe/argv/PTY и Bash MSYS — реальные границы платформы;
общие действия и хоткеи от них не должны зависеть.

## IDE-082: Go-команды уже при открытии файла

В настоящем isolated Forge открыт только main.go, без F5, тестов или health.
Контролируемый go.mod требует заведомо отсутствующий Go 1.99.0. Два новых
профиля на ОС: GOTOOLCHAIN=auto и local; GOENV/GOPROXY/GOSUMDB=off.
Proxy выключен, скачивание SDK не выполнялось. Последний вариант диагностики
задаёт GOPATH/GOMODCACHE/GOCACHE в private runtime (Windows — F:).

| Инициатор | Наблюдаемые команды | Где наблюдалось |
|---|---|---|
| nvim-dap-go opts → resolve_dlv_path → unique_dlv_candidates | Синхронные go env GOBIN и GOPATH | Windows и Ubuntu, до запуска debug |
| nvim-lspconfig gopls root detection | Асинхронные go env GOMODCACHE/GOROOT, здесь по два запроса каждого | Windows с доступным gopls; Ubuntu probe не добавляет lsp-deps/bin в PATH |
| Go label в Lualine → forge.go | Асинхронный go version, timeout 15s | Windows и Ubuntu |

В auto каждый наблюдаемый Go command вернул code=1 с `downloading go1.99.0`;
в local — code=0 без download. Mason install counter=0 в обоих режимах.
Этот counter не видит toolchain work, которое начинает сам Go.
Windows auto дал 4 hit-enter screens, local — 0. В Ubuntu оба режима дали
по одному prompt отсутствующего gopls; его нельзя приписать загрузке SDK.
Counts — не эталоны/замер задержки, а наблюдения этих controlled profiles.

Источники: [Delve search](../nvim_forge/lua/plugins/dap.lua),
[Go label](../nvim_forge/lua/forge/go.lua),
[Lualine](../nvim_forge/lua/plugins/ui.lua).
Повторяемая диагностика: [go-statusline.lua](../tests/diagnostics/go-statusline.lua),
[команды/ограничения](../tests/diagnostics/README.md).
Сводки `.tests/review-go-statusline-windows-isolated.json` и
`.tests/ubuntu/review-go-statusline-ubuntu.json`; native artifacts Windows
8812352762400/8817131557500, Ubuntu 7873624467787/7876689063212.
Это наблюдение дефекта/стоимости, не выполненное исправление и не feature PASS.

Приоритетный небольшой change: отложить поиск Delve до debug/явной диагностики;
определить пассивную политику Go label, не меняя глобально GOTOOLCHAIN и не
ломая выбор требуемого проектом SDK для реальной сборки/LSP/debug. Готовый
gopls остаётся готовым backend. Нужен постоянный regression с отсутствующим
toolchain и обычный Go language/DAP/test workflow на Windows/Ubuntu, затем Mac.

Исходная IDE-001 — задержка zsh до nvim на Mac — этим не объяснена. Требуется
отдельный shell trace с Mac. Нельзя переносить найденный редакторный call stack
на процесс, который происходил до старта редактора.

## Save/format не объединять механически

Autosave записывает текущий buffer и сохраняет write autocmd для диагностики.
Его публичные события выставляют per-buffer флаг. Conform пропускает format
такой записи, а явный save форматирует асинхронно после записи. Общий trim
не считается языковым formatter; fallback resolver уже исправлялся (IDE-050).
Это связанная политика, а не две одинаковые системы сохранения. Удалять флаг
или переводить всё в синхронный BufWritePre — изменение пользовательского UX.

## Порядок дальнейших небольших изменений

1. IDE-082: убрать фоновую работу, не нужную для открытия файла, с native RED
   и сохранёнными language/debug/test сценариями; никаких глобальных запретов SDK.
2. Политика Output/reopen из PANEL_OWNERSHIP_REVIEW, затем совпадающие predicates
   окон. Отдельно сохранить PTY/session lifetime.
3. IDE-081: выбрать обязательность native fzf, явную preparation/readiness и
   видимый fallback. Не строить свой sorter.
4. По выбранным дополнительным фичам убрать целиком plugin/hooks/настройки,
   проверяя реальные оставшиеся действия. Peek/breadcrumbs/ruler ещё не выбраны;
   Alpha/recents, Go label и SQLLogicTest — отдельные решения о полезности.
5. Только после этого сокращать launch/tool/root glue по совпадающей семантике;
   Git и языковые корни не сливать ради одного большого resolver.
