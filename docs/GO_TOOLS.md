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
