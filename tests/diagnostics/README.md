# Диагностика native terminal и CLI

## IDE-104: созданный child отсутствует в раскрытом Files

Обычный `file-explorer.test.lua` при ошибке locator сохраняет
`tree-choose-failure.json`: expected name/parent, actual source/path/ready,
cursor и native nodes/rows/expanded. Test source копируется рядом. Дедлайн
и логика ожидания не меняются. Первые6PASS/1FAIL Ubuntu сохранены отдельно;
поздние PASS не являются исправлением причины.

Для bounded native event trace (после обычной plugin подготовки):

```powershell
$env:FORGE_FILE_CREATE_TRACE='1'
& .tools/neovim/windows-x64/bin/nvim.exe -l tests/e2e/file-explorer.test.lua
Remove-Item Env:FORGE_FILE_CREATE_TRACE
```

TEMP/TMP/TMPDIR/NVIM_LOG_FILE на Windows задаются на диске checkout как в
следующем примере. Ubuntu native: `FORGE_FILE_CREATE_TRACE=1 nvim -l tests/e2e/file-explorer.test.lua`;
Docker с готовым engine/image: добавь `-e FORGE_FILE_CREATE_TRACE=1` к
обычной `run --rm --no-deps --pull never --entrypoint nvim ubuntu -l ...`.
Файл `file-create-trace.json` в профиле содержит максимум128 records,
dropped count, FileAdded/BeforeRender/AfterRender, parent/child native state
и наличие actual child на диске. Нет таймеров, refresh/scan overrides и
записи на диск на каждый event. Observer может менять тайминги; отсутствие
ошибки под ним не доказывает исправление. Default OFF, product init его не
загружает. На Mac/physical GUI результата пока нет.

Controlled IO reproducer: `nvim -l tests/diagnostics/file-create-order.lua`;
Windows — выбранный SDK с TEMP/TMP/TMPDIR/NVIM_LOG_FILE на F: как ниже.
Ubuntu — та же container команда с `-l tests/diagnostics/file-create-order.lua`.
Это отдельный private editor process: helper удерживает один последний
настоящий async root readdir от Neo-tree после реального watcher event,
пользовательский a создаёт child и новый результат, затем старый ответ
выпускается. Native entries/errors не заменяются, scan/renderer не подделаны.
При cleanup libuv функции возвращаются; в обычном редакторе hook не запускать.

`file-create-order.json` содержит before/newer/after nodes/rows, disk_child,
native producer stack, held/released/drained и completed renders (cap64).
Exit0 означает, что наблюдение снято штатно; `stale=true` означает
воспроизведение бага, не PASS исправления. Queue barrier из4 turns относится
только к final shallow callback→on_exit→job_complete→render→AFTER_RENDER.
Windows/Ubuntu воспроизводят expanded=true/loaded=false/no-child при actual
disk file; это совместимый механизм двух прежних untraced failures, не
доказательство их единственной причины. [План исправления](../../openspec/changes/reject-stale-filesystem-scans/tasks.md),
FIXLOG §178. Production/SDK/pins прежние, native Mac/physical GUI не запускались.

§179: [постоянный E2E](../e2e/file-scan-order.test.lua) —5 cases, исходные
Windows/Ubuntu3PASS/2RED. Fixture `fixtures/neo-tree-generation-only.patch`
сохраняет отклонённый19-line prototype: два controlled failures исчезли,
три positive controls отказали. Product loader его не читает; применять как
готовое исправление нельзя. Guard/dependency manifest полностью сняты
штатным revert/check, pin/SDK остались прежними. Требуется уточнить intent
незавершённого раскрытия и ownership watchers; [design](../../openspec/changes/reject-stale-filesystem-scans/design.md).

## Цельная рамка Locals и RGB UI capture

IDE-076: [сравнение/цена/границы](../../docs/PANEL_FRAME_REVIEW.md).
Нужны заранее подготовленные editor plugins и Go/Delve; сетевой setup
самими тестами не запускается. На Windows из корня checkout:

