# E2E и регресс в целевых средах

Решение владельца, 2026-10-31: **каждая фича имеет e2e; каждый исправленный
баг получает воспроизведение как постоянный регрессионный тест**. Unit и
проверка настроек дополняют e2e. Политика действует для новых изменений;
существующее покрытие постепенно доводим по таблице ниже. Зелёный запуск
имеющихся тестов не означает, что все фичи уже покрыты.

**Основной объект — nvim_forge**, его реальные плагины, проекты и поведение
редактора. WezTerm проверяет внешнюю границу клавиатуры/clipboard/GUI.
Базовый editor e2e уже запускает настоящий Neovim с нашей сборкой,
67 плагинами по lazy-lock.json, изолированным профилем и Git-проектом-фикстурой.
Проверяет запуск, дерево, открытие/изменение/сохранение файла, поиск имени и
содержимого, буферы, фокус и отсутствие фоновых установок. Есть и CLI e2e
инструментов тестирования/диагностики. Каждый шаг roadmap добавляет свои
сценарии: LSP/completion/format,
отладка, тесты, Git/worktree и задачи. См. этап 0.5 в `docs/IDE_ROADMAP.md`.
Сценарии ядра можно проверять через RPC реального редактора; PTY/ConPTY
и GUI дополняют проверку доставки ввода. Прямой вызов приватной функции
плагина с mock-зависимостями не заменяет такой пользовательский сценарий.

## Запуск на целевых машинах и внутри VM

IDE-PY-2 / IDE-119: `nvim -l tests/e2e/python-managed-debug.test.lua`.
Требует prepared Python deps; создаёт private project venv без debugpy и
private managed venv с настоящим offline debugpy.4 cases: launcher, Python
fallback без launcher, global adapter/Python overrides при других env values.
Реальные F5/breakpoint/eval42/stdout/project prefix/continue; raw argv и logs.
Windows source7673dd3/target по4 PASS,15 прежних language/debug checks PASS.
Ubuntu (§221): source7673dd3 дал2 managed RED/2 explicit PASS, target007c567
четыре PASS, ещё15 прежних language/debug PASS.20 native profiles с empty scope;
у всех target16 штатный quit. Mac не запускался и остаётся отдельным gate.
Источник/гейты — verification fix-managed-debugpy-venv-layout, FIXLOG §196/221.

IDE-114: `nvim -l tests/e2e/editor-native-outcome.test.lua`. Настоящие
nvim_forge cquit23/SIGKILL собственного child/primary-error и normal quit;
clean native cquit24 проверяет прежний generic cleanup контракт. На каждой
ОС Windows/Ubuntu source driver af982a9 даёт3 RED/2 controls; target5 PASS.
Product Lua/SDK/quit deadlines прежние. Зависимости только editor; Mac gate
открыт, actual результаты — verification enforce-editor-native-outcome.

IDE-PANEL-23 / IDE-116: `nvim -l tests/e2e/panel-restore-focus.test.lua`.
5 native cases: fallback Files, сохранённые Files+Quickfix, последующий Logs,
явный Files до render и штатный Files после render. Удерживается настоящий
callback navigate после debounce; данные/renderer не подменяются. Windows/
Ubuntu source3 RED/2 controls → target5 PASS на каждой ОС. Полные результаты,
ошибки разработки fixture и ограничения интеграции — verification
fix-panel-restore-focus. Mac/physical delivery открыты.

IDE-113: `nvim -l tests/e2e/terminal-shell.test.lua`. Общая native fixture
сначала создаёт пустой файл, затем пишет результат; observer ждёт payload,
сохраняя shell/PID/channel/history и stdout. Windows cmd: controlled source
RED → target PASS; Ubuntu bash/sh source2 RED → target2 PASS. Mac и actual
Windows pwsh имеют отдельные gates.
Общий Windows E2E2026-11-12:74 файла,71 PASS/3 FAIL; четыре native SIGTERM
IDE-085 (два скрыты старыми callers, IDE-114). Это не общий PASS; §191.

IDE-PANEL-22 / IDE-112: `nvim -l tests/e2e/focus-command-order.test.lua`.
6 native cases: normal F7/F6/cycle/close → Logs и сохранение последнего
выбора, insert text, настоящий terminal job/PID/channel/stdout. Source dc748b7
даёт4 RED/2 controls, target6 PASS Windows/Ubuntu. Source/test SHA и платформенные
границы — verification preserve-normal-command-order; нужен готовый editor SDK.

IDE-DAP-6 / IDE-111: `nvim -l tests/e2e/debugpy-exit.test.lua`, готовые Python
deps. Настоящий установленный debugpy получает invalid CLI option и выходит2;
проверяются native stderr/exit log, WARN, общая IDE Logs и edit/save после
отказа. Source83cf655 скрывает WARN, target сохраняет его. Normal client-close
проверяется существующим python-language pytest debug. Платформы и результаты —
verification remove-obsolete-debugpy-exit-filter.

DAP launch preparation: `nvim -l tests/e2e/dap-launch-routes.test.lua`.
Требует готовые Rust deps; настоящий CodeLLDB проверяет F5/current-file,
Space dP single/multiple/cancel, source args и3 fresh PTY. Source fd6b965
и refactor проходят одинаково Windows/Ubuntu; этот срез сохраняет прежнее
поведение. IDE-115: после DAP pause отдельно ждём реальный stdout PTY;
первый Ubuntu source FAIL сохранён, исправлен только observer с прежним timeout.
Результаты и платформы — verification deduplicate-dap-launch-preparation.

Переходы панелей (IDE-PANEL-21, IDE-109/110):
`nvim -l tests/e2e/panel-transitions.test.lua` —13 настоящих сценариев
Neotree/DAP UI/quickfix: native open, show/hide/toggle/cycle/focus/layout,
раздельное закрытие source, повторный show и другая вкладка.
`nvim -l tests/e2e/dap-tab-scope.test.lua` — настоящий Rust/CodeLLDB,
один PTY в двух вкладках: hide текущего вида сохраняет другой, ту же паузу,
channel/job и stdout после Continue. Второму нужны подготовленные Rust deps.
Общий helper has_window смотрит все вкладки; эти проверки дополнительно
используют текущую tabpage и исходный window ID. Mac проверяется отдельно;
актуальные результаты — verification centralize-panel-transitions.

IDE Logs (IDE-106/107): `nvim -l tests/e2e/ide-logs.test.lua`,
`ide-log-sources.test.lua`, `ide-log-history.test.lua`, `ide-log-tail.test.lua`,
`debug-focus-order.test.lua`. Настоящие missing Node→исправление→js-debug,
gofmt error/native log, Fidget, native E492, источники/фильтры/report/help/zoom,
живой terminal без restart/stop, Unicode/размер/IO failure и native TUI quit/
relaunch/повреждённая история/8 inactive sessions. Source84 console missing и
late Problems focus RED сохранены. [Пользовательские команды/лимиты](../../docs/IDE_LOGS.md).
Выбранные source/tail профили не заменяют full suite или Mac/physical GUI;
итоговые результаты — verification change add-ide-log-console.

IDE-FILE-5: `nvim -l tests/e2e/file-scan-order.test.lua`,7 native cases.
§180: Windows/Ubuntu current7/7 после source RED, включая old root, old
partial/new root, pending folder/full refresh и newer partial/pending full
snapshot. Ordinary A/a/Enter/write, independent folders и initial-file/reveal
controls сохранены. Test-only helper удерживает настоящие IO callbacks
в owned project; actual scanner/init source bytes/rows/disk/native watcher
refs и shutdown сохранены. Проверки не используют xfail/extra toggle/timeouts
для зелёного результата. Старые rejected19-line и source5 сохранены как история
§179; global full suite и native Mac/physical GUI этим selected набором не доказаны.

IDE-105: `nvim -l tests/e2e/file-filter.test.lua`,2 native keyboard cases.
Из раскрытой alpha: f/beta/Enter исключает alpha, Ctrl-X восстанавливает её;
из свёрнутого дерева clear возвращает прежние закрытые папки. На preliminary
payload §180 оба source RED Windows/Ubuntu (rescan loop), финальный §181
проходит оба. Итого9 feature cases,44 editor+15 CLI checks на каждой ОС,
включая35 соседних Files/buffers/Outline/worktree checks. Это selected regression.

Files copy/delete (IDE-FILE-3/4): `nvim -l tests/e2e/file-copy-delete.test.lua`,
Windows — выбранный SDK.9 fresh profiles: реальные clipboard/typed copy,
Unicode/dir/conflict/cancel, normal delete/zoom/recursive/root refusal,
modified file/hidden descendant/late modification. Autosave выключается
публичным ASToggle. Последний случай меняет настоящий buffer native API при
открытом диалоге, подтверждение остаётся пользовательским вводом; backend не
подменён. Все destructive targets заранее проверены внутри private project.
Root refusal — ожидаемое native ERROR notify, не API failure. Подробные
клавиши/ограничения — [FILES_WORKFLOW](../../docs/FILES_WORKFLOW.md).

Managed shell (IDE-PANEL-19): `nvim -l tests/e2e/terminal-shell.test.lua`;
Windows — выбранный `.tools/neovim/windows-x64/bin/nvim.exe`, TEMP на диске
checkout как в [diagnostics](../diagnostics/README.md). POSIX cases используют
настоящие bash/sh и частный executable pwsh shim; он только регистрирует
ошибочный выбор и запускает sh. Устанавливать PowerShell на Linux не требуется.
Windows cases используют настоящий доступный pwsh и private PATH без него
для native fallback. Противоположная ОС явно SKIP. Если `exepath('pwsh')`
не находит real exe, preference case тоже SKIP; Store alias не доказывает
отсутствие установки. Для полного Windows прогона добавь actual installation
directory только в PATH процесса теста (не через setx), затем запусти файл.
Проверяются реальные command files, PID/channel/buffer/history и q/reopen;
скрытных установок, host PATH/global shell изменений тест не делает.

