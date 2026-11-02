# Диагностика native terminal и CLI

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
Параллельный builder не меняет тот же source; manifest не готов до успешных
build/install и 50 циклов core probe. Launcher читает lock/manifest,
проверяет source/patch/binary SHA256; missing/stale/corrupt SDK даёт ошибку
с командой подготовки. Системный Neovim/PATH/установленный конфиг не меняются.
Прямой `nvim` использует прежнюю системную программу.

Lock и единственный patch: `scripts/sdk/windows.json`,
`scripts/sdk/neovim-conpty-lifecycle.patch`. Патч убирает опубликованный
указатель до запуска background free/nested uv_run и игнорирует поздний
resize закрытого ConPTY. В общем Lua UI нет платформенного обхода.
LF патча зафиксирован .gitattributes, чтобы SHA256 не зависел от autocrlf.
Metadata описывает происхождение локальной сборки, не цифровую подпись.
ConPTY набор общего runner тоже получает выбранный SDK и частный профиль
с pinned plugins. Реальные stdpath config/data/cache/state и неизменность
source lock проверяются; пользовательский каталог плагинов не используется.
При upstream исправлении SDK/patch убирается отдельным change с тем же E2E.

A/B из одного builder, upstream сохраняется отдельно от рабочего SDK:

```powershell
powershell -NoProfile -File tests/diagnostics/build-conpty-sdk.ps1 -Variant upstream -Download
$forgeUpstream=(Resolve-Path .tests/neovim-native/upstream/bin/nvim.exe).Path
nvim -l tests/diagnostics/terminal-resize.lua --nvim $forgeUpstream
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