```powershell
$env:TEMP=Join-Path (Get-Location) '.tests/tmp'
New-Item -ItemType Directory -Force -Path $env:TEMP | Out-Null
$env:TMP=$env:TEMP; $env:TMPDIR=$env:TEMP
$env:NVIM_LOG_FILE=Join-Path $env:TEMP 'panel-frame.log'
. ./scripts/lib/nvim-sdk.ps1
$forgeNvim=Get-ForgeNvim (Get-Location).Path
& $forgeNvim -l tests/e2e/ui-capture.test.lua
& $forgeNvim -l tests/e2e/panel-frame.test.lua
& $forgeNvim -l tests/e2e/debug-panels.test.lua
```

Ubuntu/macOS используют официальный `nvim` с теми же `-l` аргументами.
С уже работающим Ubuntu image/engine, без build/pull/сети:

```sh
docker compose -f tests/containers/compose.yaml -f tests/containers/limits.yaml run --rm --no-deps --pull never --entrypoint nvim ubuntu -l tests/e2e/panel-frame.test.lua
```

Логи выводят путь профиля `.tests/editor-e2e/<id>` (Ubuntu mount —
`.tests/ubuntu/editor-e2e/<id>`). Внутри `ui-redraw.jsonl`, `ui/frames.json`,
`ui/index.html`, SVG и `panel-frame.json`; source/driver/quit/scope сохранены
рядом. Тест рамки делает девять checkpoints настоящей paused сессии.
Known WARN об отсутствующем gopls разрешён явно: LSP этому DAP тесту не нужен;
неожиданные blocking prompts и ERROR остаются отказами.

Повторный экспорт raw записи без графических пакетов:

```sh
python -B tests/diagnostics/render-ui.py .tests/editor-e2e/PROFILE/ui-redraw.jsonl --output .tests/panel-frame-export
```

На Ubuntu/macOS команда — `python3`. Нужен composited RGB single-grid1,
не ext_multigrid. Захват в RPC включается только `capture_ui=true`, default
OFF; cap16MiB, ошибка записи видна отдельно и не разрывает живой RPC.
Binary MessagePack Window handles сохраняются hex-объектом, UTF8 text точен.
CLI экспортирует реальные клетки; physical GUI/font/DPI это не проверяет.
Три E2E capture покрывают RGB/wide UTF8/scroll/resize, cap и default OFF.

Preview можно включить в собственной уже открытой paused Locals zoom с
`Space w z`: `:lua _G.frame_preview=dofile('/absolute/checkout/tests/diagnostics/panel-frame-preview.lua'); _G.frame_preview.start()`.
Отключить: `:lua _G.frame_preview.stop()`. Compact placement делает только
E2E для сравнения; runtime default и все обычные split не переоформляются.

## Project/session: настоящий TUI и restart

`nvim -l tests/diagnostics/project-session.lua` после общей plugin подготовки.
Пишет raw state/lifecycle, sessions и terminal snapshots в отдельный
`.tests/editor-e2e/<id>`. Настоящий TUI обрабатывает restart; observer только
записывает события. Permanent assertion wrapper:
`nvim -l tests/e2e/project-session.test.lua`.
[Что проверено и что остаётся](../../docs/PROJECT_SESSION_REVIEW.md).

IDE-095 legacy fixture: `nvim -l tests/diagnostics/session-legacy.lua hidden`
или `winfix`; `hidden-direct`/`winfix-direct` используют Space qs. Только
создание старой Help-only раскладки использует native noautocmd only;
восстановление и callbacks реальные. Сохраняются raw Session.vim и state.
Assertions: `nvim -l tests/e2e/session-legacy.test.lua` или общая команда
`nvim -l tests/run.lua e2e --id IDE-PANEL-15`.

## IDE-090: Output q и Debug toggle

После явной editor/Rust подготовки, Windows из корня checkout:

```powershell
& .tools/neovim/windows-x64/bin/nvim.exe -l tests/diagnostics/output-toggle.lua --cycles 6
& .tools/neovim/windows-x64/bin/nvim.exe -l tests/diagnostics/output-toggle.lua --cycles 6 --trace
& .tools/neovim/windows-x64/bin/nvim.exe -l tests/diagnostics/output-toggle.lua --resize --trace
```