UI frame prototype (IDE-076): `ui-capture.test.lua` проверяет opt-in RGB
record/replay на настоящем редакторе (3 cases); `panel-frame.test.lua` —
9 состояний одной реальной Go/Delve pause, полную active/dim рамку, compact
sample, help/resize/restore и Continue. IDE-PANEL-18 в `debug-panels.test.lua`
отдельно воспроизводит docking общего zoom **без preview**, исходный source
даёт RED. [Команды](../diagnostics/README.md#цельная-рамка-locals-и-rgb-ui-capture),
[визуальное сравнение и ограничения](../../docs/PANEL_FRAME_REVIEW.md).
Это native UI E2E, не физическая проверка WezTerm и не постоянные рамки split.

Текущая схема: **Windows native + Ubuntu Docker на Windows + отдельный Mac**.
Mint временно отложен. VM остаётся вариантом для нативных Linux GUI-проверок.

Windows SDK имеет отдельную границу регресса: `process-lifecycle.test.lua`
проверяет настоящие jobstop/quit с root/child и независимым worker;
`windows-sdk.test.lua` — launcher, hashes, отказ продвижения и откат.
Они дополняют `editor-descendants.test.lua` и buffer/ConPTY проверки.
Native stale-PPID regression компилирует фактический SDK source отдельной
командой `build-process-ancestry.ps1 -SdkCandidate` (нужен MSVC).
Windows lifecycle guard на POSIX явно SKIP; там остаётся официальный SDK.

IDE-097: один native TUI session run остановился с `!stream->closed` в
wstream.c:72, после чего не открылся Quickfix. Raw assert и первый FAIL
сохранены (§168); повтор прошёл, caller/stack пока не получены. Это открытый
SDK/TUI пункт, не закрытый зелёными headless checks.

CLI framework filter (IDE-096): `nvim -l tests/e2e/python-case.test.lua` на
Windows/Ubuntu/Mac с Python3. Он запускает настоящий Neovim и короткий Python
fixture, проверяет lookup/no spawn, UTF8 argv и exit/output; это тест каркаса,
отдельный от editor workflows. Подготовка67 plugins этому файлу не нужна.

Debug toggle с настоящим Rust/CodeLLDB: Windows —
`& .tools/neovim/windows-x64/bin/nvim.exe -l tests/e2e/debug-toggle.test.lua`;
Ubuntu с уже работающим Linux engine и подготовленным image —
`docker compose -f tests/containers/compose.yaml run --rm --entrypoint nvim ubuntu -l tests/e2e/debug-toggle.test.lua`;
Mac с подготовленными editor/Rust deps — `nvim -l tests/e2e/debug-toggle.test.lua`.
Startup hide/новый breakpoint — тот же запуск с файлом
`tests/e2e/debug-startup-visibility.test.lua`. Fixture измеряет реальный
initialized→hide интервал: если pending800ms окно пропущено, это явный отказ
предусловия, а не PASS неисполненного race regression. Она также проверяет
возврат настоящих Locals42 и прежнего PTY на следующей остановке.
Эти команды не запускают Desktop/WSL и не готовят инструменты скрытно.

Для Ubuntu на Windows с запущенным Docker Desktop в режиме Linux containers:

Опциональные ограничения для последовательных fixture-прогонов: добавь
`-f tests/containers/limits.yaml` после основного compose-файла. Это2 CPU,
3 GiB RAM,256 PID и2 Go/Cargo build jobs; engine должен уже работать.
Проверенный prepared image можно использовать без build/download:

```sh
docker compose -f tests/containers/compose.yaml -f tests/containers/limits.yaml run --rm --no-deps --pull never --entrypoint nvim ubuntu -l tests/e2e/project-session.test.lua
docker compose -f tests/containers/compose.yaml -f tests/containers/limits.yaml run --rm --no-deps --pull never --entrypoint nvim ubuntu -l tests/e2e/session-legacy.test.lua
docker compose -f tests/containers/compose.yaml -f tests/containers/limits.yaml run --rm --no-deps --pull never --entrypoint nvim ubuntu -l tests/e2e/output-resize.test.lua
```

2026-11-11 (§170): под этими лимитами прошли31 native editor checks/25 profiles
и7 Python CLI contract vectors. Это session/legacy5, focus/DAP/Output/language
targeted regression22, Debug toggle2, startup visibility1 и resize1; полный
language/full suite здесь не заявляется. Все editor roots exit/signal0,
APIerrors[], own scopes empty;4 оставшиеся собственные child groups потребовали
graceful SIGTERM при scope cleanup, не «все потомки вышли сами». Windows native
assert observer на Linux даёт отдельный ожидаемый SKIP. Quick358 и trace11
прошли на обеих ОС. Mac/GUI и исходный Docker caller IDE-087 остаются открытыми.

```sh
docker compose -f tests/containers/compose.yaml run --build --rm ubuntu quick
docker compose -f tests/containers/compose.yaml run --build --rm ubuntu e2e
docker compose -f tests/containers/compose.yaml run --build --rm ubuntu full
```

Первая команда соберёт образ, последующие используют кэш. Образ:
Ubuntu 24.04 (digest зафиксирован), Neovim 0.12.2 (SHA256 официального
архива проверяется), Python 3 и исходники плагинов по lazy-lock.json. Пакеты apt
пока берутся из репозиториев Ubuntu на момент build; точные версии есть
в build-логе, полный snapshot apt — отдельное улучшение воспроизводимости.
Сборка образа использует сеть; сами тесты запускаются без сети. Чекаут
монтируется read-only, результат доступен на хосте в **`.tests/ubuntu/`**,
отдельно от Windows `.tests/report.json`. Контейнер работает пользователем
`forge`, не root: проверки прав доступа должны сохранять смысл.
Этот mount проверяется на Windows/Docker Desktop; на нативном Linux для
bind-mount нужно согласовать UID/права, либо выполнять `scripts/test.sh` нативно.

Контейнерный full прогоняет доступный консольный регресс. GUI WezTerm,
desktop clipboard и физическая доставка клавиш отмечаются отдельно как
непроверенные. Для них нужен нативный desktop/VM. Отсутствующий WezTerm
даёт SKIP соответствующих наборов; это не подтверждение GUI-сценариев.

Владелец готовит/запускает нужную машину/VM и выполняет команды в ней.
Репозиторий содержит один runner, две тонкие системные обёртки и одинаковые
сценарии. Выбор гипервизора и управление хостом не входят в test runner.

| Прогон | Windows, PowerShell | macOS / Ubuntu |
|---|---|---|
| Короткий | `pwsh -NoProfile -File scripts/test.ps1 quick` | `bash scripts/test.sh quick` |
| E2E | `pwsh -NoProfile -File scripts/test.ps1 e2e` | `bash scripts/test.sh e2e` |
| Полный доступный регресс | `pwsh -NoProfile -File scripts/test.ps1 full` | `bash scripts/test.sh full` |

В Windows допустим `powershell -NoProfile -File ...`, если pwsh отсутствует.
Для Windows один раз явно подготовить SDK с исправлением IDE-027:

```powershell
powershell -NoProfile -File scripts/prepare-windows-sdk.ps1 -Download
```

На builder нужны Git, CMake/Ninja и MSVC C++ Build Tools; обычному запуску
компилятор/сеть не нужны. `scripts/test.ps1` и `nvim_forge.cmd` используют
один проверяемый runtime `.tools/neovim/windows-x64`, официальный POSIX
SDK остаётся без изменений. Прямой `nvim -l ...` на Windows использует
системный SDK, где native bug ещё воспроизводится; для focused проверок
используй `& .tools/neovim/windows-x64/bin/nvim.exe -l ...`.
Подготовка/lock/patch/A-B/override:
[tests/diagnostics/README.md](../diagnostics/README.md).
Команды — из корня чекаута. Прямой одинаковый entrypoint на всех ОС:
`nvim -l tests/run.lua e2e`. Аргументы/фильтр существующего runner остаются
доступны через `nvim -l tests/run.lua ...`.

Перед первым нативным `e2e`/`full` отдельно подготовить плагины:

```powershell
python -B tests/e2e/prepare_editor.py --download
python -B tests/e2e/prepare_fzf.py
```

На Mac/Ubuntu использовать `python3`. Подготовка сначала читает git-объекты
из локального lazy-кэша, затем с явным `--download` скачивает недостающие
ревизии. Без этого флага сеть не используется. Источник ревизий —
`nvim_forge/lazy-lock.json`, адреса репозиториев — `plugin-sources.json`.
Исходный кэш не меняется. Подготовку повторять после изменения lock-файла;
отсутствие/расхождение зависимостей даёт FAIL, а не SKIP. Можно задать
`--cache <lazy-directory>` и `--output <directory>`; тест читает альтернативный
output через `FORGE_E2E_DEPS`. Docker выполняет подготовку при build.

Вторая команда явно собирает pinned fzf-native через upstream CMake и C
toolchain; native E2E требует этот artifact. Сборка идёт в `.tests/tmp`,
в SDK копируется только DLL/SO, SHA256/commit записываются в общий manifest.
Для другого SDK: `--editor-deps <directory>`. Обычному редактору компилятор
не нужен: [native/fallback поиск](../../docs/SEARCH.md).

Подготовка также вызывает общий локальный Lua applier временного Neogit
backport IDE-034/043; требуется Neovim (`--nvim <absolute-path>` выбирает binary).
Manifest содержит базовый pin и SHA256 результата, editor/ConPTY harness
проверяют реальный payload до запуска и не исправляют его. После добавления
или изменения backport подготовку повторить даже при прежнем lazy-lock.
Для установленного Forge отдельно выполнить `:Lazy build neogit` и перезапустить
редактор. Подробности и обратимость — [patches/README.md](../../nvim_forge/patches/README.md).
IDE-043 добавляет util companion при прежнем lock: повторить prepare_editor.py
и build Neogit. Manifest сравнивается целиком, включая оба hashes. На Linux
контейнерная подготовка выполняется явным build образа; тестовый запуск без сети.

Быстрый запуск только редактора: `nvim -l tests/e2e/editor.test.lua`.

Для DAP перед первым нативным `e2e`/`full` также подготовить совместимые
Go/Delve отдельно:

```powershell
python -B tests/e2e/prepare_dap.py --download
nvim -l tests/e2e/dap-output.test.lua
```

На Mac/Ubuntu — `python3`. Скрипт ставит Go 1.26.0 (официальный SHA256 из
[go.dev/dl](https://go.dev/dl/)) и Delve 1.26.3 в `.tests/dap-tools`,
проверяет версии, не меняет системный PATH или установленный Go. Нужная
директория добавляется в PATH только дочернего тестового редактора.
Можно использовать `FORGE_E2E_DAP_TOOLS=<directory>` либо уже совместимые
Go/Delve в PATH. Delve 1.26 требует Go >= 1.24: сочетание системного Go 1.23
и нового Delve даёт понятный FAIL, а не вечное ожидание breakpoint.
При подготовке Delve проверка Go-модулей включена для этого subprocess;
пользовательские GOENV/GOSUMDB не изменяются. На Mac инструменты отладки
могут требовать локальной подготовки Xcode/подписи — Mac ещё не проверен.
Docker уже включает эти версии при build; тестовый runtime остаётся без сети.

DAP-сценарии используют настоящие F5/F9, launch.json и stdlib Go-проект:
первый/повторный запуск, stdout/stderr до паузы и после выхода, раннее сообщение
адаптера о сборке, Go remote + integratedTerminal, скрытие панелей и panic.
Ожидание второго breakpoint синхронизируется файлом-сигналом реального процесса.
Наблюдатели записывают настоящие DAP events; результат проверяется в видимом
REPL. Артефакты дополнены `dap-events.json`, `dap.log` и `tool-versions.txt`.
Это Go/Delve E2E; Python/debugpy, Rust/codelldb и физические клавиши остаются
отдельными проверками. Шесть unit дополнительно проверяют поздние ответы
exceptionInfo после continue, смены сессии/паузы и отсутствие capability.

Go/neotest требует ещё C compiler (clang/gcc; Windows clang также требует
линкер/SDK) и явную подготовку после двух preparer выше:

```powershell
python -B tests/e2e/prepare_tests.py --download
nvim -l tests/e2e/test-runner.test.lua
```

На Mac/Ubuntu — `python3`. Скрипт собирает Go parser из ревизии каталога
pinned Treesitter, проверяет его загрузку в текущем Neovim, ставит gotestsum
v1.13.0 с проверкой Go-модулей. Результат — `.tests/test-deps` либо `--output`,
тест читает его через `FORGE_E2E_TEST_DEPS`. Компилятор — PATH/CC/`--cc`.
Подготовленный Go SDK берётся из `.tests/dap-tools`/`FORGE_E2E_DAP_TOOLS`,
иначе из PATH. Runtime тестов не скачивает инструменты. Docker включает всё
при build; после изменения preparer/lock пересобрать с `--build`.

Go LSP/format E2E также требует явной подготовки (после Go SDK):

```powershell
python -B tests/e2e/prepare_lsp.py --download
# Повтор без сети/установок проверяет metadata/SHA готовых binaries:
python -B tests/e2e/prepare_lsp.py
nvim -l tests/e2e/go-language.test.lua
```

На Windows используй подготовленный SDK, как указано выше; Mac/Ubuntu — python3.
Фиксированы gopls v0.23.0 и gofumpt v0.9.2, сборка Go 1.26.0 с -p 2,
GOTOOLCHAIN=local/GOENV=off. Module metadata и SHA — .tests/lsp-deps/manifest.json;
server и formatter находятся в отдельных bin/format-bin для проверки fallback.
Все Windows temp/build — на диске checkout. Альтернативный --output читается
через FORGE_E2E_LSP_DEPS. Dockerfile готовит те же инструменты при явном build;
runtime tests работают offline. Desktop/WSL runner не запускает.

Пять сценариев используют реальный neotest, Go parser, gotestsum и Delve:
nearest без запуска соседа, падающий nearest → весь файл → pass/fail/output
→ сохранение кода, eval без сессии, Esc/q из float и из кода, debug nearest
с breakpoint/eval 42/continue. Проект расположен в пути с пробелами. JSON
результатов runner идёт через файл, а не терминальный PTY, одинаково на ОС.
Debug DAP у upstream даёт skipped в neotest; реальный PASS проверяется в REPL.
Артефакты включают `test-results.json`, `neotest.log`, `neotest-golang.log`.
Известные WARN об отсутствующих инструментах сохраняются в snapshot; ERROR
при открытии Go-файла проваливает сценарий. Доставка клавиш через WezTerm
и Mac/Python/Rust остаются отдельным долгом.

Completion/snippet: `nvim -l tests/e2e/snippet-input.test.lua` или общий runner
с `--id IDE-SNIP-1`. Новых бинарников/подготовки нет: штатный VSCode loader
читает fixture .code-snippets, реальный cmp_luasnip показывает меню, Ctrl+j
и Enter принимают snippet. Дальше ввод идёт только клавишами. 11 сценариев:
нетронутые/заполненные параметры, Tab/Shift-Tab, Esc, passive/Unicode,
текст равен default, undo/redo, удаление нескольких диапазонов/разделителей,
многострочный вызов, два буфера с фоновой правкой, сложный блок.
Фоновая правка скрытого буфера выполняется публичным Neovim buffer API;
наблюдение не заменяет LuaSnip/cmp. Проверяется общий snippet engine,
не качество completion-ответов gopls/других LSP и не доставка клавиш WezTerm.

Обнаружение codelldb: `nvim -l tests/e2e/dap-discovery.test.lua` или общий runner
с `--id IDE-DAP-4`. Три negative E2E: Go/open/breakpoint, F9 в .txt и F5
с настоящей launch.json → повтор → сохранение файла. PATH дочернего процесса
не включает каталоги с codelldb, private LOCALAPPDATA/Mason пусты; отсутствие
binary и доступность Git проверяются явно. Если codelldb делит обязательный
PATH-каталог с Git/другими tools, нужен подготовленный профиль/гость без него.
Подмены DAP или фиктивного debugger нет; штатная установленная копия на хосте
не меняется. Positive Rust/C/C++ debugging по-прежнему требует своих E2E.

Run & Debug panels: `nvim -l tests/e2e/debug-panels.test.lua`, фильтры
`--id IDE-PANEL-1/2` в общем runner. Четыре сценария: прежний alias и скрытие
всей sidebar-группы без сессии; реальный Delve breakpoint/struct Value=42,
Enter и русское wd; help/Esc/направления; Output zoom/restore/REPL ввод/q/
восстановление и внешнее закрытие source; затем явный F5 и итоговый stdout.
Проверяется та же session/thread/frame на всех UI-переходах. RPC ru/en ввод
не доказывает физическую раскладку/доставку WezTerm; Mac и PTY других
адаптеров остаются отдельным долгом.

Рабочие панели: `nvim -l tests/e2e/work-panels.test.lua` либо фильтр
`--id IDE-PANEL-6/7/8`. Шесть сценариев проверяют общий Space w t/r/f/b,
focus/help/Esc/hide/zoom, Go summary и реальный PASS/output, два process jobs
и вывод выбранной beta, сохранение query/buffer и реальный rg переход из zoom.
Jobs ждут release marker; проверяется тот же id, без повторного запуска.
Для асинхронного Search ожидается when_ready, для Summary — discovery и render.
Legacy query RED конечным source на config fe64757 — 43617957022000; по 6 новых
и 19 релевантных прежних UI PASS Windows/Ubuntu. Source/snapshot/shutdown и
markers сохранены; команды и пределы — AGENT_COMMANDS §40, FIXLOG §109.
Это целевой набор, не полный PASS с известными IDE-047/048. Mac/GUI и
terminal/Trouble требуют отдельных проверок.

Outline: `nvim -l tests/e2e/outline.test.lua` или
`nvim -l tests/run.lua e2e --id IDE-PANEL-3`. Шесть сценариев используют
настоящий Aerial и встроенный в Neovim Lua Treesitter parser: старые aliases
и замена Explorer в одном left-слоте; h/l и Enter без autojump; фокус/помощь/
zoom/Enter/q/Esc с сохранением геометрии; смена файла и отсутствие backend;
быстрые переключения Explorer/Outline; q после штатного AerialOpen.
Фикстуры — `fixtures/outline/`; отдельные LSP/парсеры не скачиваются.
Проверяется отсутствие ERROR, установок и DAP-сессии. Это не проверка
documentSymbol каждого LSP: остальные языки проходят свой этап матрицы.
Red прежнего обхода менеджера — `.tests/windows-outline-baseline-replay.txt`,
источник `.tests/baselines/outline-before`, воспроизведение через
`FORGE_E2E_CONFIG_SOURCE`. Первый пробный прогон теста создавал лишний split
через Space w 0 на dashboard; setup исправлен на обычный `:edit`, продукт
ради этого не менялся. Пустая панель ожидается до завершения render/backend,
а не проверяется немедленно после открытия. Mac/GUI не проверены.

Полный Windows регресс затем поймал Neo-tree follow ERROR (Invalid win),
`.tests/windows-outline-regression.txt`, artifact `3730754149400`. Отдельный
replay до lifecycle-исправления — `.tests/windows-outline-lifecycle-replay.txt`:
наблюдатель after_open читает, есть ли окно у tree.bufnr. Это не подмена
backend и не вызов таймера. Он фиксирует опасную фазу детерминированно:
`closed-tree-refs.json` с tree_buf/visible_buf; при исправлении список пуст.
12 быстрых циклов дополнительно проверяют реальные отложенные события.
Нагрузочный параллельный запуск также сохранил позднее открытие Explorer
(artifact `4156763449400`): после интеграции after_render слот снова согласован.
ERROR не принимается как ожидаемый prompt. Финальные полные логи:
`.tests/windows-outline-final-regression.txt`, `.tests/ubuntu-outline-final-full.txt`.

Дерево файлов: `nvim -l tests/e2e/file-explorer.test.lua` или
`nvim -l tests/run.lua e2e --id IDE-FILE` / `--id IDE-PANEL-4`.
Семь сценариев используют настоящие Neo-tree/Nui и private project на диске:
создание каталога/файла с пробелами и Unicode и запись через редактор;
rename открытого файла/каталога с дочерним буфером; m с полным путём и записью
по новому адресу; x/p в выбранный каталог и отмена занятого пути;
отмена a/r/m и конфликт rename; source selector/Space w e/help/Esc/q;
zoom Enter и rename именно выбранной строки с сохранением исходных окон.
Диалоги открываются клавишами; fs_actions/vim.ui.input и файловые callback
не подменяются. Сохранённые буферы могут получить новый id — проверяются
путь/содержимое/возможность редактирования. Во всех сценариях проверяются
ERROR, установки и DAP-сессия. Только известный WARN конфликта rename может
быть принят как hit-enter с сохранением экрана.

Ожидания UI: настоящий renderer _ready и видимый элемент. '/' у Neo-tree —
fuzzy finder, поэтому locator читает строки и вводит normal G, повторно
находя элемент после Git/render. Литерал '<' передаётся nvim_input как <lt>.
Эти уточнения исправляют транспорт теста, не поведение редактора.
При смене источников наблюдатель читает публичный ide.current() на реальном
after_open: чтение в промежутке без окна не должно терять выбор backend.
Вариант до requested-state воспроизводит сбой Files → Buffers.

Red Move — `.tests/windows-files-move-replay.txt`, исходник
`.tests/baselines/files-before`; red source-state — windows-files-source-red.txt,
config-source artifact `5700386164500`; red zoom — windows-files-zoom-replay.txt,
config-source artifact `5534595085400`. Дубликат старого пути/ENOENT после
rename сохранён в windows-files-controls-first.txt и artifact `5358716713000`
(точный каталог указан строкой artifacts в логе). Финальные полные логи —
windows-files-complete-regression.txt и ubuntu-files-complete-recheck-full.txt в `.tests/`.
Прежние `*-files-final-*` содержат найденный позднее Esc FAIL (§82): runtime
содержал <esc> и <Esc> одновременно. Исправление проверяется одним каноническим
Esc в runtime mappings и пятью циклами help → дерево → код. Red точного
конфликта — windows-files-esc-replay.txt, источник config-source `5949438588300`.
Диагностические wrappers cancel удалены; постоянные тесты действия не подменяют.
В ubuntu-files-complete-full.txt все editor E2E прошли, но unit key-ownership
получил 30s timeout дочернего nvim_keymaps (код 124). Причина не установлена;
полный параллельный Windows прогон тоже был медленнее обычного. Отдельная
проверка — ubuntu-files-key-ownership-recheck.txt, 46 PASS. Полный Ubuntu
recheck выполнен отдельно после завершения Windows, таймауты не увеличивались.
Mac/GUI, несохранённые буферы, отдельные copy/delete/trash, case-only rename,
cross-volume/network FS и LSP file-operation матрица пока не проверены.

На Mac для отдельной проверки дерева из корня репо:

```sh
python3 tests/e2e/prepare_editor.py --download
nvim -l tests/e2e/file-explorer.test.lua
```

Первая команда — явная подготовка закреплённых плагинов. Если они уже
подготовлены для актуального lock, достаточно второй. Go SDK/парсеры/LSP для
этих текстовых файлов не нужны. Общая команда гостя остаётся scripts/test.sh e2e.

Файловые вкладки: `nvim -l tests/e2e/buffers.test.lua`, отдельно
`nvim -l tests/run.lua e2e --id IDE-BUF`. Восемь сценариев с настоящими
BufferLine/Telescope/Neo-tree/auto-save/native confirm: цикл и badd/unloaded/
readonly при реальном terminal; picker из дерева с terminal, файловый фильтр
и сохранение окон; закрытие saved файла во всех split и из панели; Cancel
последнего/непоследнего файла; Save/Discard через F4/Alt-w; alpha/reopen с
курсором; отказ Save unnamed и последующая запись после назначения имени.
Cancel удерживает confirm 750 ms (дольше autosave debounce), проверяя диск;
после отмены новое редактирование должно снова сохраниться обычным autosave.

Диалог не подменяется. Его mode=r? при blocking=false: ожидания идут через
fast get_mode/nvim_input. editor.lua запрещает Lua RPC за confirm. Из terminal
используется штатный F7; обнаруженный перехват Ctrl-\ зарегистрирован как
IDE-023 и исправлен отдельно в §171 (см. terminal-escape ниже).
Начальная попытка считывала курсор
сразу после nvim_input — теперь ожидается фактический переход. Telescope
entry_maker использует штатный formatter с явным bufnr_width.

Red закрытия — windows-buffers-cancel-replay.txt с
FORGE_E2E_CONFIG_SOURCE=.tests/baselines/buffers-before. В artifact
1534125656600/project/file_one.txt уже есть UNSAVED_ после скрытия окна:
BufLeave успел вызвать auto-save до confirm. Положительные focused логи —
windows-buffers-third.txt и ubuntu-buffers-first.txt (8 PASS на каждой ОС).
Окончательный replay IDE-BUF-1 — windows-buffers-navigation-replay.txt:
2 FAIL, в цикле выбран terminal вместо file_one, picker включает terminal.
Полные результаты — windows-buffers-full.txt и ubuntu-buffers-full.txt.
Mac/GUI/физические модификаторы и persistent session reopen не проверены;
Save As dialog не добавлен, raw :bdelete/внешние plugin close не входят
в стек Space b r. Для Mac после подготовки плагинов достаточно
`nvim -l tests/e2e/buffers.test.lua`.

### Native terminal escape — IDE-PANEL-16 / IDE-023

`nvim -l tests/e2e/terminal-escape.test.lua` либо
`nvim -l tests/run.lua e2e --id IDE-PANEL-16` — шесть настоящих editor cases:
completed native command, interactive Python PTY до/после загрузки ToggleTerm,
managed shell, cold/loaded normal aliases и paused Rust/CodeLLDB PTY.
Проверяются literal input, repeated Ctrl-\ Ctrl-n, mode/window/buffer/channel/PID,
история, DAP thread/frame и stdout после явного Continue; Esc Esc/F7 сохранены.
Private F35 no-op подтверждает обработку async input и сам не меняет mode/focus.
Закрытая команда проверяется по actual TermClose status0, не по сообщению UI.

Нужны подготовленные editor plugins, Python 3 и Rust/CodeLLDB dependencies
(см. [подготовку Rust](#rust-подготовка-и-cargo-workspace)); тест ничего не скачивает. Windows использует выбранный
SDK, Linux/macOS — официальный Neovim. Прямые команды из корня checkout:

```powershell
$env:TEMP="$PWD/.tests/tmp"
$env:TMP=$env:TEMP; $env:TMPDIR=$env:TEMP
$env:NVIM_LOG_FILE="$env:TEMP/terminal-escape.log"
& ./.tools/neovim/windows-x64/bin/nvim.exe -l tests/e2e/terminal-escape.test.lua
docker compose -f tests/containers/compose.yaml -f tests/containers/limits.yaml run --rm --no-deps --pull never --entrypoint nvim ubuntu -l tests/e2e/terminal-escape.test.lua
```

Docker engine и image должны быть готовы заранее; команды не поднимают Desktop
и не делают build/pull. Запускать поочерёдно. На Mac после подготовки:
`nvim -l tests/e2e/terminal-escape.test.lua`. Source replay использует существующий
`FORGE_E2E_CONFIG_SOURCE` с совпадающим lock:6dea7b8 дал5 native RED и1 alias
control PASS на обеих ОС, исправленный config —6 PASS. Ещё22 buffer/focus/Debug
regression на каждой ОС PASS (§171). Mac/физические клавиши WezTerm не проверены.

### Terminal/Trouble — IDE-PANEL-17

`nvim -l tests/e2e/tool-panels.test.lua` либо
`nvim -l tests/run.lua e2e --id IDE-PANEL-17`:9 editor E2E Windows/Ubuntu.
Space w T/x cold/repeated focus, пустые Problems; literal terminal input,
help/zoom/Esc/hide с тем же PID/channel/history; hide текущего из двух windows;
real gopls diagnostics и выбор другой строки в zoom; native Quickfix jump,
два Trouble views, folds и native help; old aliases; IDE-099/100 source regressions.
Public Quickfix заполняется fixture-данными с существующими файлами/строками,
gopls действительно выдаёт два разных diagnostics. Backend actions не подменяются.

Нужны общие pinned editor plugins и явная подготовка Go/gopls через
prepare_dap.py / prepare_lsp.py (см. Go workflow). Тест сам ничего не скачивает.
Windows запускает выбранный SDK; Ubuntu/Mac — официальный Neovim:

```powershell
$env:TEMP="$PWD/.tests/tmp"
$env:TMP=$env:TEMP; $env:TMPDIR=$env:TEMP
$env:NVIM_LOG_FILE="$env:TEMP/tool-panels.log"
& ./.tools/neovim/windows-x64/bin/nvim.exe -l tests/e2e/tool-panels.test.lua
docker compose -f tests/containers/compose.yaml -f tests/containers/limits.yaml run --rm --no-deps --pull never --entrypoint nvim ubuntu -l tests/e2e/tool-panels.test.lua
```

Engine/image уже должны работать; запускать поочерёдно. На подготовленном Mac:
`nvim -l tests/e2e/tool-panels.test.lua`. `FORGE_TOOL_PANEL_CASE` выбирает случай
по подстроке (например `gopls`); без фильтра обязательны все9. Для source replay
используется FORGE_E2E_CONFIG_SOURCE с archive b949919 и тем же lock:8 ожидаемых
отказов/1 legacy control PASS на ОС, fixed9 PASS. Два отдельных существовавших
бага воспроизводятся без новых shortcuts: :IdeShow terminal после Ctrl-t
скрывает окно (IDE-099), native Trouble help dock-ится как панель (IDE-100).
Native help проверяется в popup ещё300ms после отображения, чтобы не принять
первый кадр до docking за PASS. Mac/GUI не проверены; полная матрица управления
именами/порядком терминалов и LSP Trouble modes остаётся отдельной работой.
Соседний регресс: terminal-escape6/work-panels6/debug-panels4/outline6/buffers8,
по30 PASS на Windows/Ubuntu. Всего по39 checks/31 native profiles; root0,
APIerrors[], собственные scopes пусты (§172).

Go E2E разделяют compiler cache одного прогона в native temp через
`FORGE_E2E_GO_CACHE`; прямой Lua-файл получает отдельный temp cache.
Windows/Docker bind mount для runtime cache не используется. Source/flags
проверяет сам Go; результат go test не подменяется. Холодная сборка может показать штатный
adapter-slow WARN; он сохраняется в артефактах, hit-enter снимается, тест ждёт
настоящий breakpoint с deadline. ERROR не игнорируется.
`ack_warning` принимает только точный разрешённый caller-ом WARN; другие
сообщения и ERROR не снимаются автоматически.

Сейчас `quick` = unit; `e2e` = реализованные end-to-end сценарии; `full` =
unit + e2e + WezTerm + установщики + trace, на Windows ещё ConPTY. Полный
прогон установщиков использует песочницы; реальную установку в личный HOME
ради теста не выполняет. `full` не означает, что пробелы покрытия устранены.

Подготовка гостя отдельно: git, Neovim 0.12+, Python 3; WezTerm и GUI для
его сценариев; Bash и зависимости fixture-наборов установщиков (см.
основной tests/README.md). Для будущих языковых e2e — инструменты из
зафиксированного каталога. Пакеты не скачиваются из startup/prompt/test runner.
Снимок чистого гостя используем для install/upgrade-сценариев, отдельный
подготовленный снимок — для быстрого регресса IDE. Пользовательские проекты,
профили и реальные remote Git в фикстурах не используются.

После прогона сохранять **всю `.tests/`** отдельно по среде/commit: report.json,
logs и sandbox. Перед следующим запуском скопировать каталог в артефакты VM,
поскольку runner обновляет отчёт. Сведения о точном дистрибутиве/версии гостя,
GUI X11/Wayland, раскладке и версии тулчейнов пока прикладываются к результату
вручную; расширение метаданных runner — задача каркаса.

Артефакты редактора: `.tests/editor-e2e/<run>/` (в Docker —
`.tests/ubuntu/editor-e2e/<run>/`): сообщения, notifications, дочерние процессы,
буферы/окна, stderr, текст remote UI, проект после действий, копия конфига и
manifest ревизий. При сбое сохраняется отдельный snapshot с именем сценария.
`notifications.json` получает настоящий vim.notify через RPC push даже за
error/hit-enter prompt; наблюдатель сохраняет штатное отображение сообщений.
Обычно source — текущий nvim_forge. Для явного red replay допускается
`FORGE_E2E_CONFIG_SOURCE=<config-source>` с тем же lock; config-origin.txt
записывает выбор. В Docker snapshot должен быть в `.tests/ubuntu/`, потому
что контейнерный `.tests` перекрыт отдельным mount.
Большой runtime с плагинами на Windows живёт в `.tests/tmp` на диске checkout
(здесь F:). На POSIX используется native temp гостя, чтобы избежать задержки
Windows/Docker bind mount. `FORGE_TEST_TMPDIR` задаёт абсолютный override.
`scripts/test.ps1` направляет TEMP/TMP/TMPDIR и лог runner туда же только на
время запуска; для прямого Windows `nvim` задать это окружение заранее.
После сохранения артефактов child завершается и созданный профиль удаляется,
в том числе после ошибки подготовки. Проверяются realpath и JSON-маркер
владения; несовпадение запрещает удаление. Временный file lock ожидается до
5 секунд, маркер удаляется последним. При ошибке копирования артефактов
профиль сохраняется с явным диагностическим путём.

Windows Go cache один: `.tests/tmp/go-build-cache`, runner и focused наборы
переиспользуют его. `FORGE_E2E_GO_CACHE` позволяет абсолютный override.
В контейнере cache остаётся на native FS гостя. Старые тестовые данные C:
перенесены вне checkout в `F:/forge-nvim-tmp/`; подробности и ограничения
автопроверки — FIXLOG §90 и AGENT_COMMANDS §24. Пользовательские
data/state/config не используются. Нативные исполняемые инструменты берутся
из PATH; состав PATH не считается зафиксированным языковым окружением.

RPC-клиент подключает настоящий Neovim UI, получает redraw и запускает
`UIEnter`/`VeryLazy`. Одного `--headless` без UI для этого недостаточно.
Ввод идёт через публичный `nvim_input`, результат читается через API редактора;
плагины не подменяются. Ожидания проверяют готовность окна, insert mode,
файла в асинхронном дереве или результата поиска. Отдельное окно наблюдения
после VeryLazy перекрывает прежний 3-секундный таймер Mason.

## Границы настоящего e2e

- CLI: настоящий entrypoint отдельным процессом, аргументы, cwd/env, stdout,
  stderr, exit code и изменения файлов.
- IDE: настоящий Neovim с нашей сборкой и проектом-фикстурой, пользовательские
  команды/ввод, проверка результата и окон. Отладчик/runner/LSP реальные там,
  где проверяется их интеграция. Вызов приватной Lua-функции с mock DAP — unit.
- TUI: PTY (POSIX) или ConPTY (Windows), отправка ввода, ожидание состояния
  по условию с deadline. Снимок экрана — вспомогательное доказательство.
- Терминал/desktop: настоящий WezTerm и GUI гостя для доставки модификаторов,
  clipboard, фокуса и раскладок. RPC `nvim_input` не доказывает, что Cmd+C
  или Ctrl+Shift+F прошли через WezTerm и системный стек ввода.

Сценарии и assertions общие. Системные различия находятся в backend ввода,
shell/process/clipboard и подготовке VM. Крупные sleep, перезапуск до зелёного
и автоматическое обновление expected-результата не считаются исправлением.

## Контракт сценария и завершения работы

1. Стабильный ID фичи/бага, Given/When/Then, фикстура и поддерживаемые среды.
2. Для бага — исходное воспроизведение и красный результат на прежнем коде
   либо сохранённые доказательства исходного сбоя на целевой машине.
3. Исправление/фича и e2e в одном change; дополняющие unit по необходимости.
4. PASS на целевых средах с commit/версией/логами. SKIP, MANUAL и отсутствие
   реализации — незакрытое покрытие. Если прогон ждёт владельца VM, так и пишем.
5. Не затронутые ОС проверяются общим регрессом; платформенный сценарий
   отдельно запускается в применимых средах. Платформенная неприменимость
   описывается явно, а не превращается в PASS.

До реализации автоматического coverage gate таблица ниже — явный список
долга, а review change проверяет наличие e2e. Автоматический gate, сбор
артефактов и PTY/GUI-backends — следующие задачи каркаса, ещё не реализованы.
Путь к `cs2d` запрошен; его конкретный подход пока не изучен.

## Матрица исходных проблем

| ID / область | Обязательный сценарий | Текущее e2e-покрытие |
|---|---|---|
| IDE-001, исходная задержка | zsh в новой вкладке, Enter/clear внутри и вне Go-проекта; без загрузок SDK | Нет, нужны данные и прогон Mac |
| Диагностический CLI IDE-001 | Запуск на временном HOME, report/exit code, отсутствие исполнения/записи | Реализован: `shell-diagnostics.test.lua`, Windows и Ubuntu PASS; Mac ждёт прогона |
| Команды тестов | quick/e2e → правильный suite argv; неверный режим → ошибка | Реализован: `entrypoints.test.lua`, проверяет реальный entrypoint и дочерний CLI stub |
| IDE-002, clipboard | Реальное выделение WezTerm/Visual/copy mode → copy → clipboard, пустое выделение | GUI-сценарий не реализован; unit не закрывают баг |
| IDE-003, debug output | Первый/повторный запуск → stdout/stderr видны; Go remote + integratedTerminal | `dap-output.test.lua`: Go/Delve Windows/Ubuntu PASS; исходный конфиг владельца и остальные адаптеры ещё сверить |
| IDE-004, panic | Panic → stop event → текст в Output на паузе, сохранён после выхода | `dap-output.test.lua`: Go/Delve Windows/Ubuntu PASS; Mac/Python/Rust не проверены |
| IDE-005, фокус | Код → Locals → Output → код; paused-сессия сохраняется | `debug-panels.test.lua`: Windows/Ubuntu PASS; Mac/GUI открыты |
| IDE-006, ближайший тест | nearest/failing/file, результат/output; debug breakpoint/eval/continue, Esc/q | `test-runner.test.lua`: 5 Go E2E Windows/Ubuntu PASS; Mac/Python/Rust открыты; debug skipped в панели, итог в REPL |
| Go language и IDE-FMT-1/IDE-050 | Настоящие gopls definition/references/rename/cmp/diagnostics, внешний/LSP format/save/health, cleanup без tools | `go-language.test.lua`: 6 UI PASS Windows; Ubuntu build/E2E ожидают engine, Mac/прочие языки не проверены |
| IDE-007, snippet | Completion → ручной ввод вне поля → хвост отменён, текст сохранён | `snippet-input.test.lua`: 11 cmp/LuaSnip E2E Windows/Ubuntu PASS; Mac/ответы реальных LSP открыты |
| IDE-HL-1, подсветка | Сверхдлинное слово → редактирование/запись → обычные ссылки; большой файл/строка | `reference-highlighting.test.lua`: 3 UI E2E Windows/Ubuntu PASS, Unicode boundary и Alt+n/p; Mac/GUI открыты |
| IDE-012, codelldb discovery | Go/F9 без чужого WARN; F5 без binary → понятное сообщение, повтор, редактирование | `dap-discovery.test.lua`: 3 negative E2E Windows/Ubuntu PASS; Mac и positive Rust/C/C++ DAP открыты |
| IDE-005/009 и IDE-014, Debug панели | Space w, real paused Locals/Output, q/Esc/help/zoom, внешний close, сохранность сессии/вывода | `debug-panels.test.lua`: 4 E2E Windows/Ubuntu PASS; Mac/GUI и остальные панели открыты |
| IDE-008, Outline и IDE-015 | Открыть слева → найти/раскрыть символ → перейти в код → вернуться; Explorer/файлы/zoom и pending callbacks | `outline.test.lua`: 6 real Aerial E2E Windows/Ubuntu PASS; Mac/GUI и остальные языковые backend открыты |
| IDE-009/049, панели | Общий focus/hide/help/zoom, Go summary/output, running task и query/selected search result | `work-panels.test.lua`: 6 UI E2E Windows/Ubuntu PASS; ранее Debug/Outline/Neo-tree/Neogit; Mac/GUI и terminal/Trouble открыты |
| Базовое ядро редактора | Запуск, открыть/изменить/сохранить, дерево, имя/содержимое, буферы, фокус | `editor.test.lua`: Windows и Ubuntu PASS; Mac ждёт прогона |
| IDE-BOOT-1/2 | Старт без установки инструментов, отсутствие предупреждения Go в .txt | `editor.test.lua`: Windows и Ubuntu PASS; Mac ждёт прогона; наличие gopls в Windows не фиксируется, отсутствие подтверждено в Ubuntu |
| IDE-016–019, управление файлами | Создать/переименовать/переместить, cut/paste, отмена/конфликт, сохранённые буферы, общий маршрут/selector/zoom | `file-explorer.test.lua`: 7 real editor E2E; границы и результаты ниже |
| Git/worktree | Локальный bare remote → worktree → изменение → commit/push; hunks/diff/history; rejected/missing remote → retry | `git-workflow.test.lua`: 6 real editor E2E; `git-errors.test.lua`: 3 UI (IDE-GIT-10/12) + parser matrix 10 строк; `git-conflicts.test.lua`: 4 IDE-GIT-11; `diffview-close.test.lua`: 7; `worktree-refresh.test.lua`: 3; `active-worktree.test.lua`: 2 IDE-GIT-7; `gitsigns-worktree.test.lua`: 2 IDE-GIT-8; `gitsigns-live-read.test.lua`: CLI + 3 UI IDE-GIT-9; `plugin-backports.test.lua`: 9, включая настоящий Lazy build/отсутствие записи при открытии Git/файла, обновление предыдущего payload и отказ на неизвестный companion до записи. Sequence3 (IDE-GIT-13) и HTTP credentials2 (IDE-GIT-14) проверены Windows/Ubuntu; real OAuth/SSH/Mac отдельно; IDE-043 исправляет OSC output |
| Тестовый runtime IDE-030 | Реальное завершение редактора, сохранение артефактов, удаление своего профиля и отказ по чужому маркеру | `editor-runtime.test.lua`: 4 сценария, включая ошибку prepare и временный file lock внешнего процесса; `dap-output.test.lua` проверяет фактический go env GOCACHE |
| Shell/jobs | Открыть terminal, job, закрыть/восстановить фокус | Не реализован; смена/закрытие файлов и базовый фокус покрыты ядром |


IDE-GIT-10 (FIXLOG §102): новые 2 и прежние 6 Git E2E прошли Windows/Ubuntu
последовательно. В status `P u`, отказ force — `n`, `$` → строка push → `Tab`
открывает причину; `q` закрывает историю, `Esc` возвращает код. Для retry
fixture явно согласует истории через Git fetch/merge --no-edit либо исправляет
origin; UI merge этим не покрыт. В каждой истории ровно два push, первый
nonzero, второй 0, ни одного --force. Сравниваются refs, index и файлы,
первоначальные local/remote commits сохраняются как ancestors после согласования.
Git stderr независимого CLI используется только как oracle допустимого fatal
этой private fixture. Остальные ERROR и нативные E… не подтверждаются Enter.
INFO с точной первой fatal строкой может содержать весь вывод; его raw текст
сохраняется. Этот raw title tail был зарегистрирован как IDE-043; его текущее
исправление готовится явным Neogit build (см. раздел IDE-GIT-12 ниже).
Отдельно: Mac и физическая GUI доставка клавиш не проверены.

```powershell
. ./scripts/lib/nvim-sdk.ps1
$forgeNvim = Get-ForgeNvim (Get-Location).Path
# Перед прямым Windows запуском TEMP/TMP/TMPDIR и NVIM_LOG_FILE — на F:.
& $forgeNvim -l tests/e2e/git-errors.test.lua
docker compose -f tests/containers/compose.yaml run --rm --entrypoint nvim ubuntu -l tests/e2e/git-errors.test.lua
```

На Mac: `python3 -B tests/e2e/prepare_editor.py --download --nvim "$(command -v nvim)"`,
затем `nvim -l tests/e2e/git-errors.test.lua`. Прогон на Mac требуется отдельно.
| Языки | Для каждого языка LSP/format/run/debug/tests в применимых сочетаниях | Не реализован |

## Матрица VM

| Среда | Общие сценарии | Специальные проверки | Состояние |
|---|---|---|---|
| Windows native | CLI/IDE/languages | ConPTY, clipboard, ru/en, пути/venv | IDE-038: unit/e2e/trace 38 PASS / 0 FAIL / 0 SKIP, 471 проверка. IDE-039: наблюдаемый RU→EN FAIL 65/1; отдельный стабильный EN 66 PASS. Полный full с устойчивым RU не заявлен; IDE-031/039/040 открыты, GUI не проверен |
| macOS | CLI/IDE/languages | zsh startup, Cmd, clipboard, arm64 при наличии | Ждёт VM/машину владельца |
| Ubuntu | CLI/IDE/languages | apt/version check, bash/zsh, X11/Wayland по целевой сессии | IDE-038 full: 41 PASS / 0 FAIL / 3 SKIP, 42 файла/44 прогона, 640 проверок; официальный SDK. ConPTY diagnostic — явный SKIP. GUI не проверен |
| Mint | CLI/IDE/languages | apt/version check, bash/zsh, desktop clipboard | Временно отложен владельцем |

Этот набор дополняет существующие `wezterm`, `install`, `trace`, `conpty`;
их доказательства учитываются по фактической границе проверки, а не просто
переносятся под ярлык e2e.

Предыдущий прогон 2026-11-01, рабочее дерево HEAD `4368fa1` с тогдашними изменениями:
Windows Neovim 0.12.2, Ubuntu 24.04/Neovim 0.12.2. Ubuntu SKIP: реальная
загрузка WezTerm (бинарник отсутствует), две дополнительные ветки установщиков
под Bash 3.2 (интерпретатор отсутствует). Основные sandbox-сценарии
установщиков под Bash 5 прошли. Windows ConPTY в этой сессии не прогонялся.

Git-шаг: Windows `.tests/windows-git-full-recheck.txt` — 29 PASS/0 FAIL/0 SKIP;
Ubuntu `.tests/ubuntu-git-full-recheck.txt` — 31 файл/33 прогона,
30 PASS/0 FAIL/3 SKIP. В обоих полных прогонах Git — 6 PASS. Последнее
уточнение файлового locator дополнительно проверено всем focused набором
Windows (7 PASS) и полным Ubuntu. Первые красные прогоны сохранены:
Windows — единичное завершение child в buffer/terminal (IDE-027, не закрыта),
Ubuntu — гонка ожидания созданного файла (IDE-029, FIXLOG §88).
Между прогонами восстановлен остановившийся Docker Desktop штатным start.

Новые Git-сценарии используют private bare remote и native popup/input/commit
editor. Commit подтверждается ZZ; готовность picker проверяется по insert
mode и введённому фильтру. Path input ждёт отложенный prefix backend, visit
ждёт выбранную ветку в Head. Быстрое закрытие IDE-026 теперь имеет отдельный
регресс `diffview-close.test.lua`; быстрый visit IDE-028 остаётся открытым. Mac остаётся
за владельцем; GUI/доставка физического Ctrl/Cmd не проверяются RPC grid.

Последующий шаг IDE-026/030 (FIXLOG §89–90):
`.tests/windows-diffview-runtime-final.txt` — 30 PASS / 1 FAIL / 0 SKIP;
`.tests/ubuntu-diffview-runtime-final.txt` — 33 файла / 35 прогонов,
32 PASS / 0 FAIL / 3 SKIP. Diffview — 7 PASS и runtime — 4 PASS на обеих ОС.
Windows FAIL — native terminal crash IDE-027, child_exit=3221225477;
он повторился, причина неизвестна, весь Windows-регресс зелёным не считается.
Первый полный запуск после добавления cleanup (28 PASS / 3 FAIL) сохранён
как windows-diffview-runtime-full.txt: отдельно устранены transient lock
при удалении DAP профиля и публикация неполного JSON Git gate.

После последнего уточнения общего Windows Go cache дополнительно пройдены
целиком focused Go/Delve (4), neotest/eval (5), Debug panels (4) и launcher
quick (13 файлов). Ubuntu full использовал окончательный helper/cache код.
Полный Windows отчёт и логи сохранены отдельно как
windows-diffview-runtime-final-report.json и -logs/ до последующего quick.
После Windows тестов — 0 оставшихся private runtime и 0 файлов в старом
C TEMP/nvim.0 (forge-storage-final-audit.json). Старые данные сохранены на F:.
Оба strict change validate, trace и git diff --check прошли; Mac/GUI/ConPTY
не запускались. Windows/Ubuntu прогонялись последовательно.

IDE-028 (FIXLOG §91): три `worktree-refresh.test.lua` e2e на Windows/Ubuntu
проверяют удерживаемый настоящий log → visit и конечные Head/recent/LogView,
файлы/HEAD/index, split/full tab, серию visit без proxy и reopen. После
release ждём фактической доставки captured output (done), сохранённого
refresh task (он может быть отменён Neogit), проверяем интерфейс и ещё
500 ms наблюдаем поздние ошибки. Действия — только native клавиши, private
состояние используется для наблюдения. Обе платформы: финальные 3 PASS,
транскрипты windows-/ubuntu-worktree-refresh-final.txt. Unicode renderer
строит граф из тех же commit, штатные операции/зависимости не менялись.

Полный Windows IDE-028: 32 файла, 30 PASS / 2 FAIL / 0 SKIP
(windows-worktree-refresh-full.txt). Новый Windows launcher с CreateNoWindow
сначала терял stdout; добавлен бинарный pipe pump, весь новый набор прошёл.
Другой FAIL — единичный CLI unknown-mode timeout 10s (IDE-031), причина
неизвестна. Повтор обоих файлов через временный registry — 2 PASS / 0 FAIL,
CLI 0,5s, новый editor набор 3 PASS; файл windows-worktree-refresh-recheck.txt.
Этот повтор не превращает первый full в полностью зелёный. Все 8 buffer
e2e в этом full прошли, IDE-027 остаётся открытым без объяснённой причины.

Полный Ubuntu IDE-028: 34 файла / 36 прогонов — 33 PASS / 0 FAIL / 3 SKIP
(ubuntu-worktree-refresh-full.txt). Прежние Git 6, Diffview close 7 и runtime
4 прошли в обоих full. Перед добавлением final done/quiet наблюдения full
уже проверил основной код; после этого уточнения весь новый набор отдельно
повторён на обеих ОС. Отчёты Windows full/recheck и Ubuntu full сохранены
отдельно; старые FIXLOG байты проверены. Следующая диагностика Windows —
IDE-027/031, затем ошибки push/конфликты. Mac/GUI/ConPTY не проверены.

Уточнение IDE-027/031 (§92–93, HEAD 25dfbab с текущими изменениями):
чистый terminal resize без Forge падает в pty_proc_resize на официальном
Windows Neovim. A/B одного source commit/компилятора: upstream red на
цикле 1, patched SDK 50 циклов green, все исходные 8 buffer E2E green.
Владелец выбрал временный Windows SDK с явной подготовкой; в общем Lua
нет Windows workaround. На Ubuntu официальный 0.12.2 прошёл 50 циклов.

Добавлены постоянные файлы registry: windows-sdk.test.lua (настоящие
launcher/test CLI выбранной ОС и native resize), native-probe.test.lua
(CLI/cleanup/artifacts), entrypoint-diagnostics.test.lua (реальные ошибочный
exit/stdout/stderr, timeout с частичным выводом и spawn error).
Windows launcher проверяется в пути с пробелами и кириллицей, с настоящим
SDK: argv/exit, same-process env restoration, broken/missing/stale manifest,
явный system override, отказ preparer по неверному source/patch до build.
POSIX использует официальный SDK без Windows manifest/build tools.

IDE-045: Lua runner получает список методов через
`python -B tests/windows_sdk_test.py --list-cases TestWindowsSDKCLI`
(на POSIX — TestPOSIXSDKCLI) и запускает каждый метод отдельным Python
процессом. Лимиты прежние: команда CLI 10s, один сценарий 30s, файл registry
60s. Раньше все шесть Windows сценариев делили один 30s; при холодном запуске
это обрывало допустимую команду. Артефакты discovery/каждого сценария —
`.tests/sdk-cases/<run>/`: argv/PID/elapsed/code/stdout/stderr. Это не исправление
неустановленной причины замедления PowerShell. Прямой запуск Python class
по-прежнему поддерживается.

IDE-031: 10 повторов/30 CLI процессов прошли без увеличения прежних 10s.
Артефакты каждой попытки — .tests/entrypoints-e2e. Исходный timeout не
объявлен исправленным; unit/CLI проверка намеренного timeout доказывает
контракт диагностики, а не причину той ошибки. Native ConPTY lifecycle
проверен core probe, доставка физических клавиш/GUI и Mac — отдельный долг.

Windows full выбранным SDK: 38 файлов / 40 прогонов, 37 PASS / 1 FAIL /
2 SKIP (обе дополнительные ветки Bash 3.2); 8 buffer, core probe и SDK CLI
прошли. FAIL — IDE-032: E211/RPC timeout после удаления worktree с открытым
файлом, artifact 20402797082900. Отдельно исходный IDE-GIT-3 прошёл на обоих
SDK; источник блокировки остаётся открытым. Исходный full сохранён целиком,
он не считается зелёным после частичного повтора.

В конце того full обнаружена IDE-033: старый ConPTY reader использовал user
plugins и переписал source lazy-lock. Изменённый lock сохранён, восстановлены
точные прежние байты; после исправления изоляции весь ConPTY набор повторён:
1 файл PASS, 0 FAIL/SKIP, включая реальные private stdpath и выбранный SDK.
Source lock после него не менялся. Это программная проба через conpty.dll,
не GUI/физическая клавиатура. Следующий открытый Git-регресс — IDE-032.

Ubuntu final: 37 файлов/39 прогонов, 36 PASS / 0 FAIL / 3 SKIP
(WezTerm отсутствует, две ветки Bash 3.2). Первый full имел единственный
FAIL нового POSIX launcher CLI из-за CRLF рабочего nvim_forge.sh. Нормализован
сам launcher по существующему .gitattributes, исходный red сохранён как
ubuntu-stability-full-first.txt/report и SDK CLI log. После этого повторён
полный Ubuntu, не только новый файл. Final Windows quick 13/13 и trace 2/2,
strict validate PASS; SDK source/build/temp и runtime на F:, частные профили
после завершения отсутствуют. Mac/GUI отдельно не запускались.

IDE-032 (§95): FileChangedShell deleted сохраняет буфер/текст/modified,
удерживает autosave и снимает watchers исчезнувших файлов. Конкретное Files
warning показывает Fidget без hit-enter; другие native причины остаются ask.
Новый deleted-files.test.lua содержит 5 real editor E2E: 12 loaded файлов
worktree, успешное удаление после visit, hidden pending save/write/repeated
episode, Save As, autoread/native conflict. Готовность signs наблюдается
пока файл видим; общий checktime не проверяет hidden, для него используется
явный номер. Windows focused 5 PASS, Ubuntu focused 5 PASS; старый полный
config-source на том же сценарии даёт E211, artifact 36164862736900.

Windows full: 39 файлов/41 прогон, 38 PASS / 1 FAIL / 2 SKIP (Bash 3.2).
Пять новых и все прежние buffer/Git/worktree/Diffview прошли. Единственный
FAIL — SDK CLI partial unittest ERROR на missing manifest без законченной
сводки во внешнем deadline, причина не установлена (IDE-031). Отдельно весь
SDK файл — 2 PASS; общий full остаётся красным. SDK CLI теперь тоже сохраняет
started/result/PID в .tests/sdk-cli; deadlines не повышались, retry нет.

Ubuntu full: 38 файлов/40 прогонов, 37 PASS / 0 FAIL / 3 SKIP. После
диагностического уточнения helper SDK/CLI contracts отдельно повторены на
обеих ОС. Full отчёты/логи сохранены с deleted-files префиксом. Mac/GUI
не запускались. IDE-034 (удаление самого cwd) и IDE-035 (rapid initial attach)
сохранены отдельными CLI в tests/diagnostics и остаются открытыми.

IDE-035 (§99, 2026-11-02): initial index show → удаление linked → следующий
HEAD show воспроизводится через прозрачный gate настоящих результатов Git.
Два gitsigns-worktree E2E проверяют сохранение текста, отсутствие блокировки,
последующий main stage/unstage и dirty cancel со stage именно linked index.
Windows/Ubuntu — 2 PASS; plugin-backports — 7 PASS на обеих ОС, включая CLI
--plugin и настоящий Lazy build Gitsigns. Baseline red можно повторить на
config archive 89237bf и private upstream Gitsigns; команды — AGENT_COMMANDS §32.

Ubuntu full новой версии: 41 файл/43 прогона, 40 PASS / 0 FAIL / 3 SKIP.
Windows targeted интеграция: 6 файлов PASS / 1 FAIL (повторное active delete,
IDE-038); улучшен сбор исходной ошибки/cleanup, его повтор 2 PASS не является
фиксом Permission denied. Tail unit/trace/ConPTY: 15 PASS / 1 FAIL, 65/66
ConPTY PASS. Единственное JSON отличие RU fixture — Ctrl+/ replay/right_ctrl
в nvim/vt (IDE-039), эталон не менялся. Единичный RPC timeout при фокусе Git
сохранён как IDE-040. Полный Windows PASS и проверка Mac/GUI не заявлены.

IDE-038 (§100): первый вариант наследовал cwd и прошёл 3 live проверки,
но дополнительный сценарий с уже текущим linked дал Git 255. Эти ранние
Windows 38 PASS/469 проверок и Ubuntu serial full 41 PASS/0 FAIL/3 SKIP
(42 файла/44 прогона, 638 проверок) не доказывают окончательный вариант.
Теперь process cwd явно common git-dir, файловые команды сохраняют -C;
live набор содержит CLI пяти native вариантов и 3 UI пути. Completed gate
IDE-035 отдельно требует настоящий ошибочный read после удаления; current
linked допускает detach до следующего read и проверяет текст/UI/stage.
Backport имеет два проверяемых файла, previous upgrade и preflight unknown
companion; ordinary check сохраняет bytes/mtime, настоящий Lazy build готовит
оба файла. Итоги текущей версии — FIXLOG §100.
Итоговые verified: Windows unit/e2e/trace 38 PASS/0 FAIL/0 SKIP, 471 проверка;
Ubuntu full 41 PASS/0 FAIL/3 SKIP (42 файла/44 прогона), 640 проверок.
Live 4, completed 2, подготовка 8 PASS на обеих ОС. Final previous baseline
даёт реальный Git 255, upstream baseline — исходный ENOENT/traceback.
Первый Ubuntu full имел единственный 60s timeout key-ownership (IDE-042);
raw FAIL, отдельный 46 PASS и serial repeat сохранены раздельно. Повторы
не устанавливают причину timeout. ConPTY IDE-039 и Mac/GUI остаются открытыми.


IDE-GIT-11/IDE-044 (FIXLOG §103): `git-conflicts.test.lua` создаёт две локальные
ветки с настоящим конфликтом и проверяет merge/rebase resolve/continue и
отдельный abort — 4 PASS Windows/Ubuntu. Все действия Neogit/Diffview выполняются
клавишами; после выбора ours/theirs проверяются файл/index/refs и завершение
Git metadata. Merge имеет обе исходные вершины родителями; rebase даёт новый
commit на main и сохраняет main, abort возвращает исходные HEAD/index/оба файла.

Alt+e проверяется из file panel и из крайней правой версии. Исходный selector
выбирал правую :3: панель (buftype=nowrite, modifiable=false), writable result
находился посередине. Новый выбирает normal modifiable buffer. В baseline
34f2054 постоянный тест даёт именно этот RED (13338206520000); прежний config
в частном FORGE_E2E_CONFIG_SOURCE, plugin lock/payload те же. Ранний locator
искал заголовок Unmerged вместо строки unmerged — его FAIL сохранён как
ошибка тестового ожидания, а не причина runtime.

Команды: `nvim -l tests/e2e/git-conflicts.test.lua` (Windows — SDK и temp на F:),
`docker compose -f tests/containers/compose.yaml run --rm --entrypoint nvim ubuntu -l tests/e2e/git-conflicts.test.lua`.
На Mac — официальный nvim после prepare_editor.py, проверка ещё не выполнялась.
Фильтр `FORGE_GIT_CONFLICT_CASE='merge resolve'` оставляет один сценарий.
Raw observations содержат diff_windows, after_alt_e/alt_e_from_panel, before/after
refs/index/files, prompts, notifications и snapshot. Полная сверка — ignored
.tests/git-conflicts-evidence-validation.json. GUI/физические Alt, credentials,
sequence editor, конфликты delete/rename/binary и сложные многофайловые операции
не объявляются покрытыми этими четырьмя сценариями.


IDE-GIT-12/IDE-043: util companion удаляет завершённые OSC title/hyperlink
с BEL/ST до CSI и сохраняет UTF-8. `git-errors.test.lua` теперь содержит
3 настоящих UI E2E: divergence/retry, native missing-origin/retry и private
pre-receive hook с цветной причиной/OSC/ссылкой/обычным путём → отказ → retry.
Четвёртая protocol check — parser matrix 10 строк, это не 10 UI E2E.
Матрица проверяет соседние разные BEL/ST, видимый текст ссылки, CSI, UTF-8
рядом с ASCII и буквальный Windows path. До исправления 8 строк не совпадали,
после — все 10 PASS. Полезный путь вне OSC остаётся в настоящем hook output.

Кеш зависимостей подготовить повторно даже при прежнем lock; descriptor Neogit
теперь содержит primary и util, исходники не исправляются тестом при старте.
`plugin-backports.test.lua` — 9 проверок, включая LF/CRLF обоих файлов,
legacy primary-after/util-before, неизвестный companion до любой записи и
настоящий `:Lazy build neogit` с последующим read-only открытием.

Для исходного UI RED используется только private source variant:
`FORGE_NEOGIT_OUTPUT_SOURCE_VARIANT=upstream` требует явного
`FORGE_E2E_CONFIG_SOURCE` с архивом 7938409 до IDE-043. Prepared parent cache
остаётся новым; только util дочернего профиля возвращается к точной исходной
SHA перед запуском, IDE-034 primary сохраняется. Normal run оба override
очищает. В артефакте — neogit-util.lua, util_source SHA/variant, raw
notifications/history/prompts/refs. Конечный RED: 27202749796900 (native INFO),
27213070080100 (hook metadata). Это реальные Git результаты, не подмена вывода.

Итог IDE-043 (§104–106): Windows unit/e2e/trace 40 PASS, 486 checks, после
последней коррекции visible Head — ещё 6 workflow PASS. Ubuntu serial full
сначала 42 PASS/1 FAIL/3 SKIP (лишнее требование фокуса теста), затем
41 PASS/2 FAIL/3 SKIP, 650 checks. Все OSC/backport/SDK/workflow проверки
прошли; два старых Gitsigns сценария дали первичный RPC timeout и ошибку
teardown, IDE-047 остаётся открытым. Это не чистый Ubuntu full PASS;
исходные report/logs не переписаны. Mac/GUI не проверены.

IDE-047: процессный регресс `editor-process.test.lua` запускает настоящий
clean Neovim через RPC. Обычный qa! проверяется на Windows/Ubuntu. На POSIX
собственный child останавливается SIGSTOP, настоящий RPC deadline остаётся
10s; остановка проходит qa!/2s → SIGTERM/2s → SIGKILL/2s. Успешный SIGKILL
не превращает cleanup в PASS: helper возвращает ok=false с первичной ошибкой,
editor caller завершает проверку FAIL. Windows SIGSTOP ветка — явный SKIP;
Mac требует отдельного запуска. После каждого сценария тест обязан убрать
свой child даже на baseline RED.

`shutdown.json` содержит PID, этапы и elapsed, code **и signal**, первый RPC
сбой и исходную ошибку caller. `rpc-error.json` пишется до первого SIGTERM;
последующие snapshot не повторяют зависший RPC. После подтверждённого exit
и сохранения artifacts runtime очищается; если это невозможно — остаётся с
явным путём. Исходная ошибка передаётся `e:stop(primary_error)` из общего
Gitsigns wrapper обоих файлов и из startup. Повторный stop сохраняет verdict.
Проверки завершают только переданный собственный handle, без поиска по имени.
Это исправляет cleanup/доказательства; причина первичного IDE-047 RPC
timeout остаётся открытой, даже если отдельный Git повтор прошёл.

Исходный stop_process из commit 5e4dfe8 можно проверить явно: Git show
tests/lib/editor.lua сохранить в файл, на Ubuntu положить в .tests/ubuntu,
задать FORGE_EDITOR_STOP_LEGACY_SOURCE=/workspace/.tests/ide047-legacy-editor.lua
и FORGE_EDITOR_PROCESS_CASE=forced. Adapter сверяет SHA, экспортирует исходную
локальную функцию без изменения её тела. Ожидаемый RED доходит до старого
assert «Дочерний Neovim не завершился»; обязательный finally убирает child.
Команды/артефакты — docs/AGENT_COMMANDS.md §38.

IDE-047 targeted: Windows 11 PASS/2 POSIX SKIP, Ubuntu 13 PASS. Затем Ubuntu
full — 43 PASS/1 FAIL/3 SKIP (653 checks); единственный FAIL — отдельное
ожидание следующего completed Git-read, IDE-048. Cleanup/процессные сценарии
прошли; первичный RPC IDE-047 и новый IDE-048 остаются открытыми.

IDE-HL-1/IDE-041: `reference-highlighting.test.lua` содержит три реальных
editor UI сценария. Слово 512 КиБ → редактирование/запись → обычное слово;
Unicode граница 4096/4097 UTF-8 bytes; файл 5003 строки; строка длиннее
512 КиБ с короткими Unicode вхождениями. Extmarks наблюдаются публичным
Neovim API, Alt+n/Alt+p реально меняют курсор; private provider/handlers
напрямую не вызываются. Один callback should_enable применяется в обычном
и large-file режимах, без нового backport/пина/SDK.

Постоянный тест на исходном config archive fa33150 воспроизводит E339 /
hit-enter и RPC timeout: Windows artifact 37931338029900. Сохранены screen,
первичный RPC и исходный ide.lua; конечный test source тот же. Raw v:errmsg
не обнуляется: silent! loadview может оставить прежний E484 без сообщения.
Проверяются реальные действия, видимые messages/notifications и mode;
неожиданные prompt/ERROR/видимые E… не подтверждаются автоматически.

Итог IDE-041: по 3 новых UI + 10 smoke PASS Windows/Ubuntu; Windows unit/trace
15 файлов PASS, 364 checks. Перед/после source и все 6 GREEN artifacts
сверены в .tests/ide041-evidence-validation.json. Установки/обновления
зависимостей не было; известные IDE-047/048 и Mac/GUI остаются открытыми.

Ранний hook locator останавливался на строке push: длинный вывод оставлял
причину ниже viewport. Keyboard search по literal cause открыл её; исходный
FAIL 26077291181500 относится к locator, после него получен runtime RED
26380326922600. Обе попытки сохраняются в истории. Mac/GUI ещё требуют прогона.

## JS / Node workflow

После общих pinned plugins явно подготовить инструменты (Windows: выбранный
SDK Neovim и TEMP/TMP/TMPDIR на диске checkout):

```sh
python -B tests/e2e/prepare_node.py --download --nvim <nvim>
python -B tests/e2e/prepare_node.py --nvim <nvim>
<nvim> -l tests/e2e/node-language.test.lua
```

На macOS/Ubuntu — python3. Node 24.11.0, TSLS 5.1.3, TypeScript 5.9.3,
Prettier 3.6.2, Jest 30.2.0, js-debug 1.105.0, JS parser из pinned Treesitter.
SDK/debug archives проверяются по SHA256; npm ci использует committed lock и
integrity. Кэш/SDK/parser/manifest — .tests/node-deps, отдельный output можно
задать --output и FORGE_E2E_NODE_DEPS. Повтор без --download не ставит tools.
Linker .exp/.lib остаются в build, parser directory содержит только библиотеку;
подготовка проверяет именно runtime lookup и реальный JS parse.

Восемь UI E2E используют настоящие server/Prettier/npm/Node/Jest/js-debug,
project-local dependencies, путь с пробелом/Unicode, native клавиши и панели.
Проверяются definition/references/rename и сохранение, cmp source nvim_lsp,
diagnostic/correction, format, NodeRun/File, F5 default/launch.json, stderr/stdout,
breakpoint/eval/continue, nearest/file/output/debug tests, missing Node/adapter.
Snapshots исключают node_modules, сохраняют source/lock/manifest/logs/shutdown;
это исключение только для данных проекта, не для конфигурации редактора.

Итог Windows: 8 PASS, прежние Go language 6 + Go tests 5 + smoke 10 PASS,
unit/trace 364 checks PASS. Ubuntu image дополнен явным preparer, но build и
прогоны пока не выполнялись: engine недоступен. Mac/GUI не проверены.

IDE-051 replay: FORGE_NODE_CASE=nearest/file и FORGE_NODE_NEAREST_LEGACY=1
восстанавливают точную исходную функцию только в private plugin copy до
старта редактора. SHA до/после проверяются; global prepared source не меняется.
Конечный постоянный тест даёт исходный RED «No tests found» при двух обнаруженных
позициях; без legacy — GREEN. История/команды: FIXLOG §111 и AGENT_COMMANDS §43.

## Python: project venv, Pyright, Ruff, debugpy и pytest

Сначала подготовить общие plugins и Node SDK по разделам выше. На Windows
использовать Neovim SDK из scripts/lib/nvim-sdk.ps1 и TEMP/TMP/TMPDIR на F:.
Python предоставляет целевая машина (>=3.10); preparer не устанавливает SDK.

```sh
python -B tests/e2e/prepare_python.py --download --nvim <nvim>
python -B tests/e2e/prepare_python.py --nvim <nvim>
<nvim> -l tests/e2e/python-language.test.lua
```

На macOS/Ubuntu — python3. Проверенный Windows Python 3.14.0; Pyright 1.1.414,
pytest 9.2.0, debugpy 1.8.22, Ruff 0.17.3. В tests/e2e/python-tools сохранены
полные wheel/npm locks и SHA. Tool venv, wheelhouse, parser и caches находятся
в .tests/python-deps. Повтор без --download проверяет готовность без установки.
Переопределение: --output и FORGE_E2E_PYTHON_DEPS; Windows output на диске checkout.

Private Unicode/space project получает настоящий .venv offline из wheelhouse,
включая отдельно собранную локальную dependency. Venv не активируется в shell.
Восемь UI E2E проверяют LSP navigation/rename/completion/diagnostics, определение
в site-packages, сохранение explicit Python setting, Ruff manual/on-save,
F5 default/launch.json, breakpoint/eval/continue/stdout/stderr, pytest nearest/
file/output/debug и неожиданный adapter exit. Используются реальные процессы.
Snapshots сохраняют source/locks/manifest/logs/shutdown, исключая venv/cache.
Подробное поведение и команды пользователя — [Python workflow](../../docs/PYTHON_WORKFLOW.md).

IDE-052 исходный runtime 6988af1 воспроизводится через FORGE_E2E_CONFIG_SOURCE
и FORGE_PYTHON_CASE='LSP definition'. IDE-053: FORGE_PYTHON_CASE='pytest debug'
и FORGE_PYTHON_DAP_LEGACY=1 восстанавливают исходный pinned session.lua в private
plugin copy до startup; SHA проверяется, общая подготовка не меняется.
Оба окончательных теста дают исходный RED; с исправлениями GREEN. Настоящий
adapter exit 23/stderr по-прежнему даёт WARN и не блокирует редактирование.

Windows: 8 Python PASS, Node 8 + Go language 6 + Go tests 5 + smoke 10 PASS,
364 unit/trace checks PASS. Запуски 2026-11-03, source/hash audit 2026-11-09.
Ubuntu image дополнен preparer, но не собран: engine недоступен при read-only
проверке 2026-11-09. Docker Desktop/WSL не запускались. Mac/GUI и managed
Python env отдельно не проверены. История/команды: FIXLOG §112–113, AGENT_COMMANDS §44.

## Rust: подготовка и Cargo workspace

После общих plugins нужен установленный host Rust с rust-analyzer, rustfmt,
clippy и rust-src. SDK не устанавливается/обновляется preparer. На Windows
использовать выбранный Neovim SDK и TEMP/TMP/TMPDIR на диске checkout.

```sh
python -B tests/e2e/prepare_rust.py --download --nvim <nvim>
python -B tests/e2e/prepare_rust.py --nvim <nvim>
<nvim> -l tests/e2e/rust-language.test.lua
```

На macOS/Ubuntu — python3. Версии/sysroot/hash host SDK записываются в
manifest; compile probe проверяет native linker до запуска UI. CodeLLDB 1.12.2,
cargo-nextest 0.9.151 и parser из pinned Treesitter подготовлены по SHA из
rust-tools/sources.json в .tests/rust-deps. Повтор без --download не ставит tools.
Другой каталог: --output/FORGE_E2E_RUST_DEPS, на Windows — диск checkout.

Private offline workspace с двумя local crates и несколькими targets имеет
отдельные Cargo home/target/temp; UI F5 сам выполняет preLaunch build, fixture
не предоставляет готовый executable. Source/locks/manifest/logs сохраняются,
target не дублируется в snapshot. FORGE_RUST_CASE ограничивает случаи по имени.
Workflow и пользовательские команды — [RUST_WORKFLOW.md](../../docs/RUST_WORKFLOW.md).
Наличие tools/успешная подготовка не являются PASS UI; текущие результаты
и IDE-054 отслеживаются в verify-rust-language-workflow/fix-rust-test-workspace-paths.
Ubuntu/Mac/GUI пока не проверены, Docker Desktop/WSL не запускаются ради теста.

Итог Windows 2026-11-09: 8 Rust PASS; прежние language/smoke 37 сценариев,
backport E2E 9 и unit/trace 364 checks PASS. Source replay IDE-054/055 и
границы — FIXLOG §114–115 / AGENT_COMMANDS §45. При debug E2E readiness
проверяется повторно без скачивания после настоящего CodeLLDB; generated
__pycache__ исключён из immutable payload, остальные source/tool SHA строгие.
Источник stdout сохраняется как test-stdout.txt. Отдельно не проверены
stdlib navigation, cross-compile и native GUI; offline sysroot metadata warning
про cfg-if сохранён в evidence. Ubuntu image ещё не build/run, engine недоступен.

## Bash edit/run/tests

`python -B tests/e2e/prepare_bash.py --download --nvim <nvim>` — явная
подготовка; повтор без `--download` проверяет SHA/versions без установки.
Сначала нужны подготовленные plugins/Node, host native Bash и C compiler.
На Ubuntu/macOS — python3. Windows использует подготовленный Forge SDK,
TEMP/TMP/TMPDIR/NVIM_LOG_FILE в .tests/tmp на диске checkout.

`<nvim> -l tests/e2e/bash-language.test.lua` — восемь настоящих UI cases:
sourced definition/references/rename (IDE-058 URI aliases), LSP completion/
ShellCheck diagnostics, manual/save shfmt и .editorconfig, native args/cwd/
stdout/stderr/exit 7 + успешный hotkey task; Bats nearest/file/два синтаксиса,
literal regex/Unicode и соседние markers; отсутствие tools без WSL/install.
Private BASH_ENV fixture имеет положительный CLI контроль, затем редактор
обязан не исполнять startup hook. Tests adapter использует официальный Bats
declaration DSL; Bash parser не подменяет Bats grammar.

Tools pinned в bash-tools/package-lock.json и sources.json: Bash-LSP 5.8.1,
shfmt 3.14.1, ShellCheck 0.11.0, Bats 1.14.0, parser из catalog. Host Bash/Node
не устанавливаются; manifest/hash и private source/config/logs/snapshots
сохраняются. Ни plugin pins, ни backports не меняются.
Workflow/примеры/команды: [BASH_WORKFLOW.md](../../docs/BASH_WORKFLOW.md).
`FORGE_BASH_CASE` — фильтр случаев по имени; `FORGE_E2E_BASH_DEPS` — готовые tools.
Ubuntu image дополнен, но engine недоступен; Mac/GUI/Bash 3.2 не PASS.
Bash debug остаётся IDE-057; обычные tests не открывают DAP session.

## SQL editing/query

После общих plugins: `python -B tests/e2e/prepare_sql.py --download --sqls-variant patched --go <go-1.25+> --nvim <nvim>`.
Повтор без --download только проверяет sources/payload/versions/parser, без
установки. SQLS 0.2.48+forge.1, Sqruff 0.44.0 и SQL parser закреплены по SHA.
На Ubuntu/Mac — python3. Source SDK использует предоставленные Go >=1.25/CC,
на Windows pinned portable Zig. Go SDK автоматически не ставится.
Windows: Forge SDK, TEMP/TMP/TMPDIR/NVIM_LOG_FILE на диске checkout.

`<nvim> -l tests/e2e/sql-language.test.lua` — 20 real UI cases Windows PASS:
schema completion/definition/hover/alias rename с первого символа и emoji,
Sqruff parse diagnostics/gl/correction, project manual/save style и autosave
без форматирования, unsaved batch с actual DB counters, precise same-line
Unicode/semicolon literal selection, две connection/два workspace, Results
focus/zoom/help/hide/reopen без повторного SQL, snapshot под настоящим lock,
late callback после hide/tab switch, SQLStop/смерть своего backend PID/reconnect,
реальный unexpected exit, leading line/block comments/batch/literal с actual
rows и missing tools/config/DB без установки/пустой БД/DAP.

Private fixture использует host Python sqlite3, native SQLS и настоящие
file-backed БД. UI/RPC только вводит клавиши и наблюдает, не подменяет SQL/
LSP/diagnostic replies. Сохраняются source/config/project, dependency SHA,
UI grid/screen, native PID/LSP log/events/final-mode и graceful shutdown.
FORGE_SQL_CASE — substring filter; FORGE_E2E_SQL_DEPS — готовый dependency dir.
[Workflow/подготовка/границы](../../docs/SQL_WORKFLOW.md).

IDE-063: autosave opts.callbacks не вызывались pinned plugin; используются
публичные User write events и buffer-local guard, явное save форматирует.
IDE-064: Sqruff LSP 0.44.0 теряет parse-errors/dialect flags, поэтому один
async CLI/stdin lint с debounce/cancel/changedtick guard заменяет его LSP.
IDE-065: expected SQL stop нормализуется на per-client RPC boundary до
native/core crash UI; unexpected exit по-прежнему виден.
IDE-066 исправлен native source SDK: только Query/Exec classification по
существующему AST и version marker, исходный SQL сохраняется. Go locks и
upstream executeQuery test PASS. Вариант upstream — для отрицательного replay.
`<nvim> -l tests/e2e/sql-sdk.test.lua` — 2 реальных CLI E2E: SDK без tmp и
компиляторов остаётся Ready, payload/manifest неизменны, variant change без
--download отклоняется. IDE-067 source RED — полный tests/e2e из 79230c3.
SDK CLI artifacts включают exact script/test SHA и native stdout/stderr;
Windows private readiness profile удаляется и при отказе variant switch.
IDE-068: visible/hidden/reverse selection сохранённого Results двух SQLite
workspace, пустой root и поздний ответ при выбранном другом root. Три source
RED на d43c094; DB counters исключают повторное выполнение. Harness ждёт
новый публичный LspRequest complete, а не оставшийся Done прошлого запроса.
SQL tests/references — IDE-062. Ubuntu image дополнен, но build/run и
Mac/ARM64/GUI/внешние RDBMS не проверены; Desktop/WSL не запускаются ради теста.

## SQLLogicTest SDK и editor workflow

`python -B tests/e2e/prepare_sql_test.py --download --rustc <rustc>` явно
собирает locked native SQLite runner предоставленными Rust/CC (-j2).
`python -B tests/e2e/prepare_sql_test.py` проверяет payload/version/реальный
assertion без build/download/compiler/scratch; output по умолчанию .tests/sql-test-deps.
`<nvim> -l tests/e2e/sql-test-sdk.test.lua` — 12 native process E2E Windows PASS.
Для другого output: FORGE_E2E_SQL_TEST_DEPS. Ubuntu/Mac используют python3;
их сборка/запуск не проверены. Обычный runner не требует Python или Bash.
Exact sources/lock/test/preparer/manifest, process PID/stdout/stderr/exit и
JSON сохранены. [Protocol, команды и границы](../../scripts/sdk/sql-test/README.md).
SDK process checks проверяются отдельно от editor UI.

`<nvim> -l tests/e2e/sql-tests.test.lua` — 12 настоящих UI Windows PASS:
nearest/file/all с setup/private SQLite, ошибкой и исправлением/save/rerun,
quickfix, Unicode/space/quote argv, stop живого PID, missing runner/DAP guard,
invalid/empty scripts, damaged real report и общие focus/help/zoom/hide.
Реальные SQL counters исключают фиктивное исполнение. Mixed All запускает
настоящий native Bats рядом с SQL, другой открытый workspace не запускается.
Для mixed case нужны явно подготовленные Bash deps. Нет подмены SQL/replies;
fault case повреждает настоящий файл report после exit, сохраняя native копию.

IDE-069: прежний Run all выбирал один adapter корня; consumer через
documented Client API обходит непустые trees cwd. IDE-070: Neotest discovery
смешивал native/file-event paths, merge зацикливался при смене файла. Три
companions pinned backport нормализуют update_positions, library parent/real
и adapter-group root (IDE-072, один pytest namespace вместо двух).
`<nvim> -l tests/e2e/plugin-backports.test.lua` включает native CLI E2E для
apply/check/repeat/revert LF/CRLF и отказа неизвестного последнего companion
до записи всех четырёх файлов. Pin не менялся; явный `:Lazy build neotest`.

Source RED сохраняет feature config ea63bf5, prototype All и точные upstream
client/file/adapter-group companions в private runtime. Original SDK files не меняются
для replay; FORGE_SQL_TEST_CLIENT_SOURCE/FORGE_SQL_TEST_FILE_SOURCE/
FORGE_SQL_TEST_ADAPTERS_SOURCE допустимы
только вместе с full FORGE_E2E_CONFIG_SOURCE, SHA обязаны совпасть с before.
Все final source/UI test/helper SHA сохранены; диагностический watchdog
использовался только для stack, постоянные RED/GREEN идут без него.
Фильтр UI: FORGE_SQL_TEST_CASE. [Клавиши/подготовка/границы](../../docs/SQL_TESTS.md).
Ubuntu recipe дополнен, engine не запускается. Mac/Ubuntu/ARM64/GUI открыты;
SQL semantic references остаются IDE-062.

## IDE-075: lifecycle потомков тестового editor

`editor-descendants.test.lua` запускает настоящий Neovim и Python worker,
который открывает реальный файл и переживает своего intermediate parent.
Отдельный контрольный процесс вне editor scope должен остаться живым.
Проверяются обычный qa!, уже завершившийся root, принудительный root exit,
private runtime настоящей IDE и native attach failure до пользовательского init.

Windows: 6 native E2E PASS; Ubuntu: 5 PASS/1 Windows-only SKIP, включая
orphan из native jobstart и проверку ENOENT tuple. Предыдущий срез §136 с exact
driver eeae06c сохраняет 4 целевых RED: три живых worker после stop и реальный
runtime/file-lock cleanup FAIL. Baseline fixture освобождает свой worker через уникальный
control file, сохраняет отказ и не оставляет процессы/runtime.

```powershell
$env:TEMP="$PWD/.tests/tmp"; $env:TMP=$env:TEMP; $env:TMPDIR=$env:TEMP
$env:NVIM_LOG_FILE="$env:TEMP/descendants.log"
. ./scripts/lib/nvim-sdk.ps1
$forgeNvim=Get-ForgeNvim $PWD.Path
& $forgeNvim -l tests/e2e/editor-descendants.test.lua
```

Фильтр: `FORGE_DESCENDANT_CASE=orphan` или `startup`. Для source replay
`FORGE_DESCENDANT_DRIVER_SOURCE` указывает на `tests/lib` из `git archive
eeae06c tests/lib`; test сверяет четыре exact source SHA и сохраняет копии.
Без override используются текущие drivers. Suite включён в общий e2e реестр.

Общий process scope вызывается из RPC launcher/stop. Windows backend использует
анонимный Job Object с kill-on-close и startup barrier до init: spawn→assign→
release. Job active counts/termination/error/elapsed записываются в shutdown.json
вместе с прежними main code/signal/primary error. Scope закрывается и после уже
вышедшего root; ошибка scope не становится успешным cleanup. Реальный отказ
OpenProcess в отдельном case — явный argument fault injection, не fake reply.

POSIX backend использует собственную группу root и группы реальных editor
jobstart/termopen/отделённых uv.spawn. Startup observer пишет actual PID/PGID
в private append-only JSONL; cleanup читает его после root exit и применяет
TERM/wait/KILL только к этим группам. Registry не зависит от закрывающегося
RPC и не меняет argv/callbacks/return tuple. `shutdown.json` сохраняет список
групп, их API, действия и live state. Намеренно отделившийся внутри backend
daemon требует отдельного lifecycle; поиск/kill по имени не используется.

IDE-077 source replay: `FORGE_POSIX_SCOPE_SOURCE` указывает на точный
`tests/lib/process_scope_posix.lua` из 054ee05 (SHA проверяется),
`FORGE_DESCENDANT_CASE=jobstart`. На native Ubuntu старый module даёт один
целевой RED; текущий — GREEN с прежним сценарием и живым чужим child.
Для контейнера включён `init: true`, чтобы reap orphan zombies. Engine
запускает владелец, тестовый каркас не управляет Desktop/WSL.

Mac/GUI остаются непроверенными; Windows PASS не доказывает POSIX/GUI.
macOS: `nvim -l tests/e2e/editor-descendants.test.lua` в
подготовленном окружении; native OpenProcess case там имеет явный SKIP.
Для проверки live/zombie members POSIX backend использует `ps`: на macOS он
штатный, в Ubuntu recipe явно добавлен пакет `procps`. Образ пересобран
2026-11-09; отдельные language gates отмечаются по фактическим прогонам.

SQL observer regressions IDE-078/079: terminal rows могут разрывать заголовок
native PASS, поэтому UI assertion учитывает перенос, сохраняя реальные
process/DB/status проверки. Unexpected SQLS exit записывается в отдельный
native JSONL: parent читает raw code/signal без blocking RPC на hit-enter.
Нужные crash notices определяются по этому tuple и поведению Neovim 0.12.2,
а не фиксированным числом сообщений. Production LSP/query код не менялся.

## SQL references — IDE-SQL-9, собственный подход отменён

Уточнение владельца 2026-11-10: использовать готовый поддерживаемый backend,
без своего LSP/binder/index. Неподключённый prototype и только его tooling/fixtures
убраны из текущего дерева и реестра. Реализованной editor references фичи не было;
IDE-062/IDE-SQL-9 остаются открытыми. Новый backend пока не выбран.

Исходный acceptance case и его source — Git 341aba2, FIXLOG §142; реальный
Windows artifact 927194342200 сохраняет SDK/config/test, raw -32601 и отсутствие
provider/quickfix. Исторические 4 native unit Windows/Ubuntu относятся только
к тому прототипу. Текущий SQLS forge.1 и прежние query/Tests E2E сохранены.

После выбора готового кандидата editor E2E снова должны проверять точные
bindings/scopes/CTE/DML, unsaved/closed files, Unicode и переход quickfix→код.
Один provider flag и grep не закрывают requirement. До этого —
[feature/cost review](../../docs/FEATURE_REVIEW.md), §143.

## Пассивная Go metadata — IDE-BOOT-4

`nvim -l tests/e2e/go-passive.test.lua` с заранее подготовленными editor/Go/
Delve/gopls SDK проверяет пять native сценариев: edit будущего module без SDK
download от helper, один явный GoVersion, поздний реальный ответ после смены
контекста, GoToolchain с настоящим перезапуском gopls и late Delve override
с F5/breakpoint/stdout.
На Windows использовать выбранный SDK и F: temp, как в [GO_TOOLS](../../docs/GO_TOOLS.md).

Metadata-only profiles намеренно исключают gopls/dlv из PATH. Отсутствующий
gopls имеет прежнее контекстное предупреждение; собственные Go CLI calls
наблюдаются без подмены. Явные info prompts GoVersion/GoToolchain сохраняются
и подтверждаются Enter после проверки push notification. Обычное редактирование
не получает такого исключения: неожиданный SDK download остаётся FAIL.
В сценарии запрошенного GoToolchain restart на Windows отдельно записывается
известный native force-stop tuple gopls code=1/signal=15; другой warning/error
этим разрешением не скрывается. Проверяются разные initialized client IDs.
Late response case удерживает доставку настоящего завершённого CLI result,
не фабрикует версию/ответ. Go build cache Windows остаётся на F:.

## Peek с клавиатуры — IDE-PANEL-9

`nvim -l tests/e2e/peek-navigation.test.lua` — семь native сценариев с настоящим
gopls: `gpd` и закрытие `q`/`Esc`, `gpr` и группы `h`/`l`, выбор `j`/`k` и
`Enter`, split через `v`/`s`, типы/реализации `gpt`/`gpi`, фокус `Space l` и
закрытие `Q` из обоих окон. Проверяются реальная позиция preview/перехода,
ориентация split, возврат исходного курсора и неизменность исходников.
Ответы LSP не подменяются. Fixture не требует внешних Go modules.

Нужны заранее подготовленные editor/LSP/Go SDK, как для go-language;
Windows использует выбранный patched SDK, temp/cache на F:. Suite включён
в общий e2e registry. Один случай: `FORGE_PEEK_CASE` — подстрока имени.
Обычный полный прогон выполняется без этого фильтра.
macOS требует отдельного native прогона; GUI/физическая клавиатура не эмулируются.

## Позднее окно дерева и фокус — IDE-PANEL-10

`nvim -l tests/e2e/outline-focus.test.lua` — три native сценария с настоящим
gopls/Neo-tree/Edgy: первое открытие Outline, позднее дерево поверх Outline и
позднее дерево после явного выбора split с кодом. Public команда Neo-tree
в отложенном producer задаёт порядок реальных UI операций; backend/LSP ответы
не подменяются. Проверяются итоговое окно/файл/курсор, единственный left slot,
неизменные исходники, отсутствие ERROR/install/prompt. Suite включён в registry.
Зависимости и Windows SDK те же, что у Go/Peek E2E.

`nvim -l tests/diagnostics/outline-focus.lua` — отдельный trace трёх холодных
профилей с project/Alpha/Explorer и LSP Outline. Записывает WinEnter/call stacks,
первую готовность символов и 24 последующих опроса, затем явный возврат в код.
`FORGE_OUTLINE_SAMPLES=1..5`, `FORGE_OUTLINE_OUTPUT=<json>` задают объём/отчёт.
Диагностика не равна acceptance: cold race может не проявиться в данном запуске.
macOS/GUI требуют собственного прогона; Docker проверяет только Ubuntu.

## Native sorter и fallback — IDE-BOOT-5

`nvim -l tests/e2e/search-sorter.test.lua` — четыре настоящих editor UI случая:
готовая DLL/SO без CMake в PATH; missing с CMake; corrupt с CMake; missing без
CMake. Проверяются исходный sorter callback, настоящие C scores, file/content
поиск через клавиатуру/rg, переход Enter, неизменность файла, health и отсутствие
startup build/download. Наблюдатель C score вызывает исходную функцию и только
сохраняет её результат. Ошибочный artifact меняется исключительно в private copy.

Пятый native check вызывает реальный `:checkhealth forge` без пользовательского
init и проверяет `Telescope not loaded`; остальные health-секции могут сообщить
об отсутствии настроенного Conform в этом намеренно неполном профиле. Процесс
ограничен собственным Job/PGID. Это отдельный headless health check, не пятый UI
workflow. В обычной сборке Telescope может заранее загрузиться через DAP;
health сохраняет фактическое состояние до/после picker.

Подготовка — `python[3] -B tests/e2e/prepare_fzf.py` после prepare_editor.
Тест требует native artifact даже для missing/corrupt matrix и не заменяет
отсутствующий native SDK молчаливым SKIP. `FORGE_SEARCH_CASE` выбирает UI случай;
полный suite без фильтра запускает также health check. Mac/ARM64/GUI отдельно.

## Состояние Files в сессии

`nvim -l tests/e2e/session-files-view.test.lua`: native TUI quit/relaunch,
две вкладки с разным деревом/scroll/width, A→B→A, скрытый Files, удалённый узел,
меньший UI, native Ctrl-w > и follow только при смене файла. Session/JSON,
expected/actual и terminal при отказе сохраняются в artifacts. SDK — обычный
Editor; отдельная framework/dependency не нужна. Platform gates — FIXLOG §205.

## Пассивный поиск окон компонентов

Пассивный lookup/default focus компонентов: `nvim -l tests/e2e/window-lookup.test.lua`.
Реальные окна normal/float и tab, несколько FT в обратном приоритете, live
metadata/custom callback/no-match; настоящие Neo-tree filesystem/buffers/git_status.
Проверки одинаково проходят до/после refactor (§185), не требуют новых SDK.

## Рабочий пилот рамок

Рабочий opt-in layout Code/Locals: `nvim -l tests/e2e/frame-layout.test.lua`.
Сценарий использует подготовленные Editor/Go/Delve SDK, реальные F9/F5/F10,
UI RGB и session save/restore; [команды и границы](../../docs/PANEL_FRAME_PILOT.md).

## Quit/RPC capture — IDE-085

Все RPC test children с artifacts получают controller/native JSONL и
driver-source/SHA до init. `quit-trace.test.lua` проверяет normal quit,
реальный delayed QuitPre и native API notification error после detail cap.
`nvim_error_event` сохраняется отдельно в shutdown.api_errors; normal search
считает такой неожиданный event ошибкой, controlled fixture ожидает его явно.

`nvim -l tests/e2e/quit-trace.test.lua` не требует plugin SDK. Подробный сбор
`FORGE_E2E_RPC_TRACE=1` ограничен 256 detail records, critical quit/error/EOF
не отбрасываются. Только для unhooked сравнения исходного сценария можно
задать `FORGE_E2E_QUIT_TRACE=0`; обычный регресс/CI использует capture.
Протокол, команды и границы выводов — [diagnostics](../diagnostics/README.md#ide-085-quit-и-api-error-timeline).

## Native Git HTTP credentials — IDE-GIT-14

После обычной явной подготовки Editor SDK (prepare_editor.py --download):

```sh
<nvim> -l tests/e2e/git-auth.test.lua
```

Два native UI случая: cancel Username→P u→success и wrong Password→видимый
Authentication Failed/Enter→native retry→success. Настоящий Git http-backend
работает через stdlib Python127.0.0.1 fixture в owned job; внешних accounts,
сети и global Git/helper настроек нет. Synthetic secret маскируется; audit
хранит только совпадения/длину. Проверяются прежние refs до успеха, POST200,
remote HEAD, clean tree и реальный pre-push marker. Host Python/Git обязательны.

FIXLOG §213–214: Windows auth2 distinct на конечном runtime +22 controls PASS;
Ubuntu final auth2+22=24 PASS. Source failures сохранены, детали версий в change
verify-git-authentication-flow/verification.md. Native Mac/physical/OAuth/SSH/
user helper/real account отдельно. Существующий Docker image должен иметь
актуальный SDK payload: final run использовал private overlay готового Neogit,
без image rebuild/lifecycle. Установленный IDE: :Lazy build neogit и restart.

## Bash debug — IDE-SH-5

Нужны Editor SDK и pinned Node SDK из обычной Node подготовки выше. Затем:

```sh
python -B tests/e2e/prepare_bash_dap.py --download
python -B tests/e2e/prepare_bash_dap.py
<nvim> -l tests/e2e/bash-debug.test.lua
<nvim> -l tests/e2e/bash-interactive.test.lua
```

Три случая: real debug current file/edit-repeat/launch.json/Stop, missing
adapter и missing Node. Fixture использует public DAP и клавиши, нет backend
mocks/private state writes. Windows — уже готовый default WSL2 Linux с
Bash4+/cat/mkfifo/rm/pkill, host Node; Linux/macOS — native Bash4+. Distro или
системные tools preparer не устанавливает. VSIX0.3.9 закреплён SHA, повтор
проверяет269 payload files; --archive позволяет готовый offline VSIX.
IDE-128 patch входит в явную подготовку SDK; Mason installation требует
:BashDebugPrepare. --patch-installed <JS> исправляет только два известных
payload0.3.9 (OpenVSX/Mason), LF/CRLF сохраняются, unknown bytes отклоняются.
Обычные startup/F5 не меняют SDK и ничего не скачивают.

Default — integrated PTY, explicit args/env/cwd и optional debugConsole
проверены; Linux warning optional console описан IDE-127, не скрывается.
Новые4 bash-interactive cases (§217/IDE-SH-6): реальные stdin Unicode и
scroll/search Output→i→Enter; Stop на read из terminal-mode; явная Lua SDK
prepare/repeat/unknown/F5 guard; CLI LF/CRLF repeat/unknown. Отдельный Node job
принадлежит Editor, но не debug: после Stop/exit он обязан остаться live.
Fixture PID/parent проверяются **до** Editor stop, затем общий native scope.
Обычный exit не должен печатать Killed. Только public API/настоящий backend.
Windows21 distinct selected PASS (последние7 Bash + неизменные14 controls),
Ubuntu21 PASS одним итоговым script. По15 native profiles: штатный exit0,
APIerrors[], scope empty. Source sentinel RED и все промежуточные ошибки
сохранены; точные версии — change verify-bash-interactive-terminal/verification.md.
Mac/physical/cold distro/UNC/custom mounts/полный Locals не заявлены проверенными.
Image build не повторялся; поздний Dockerfile слой получил SDK patch metadata.


## Сессия IDE Logs — IDE-LOG-5

`<nvim> -l tests/e2e/session-logs-view.test.lua` использует прежний session_tui:
настоящий TUI/PTY,6 native backend PID, quit/relaunch и A→B→A. Проверяются
два tab views, скрытый Logs, общие filters даже при всех скрытых окнах,
refresh старой строки и меньший реальный UI. Историю создаёт public recorder,
никакие события restore/процессы/окна не подменяются. Сохраняются native session
files, JSON sidecars, screen/state/lifecycle/config source/shutdown.

Windows/Ubuntu по10 selected PASS (§218): новый1 + Files1/project1/legacy4/Logs3.
Windows controls9 один раз на итоговом runtime, затем исправлен только UI
fixture нового case и выполнен он один. Ubuntu10 одним script. Первый source
RED и target fixture FAIL сохранены; Mac/physical отдельно. Готовых Editor deps
достаточно; нет новых SDK/build/network/Docker lifecycle требований.


## Сессия Outline — IDE-PANEL-26

`<nvim> -l tests/e2e/session-outline-view.test.lua`: встроенный Lua Tree-sitter,
реальные50 functions/Aerial,2 вкладки, quit/relaunch и A→B→A, hidden и меньший
UI. Никаких LSP/backend mocks/parser downloads;6 native child PID, session/
sidecar/source/lifecycle/shutdown сохранены. Проверяются открытость/ширина и
symbols, прежний native follow не заменён arbitrary saved scroll/folds.

Windows/Ubuntu по6 selected PASS одним script на OS: новый1 + Files1 + Logs1 +
Outline focus3. Source Windows0/1 до runtime сохранён. Mac/physical отдельно.
Общие Edge resize и native view теперь находятся в session_views, plugin pins
и SDK прежние. Это не закрывает Tests/console/debug или весь WF-01.


## Tests и отложенные размеры Terminal/Debug — IDE-PANEL-27/28

`<nvim> -l tests/e2e/session-tool-views.test.lua` —3 native PTY cases:50 настоящих
Bats positions без run; сохранённая после q высота Terminal, отсутствие shell
после restore и настоящий echo после явного открытия; официальный Bash F9/F5,
сохранённые sidebar/Output после завершения/скрытия и отсутствие auto session.
Readonly наблюдение — public positions/windows/session; новые runner/mocks нет.

Для Debug нужен ready Node и исправленный pinned Bash SDK:
`python -B tests/e2e/prepare_bash_dap.py` (check; явная подготовка --download
описана выше). Tests discovery новых SDK не требует. На Windows готовый WSL2
выбран владельцем. Сценарии принимают FORGE_TEST_ID как обычные E2E.

Итог §220: core3 PASS на каждой ОС; Ubuntu22 PASS одним selected script.
Windows21 PASS/1 FAIL — Logs quit SavePre→SavePost13.9s (IDE-129), host/frontend
позже exit0; исходный FAIL сохранён. Native phase diagnostic:
`<nvim> -l tests/diagnostics/session-save-phases.lua`. Один выполненный probe
имел прежний runtime/deadline,6 быстрых saves и PASS; это не замена исходному
FAIL. Скрипт только измеряет capture/cleanup/save в private TUI fixture.
Полный Windows gate/Mac/physical остаются открытыми, timeouts не увеличивались.


## IDE-131: Cargo diagnostics без обязательного Clippy

`FORGE_RUST_CASE=IDE-RUST-1 nvim -l tests/e2e/rust-language.test.lua`
(PowerShell: `$env:FORGE_RUST_CASE='IDE-RUST-1'`, затем выбранный nvim -l).
Нужны прежние prepared Rust deps. Case использует настоящий Cargo/compiler/RA,
private PATH/CARGO_HOME без Clippy; native cargo clippy --version должен дать
code101. Проверяется именно source=rustc/severity ERROR, текст через gl и
удаление diagnostic после сохранения исправления, startup installs0.
Windows/Ubuntu source1 RED → target1+прежний completion control1 PASS (§223),
Mac не запускался. Это не тест cold warmup или полного editor regression.
