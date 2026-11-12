# Go: версия, toolchain и Delve

Go label показывает состояние без фонового запуска Go. До явного запроса
виден выбранный режим: `Go auto`, `Go local`, `Go go1.26.0` либо `Go default`,
если GOTOOLCHAIN не задан. `default` оставляет выбор обычному Go окружению,
в том числе GOENV; установленная версия этим не утверждается.

`:GoVersion` асинхронно запускает настоящий `go version`, показывает ответ,
исходные CWD/GOTOOLCHAIN и обновляет label последней подтверждённой версией.
При изменении cwd/GOTOOLCHAIN/PATH/GOENV прежний cache не используется. Поздний
ответ прежнего запроса не заменяет текущую label. В минимальном профиле без
floating notifications информационное сообщение закрывается Enter.

`:GoToolchain` открывает picker; аргумент задаёт режим напрямую, например
`:GoToolchain local`, `:GoToolchain auto` или `:GoToolchain go1.26.0`.
Выбранное окружение применяется к текущему Neovim, версия уточняется явно,
gopls перезапускается. Глобальный Go config команда не переписывает.

Явные действия сохраняют обычное поведение Go: auto/заданная отсутствующая
версия могут потребовать загрузку SDK. Готовый gopls получает исходное
окружение и использует Go для языка. Его SDK/readiness определяется обычными
правилами сервера. Метаданные statusline и поиск debug adapter не запускают
эту работу при отрисовке/открытии файла. Для задержки zsh до nvim нужен
отдельный [Mac shell trace](MACOS_STARTUP_DIAGNOSTICS.md).

Delve выбирается при запуске отладки. Если инструмент установлен или изменён
после открытия Go-файла, редактор перезапускать не требуется. Явные overrides:
`vim.g.forge_dlv_path`, `FORGE_DLV_PATH`, `DLV_PATH`. Далее используются прежние
GOBIN/GOPATH/bin/PATH/Mason candidates и приоритет версии. `:DapGoDlvInfo`
явно показывает найденные варианты/выбранный путь.

Для debug: F9 — breakpoint, F5 — launch/continue, Space w d — Locals,
Space w c — Output, Space w 0 — код. Переключение панелей описано в
[плане панелей](PANELS_PLAN.md). Полнота language/run/tests —
[языковая матрица](LANGUAGE_MATRIX.md).

## Go workspace с несколькими модулями

Откройте корень с `go.work`, затем `main.go` нужного приложения. `F9` ставит
breakpoint, `F5` → `Current Go package` запускает пакет текущего файла.
Отдельный `launch.json` для этого не требуется: зависимости из соседних
модулей разрешает сам Go. Окружение `GOWORK`/`GOENV` сохраняет обычное влияние;
проверенный сценарий использует стандартный поиск go.work.

После изменения и сохранения соседнего модуля новый `F5` пересобирает его.
В native E2E значение42 стало43, Delve подтвердил оба на паузе, stdout/stderr
появились до breakpoint и сохранились после exit, повтор очистил старый вывод.
Windows/Ubuntu по1 PASS, runtime/SDK/plugins не менялись (§206).
Это проверка debug/edit-repeat; смешанный проект целиком ещё остаётся
в очереди. Mac и физические клавиши не проверены.
Команда: `nvim -l tests/e2e/go-workspace.test.lua` с готовыми Editor/Go/Delve SDK.

### Навигация между модулями

Обычные `gd`/`F12` идут к объявлению, `gi`/`Ctrl+F12` — к реализации,
`gr`/`Shift+F12` — к ссылкам. `Ctrl+o` возвращает назад; в списке ссылок
выберите строку и нажмите Enter. Готовый gopls обнаруживает общий go.work.
WF-10/§208: Windows1 PASS/Ubuntu1 PASS — переход app→shared до открытия
shared, возврат, implementation типа/метода и reference обратно в app.
Во всех переходах один native client/root, cwd проекта сохранён, installs0.
Runtime/pins не менялись. Mac/physical и mixed-language проект отдельно.
Команда: `nvim -l tests/e2e/go-workspace-language.test.lua` с готовым LSP SDK.

### Тесты всех модулей

`Space T p` открывает Summary, `Space T t` запускает ближайший test,
`Space T f` — текущий файл, `Space T A` — все обнаруженные tests проекта.
Для go.work отдельный launch.json или открытие каждого модуля не нужны.
Run all использует штатный Neotest fallback по файлам; команды выполняются
последовательно, чтобы большой workspace не создавал сразу множество процессов.
Семантика самих Go tests остаётся обычной. Такой запуск может быть медленнее
одной команды на модуль, зато UI отвечает и Output сохраняет реальный fail.

IDE-TEST-7/§207: Windows12 PASS/Ubuntu12 PASS в selected наборе Go.work Tests,
прежних Go/DAP и рабочих панелей. Три tests двух модулей обнаружены до открытия
shared; nearest/file/all, исправление fail и public native suite проверены
с реальными счётчиками запусков. Mac/physical отдельно.
Команда: `nvim -l tests/e2e/go-workspace-tests.test.lua` с готовым test-deps SDK.

Постоянный regression: `tests/e2e/go-passive.test.lua` (IDE-BOOT-4). Он
использует настоящий Go/Delve/gopls, включая отсутствующий SDK, явную версию,
старый реальный ответ после смены контекста и late override/F5/breakpoint.
Проверяется и перезапуск настоящего gopls через GoToolchain. Зависимости
предварительно готовятся штатными prepare scripts, обычный старт
редактора не запускает установку.

Из корня checkout на Windows:

```powershell
$env:TEMP='F:/repo/forge-nvim/.tests/tmp'
$env:TMP=$env:TEMP; $env:TMPDIR=$env:TEMP
$env:NVIM_LOG_FILE="$env:TEMP/go-passive.log"
$env:GOMAXPROCS='2'; $env:GOFLAGS='-p=2'
. ./scripts/lib/nvim-sdk.ps1
$forgeNvim=Get-ForgeNvim (Get-Location).Path
& $forgeNvim -l tests/e2e/go-passive.test.lua
```

Ubuntu/macOS: `nvim -l tests/e2e/go-passive.test.lua` с подготовленным SDK.
Общие команды и platform gates — [E2E README](../tests/e2e/README.md).
Результаты отмечаются только после фактического native запуска; Mac/GUI
не заменяются Windows/Ubuntu. Glance/Outline — отдельные IDE-083/084.