Ubuntu/Mac используют официальный `nvim` с теми же аргументами. `--cycles`1..10
повторяет q/toggle на настоящем paused CodeLLDB; `--resize` один раз меняет
подключённый UI со140×45 на140×35 перед q. Это диагностическое возмущение,
не повтор исходного случайного события. На старом helper resize даёт history RED.
С §165 terminal-only comparison сохраняет semantic history при resize; пустые
строки внутри текста и REPL остаются точными. Raw snapshots не нормализуются.
`output-attempt-NN.json` содержит last stage, raw before/after и исходную ошибку,
даже если assertion не прошёл. Без --trace дополнительных native hooks нет.
С --trace записывается `output-capture.json`: bounded2048 native events в памяти,
реальные keys/typed в hex, принятые nvim_input bytes и Debug public calls/callers.
В trace нет slot refresh и пособытийной записи на диск. Observer может менять
тайминги; отсутствие сбоя под ним не доказывает исправление.

## IDE-087/089: Windows process ancestry

Очистка private profiles также покрыта native links:
`nvim -l tests/e2e/runtime-links.test.lua` (Windows — выбранный SDK).
Live/dangling links сохраняют target sentinel; Windows malformed NT target
воссоздаётся только внутри owned TEMP без изменения permissions. Fixture ABI —
[REPARSE_DATA_BUFFER](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/ntifs/ns-ntifs-_reparse_data_buffer).
Directory junction удаляется как link без удаления target, как описано в
[RemoveDirectoryW](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-removedirectoryw).
Timeout/ownership проверки прежние; production filesystem code не меняется.

Read-only: `python -B tests/diagnostics/windows-process-parents.py --output .tests/ancestry-read-only.json`.
Native source proof после подготовки SDK: `powershell -NoProfile -File tests/diagnostics/build-process-ancestry.ps1 -SdkCandidate`.
Нужны уже подготовленный pinned Neovim source и MSVC Build Tools. SDK/система
не изменяются. Фрагмент upstream сравнивается с фактическим patched proc.c на собственных
workers; одна snapshot edge контролируемая, timestamps/termination настоящие.
Это диагностический native integration, не полный IDE E2E и не Docker caller proof.
Без `-SdkCandidate` нужен неизменённый upstream proc.c: это прежний prototype probe.
Реальные SDK jobs: `& .tools/neovim/windows-x64/bin/nvim.exe -l tests/e2e/process-lifecycle.test.lua`.
Артефакты, matrix и ограничения — [WINDOWS_PROCESS_DIAGNOSTICS](../../docs/WINDOWS_PROCESS_DIAGNOSTICS.md).

## IDE-080/088: поиск окна кода и restore

`nvim -l tests/diagnostics/code-window.lua` — пять private native profiles:
normal, float-only, terminal-only, live-marker, session-winfix. SDK/editor deps
готовятся заранее; на Windows выбранный patched SDK и TEMP на диске checkout.
`FORGE_WINDOW_CASE` ограничивает запуск одним profile. JSON и screens сохраняются
в `.tests/editor-e2e/`, итог — `.tests/code-window-review.json`.
Probe не меняет runtime и не включён в общий regression registry.
Результаты/ограничения и команды Docker — [CODE_WINDOW_REVIEW](../../docs/CODE_WINDOW_REVIEW.md).

## IDE-080/083: project/focus/idle и Peek baseline

После явной подготовки editor/Go/gopls SDK, из корня checkout:

```powershell
$env:TEMP='F:/repo/forge-nvim/.tests/tmp'
$env:TMP=$env:TEMP; $env:TMPDIR=$env:TEMP
$env:NVIM_LOG_FILE="$env:TEMP/project-review.log"
$env:GOMAXPROCS='2'; $env:GOFLAGS='-p=2'
. ./scripts/lib/nvim-sdk.ps1
$forgeNvim=Get-ForgeNvim (Get-Location).Path
& $forgeNvim -l tests/diagnostics/profile-project.lua
```

Ubuntu/macOS: `nvim -l tests/diagnostics/profile-project.lua`.
FORGE_PROJECT_REVIEW_SAMPLES=1..5, default 3; FORGE_PROJECT_REVIEW_OUTPUT
задаёт output вместо `.tests/project-review.json`. Каждый fresh profile
использует Go fixture, настоящий gopls, proxy off/local toolchain и private
GOPATH. Source SDK/manifest должны быть заранее подготовлены. Windows temp/cache
на F:, native guest temp в Ubuntu. На одном хосте ОС-наборы последовательны.

