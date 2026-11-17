# Установка и обновление языковых инструментов

Обновлено: 2026-11-17. Основа для обсуждения установки fride на Windows,
macOS и Ubuntu. Описаны Go, Rust, Python, JavaScript/Node.js, Bash и SQL.
Базовый подход выбран владельцем 2026-11-17; план реализации описан в конце.
Первый runtime-срез настройки путей реализован (§265); поведение установщика
этим срезом не изменяется.

Главный вывод: единого способа установки всех языков нет. Обычно редактор
использует менеджеры соответствующих экосистем, готовые upstream-пакеты и
собственные расширения. Поддерживать свой набор сборок всех LSP для каждой ОС
для этого не обязательно. Сначала следует определить ответственность каждого
участника: SDK проекта, менеджера инструментов и самой IDE.

## Что именно устанавливается

| Слой | Примеры | Для чего нужен |
|---|---|---|
| SDK или среда выполнения | Go, Rust/Cargo, Python, Node, Bash | Сборка и запуск пользовательского проекта |
| Окружение проекта | Python venv, npm dependencies, выбранный Rust toolchain | Версии и библиотеки конкретного репозитория |
| Языковой сервер LSP | gopls, rust-analyzer, Pyright, typescript-language-server | Навигация, completion, диагностика, переименование |
| Отладчик и адаптер DAP | Delve, CodeLLDB, debugpy, js-debug | Breakpoints, переменные, stack trace, управление выполнением |
| Форматтеры и линтеры | gofumpt, rustfmt, Ruff, Prettier, ShellCheck, sqruff | Форматирование и дополнительные проверки |
| Средства тестирования | go test, cargo test, pytest, npm scripts, SQLLogicTest runner | Запуск и разбор результатов тестов |

Версия SDK проекта и версия компилятора, которым собран инструмент IDE,
могут различаться. Готовый инструмент также может требовать установленную
среду выполнения: например, JavaScript LSP требует Node. Установка готового
пакета сама по себе не означает отсутствие внешних зависимостей.

Принятая владельцем граница fride: Neovim, плагины и IDE tools принадлежат
отдельному приложению fride; языковые SDK, активные окружения и настройки
проектов переиспользуются штатно. Подробности — [SDK_STATE](SDK_STATE.md).

## Что делает Mason

