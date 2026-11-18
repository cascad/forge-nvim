# Выбор установленной языковой среды

`Space l S` или `:ForgeSdk` открывает выбор языка и области настройки.
Языки: Go, Rust, Python, Node. Быстрый вход: `:ForgeSdk go project`,
`:ForgeSdk rust user`, `:ForgeSdk python project`, `:ForgeSdk node user`.
Это выбор уже установленной среды; меню не устанавливает и не обновляет SDK.

В списке показаны проверенная версия, executable и источник. Можно выбрать
найденную установку, «Указать путь…», «Обновить список» или сброс выбора. Поиск и
проверки CLI асинхронные, с ограничением времени/параллельности; обычный startup
этот поиск не запускает. Неполная папка Go wrapper без SDK не считается SDK.

После выбора можно переоткрыть проект или только сохранить настройку для
следующих запусков. Переоткрытие использует штатный Neovim restart и существующее
восстановление сессии. Изменённые файлы сохраняются обычным механизмом проекта.
Активные debug/tests/tasks/terminal блокируют переоткрытие; сначала завершите
их. `:ForgeSdkApply` повторяет применение сохранённого выбора. Само сохранение
не переключает уже работающие LSP, программы или отладчик.
Действия и ошибки доступны в общей консоли: `:ForgeLogs events:SDK`.

## Где хранится выбор

Этот раздел описывает Go/Rust. Python/Node используют прежний tools.json,
см. отдельный раздел ниже; настройки между файлами не дублируются.

- Пользователь: `sdk.json` в `:echo stdpath('config')`, для установленного fride
  отдельно от обычного nvim и конфигурации kit.
- Проект: `.fride/sdk.json` ближайшего корня `.git`/`.fride`.
- Приоритет: project key → user key → исходное окружение.

Пример; замените пути существующими путями своей машины:

```json
{
  "version": 1,
  "sdks": {
    "go": "D:/SDK/Go1.26",
    "rust": "C:/Users/me/.rustup/toolchains/stable-x86_64-pc-windows-msvc"
  }
}
```

При ручном вводе подходят SDK root, его `bin` либо native `go`, `rustc`/`cargo`
executable. Меню проверяет установку и сохраняет её фактический root. Пробелы
не требуют shell-кавычек. В JSON относительный путь проекта считается от корня
проекта, пользовательский — от каталога sdk.json; поддерживается `~`.

`"go":"auto"` в проекте явно выбирает исходное окружение, даже если user
выбрал конкретный Go. Отсутствующий project key наследует user. Для возврата
к user удалите только соответствующий project key. Неверный путь отклоняется
с указанием источника, другая копия молча не выбирается. Ошибочный JSON надо
исправить в файле; меню его не затирает.

## Как применяется среда

Без настроек сохраняются обычные PATH, Go toolchain и rustup/project rules.
Явный Go выбирает bin/GOROOT и `GOTOOLCHAIN=local`: проект, которому нужен
более новый Go, получит обычную ошибку Go вместо загрузки другой версии.
Явный Rust выбирает native bin/compiler и абсолютный `RUSTUP_TOOLCHAIN`;
автоматическая установка отсутствующего toolchain отключается для этого выбора.
«Авто» и переход проекта восстанавливают исходную среду, затем применяют
настройки нового проекта.
Обычный `:cd` не переоткрывает проект и не переключает SDK; используйте
штатное открытие проекта или явный `:ForgeSdkApply`.

Меняются только переменные процесса fride и его дочерних процессов. Системный
PATH, profiles, настройки менеджеров, CARGO_HOME/RUSTUP_HOME/GOPATH, SDK installs
и внешние терминалы не изменяются. Native adapters продолжают вызывать обычные
go/cargo; отдельные overrides их private API не нужны. Настройки LSP/DAP/
форматтеров остаются в [tools.json](TOOL_PATHS.md), независимо от SDK.