Измеряются driver start (с copying), вход в текущий project/Explorer, Go/LSP,
первые symbols, прямой Space w a / Space w 0, ~1s editor idle CPU/RSS и gpd.
Это не cold restart/GUI benchmark и не CPU/memory всего дерева процессов.
Lazy часы Windows/Linux могут отличаться — см. real_cputime в raw report.

Проверка q остаётся честным RED IDE-083: в текущем runtime literal mapping
даёт E21 и оставляет Glance. Native Q используется только для cleanup,
после сбора source/snapshots/report всех profiles controller выходит code=1
с числом failures. Ненулевой код здесь не превращать в PASS или SKIP.
Project-profile содержит peek_q_closed, after_peek_q и first_outline_focus;
готовность symbols не равна установившемуся фокусу (IDE-084).

Все artifacts содержат profile-project.lua, project-profile.json, LSP manifest,
config-source, snapshots до/после q и shutdown.json. Сводка и ограничения —
[FEATURE_REVIEW](../../docs/FEATURE_REVIEW.md).

## IDE-082: Go-команды при открытии файла

После IDE-BOOT-4 Go label/Delve discovery пассивны. Этот probe больше не ждёт
фонового go version: после готовности экрана записывает label и реальные calls,
проверяя отсутствие собственных metadata calls. В private profile готовый gopls
отключён через публичный API, чтобы его Go env/поздние info prompts не смешивались
с metadata. Native language workflow проверяется отдельным go-language E2E.
Постоянный regression и явные
GoVersion/GoToolchain — [GO_TOOLS](../../docs/GO_TOOLS.md).

После явной подготовки editor SDK и Go 1.26.0, из корня checkout:

```powershell
$env:TEMP='F:/repo/forge-nvim/.tests/tmp'
$env:TMP=$env:TEMP; $env:TMPDIR=$env:TEMP
$env:NVIM_LOG_FILE="$env:TEMP/go-statusline-review.log"
. ./scripts/lib/nvim-sdk.ps1
$forgeNvim=Get-ForgeNvim (Get-Location).Path
& $forgeNvim -l tests/diagnostics/go-statusline.lua
```

Ubuntu/macOS: `nvim -l tests/diagnostics/go-statusline.lua`.
Диагностика создаёт два isolated editor profiles с module go 1.99.0 и
GOTOOLCHAIN=auto/local. GOENV/GOPROXY/GOSUMDB=off; GOPATH/GOMODCACHE/GOCACHE
в private runtime (Windows — F:). Сам SDK не скачивается; собственный helper
не должен запускать metadata CLI. Исходный offline RED сохранён в §146.
Глобальный Go/shell config не меняется.

Наблюдатель записывает реальные Go vim.system/system/systemlist calls,
call stacks/results и не подменяет API results. При hit-enter сохраняет экран
и нажимает Enter через fast API, чтобы исследовать оставшиеся инициаторы;
это диагностический сбор, не утверждение отсутствия UI-blocking дефекта.
В private profile gopls не активируется; при отсутствии binary возможно прежнее
контекстное предупреждение, которое записывается отдельно от SDK download.
Ранние вызовы до editor.start не наблюдаются.

Сводка `.tests/go-statusline-review.json`, override
FORGE_GO_STATUSLINE_OUTPUT. Каждый editor artifact содержит go-statusline.json,
go-spawns.jsonl, source diagnostic, prompt screens и обычные snapshots/shutdown.
Два завершённых profiles означают успешный сбор/пассивность собственного helper,
а не полное отсутствие работы готового language backend.
Разбор владельцев и границ — [WORKSPACE_TOOL_REVIEW](../../docs/WORKSPACE_TOOL_REVIEW.md).

## IDE-080: трасса DAP/panel ownership

После явной подготовки editor/DAP SDK можно запустить существующий E2E
с observer, сохранив настоящие API, assertions и return values:

