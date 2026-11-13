# Bash: язык, запуск и Tests

Общий workflow Windows/macOS/Ubuntu использует native Bash, Bash Language
Server, shfmt, ShellCheck и Bats. Открытие файла ничего не скачивает.
Bash LSP можно держать в node_modules корня смешанного repo без package.json:
переданный language root сохраняется при поиске tools (IDE-120/§209).

Инструменты готовятся явно: например, `:MasonInstall bash-language-server
shfmt shellcheck` и `:TSInstall bash`. Language server требует Node.js 20+.
Bats — script из [официального проекта](https://github.com/bats-core/bats-core),
project `node_modules/bats/bin/bats` либо `FORGE_BATS_EXECUTABLE`.

На Windows используется Git Bash/MSYS/Cygwin; `System32/bash.exe` и
`Sysnative/bash.exe` — WSL launchers, сборка их отвергает. Явный interpreter:
`FORGE_BASH_EXECUTABLE` или `vim.g.forge_bash_executable`. На macOS/Ubuntu —
host Bash; обычный workflow рассчитан на Bash 3.2+. Mac ещё требует проверки.

`gd` / `gr` / `F2` — definition/references/rename; `gl` — диагностика.
`Space l f` / `Shift Alt f` / `:Format` форматируют через shfmt. Явное
сохранение форматирует асинхронно; `.editorconfig` задаёт отступы.
Сервер запускается как native Node + JS entrypoint. Общий Node resolver
понимает project/shared/Mason/global tools; `FORGE_NODE_EXECUTABLE` и
`FORGE_NODE_TOOLS` задают явные пути.

`Space j b` или `:BashRunFile` запускает сохранённый файл из ближайшего
Git root (без Git — каталог script). Аргументы передаются как argv:
`:BashRunFile hello\ world_ü 7`. Bash работает с `--noprofile --norc`,
без `BASH_ENV`/`ENV`. Stdout/stderr и настоящий status — в Tasks:
`Space w b`, выбрать задачу, `Ctrl s` — output, `F7` — код.
Изменённый buffer сначала сохранить: Run читает файл на диске.

`Space w t` — Tests, `Space w r` — Test Output; `Space T t` — nearest,
`Space T f` — file, `Space T A` — root. Adapter обнаруживает `.bats`
по правилам declarations самого Bats, без исполнения script:

```bash
@test "calculates answer" {
  [ "$(calculate_answer 21)" -eq 42 ]
}
function other_test { # @test
  [ 1 -eq 2 ]
}
```

Каждый выбранный test запускается отдельным Bats process с exact regex
filter. Его exit/output принадлежит этому test. Dynamic registration не
входит в discovery. В Git Bash Bats child по умолчанию получает штатный
`MSYS=winsymlinks:lnk`; пользовательский `winsymlinks:` сохраняется.
Права администратора и изменение Windows настроек не нужны. Пути
scripts/temp переводит `cygpath` из того же native SDK.

Bash debug IDE-057/IDE-SH-5 работает через официальный bash-debug (§215).
Windows использует текущий default WSL2 distro (выбран владельцем), Linux/macOS
— native Bash4+. Обычные Tests не создают DAP session; debug nearest Bats
остаётся отдельным неподдержанным действием.

Явная подготовка adapter (Node и WSL/Bash этим не устанавливаются):

```sh
python -B tests/e2e/prepare_bash_dap.py --download
python -B tests/e2e/prepare_bash_dap.py
```

SDK: `.tests/bash-dap-deps/extension/out/bashDebug.js`. Для обычной установки
есть `:MasonInstall bash-debug-adapter`; для своего SDK задайте
`FORGE_BASH_DEBUG_ADAPTER` либо `vim.g.forge_bash_debug_adapter` на этот JS.
Windows использует host Node и штатный WSL launcher adapter, Node внутри
WSL не требуется. Distro/default/mounts сборка не меняет; поддержан native
adapter layout `/mnt/<drive>`. Для нестандартных mounts пути bashdb задаются
явно в launch.json; UNC этим срезом не проверен.

Сохранённый `.sh` → F9 на строке → F5; F5 продолжает, Space d q/Shift-F5
останавливает. Output — общая `Space w c`, переменные/стек — `Space w d`.
Явный case имеет `type: "bashdb"`; args/env/cwd/pathBash/terminalKind
пользователя сохраняются. Default `terminalKind: "integrated"` и
`console: "integratedTerminal"` используют общий DAP PTY; stdout остаётся
видимым после завершения. Для Watch: `Space d w` → `$answer`, Evaluate — `Space d e`.
Mac: `FORGE_BASH_DEBUG_BASH` или launch.json `pathBash` на Bash4+; системного
Bash3.2 недостаточно, Brew Bash ищется по стандартным путям при debug.

Ограничение готового bundle: Locals содержит главным образом `$PWD` и `$?`.
Остальные значения смотрятся через Watch/Evaluate (`$answer`), полный список
переменных не эмулируется. Runtime не устанавливает adapter и не запускает
WSL до debug. Native workflow, missing adapter/Node и14 Bash/DAP controls —
17 distinct PASS Windows+WSL2 и17 Ubuntu. Mac/physical/cold distro startup
и interactive stdin отдельно. Opt-in `terminalKind: "debugConsole"` с
`console: "internalConsole"` сохраняется; на Linux bundle0.3.9 пишет native
`/dev/stdin` warning (IDE-127). Он не скрывается, default PTY не выдаёт его.

## Постоянные E2E

Сначала plugins и Node по [инструкции](../tests/e2e/README.md), затем:

```sh
python -B tests/e2e/prepare_bash.py --download --nvim <nvim>
python -B tests/e2e/prepare_bash.py --nvim <nvim>
<nvim> -l tests/e2e/bash-language.test.lua
```

На Ubuntu/macOS — `python3`. На Windows выбрать SDK через `Get-ForgeNvim`
из `scripts/lib/nvim-sdk.ps1`; перед прямым запуском TEMP/TMP/TMPDIR/
NVIM_LOG_FILE задать в `.tests/tmp` на диске checkout. Нужны host native
Bash и C compiler для parser. Явная подготовка переиспользует Node 24.11.0
из `.tests/node-deps`, готовит Bash-LSP 5.8.1 (npm lock), shfmt 3.14.1,
ShellCheck 0.11.0, Bats 1.14.0 и pinned parser. Host SDK не устанавливаются.
Manifest хранит версии/SHA; повтор без `--download` проверяет готовность.
Payload/cache/build — `.tests/bash-deps`; private editor — `.tests/tmp`.
`--output`/`FORGE_E2E_BASH_DEPS` задают другой подготовленный каталог,
`FORGE_BASH_CASE` фильтрует UI cases по имени.

Для Ubuntu image tools готовятся при явном build. Desktop/WSL ради
проверки не запускаются. Mac/GUI/Bash 3.2/DAP не становятся PASS по Windows.