Mason управляет LSP, DAP, форматтерами и линтерами в каталоге данных Neovim.
Способ получения конкретного пакета определяется его registry definition.
Есть пакеты с готовыми GitHub assets, пакеты npm/PyPI и инструменты,
устанавливаемые через Go. Поэтому «Mason» и «готовые программы» не являются
взаимоисключающими вариантами. [Документация Mason](https://github.com/mason-org/mason.nvim).

Примеры действующих определений:

| Пакет | Способ получения в Mason | Внешняя зависимость |
|---|---|---|
| gopls | Go module provider | Go для установки и работы с проектом |
| rust-analyzer | Готовый платформенный asset | Rust/Cargo для анализа Rust проекта |
| Pyright | npm package | Node/npm |
| debugpy | PyPI package в окружении инструмента | Подходящий Python; наличие wheel зависит от платформы/версии |
| Ruff | Готовый платформенный asset | Rust SDK для этого способа установки не нужен |
| typescript-language-server | npm package | Node/npm и TypeScript |
| Bash language server | npm package | Node/npm |
| sqruff | Готовый платформенный asset | Rust SDK для этого способа установки не нужен |

Это сведения о механизмах, а не закрепление последних номеров пакетов.
Источник определения: [Mason Registry](https://github.com/mason-org/mason-registry/tree/main/packages),
в частности [gopls](https://github.com/mason-org/mason-registry/blob/main/packages/gopls/package.yaml),
[debugpy](https://github.com/mason-org/mason-registry/blob/main/packages/debugpy/package.yaml),
[Ruff](https://github.com/mason-org/mason-registry/blob/main/packages/ruff/package.yaml)
и [sqruff](https://github.com/mason-org/mason-registry/blob/main/packages/sqruff/package.yaml).

Основные команды Neovim:

```vim
:Mason
:MasonInstall gopls
:MasonInstall gopls@v0.23.0
:MasonUpdate
:MasonLog
```

`:MasonUpdate` обновляет реестры, а не все установленные инструменты. Обновление
пакетов выполняется отдельно через Mason UI или установку выбранной версии.
В UI доступны проверки новых версий и обновление установленных пакетов.
[Команды Mason](https://github.com/mason-org/mason.nvim/blob/main/doc/mason.txt).

Команды ниже показывают штатные операции экосистем. Это справочные примеры,
а не команды, автоматически исполняемые fride при открытии проекта.

## Установка SDK на разных системах

Сначала используется уже выбранный пользователем SDK. Следующая таблица
показывает обычные каналы установки, если подходящего SDK ещё нет.

| Среда | Windows | macOS | Ubuntu |
|---|---|---|---|
| Go | Официальный installer либо выбранный системный менеджер | Официальный package либо выбранный менеджер | Официальная поставка либо пакет дистрибутива с проверкой версии |
| Rust | rustup; для MSVC target также нужны соответствующие C++ build tools | rustup и необходимые системные linker tools | rustup и необходимые системные linker tools |
| Python | Python install manager/поставка python.org либо существующий менеджер окружений | Поставка python.org либо существующий менеджер | Обычно Python дистрибутива и пакет поддержки venv |
| Node/npm | Официальная поставка либо существующий Windows version manager | Официальная поставка либо существующий version manager | Поставка Node либо существующий version manager; версия пакета дистрибутива проверяется отдельно |
| Bash | Git Bash для подходящих локальных сценариев; WSL2 для Linux backend отладчика | Системный Bash либо выбранная версия | Bash дистрибутива |
| SQL | Зависит от конкретной СУБД; универсального SDK нет | То же | То же |

Здесь не предлагается устанавливать ещё один менеджер поверх существующего.
Версии в пакетах ОС могут отличаться от требований проекта или IDE tool.
Выбор менеджера и смена системного SDK должны оставаться явными действиями.
Источники: [Go installation](https://go.dev/doc/install),
[rustup installation](https://rust-lang.github.io/rustup/installation/index.html),
[Rust Windows prerequisites](https://rust-lang.github.io/rustup/installation/windows-msvc.html),
[Python Windows](https://docs.python.org/3.14/using/windows.html),
[Python virtual environments](https://packaging.python.org/en/latest/guides/installing-using-pip-and-virtual-environments/),
[Node/npm installation](https://docs.npmjs.com/downloading-and-installing-node-js-and-npm/),
[WSL](https://learn.microsoft.com/en-us/windows/wsl/install).

## Go

### SDK проекта и установка инструментов

В Go нужно различать три версии: компилятор для сборки gopls, Go в окружении
работающего gopls и версию языка проекта. Их совместимость описывает сам
[gopls](https://go.dev/gopls/#supported-go-versions).

Обычные upstream-команды установки инструментов:

```sh
go install golang.org/x/tools/gopls@latest
go install github.com/go-delve/delve/cmd/dlv@latest
```

`@latest` означает явный запрос актуальной версии в момент установки; для
воспроизводимой установки вместо него указывается конкретный tag. Результат
попадает в обычное место установки Go tools, определяемое GOBIN/GOPATH.
Менеджер IDE может задавать каталог назначения только для этой операции.
[Установка gopls](https://go.dev/gopls/), [установка Delve](https://github.com/go-delve/delve/blob/master/Documentation/installation/README.md).

Начиная с Go 1.21 штатный механизм toolchain selection позволяет Go выбрать
или скачать более новый компилятор. Это зависит от GOTOOLCHAIN и требований
модуля. При `GOTOOLCHAIN=local` используется только имеющийся toolchain;
`auto` допускает автоматический выбор. Форма `go install package@version`
не работает как изменение зависимостей текущего проекта и не добавляет ему
строку toolchain. Проверка скачиваемого toolchain требует checksum database:
при `GOSUMDB=off` такая загрузка завершается ошибкой.
[Go toolchains](https://go.dev/doc/toolchain).

### Как это делает VS Code

Go-расширение предлагает установку отсутствующих инструментов и команду
`Go: Install/Update Tools`. Оно вызывает `go install` и задаёт
`GOTOOLCHAIN=auto` в отдельном окружении установки. Можно выбрать Go для
установки tools отдельно через `go.toolsManagement.go`.
[Код установки](https://github.com/golang/vscode-go/blob/master/extension/src/goInstallTools.ts),
[окружение установки](https://github.com/golang/vscode-go/blob/master/extension/src/goEnv.ts).

Таким образом, VS Code не обязан сам публиковать gopls для каждой ОС:
сборку и получение зависимостей выполняет Go. При необходимости новый
компилятор для установки tool скачивает штатный Go-механизм; это отличается
от замены основного SDK пользователя в PATH.

### Что важно для fride

Сейчас fride фиксирует `gopls v0.23.0` и несколько дополнительных Go tools.
Для их сборки explicit setup требует Go 1.26+ и задаёт `GOTOOLCHAIN=local`.
Это наше текущее ограничение установки, а не универсальное требование языка.
См. [catalog](../nvim_forge/lua/forge/tool_catalog.lua),
[build check](../nvim_forge/lua/forge/setup_readiness.lua),
[setup stage](../nvim_forge/scripts/setup-stage.lua) и
[go.mod выбранного gopls](https://github.com/golang/tools/blob/gopls/v0.23.0/gopls/go.mod).

Ручная команда Mason и наш setup — разные пути. Закреплённый Go provider
Mason вызывает go install и выбирает GOBIN для пакета; сам этот provider
не задаёт GOTOOLCHAIN. Поэтому ограничение нашего setup нельзя приписывать
любой ручной установке Mason: важно её унаследованное окружение.
[Исходник закреплённого provider](https://github.com/mason-org/mason.nvim/blob/e54f5bf5f12c560da31c17eee5b3e1bd369f3ff9/lua/mason-core/installer/managers/golang.lua).

Проверка готового gopls с обычным Go 1.23.3 нашла типовую ошибку и перестала
сообщать её после исправления. Это пример работоспособности, а не гарантия
полной поддержки старого SDK: у gopls есть собственная политика совместимости.

При обсуждении нужно отдельно решить, разрешать ли штатную загрузку build
toolchain при явной установке tools. Запрет внезапных загрузок до приглашения
shell и при обычном запуске IDE не требует автоматически запрещать такую
операцию после осознанного запроса пользователя. Глобальные GOENV/GOTOOLCHAIN,
GOSUMDB, go.mod и go.work для этого менять не требуется.

Пример явной установки IDE tools через Mason:

```vim
:MasonInstall gopls delve gofumpt golines golangci-lint gotestsum
```

## Rust

### SDK и компоненты

Штатный rustup управляет rustc, Cargo и компонентами. Выбор зависит от override,
переменных окружения и `rust-toolchain.toml`; fride должен учитывать выбранный
проектом toolchain. Для него добавляются нужные компоненты:

```sh
rustup show
rustup component add rust-src rustfmt clippy
cargo check
cargo test
```

Добавление компонентов выполняется явно в контексте нужного проекта/toolchain.
Это установка частей SDK, а не LSP. Наличие готового rust-analyzer не заменяет
Rust SDK, исходники стандартной библиотеки или linker, нужные самому проекту.
[Выбор toolchain](https://rust-lang.github.io/rustup/overrides.html),
[компоненты rustup](https://rust-lang.github.io/rustup/concepts/components.html).

### LSP и отладчик

VS Code Rust Analyzer поставляет бинарник rust-analyzer с расширением.
В других редакторах можно использовать готовый upstream binary или менеджер
пакетов. Rust Analyzer также может пытаться автоматически добавить rust-src;
эту возможность следует учитывать в политике загрузок fride.
[Установка rust-analyzer](https://rust-analyzer.github.io/book/installation.html).

Для отладки наша сборка использует CodeLLDB — отдельный DAP-компонент со своими
платформенными зависимостями. Форматирование и Clippy обычно берутся из
выбранного Rust toolchain. Компилировать rust-analyzer самим только ради
Neovim обычно не требуется. [CodeLLDB](https://github.com/vadimcn/codelldb).

Новое Rust SDK и новый rust-analyzer выходят независимо. Для старого или
nightly toolchain может потребоваться совместимая версия сервера, а не
безусловная установка latest. Поиск SDK также не должен незаметно вызывать
скачивание недостающего toolchain через rustup.

Пример явной установки IDE tools через Mason:

```vim
:MasonInstall rust-analyzer codelldb
```

## Python

### Интерпретатор и окружение проекта

Сначала выбирается Python проекта: существующая venv, Conda, uv или другой
используемый проектом менеджер. Когда проекту действительно нужна новая venv,
обычные команды такие:

```sh
# Linux/macOS
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
```

```powershell
# Windows, если выбран подходящий python
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements.txt
```

Эти команды создают окружение и устанавливают зависимости проекта. IDE не
должна запускать их только из-за открытия каталога. Имя requirements.txt —
пример; проект может использовать pyproject.toml и другой lock/менеджер.
[Python Packaging Guide](https://packaging.python.org/en/latest/guides/installing-using-pip-and-virtual-environments/).

В VS Code выбранный interpreter используется для запуска, debugging и
языковых возможностей; для отладки его можно переопределить. Это полезный
референс для единого выбора Python во fride.
[Python environments](https://code.visualstudio.com/docs/python/environments).

### Языковой сервер и инструменты

В нашей сборке используются Pyright, Ruff и debugpy. Для Pyright необходим
Node: официальный npm-вариант использует Node/npm. Python-пакет-обёртка Pyright
тоже может автоматически устанавливать Node, поэтому выбор pip-обёртки не
устраняет эту зависимость. VS Code обычно использует Pylance, включающий
Pyright; это не требование заменять наш сервер.
[Pyright installation](https://github.com/microsoft/pyright/blob/main/docs/installation.md).

Ruff доступен через готовые binaries и Python packaging. Установка готового
пакета не требует Rust SDK пользователя. Если используется проектная версия
Ruff, её следует согласовать с проектом, а не незаметно заменить другой.
[Ruff installation](https://docs.astral.sh/ruff/installation/).

Debugpy можно установить в отдельную venv инструмента; Python отлаживаемого
приложения при этом выбирается отдельно. Для remote attach с запуском через
`python -m debugpy` пакет нужен в том окружении, где выполняется эта команда.
Нельзя считать установку debugpy в одну venv установкой во все окружения.
[Debugpy](https://github.com/microsoft/debugpy),
[nvim-dap-python](https://github.com/mfussenegger/nvim-dap-python#debugpy).

Для Neovim штатный путь — Mason для этих IDE tools и существующий Python
проекта для run/debug/tests. На Ubuntu нужно сохранять системный Python;
пакеты приложения не устанавливаются глобальным pip поверх него. Отдельная
venv инструмента относится к IDE, проектная venv — к проекту.

Пример явной установки IDE tools через Mason:

```vim
:MasonInstall pyright ruff debugpy
```

## JavaScript и Node.js

### Runtime и зависимости проекта

Используется выбранный Node и соответствующий npm/package manager. Уже
существующий version manager переиспользуется. Версия Node может быть задана
соглашениями проекта; зависимости определяются package.json и lockfile.
[npm о Node и version managers](https://docs.npmjs.com/downloading-and-installing-node-js-and-npm/).

```sh
node --version
npm --version
npm ci
```

`npm ci` уместен при наличии соответствующего package-lock.json и явном запросе
установить зависимости. Он меняет node_modules и не является действием
обычного открытия проекта. Для pnpm/yarn используются команды самого проекта.

### Языковой сервер и отладка

VS Code содержит TypeScript Language Features, работающий через tsserver.
Для LSP-редакторов typescript-language-server предоставляет соответствующий
LSP-интерфейс. В Neovim можно устанавливать его штатно через Mason; Node
остаётся внешним runtime. Версию TypeScript проекта нужно учитывать отдельно
от версии сервера IDE.
[TypeScript Language Server](https://github.com/typescript-language-server/typescript-language-server).

Js-debug уже входит в VS Code. Upstream также публикует standalone DAP server,
который могут использовать другие редакторы, включая Neovim. В нашей сборке
для него используется js-debug-adapter; собственный debugger не нужен.
[Microsoft js-debug](https://github.com/microsoft/vscode-js-debug).

Prettier рекомендует проектную установку с закреплённой версией. Запуск
случайного latest через npx может скачать другой formatter и изменить результат.
Для fride нужно явно согласовать приоритет проектной версии и IDE fallback.
Сейчас formatter подключён через [forge.node](../nvim_forge/lua/forge/node.lua).
[Prettier installation](https://prettier.io/docs/install.html).

Обновление Node, npm dependencies проекта, TypeScript LSP и DAP — разные
операции. Обновление одного пакета IDE не должно выполнять npm update в проекте.

Пример явной установки IDE tools через Mason:

```vim
:MasonInstall typescript-language-server js-debug-adapter prettier
```

## Bash

### Shell и инструменты

Для выполнения нужен выбранный Bash. Системный Bash macOS может отличаться
от Bash в Ubuntu или WSL; редактор должен показывать реально выбранную среду.
Git Bash подходит для части Windows-сценариев, но не заменяет автоматически
Linux-среду Bash debugger.

Bash language server устанавливается как npm package и требует Node.
ShellCheck и shfmt — отдельные программы; их можно получать готовыми из
Mason, upstream releases или пакетов ОС. Go для сборки shfmt и Haskell для
сборки ShellCheck нужны только при выборе соответствующей сборки из исходников.
[Language server](https://github.com/bash-lsp/bash-language-server),
[ShellCheck](https://github.com/koalaman/shellcheck#installing),
[shfmt](https://github.com/mvdan/sh#shfmt).

Для анализа Bash-файлов во fride достаточно выбранных language tools; установка
Node ради LSP должна быть видимой зависимостью. Bats или другой тестовый runner
добавляется по потребностям проекта, а не как универсальная часть Bash SDK.

### Отладка на Windows

Используемый Bash Debug построен поверх bashdb, который входит в пакет
адаптера. Для Windows его upstream-инструкция предполагает WSL. Во fride уже
выбран WSL2 backend; Node adapter, Linux Bash/bashdb и преобразование путей
нужно проверять вместе. Автоматически переустанавливать WSL или Docker для
этого не требуется. [Bash Debug](https://github.com/rogalmic/vscode-bash-debug),
[текущая интеграция](../nvim_forge/lua/forge/bash_debug.lua).

Пример явной установки IDE tools через Mason:

```vim
:MasonInstall bash-language-server shellcheck shfmt bash-debug-adapter
```

## SQL

### СУБД и поддержка редактора

У SQL нет общего SDK, который нужно установить для всех проектов.
Выбираются диалект, подключение к конкретной СУБД и, при необходимости,
локальный клиент или драйвер. Удалённая БД не требует автоматически ставить
такую же СУБД локально. Для форматирования и части статических проверок
соединение с БД вообще не обязательно.

SQLTools в VS Code использует отдельные driver extensions для разных СУБД.
Это пример специализированной интеграции, а не универсального Go/Rust
тулчейна для SQL. [SQLTools](https://github.com/mtxr/vscode-sqltools).

### Текущие инструменты fride

В сборке используются sqruff, sqls и собственный forge-sqltest. Sqruff —
готовый SQL formatter/linter; Mason имеет платформенные assets, поэтому
Rust SDK пользователю для его установки не требуется.
[Sqruff](https://github.com/quarylabs/sqruff),
[Mason package](https://github.com/mason-org/mason-registry/blob/main/packages/sqruff/package.yaml).

Upstream sqls можно собрать через Go, но наш accepted вариант содержит
конкретный patch и имеет версию `0.2.48+forge.1`. Вместе с forge-sqltest он
уже выделен в native SQL part. Это существующий отдельный случай поставки;
обычный stock sqls нельзя объявлять его эквивалентом без проверки patch.
[Upstream sqls](https://github.com/sqls-server/sqls),
[наш patch/policy](../scripts/sdk/sqls.json),
[SQL runner](../scripts/sdk/sql-test/README.md).

Наличие Go/Rust в исходниках этих tools не означает необходимость ставить
обоих компиляторов пользователю SQL. Они нужны там, где выполняется сборка.
Runtime-зависимости готовых binaries, диалект и доступ к БД проверяются отдельно.

Пример явной установки IDE tools через Mason:

```vim
:MasonInstall sqruff
```

Sqls с нашим patch и forge-sqltest доставляются существующим native SQL part;
их установка описана в [плане](INSTALLATION_PLAN.md).

## Что действительно приходится сопровождать

| Подход | Что делает upstream/менеджер | Что остаётся на нашей стороне |
|---|---|---|
| Штатная установка через Mason и language providers | Поиск пакетов, платформенные рецепты, получение/установка tools | Состав профилей, UX, совместимость, работа с SDK проекта, тесты |
| Скачивание официальных готовых assets | Публикация binaries по поддержанным платформам | Выбор версии/архитектуры, проверка, обновление и подключение; часто уже реализовано Mason |
| Собственные собранные пакеты fride | Upstream публикует исходники | Сборочная матрица, runtime dependencies, хранение/доставка, provenance, обновления и проверки |
| Версионный кэш или зеркало | Первичную поставку делает upstream | Проверка и обновление кэша, срок хранения; это не обязательно отдельная сборка |

Ранее предложенная необходимость собирать все IDE tools самим не следует из
требования одной команды установки. Общий installer может управлять штатными
providers. Свои сборки нужны там, где есть отдельная причина: обязательный patch,
отсутствие подходящей поставки или требование отдельной offline-дистрибуции.

## Обновления и совместимость

Выход нового SDK языка, LSP, отладчика и formatter не синхронизирован.
Редактор должен проверять совместимость выбранных компонентов, а не просто
обновлять всё вместе при обнаружении новой версии языка.

Сейчас часть tools закреплена в [tool_catalog](../nvim_forge/lua/forge/tool_catalog.lua).
Это проверенная исходная конфигурация fride; lock плагинов — отдельный файл.
Для дальнейшего управления нужны различимые действия:

1. Поставить недостающее для выбранных языков.
2. Проверить обновления tools и показать предлагаемые версии.
3. Обновить выбранные tools либо вернуть совместимую версию.
4. Отдельно выбрать/установить SDK проекта.

Нужно согласовать pins и ручные обновления Mason: иначе пользователь обновит
пакет, а повторный setup вернёт старую закреплённую версию. Поддержка обновлений
без выпуска новой fride возможна, но для неё нужна понятная политика baseline,
совместимых версий и явно выбранного latest. Эта политика ещё не реализована.

## Принятый подход fride — 2026-11-17

Владелец выбрал штатные менеджеры экосистем и готовые upstream-пакеты,
с возможностью самостоятельно настроить нужные пути. Референс — подходы VS Code.
Mason остаётся менеджером IDE tools и использует свои штатные providers;
собственный менеджер пакетов или сборка всех LSP для каждой ОС не планируются.
Уже существующие patched-компоненты учитываются отдельно, без обещания заменить
их непроверенными upstream-версиями.

Для SQL/Bash владелец уточнил базовый объём: подсветка и готовые LSP/форматтеры.
§267 использует штатный Sqruff LSP для SQL; собственные SQL runners/DB backend
и Bash debug extensions дальше не развиваются до обзора состава.

Для SDK переиспользуем окружение пользователя и проекта. Для LSP, DAP,
форматтера и других IDE tools допускаются как управляемая установка, так и
заданный пользователем инструмент. Ручной путь нужен не только к каталогу SDK:
должна быть возможность выбрать конкретный executable или entrypoint адаптера,
включая необходимые ему аргументы. Эти настройки не должны требовать правки
исходников fride, глобального PATH или перемещения установленного SDK.

Уточнение владельца (§270): **вариант1 принят как основа** — по умолчанию
SDK определяется штатным окружением. Выбор из нескольких установленных версий
и ручной путь добавляем ближайшим отдельным продуктовым шагом, сначала Go/Rust,
до providers/update policy и полного Default. Это интерфейс явного выбора
среды проекта поверх native mechanisms. Если применение требует другого
окружения fride, допускается явное переоткрытие проекта с восстановлением
сессии. Изменение окружения выбранного процесса после действия пользователя
не означает изменения системного PATH/profiles или изоляции SDK в IDE.
Критерии готовности и очередность — в [рабочем плане](IDE_ROADMAP.md#следующий-продуктовый-шаг--выбор-установленного-sdk).

В VS Code есть общие настройки пользователя и переопределения workspace;
Go extension позволяет задавать alternate tools, а Python — выбирать interpreter
и его путь. Это референсы поведения, не обещание полной совместимости формата
настроек VS Code. [User/workspace settings](https://code.visualstudio.com/docs/configure/settings),
[Go settings](https://github.com/golang/vscode-go/blob/master/docs/settings.md),
[Python settings](https://code.visualstudio.com/docs/python/settings-reference).

### Ближайшая реализация: выбор путей

§265 реализовал [первый срез Python/Node/Bash](TOOL_PATHS.md): user/project
tools.json, прежние overrides, ошибки и ForgeToolPaths. Выбор SDK установщика
пока отдельный; остальные consumers остаются в плане. Общая часть отвечает за настройку пути и объяснение
выбора; правила venv, Rust overrides, npm project tools и DAP остаются у своих
языковых интеграций. Новый универсальный менеджер окружений не нужен.
§269 добавил семь Go/Rust IDE executables через public LSP/Conform/DAP APIs.
Native Go/Cargo/rustup выбор сохранён. Отдельные пути SDK/test runners во всех
режимах пока требуют API адаптеров: gotestsum PATH fallback вызывается до
RunSpec, `go`/`cargo` местами hardcoded. Не подменяем общий PATH и не вводим
runtime monkey patches ради частично работающего override.

Рабочий порядок для реализации:

1. Явная настройка конкретного инструмента в проекте; затем настройка пользователя.
2. При отсутствии переопределения — штатный выбор среды проекта и подходящих
   проектных tools; затем обнаружение в унаследованном PATH.
3. Для IDE tools — управляемая копия Mason/fride как fallback. Для SDK такой
   fallback означает предложение выбрать существующий SDK или установить его.

Явный путь не заменяется молча другим при ошибке. В UI/общих логах показываются
выбранный executable/entrypoint, источник настройки, версия и причина отказа.
Относительный путь проекта считается от его корня; пути Windows/macOS/Linux,
пробелы и активная venv должны поддерживаться без shell-склейки команд. Путь к
entrypoint проверяется с учётом его типа: JS-файл адаптера не обязан быть
самостоятельно исполняемым файлом. Существующие настройки сохраняют совместимость.

Для первого среза доступны строковые пути tools.json, описанные в руководстве;
это не универсальный API всех языков и аргументов адаптеров. Остальной порядок —
план следующих срезов. SDK проекта и toolchain установки IDE tools разделяются.

### Следующие шаги после путей

Единый интерфейс показывает SDK проекта, нужные IDE tools, установленные и
предлагаемые версии, зависимости и результат установки. Установка и обновление
выполняются асинхронно по явному запросу с прогрессом, отменой и общими логами.
При первом Default выбранные компоненты готовит установщик; обычное открытие
проекта не должно незаметно выполнять установочные действия IDE.

Штатное выполнение пользовательского проекта при этом сохраняет его настройки.
Например, Go/rustup могут выбирать toolchain по собственным правилам. Разрешать
ли fride заранее инициировать такую загрузку ради IDE tool — отдельная настройка,
которую нужно согласовать и показать пользователю до скачивания.

Для следующих шагов остаётся определить детали:

- Допускается ли штатная загрузка более нового build toolchain только внутри
  явно выбранной установки IDE tools; что делать при отказе или offline.
- Как сочетаются проверенный baseline, ручное обновление tools и ограничения
  совместимости; какие существующие patched-компоненты остаются отдельными.
- Как выразить общий порядок выбора в настройках каждой языковой интеграции,
  сохранив существующие переопределения и штатные правила SDK.

## Проверки будущей реализации

| Сценарий | Ожидаемый результат |
|---|---|
| Открыть проект с имеющимися SDK/tools | Работа без установки и изменения SDK/lockfiles |
| Не хватает одного language tool | Понятное предложение установить нужный пакет и его зависимости |
| Go для build новее Go проекта | Явное объяснение; выбранная операция не переписывает SDK проекта |
| Toolchain download запрещён или недоступен | Причина и варианты действия в UI/логах, отсутствие бесконечного retry |
| Сменить Python venv или Rust override | Run/debug/tests используют выбранное окружение |
| Задать пользовательский путь, затем проектное переопределение | Выбран проектный инструмент; источник выбора виден |
| Задать неверный явный путь | Видна ошибка этого пути, без скрытого переключения на другую копию |
| Задать executable/adapter entrypoint в пути с пробелами | Правильные executable и argv на каждой поддерживаемой ОС |
| Python/Bash требуют Node для LSP | Node виден как отдельная зависимость |
| Обновить LSP/formatter | Проверка работы выбранной версии и возможность выбрать совместимую |
| Прервать установку | IDE остаётся отзывчивой, ошибка и незавершённый пакет видны |
| Повторить setup после ручного обновления | Поведение соответствует выбранной политике версий |
| Установить fride рядом с обычным nvim | Чужие config/SDK и глобальные package prefixes не меняются |

Эти сценарии должны проверяться на Windows и Ubuntu; macOS прогоняет владелец
на своей машине. Для каждого исправления или изменения поведения добавляется
регресс, одна целевая тестовая итерация на изменение.

## Что уже есть и что документ не меняет

В fride уже есть отдельный NVIM_APPNAME, native SDK discovery, явный setup,
Mason tools, language-specific run/debug/tests и общие логи. Source entry и
полная поставка Default ещё требуют завершения; production release catalog
пока пуст. Описанные примеры не являются результатом чистой установки всех
языков на трёх ОС и не означают, что выбранная схема уже реализована.

Материалы реализации: [граница SDK](SDK_STATE.md),
[план установки](INSTALLATION_PLAN.md), [состав поставки](RELEASE_INVENTORY.md),
[матрица языков](LANGUAGE_MATRIX.md), [рабочий план](IDE_ROADMAP.md).