```powershell
$env:TEMP='F:/repo/forge-nvim/.tests/tmp'
$env:TMP=$env:TEMP; $env:TMPDIR=$env:TEMP
$env:NVIM_LOG_FILE="$env:TEMP/panel-review.log"
$env:GOMAXPROCS='2'; $env:GOFLAGS='-p=2'
. ./scripts/lib/nvim-sdk.ps1
$forgeNvim=Get-ForgeNvim (Get-Location).Path
& $forgeNvim -l tests/diagnostics/trace-panels.lua tests/e2e/debug-panels.test.lua
```

Из корня checkout Ubuntu/macOS: `nvim -l tests/diagnostics/trace-panels.lua
tests/e2e/debug-panels.test.lua` (одна команда). Вместо debug-panels можно
передать dap-output или другой repo `tests/e2e/*.test.lua`. Для одного Rust
case задать `FORGE_RUST_CASE='Rust F5 default Cargo preLaunch build'`; без
фильтра выполнится весь соответствующий language suite. Это не подготовка
зависимостей и не загрузка tools на старте. Docker/Windows тяжёлые наборы
на одном хосте запускать последовательно.

В обычном editor artifact дополнительно сохраняются panel-trace.json и
trace-panels.lua. Event limit=4096, dropped/capture_error проверять явно.
Подключение после editor.start и LazyLoad не гарантирует захват всех ранних
или сохранённых ранее function references. Fixture listeners forge_e2e
отделять от production. Observer не заменяет E2E и не измеряет CPU/скорость.
Результаты текущего review и границы —
[PANEL_OWNERSHIP_REVIEW](../../docs/PANEL_OWNERSHIP_REVIEW.md).

IDE-027: Neovim Windows 0.12.2 падает в pty_proc_resize при resize
завершающегося ConPTY. Чистый probe не загружает Forge и плагины; запускает
настоящий terminal echo, ждёт job exit, возвращается в код и закрывает буфер.
Resize через public window API воспроизводит сбой; --passive — контроль.
На официальном Windows binary ожидается **ненулевой exit**, это red, не SKIP.

Из корня checkout, macOS/Linux — те же команды:

```sh
nvim -l tests/diagnostics/terminal-resize.lua --passive
nvim -l tests/diagnostics/terminal-resize.lua
```

По умолчанию 50 циклов; `--cycles 1..200` меняет число, `--nvim EXE`
задаёт абсолютный путь child SDK. Артефакты в
`.tests/native-terminal/<id>/`: result.json, screen.txt, stderr.log,
nvim.log при наличии. JSON содержит версию/ОС/PID, этап/цикл, child_exit,
ошибку и результат cleanup. Изолированный runtime удаляется с проверкой
маркера владения; Windows temp в `.tests/tmp` на диске checkout.
Ошибка запуска тоже возвращает 1 с JSON; неверные аргументы — 2.

## Временный Windows SDK

Владелец выбрал временный SDK Windows после A/B: исходники одного commit,
MSVC/RelWithDebInfo с одинаковыми flags/dependencies, без debugger:
upstream падает на первом цикле; candidate проходит 50 и все 8 buffer E2E.
Официальный 0.12.5 также падал в Forge; простое обновление не доказало фикс.
На Ubuntu официальный 0.12.2 прошёл 50 циклов. Mac/GUI ещё не проверены.

Нужны Git, CMake, Ninja в PATH и Visual Studio 2022 C++ Build Tools с x64
toolchain/Windows SDK на **builder-машине**. Скрипт их не устанавливает.
Явная подготовка (сеть только с -Download):

```powershell
powershell -NoProfile -File scripts/prepare-windows-sdk.ps1 -Download
.\nvim_forge.cmd
powershell -NoProfile -File scripts/test.ps1 full
```