Native interfaces: [Go toolchains](https://go.dev/doc/toolchain),
[rustup environment](https://rust-lang.github.io/rustup/environment-variables.html),
[Neovim restart](https://neovim.io/doc/user/gui/#%3Arestart).
Поддержка произвольного SDK не означает совместимость любой версии LSP/Delve/
CodeLLDB с ним: ограничения upstream tools сохраняются. Их update/provider policy
остаётся отдельным пунктом плана. Старый `:GoToolchain` сохраняет прежнее явное
поведение Go, включая возможную загрузку запрошенной отсутствующей версии.

## Python и Node через общие настройки

В меню выберите Python/Node, затем project/user. При ручном вводе подходит
executable либо корень SDK/venv; для Python также каталог Scripts/bin.
Venv symlink сохраняется как путь venv, поэтому interpreter получает её prefix.
Список проверяет текущий выбор, active/project venv и доступные PATH/native
manager directories. Другую установку можно указать вручную. WindowsApps
aliases не предлагаются как установленный SDK.

Выбор записывается в ключ `python` или `node` существующего user/project
[tools.json](TOOL_PATHS.md). Другие tools и metadata сохраняются. `sdk.json`
остаётся только для Go/Rust. «Сбросить выбор — наследовать настройки и среду»
удаляет ключ только выбранной области: project снова наследует user, затем
прежние legacy/native rules. Это отличается от Go/Rust «Авто», явно выбирающего
исходное окружение даже поверх user choice.

«Сохранить для следующих запусков задач» обновляет выбор существующих языковых
резолверов: следующие Python/Node workflow читают его сами. Уже работающие LSP,
отладка и процессы продолжают использовать свою среду. Для полного обновления
выберите «Сохранить и переоткрыть проект» или позже `:ForgeSdkApply`.
Python active/project venv priority, явный Pyright pythonPath, Node project-local
tools и настройки конкретного запуска сохраняют прежние правила.
PATH, VIRTUAL_ENV/CONDA_PREFIX, npm/pip homes и SDK installations меню не меняет.
Corrupt JSON не перезаписывается; invalid path не заменяется другим SDK.

## Выбранная среда при подготовке tools

Явный tools setup читает те же Python/Node overrides до загрузки Mason.
В PATH только этого setup процесса добавляются native SDK bin directories;
остальные процессы fride, системный PATH и SDK homes не меняются. Отчёт
`Setup SDK selection` в setup-tools.log показывает path/source.

Штатный Python provider ищет python/python3, Node provider — node/npm.
Если произвольно названный executable нельзя представить этими командами либо
рядом с выбранным Node нет npm, setup остановится до установки. Создавать shim
или молча брать другую системную копию он не будет. Native Mason сохраняет
собственные правила совместимости пакетов, включая подбор совместимого Python.
Для SQL/Core без зависимости от этих SDK соответствующие paths не читаются.

Go/Rust по-прежнему применяются early SDK init; build toolchain/download policy
не менялась. Старый installer `--sdk-path` остаётся fallback directory после
PATH; это пока отдельный контракт, а не typed persistent SDK selector. Следующий
шаг — согласовать preflight/frontend с runtime settings, не дублируя резолверы.

Проверки законченного блока и полный regression: [TESTING_WORKFLOW](TESTING_WORKFLOW.md).

## Целевой regression

### Python и Node — IDE-BOOT-38

Нужны подготовленные editor/Node deps и обычный native Python. Новые SDK тест
не устанавливает. Реальная venv без pip создаётся только в private test runtime.

```powershell
$env:FORGE_TEST_ID='IDE-BOOT-38'
& .tools/neovim/windows-x64/bin/nvim.exe -l tests/e2e/python-node-sdk-picker.test.lua
```

```sh
FORGE_TEST_ID=IDE-BOOT-38 nvim -l tests/e2e/python-node-sdk-picker.test.lua
docker compose -f tests/containers/compose.yaml run --rm --no-deps --pull never -e FORGE_TEST_ID=IDE-BOOT-38 --entrypoint bash ubuntu tests/containers/tool-paths.sh tests/e2e/python-node-sdk-picker.test.lua
```

Для повтора одного случая: `FORGE_RUNTIME_SDK_CASE='common menu'` либо
`'native TUI'`. Native Mac отдельно. Артефакты содержат python-runtime.json,
node-runtime.json или runtime-sdk-native.json, снимки UI и shutdown.json.

### Go и Rust — IDE-BOOT-37

Нужны подготовленные editor/LSP/test/Rust/DAP deps и две существующие версии
Go и Rust. Пути можно задать переменными `FORGE_SDK_GO_OLD`, `FORGE_SDK_GO_NEW`,
`FORGE_SDK_RUST_OLD`, `FORGE_SDK_RUST_NEW` (SDK roots). Это тестовые параметры,
они не являются пользовательской конфигурацией fride. На macOS задайте пути
своих двух native SDK; установку пользовательской среды тест не выполняет.

```powershell
$env:FORGE_TEST_ID='IDE-BOOT-37'
& .tools/neovim/windows-x64/bin/nvim.exe -l tests/e2e/sdk-selection.test.lua
```

```sh
FORGE_TEST_ID=IDE-BOOT-37 nvim -l tests/e2e/sdk-selection.test.lua
```

Для существующего Ubuntu image есть **отдельная явная подготовка стенда**:

```powershell
docker run --rm --cpus=2 --memory=2g --network bridge --mount 'type=bind,source=F:/repo/forge-nvim,target=/workspace,readonly' --mount 'type=bind,source=F:/repo/forge-nvim/.tests/ubuntu,target=/workspace/.tests' --workdir /workspace --entrypoint bash forge-nvim-tests:ubuntu24.04-nvim0.12.2 tests/containers/prepare-sdk-selection.sh
```

Она использует штатные Go/rustup для тестовых Go1.23.3/Rust1.91.1; caches/homes
живут только в `.tests/ubuntu/sdk selection` на F. Системные SDK и image не
меняются. Это подготовка тестов, она не вызывается редактором или установщиком.
Путь репозитория в mounts заменяется для своей машины. Затем прогон без сети:

```sh
docker compose -f tests/containers/compose.yaml run --rm --no-deps --pull never -e FORGE_TEST_ID=IDE-BOOT-37 --entrypoint bash ubuntu tests/containers/tool-paths.sh tests/e2e/sdk-selection.test.lua
```

Артефакты — `.tests/editor-e2e` / `.tests/ubuntu/editor-e2e`, включая
sdk-selection.json с native PIDs, выбранными executable и compiler versions.
macOS acceptance выполняется отдельно владельцем.

## Проверено 2026-11-17

Python/Node (§272): Windows/Ubuntu по2 новых E2E и5 controls PASS. Настоящее
меню, venv с пробелами и сохранением prefix, NodeRunFile, user/project/reset/
cancel/invalid/corrupt, соседние JSON keys/metadata и отсутствие startup probes.
Native TUI: три процесса редактора, восстановление файла/курсора после двух
применений, active task guard; shutdown exit0/signal0/active_after0, без hardkill.
Controls: прежние tool paths4 и Go/Rust menu1. Native Mac отдельно.

Windows и Ubuntu: по два E2E PASS — настоящее меню и native TUI с восемью
процессами редактора через restart (ОС может повторно использовать старый PID).
Проверены Go1.23.3/1.26.0 и Rust1.91.1/1.96.1,
ручной путь с пробелами, сохранение/отмена/ошибки, project/user/«Авто», переход
между проектами, сохранение курсора и фактические LSP/run/tests/debug.
Активные задачи и реальные Neotest tests блокируют SDK apply. Установок из
редактора — ноль. Отдельно прошли GoToolchain и восстановление project session.
Полный регресс и native macOS этим прогоном не заявляются.

На Windows Rust/MSVC оставил VCTIP.EXE после завершения редакторов. Стенд
разрешает этот helper только по явной настройке данного E2E, проверив точный
состав принадлежащего тесту Windows Job и путь MSVC. Затем закрывает свой Job;
active_after=0. Неизвестные процессы по-прежнему проваливают проверку; обычные
session E2E требуют полного естественного завершения без этой оговорки.
Системные настройки MSVC/SDK и чужие процессы тест не меняет.
