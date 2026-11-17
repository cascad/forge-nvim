# Выбор установленного Go/Rust SDK

`Space l S` или `:ForgeSdk` открывает выбор языка и области настройки.
Быстрый вход: `:ForgeSdk go project`, `:ForgeSdk rust user`.
Это выбор уже установленной среды; меню не устанавливает и не обновляет SDK.

В списке показаны проверенная версия, executable и источник. Можно выбрать
найденную установку, «Указать путь…», «Обновить список» или «Авто». Поиск и
проверки CLI асинхронные, с ограничением времени/параллельности; обычный startup
этот поиск не запускает. Неполная папка Go wrapper без SDK не считается SDK.

После выбора доступны «Сохранить и переоткрыть проект» и «Сохранить для следующего
запуска». Переоткрытие использует штатный Neovim restart и существующее
восстановление сессии. Изменённые файлы сохраняются обычным механизмом проекта.
Активные debug/tests/tasks/terminal блокируют переоткрытие; сначала завершите
их. `:ForgeSdkApply` повторяет применение сохранённого выбора. Само сохранение
не переключает уже работающие LSP, программы или отладчик.
Действия и ошибки доступны в общей консоли: `:ForgeLogs events:SDK`.

## Где хранится выбор

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

## Целевой regression

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