Повтор с готовыми source/deps: та же подготовка без `-Download`.
Сборка SDK не входит в обычный старт, не запускается из shell profile.
Исходники: `.tests/neovim-native/v0.12.2-src`, runtime:
`.tools/neovim/windows-x64`; оба каталога игнорируются Git. TEMP/TMP/TMPDIR
и NVIM_LOG_FILE ограничены процессом builder и диском checkout.
Параллельный builder не меняет тот же source. Проверка source относительно HEAD
включает staged и unstaged правки; неизвестные изменения отклоняются до применения
обоих patch и запуска builder. Новый runtime сначала создаётся в уникальном
`.tests/neovim-native/stage-*/sdk`, build использует parallel=2.
До продвижения обязательны native ancestry fixtures, настоящие Neovim
jobstop/quit E2E и 50 циклов ConPTY probe. Старый SDK сохраняется как
`.tools/neovim/windows-x64.previous-<id>`; ошибка подготовки его не перезаписывает.
`-StageOnly` выполняет те же probes и оставляет кандидата отдельно.
Launcher читает Schema 2 lock/manifest,
проверяет оба patch/source/binary SHA256 и признаки завершённых probes; missing/stale/corrupt SDK даёт ошибку
с командой подготовки. Системный Neovim/PATH/установленный конфиг не меняются.
Прямой `nvim` использует прежнюю системную программу.

Lock и два узких patch: `scripts/sdk/windows.json`,
`scripts/sdk/neovim-conpty-lifecycle.patch`, `scripts/sdk/neovim-process-ancestry.patch`.
ConPTY patch убирает опубликованный
указатель до запуска background free/nested uv_run и игнорирует поздний
resize закрытого ConPTY. В общем Lua UI нет платформенного обхода.
Process patch пропускает связи PPID с более старым child либо неизвестным временем
создания; явно выбранный root по-прежнему завершается. Это исправление IDE-089,
не доказательство причины остановок Docker IDE-087. Linux/macOS используют официальный SDK.
LF патча зафиксирован .gitattributes, чтобы SHA256 не зависел от autocrlf.
Metadata описывает происхождение локальной сборки, не цифровую подпись.
ConPTY набор общего runner тоже получает выбранный SDK и частный профиль
с pinned plugins. Реальные stdpath config/data/cache/state и неизменность
source lock проверяются; пользовательский каталог плагинов не используется.
При upstream исправлении SDK/patch убирается отдельным change с тем же E2E.

A/B из одного builder, upstream сохраняется отдельно от рабочего SDK:

```powershell
# Upstream diagnostic больше не записывается по фиксированному пути:
powershell -NoProfile -File tests/diagnostics/build-conpty-sdk.ps1 -Variant upstream -Download
# Подставить binary из строки "SDK staged:"; запуск upstream crash repro — отдельная диагностика.
powershell -NoProfile -File scripts/prepare-windows-sdk.ps1
$forgeSdk=(Resolve-Path .tools/neovim/windows-x64/bin/nvim.exe).Path
& $forgeSdk -l tests/e2e/buffers.test.lua
& $forgeSdk -l tests/e2e/windows-sdk.test.lua
```

Только для явного сравнения с системным SDK:

```powershell
$env:FORGE_NVIM='system'
.\nvim_forge.cmd --version
Remove-Item Env:FORGE_NVIM
```

Linux/macOS используют официальный SDK через прежний `.sh` launcher.
На Ubuntu Docker проверяются тот же core probe, CLI диагностики и POSIX
launcher, без Windows SDK/build tools:

```sh
docker compose -f tests/containers/compose.yaml run --rm --entrypoint nvim ubuntu -l tests/diagnostics/terminal-resize.lua
docker compose -f tests/containers/compose.yaml run --rm ubuntu full
```

## IDE-031: редкий CLI timeout

`TestEntryPointsCLI` запускает настоящий PowerShell/bash, fixture test
entrypoint и nvim-stub. Прежний deadline **10 секунд**, без retry.
`tests/lib/cli_probe.py` сохраняет каждую попытку в
`.tests/entrypoints-e2e/<id>/`: started.json и result.json с argv/cwd/PID,
временем, кодом, stdout/stderr и timed_out. При ошибке сохраняются только
явно перечисленные fixture scripts; HOME и полное окружение не копируются.
При timeout дочерний процесс останавливается/ожидается, исходный
TimeoutExpired остаётся ошибкой теста; частичный вывод сохраняется.

```powershell
python -X utf8 -B tests/shell_diagnostics_test.py TestEntryPointsCLI
nvim -l tests/e2e/entrypoint-diagnostics.test.lua
```

На POSIX — python3. Десять Windows повторов (30 CLI процессов: quick/e2e/
unknown-mode) прошли; исходная причина 10s timeout остаётся неизвестной.
Постоянные E2E обвязки проверяют реальные exit=7/stdout/stderr, намеренно
зависший процесс с частичным выводом, spawn error и отсутствие retry.
Новые launcher E2E проверяют настоящий SDK, argv с пробелами/кириллицей,
exit code, восстановление env в том же PowerShell, broken manifest и
явный system override. Они входят в общий registry.

## IDE-034: удаление активного worktree

```powershell
python -B tests/diagnostics/git-worktree-cwd.py
& .tools/neovim/windows-x64/bin/nvim.exe -l tests/e2e/plugin-backports.test.lua
& .tools/neovim/windows-x64/bin/nvim.exe -l tests/e2e/active-worktree.test.lua
```

На Windows перед прямым запуском задать TEMP/TMP/TMPDIR в `.tests/tmp`.
На Mac/Ubuntu: `python3`, официальный `nvim`; общий runner делает это сам.
`git-worktree-cwd.py` создаёт частные Git fixtures и обычный дочерний процесс,
удерживающий cwd. Windows: Git из linked или при таком процессе получает
exit 255, оставляя пустой каталог; из main удаляет его. На POSIX все три
удаления проходят. JSON — `.tests/git-worktree-cwd.json`.

Trace исходного Neogit: Git remove spawn происходил до scheduled `Changing Dir`.
Однострочный backport ждёт этот переход. ID/revision/SHA, явная подготовка,
проверка и отмена — [patches](../../nvim_forge/patches/README.md).
CLI/Lazy E2E проверяют LF/CRLF, повтор, неизвестные revision/payload, read-only
check, revert и реальный `:Lazy build neogit`. Editor E2E удаляет чистый
текущий worktree и сохраняет dirty при отказе force; внешний настоящий commit
переводит fixture в чистое состояние для повторного UI удаления. UI commit
отдельно покрыт `git-workflow.test.lua`.

Старый `delete-current-worktree.lua` сохраняет исходную последовательность
IDE-BUF-4; с подготовленным Neogit ожидается PASS. IDE-035 (rapid Gitsigns
initial attach) остаётся отдельным `delete-pending-attach.lua`, не скрывается
этим ожиданием смены cwd. Mac/GUI не проверены.

## IDE-038: живое чтение Git-объекта

```powershell
python -B tests/diagnostics/git-object-read-cwd.py
& .tools/neovim/windows-x64/bin/nvim.exe -l tests/e2e/gitsigns-live-read.test.lua
```

Первый сценарий CLI читает 512 KiB из отличающегося linked HEAD; pipe
удерживает настоящий Git живым до завершения remove. С `-C linked`
Windows даёт exit 255; с явным `--git-dir` без перехода в linked — exit 0,
в том числе без `--work-tree`. Наследование cwd linked тоже даёт 255;
явный process cwd в common git-dir даёт 0. На POSIX все пять случаев дают 0.
Вывод обязан целиком совпадать с linked blob, main HEAD/index/файл сохраняются.
JSON — `.tests/git-object-read-cwd.json`, временные Windows fixtures на F:.

Editor gate имеет два режима: completed в IDE-GIT-8 удерживает только
доставку уже готового результата; live в IDE-GIT-9 удерживает чтение pipe
живого Git. Проверяются PID/состояние в начале и живой процесс непосредственно
перед release после remove/cancel, затем настоящий code/stdout/stderr.
Proxy освобождает собственный cwd, результат Git не синтезируется.
UI проверяет и чтение, начатое при уже текущем linked cwd. Для него допустима
отмена следующего update после detach; обязательны успешное удаление,
сохранение текста и main stage/unstage. Старый completed регресс отдельно
требует настоящий неуспешный запрос после удаления.
Это доказывает класс блокировки object read, а не владельца handle первого
случайного отказа 551474721600. Для red replay прежнего backport используется
source variant previous и отдельный config archive 199b1a7.

## IDE-039: расхождение ConPTY и эталона

```powershell
$env:TEMP = Join-Path (Get-Location) '.tests/tmp'
$env:TMP = $env:TEMP; $env:TMPDIR = $env:TEMP
. ./scripts/lib/nvim-sdk.ps1
$env:FORGE_TEST_NVIM = Get-ForgeNvim (Get-Location).Path
python -B tests/diagnostics/conpty-layout.py
```

Можно добавить `--layout ru` или `--layout en`: исходная проба делает SKIP,
если foreground language в начале не совпадает. Это условие стенда, а не
доказательство языка переводящего потока каждой ConPTY. Проба занимает около
1,5 минут; запускать отдельно от тяжёлых Windows/Ubuntu регрессов.

В новом `.tests/artifacts/conpty-layout-*` сохраняются `probe.log`,
`actual.json`, `expected.json`, `difference.json`, `sessions.json`, `manifest.json`.
Последний содержит exit/status, Windows build, DLL/EXE SHA, SDK и fixture SHA;
сессии — время, argv, синтетические входы и отдельные HKL foreground/observer/
reader primary thread. Это метаданные, а не утверждение об actual input HKL.
Инструмент не переключает раскладку, не меняет фокус/профиль/эталон. Исходные
проверки и exit code сохраняются; при несовпадении остаётся FAIL. Вне Windows
явный SKIP. `--fixture <частная-копия.json>` позволяет проверить путь FAIL
на заведомо неверной read-only копии, не переписывая tracked fixture.

IDE-039 остаётся открытым: два прежних RU FAIL отличались четырьмя полями
Ctrl+/ (`<C-_>`/`1f` вместо `<C-N>`/`0e`), последующий EN повтор прошёл 66
проверок. Новый наблюдаемый повтор поймал RU → EN между сессиями: root layout
RU, следующие reader primary HKL EN, те же четыре отличия. Этот повтор
объяснён; для старых нет ретроспективного доказательства. Смена HKL только у
тестового потока не изменила VT Ctrl+/; прямой запрос console layout вернул
false/error 16385. Эти отрицательные результаты не доказывают actual input HKL.
Следующий шаг — изолировать/проверять раскладку переводящего потока, явно
различать нестабильную среду и регресс и проверить устойчивые RU/EN прогоны.

## IDE-085: quit и API error timeline

Из корня checkout, с выбранным Windows SDK/F: temp либо native nvim на Ubuntu/Mac:

```sh
nvim -l tests/e2e/quit-trace.test.lua
FORGE_E2E_RPC_TRACE=1 FORGE_SEARCH_CASE='missing с CMake' nvim -l tests/e2e/search-sorter.test.lua
```

PowerShell: `$env:FORGE_E2E_RPC_TRACE='1'; $env:FORGE_SEARCH_CASE='missing с CMake'`,
затем `& $forgeNvim -l tests/e2e/search-sorter.test.lua`. Нужен подготовленный
editor/native SDK, как в e2e README. Одна серия — максимум 3 samples; на отказе
сохранить artifact и разбирать trace, не повышать timeout. Нет автоматического
запуска/ремонта Docker/WSL. Mac результат требует фактического native запуска.

| Artifact | Наблюдение |
|---|---|
| `quit-controller.jsonl` | Quit write-returned, handle closing, EOF/completion; optional method/id/chunk metadata |
| `quit-native.jsonl` | Observer готов до init, начаты QuitPre/VimLeavePre/VimLeave; mode/dying/exiting и общая monotonic ms шкала |
| `shutdown.json` | Реальный code/signal, stages, primary error, API notification errors, scope и trace errors |
| `driver-source/`, `driver-source.json`, `quit-observer.lua` | Копия 6 helpers/byte length/SHA и точный native observer |

Write-returned не является ack доставки. Native QuitPre показывает начало
обработки quit, VimLeave — начало соответствующего события; сам по себе он не
доказывает завершение OS process. Completion callback vim.system ждёт EOF,
поэтому он и is_closing handle записываются отдельно. API nvim_error_event
не равен stderr или сообщению UI. Critical records сохраняются после лимита
256 detail entries, payload RPC не пишется.

Три native fixtures доказывают наблюдаемость: normal exit=0, намеренная задержка
QuitPre до штатного SIGTERM и native invalid-command notification с сохранённым
ошибочным event/успешным выходом. Это не воспроизведение причины старого IDE-085.
Bounded source RED и followup — FIXLOG §152. Unhooked control flag отключает
observer только для сравнения; обычные regressions оставляют capture включённым.
