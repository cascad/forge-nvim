# Проверки законченного блока

Для прямых installer SDK-проверок указывай актуальный prepared frontend через
`FORGE_INSTALL_UI_BINARY`: бинарник из старого SDK может не знать нынешние CLI
параметры. На Linux в Docker с Windows bind mount приватные installer-стенды
размещай через `FORGE_INSTALL_STAND_ROOT` в `/tmp` гостя; большие Mason test
caches также должны жить на native FS гостя. Короткие отчёты сохраняются на F.
Это prerequisites стенда, не повод менять SDK пользователя или увеличивать
таймауты. [Фактический разбор §300](../openspec/changes/remove-sql-extras/verification.md).

§290: отдельный explicit network diagnostic чистой Ubuntu —
`python -B tests/diagnostics/check-cold-install.py --artifacts <native archives> --publisher-container <owned publisher id>`.
Не входит в каждый quick/E2E. Проверяет clean baseline без SDK/cache, реальные
source/Core/Terminal/frontend hashes и SDK actions; host SDK не меняет.
Первый actual run выявил SDK compatibility/tzdata, не PASS. Владелец изменил
порядок на first-file preparation; итоговый cold/regression следует после
цельной реализации. [Evidence и prerequisites](../openspec/changes/verify-cold-ubuntu-installation/verification.md).

Решение владельца 2026-11-18: E2E нужны для каждой фичи и исправления, но
запускаются после цельной реализации, а не после каждого изменения файла.

[Каталог покрытия и проверка готовности change](E2E_CATALOG.md) использует общий
registry/native inventory. Он проверяет наличие E2E, результаты ОС смотрятся
отдельно. Каталог не запускает тяжёлые suites по ссылкам и не заменяет их прогон.

## Когда запускать

1. Во время реализации — чтение кода, syntax/diff и быстрые проверки. Native
   воспроизведение нужно при расследовании бага, когда без него нет доказательства.
2. Когда код и тесты всего блока готовы — один пакет затронутых файлов на каждой
   доступной ОС. Список и ожидаемые проверки записать до запуска.
3. Если пакет упал — разобрать лог, поправить причину и повторить failed case
   либо affected files. Уже прошедшие несвязанные suites не повторять.
4. Большой `regression` — после завершения крупного этапа, перед выпуском или
   рефакторингом общей основы. Не добавлять его к каждой локальной правке.

Native macOS прогон отдельно выполняет владелец. Запуск на Windows не доказывает
работу macOS. Команды не устанавливают и не перенастраивают Docker/WSL.

## Автоматическая приёмка редактора

Запускай из корня репозитория. При первом запуске подготовь окружение и
выполни приёмку одной командой.

```powershell
./scripts/test.ps1 acceptance -Prepare
```

```sh
bash scripts/test.sh acceptance --prepare
```

Для подготовки нужны Git, ripgrep, Neovim 0.12, Python 3.12+ с venv,
C-компилятор и установленный Rust SDK. На macOS нужен Bash 4+ для сценария
Bash Debug и Xcode Command Line Tools для парсеров. fride находит Bash из
Homebrew. Свой путь можно задать в `FORGE_BASH_DEBUG_BASH`.
Если используешь rustup, недостающие компоненты добавляются командой
`rustup component add rust-analyzer rustfmt clippy rust-src`.

Подготовка скачивает тестовые плагины и инструменты в `.tests`.
Она использует имеющийся Rust SDK. Каталоги, переданные через `FORGE_E2E_*`,
используются как готовые входы. Для последующих прогонов убери флаг подготовки.

```powershell
./scripts/test.ps1 acceptance
```

```sh
bash scripts/test.sh acceptance
```

В готовом Ubuntu-образе с зависимостями для текущего `lazy-lock.json`:

```sh
docker compose -f tests/containers/compose.yaml run --rm ubuntu acceptance
```

Состав и готовность окружения можно посмотреть с `-Plan` на Windows и
`--plan` на Linux/macOS. При недостающих входах обычная команда показывает
список зависимостей и завершает работу до запуска E2E.
Приёмка идёт по отметкам `acceptance = true` в [реестре](../tests/registry.lua).
Сценарии запуска используют публичный fride. Остальные проверяют конфиг IDE
в отдельном профиле с настоящим Neovim. Тесты проверяют открытый файл,
содержимое на диске, изменения в индексе и remote Git, вывод процессов
и фокус после действия.
Ошибка или пропущенный сценарий дают ненулевой код выхода.

| Что проверяем | Тесты в `tests/e2e/` (суффикс `.test.lua`) |
| --- | --- |
| Запуск из checkout через `fride`, стартовый экран, выбор проекта, вкладки, восстановление сессии и клавиши Files в двух раскладках | `editor`, `buffers`, `project-session`, `session-files-view`, `session-tool-views` |
| Создание, rename, copy, cut/paste и delete, Unicode, отказ ОС и ввод во время операций | `file-explorer`, `file-copy-delete`, `filesystem-errors`, `acceptance-navigation` |
| Ctrl+P из кода и Files, поиск текста из Logs до строки, палитра, F1, Alt+B, reveal | `acceptance-navigation` |
| LSP в смешанном проекте, переход к определению и реализации, возврат, ввод аргументов | `mixed-project`, `go-workspace-language`, `snippet-input` |
| Запуск Node, Python venv, выбор конфигурации, breakpoint, Locals, стек, Output, паника и повтор после правки | `mixed-project`, `go-workspace`, `debug-panels`, `dap-output` |
| Тест под курсором, файл и проект, pass/fail, отладка теста, исправление и повтор | `test-runner`, `go-workspace-tests` |
| Diff и история, stage файла, hunk и выбранной строки, ветка, worktree, commit и push | `git-workflow` |
| Фокус, закрытие и разворот панелей, Help, Outline, общие логи и сбой Go workspace, встроенная консоль и отправка выделения | `window-ownership`, `work-panels`, `tool-panels`, `outline`, `ide-logs`, `terminal-selection` |

### Короткая приёмка основных действий

Цель — собирать ошибки на первом типичном действии по каждой фиче.
Подготовка профиля и локальных фикстур выполняется один раз. В конце
итерации запускается затронутый набор. Перед выпуском короткий набор
проходит из checkout и из готового комплекта на целевых ОС, затем
отдельно запускается полная приёмка.

| Маршрут пользователя | Что проверяем автоматически | Текущее покрытие и остаток |
| --- | --- | --- |
| Обновить checkout, открыть проект, раскрыть папку и файл, вернуться в предыдущий проект | Без ошибок конфигурации. Фокус и содержимое дерева верны с первой клавиши. Сохранённый файл и панели возвращаются в нужный проект. | `editor`, `project-session`. Нативный macOS-прогон по текущей ревизии открыт. |
| Открыть файл из Files и из `Ctrl+P`, найти строку, открыть недавний проект, вызвать команду | Выбранный файл и строка видны в коде. Активный проект и фокус после отмены соответствуют действию. | `editor`, `acceptance-navigation`. Для короткого набора взять по одному маршруту поиска файла и команды. |
| Создать папку и файл с Unicode, скопировать и удалить через дерево | Диск и Files показывают одинаковый результат. При отказе ОС видна ошибка, а пользователь сразу может продолжить редактировать. | `file-explorer`, `file-copy-delete`, `filesystem-errors`. Оставить один короткий успешный маршрут и один отказ ОС. |
| Поставить breakpoint, запустить Go или Python, продолжить до конца | Собирается выбранная цель, остановка на нужной строке, вывод виден после выхода. В Go проверить пакет без модуля и workspace; в Python проверить выбор проектной venv при активированной сторонней. | `go-workspace`, `dap-output`, `mixed-project`. Для короткого Python-прогона вынести одну venv и Debug без остальных языков. Сценарий Rust с реальным адаптером нужен в коротком наборе. |
| Запустить тест из Tests и открыть вывод, запустить выделение в терминале | Запускается выбранный тест. Вывод закрывается клавишей и остаётся доступным. Выделенная команда выполняется в нужной консоли, фокус можно вернуть в код. | `test-runner`, `terminal-selection`. Оставить по одному реальному процессу и одному сценарию возврата фокуса. |
| Изменить файл, отметить одну строку, закоммитить и запушить | Diff виден. Staging затронул выбранную часть. Коммит и ветка появились в локальном bare-репозитории. | `git-workflow`. Сократить маршрут до одной правки и одного локального remote. |
| Нажать `Cmd+/` на Mac и `l` / `h` в двух раскладках | Текст и видимая ветка меняются. Вывод содержит отдельно факт доставки клавиши и результат редактора. | `editor` покрывает поведение редактора. Автоматический прогон с вводом через реальное окно WezTerm нужен отдельно. |

Тест подготавливает входные файлы и зависимости. Затем он открывает
проект, выбирает цель и нажимает клавиши через пользовательские точки
входа. Результат проверяется по фокусу, тексту на экране, файлам, выводу
процесса и логу текущей сессии. Для ошибки прогона достаточно имени
маршрута, последнего экрана и пути к артефактам.

Уже можно прогнать этот блок на Mac с ранее подготовленными плагинами
и языковыми инструментами.

```sh
bash scripts/test.sh e2e \
  --file tests/e2e/editor.test.lua \
  --file tests/e2e/go-workspace.test.lua \
  --file tests/e2e/mixed-project.test.lua
```

Следующий шаг — зарегистрировать короткий список сценариев в текущем
runner и замерить время на Windows и Mac. Целевой ориентир для
подготовленной среды — до двух минут, исходя из замера на каждой ОС.
В ручной проверке остаются удобство, реальная отзывчивость, внешний вид,
выделение мышью и особенности раскладок, пока нет драйвера WezTerm.

Нужны Git, ripgrep, Python 3 и Neovim для тестов. На Windows Neovim выбирает
`scripts/test.ps1`. Уже подготовленные каталоги можно передать
через `FORGE_E2E_*_DEPS` и `FORGE_E2E_DAP_TOOLS`. Подготовка плагинов, Go/Delve,
Go tests/gopls, Node, Python, Rust, Bash, Sqruff и Bash DAP описана в
[инструкции E2E](../tests/e2e/README.md). Те же подготовительные шаги есть
в [Dockerfile Ubuntu](../tests/containers/Dockerfile). Скачивание выполняется
при явном флаге подготовки. На текущем Windows-стенде актуальный набор плагинов
лежит в `.tests/terminal-test-panel-keys/editor-deps`. Укажи этот путь перед запуском.

```powershell
$env:FORGE_E2E_DEPS = (Resolve-Path .tests/terminal-test-panel-keys/editor-deps).Path
./scripts/test.ps1 acceptance
```

Результат и путь к логу печатаются в конце. Сводный лог прогона сохраняется
в `.tests/batches/<stamp>/00.log`, подробности последнего прогона —
в `.tests/report.json` и `.tests/logs/`. Повторяй упавший файл через `e2e -Files`
или `e2e --file`. Установщик, физические клавиши и clipboard WezTerm, а также
замеры отзывчивости на рабочем проекте входят в отдельную приёмку.

### Пробелы приёмки обычного запуска

Сценарий IDE-BOOT-12 в `editor.test.lua` запускает `fride.cmd` или
`./fride` из текущего checkout с отдельным подготовленным профилем.
Он сверяет путь конфига и runtime, затем проходит три маршрута.

1. Запуск с аргументом-каталогом и неподготовленными Neo-tree и Gitsigns
   на закреплённых ревизиях. Launcher приводит локальный кэш к ожидаемым
   SHA256. В Files сразу работают `l` / `h` и `д` / `р`.
2. Запуск без аргументов. На стартовом экране `p`, имя проекта и `Enter`
   открывают нужный каталог. Files сразу принимает те же клавиши.
3. Возврат в первый проект через `Space o p`. Курсор возвращается к
   сохранённому файлу. `Space w e` переводит фокус в Files, где снова
   проверяются обе раскладки. В конце `:ForgeLogs` открывает панель логов.

Для короткого прогона на Mac с подготовленными плагинами:

```sh
bash scripts/test.sh e2e --file tests/e2e/editor.test.lua
```

Прогон IDE-BOOT-12 подаёт клавиши во встроенный TUI Neovim. Если
пользователь видит сбой в окне WezTerm, дополнительно фиксируем реальные
клавиши и активную панель в WezTerm на той же ОС. В результате приёмки
указываем ревизию, ОС и запускатель. Статус macOS требует прогона на Mac.

| Открытая проверка | Что проверяем до выпуска |
| --- | --- |
| Готовый комплект | Windows Core прошёл обновление и повтор из одного комплекта, запуск через `bin/fride` и сверку установленного конфига. Native macOS остаётся открытой. |
| Ввод из WezTerm | На Mac подтверждены доставка клавиш и сбой конфигурации Neo-tree из-за неподготовленного backport. После проверки исправления с прежним кэшем подтвердить оба маршрута в реальном окне с двумя раскладками. Отдельно проверить выделение мышью и последний символ в clipboard. |

Для каждого сценария фиксируем вход пользователя и наблюдаемый результат.
Например, после выбора проекта проверяем активный каталог, открытые вкладки
и способность раскрыть ветку. Для фонового сбоя проверяем рабочий экран,
доступные действия и запись в Logs. Прогоны группируем по законченному блоку.

Чтобы добавить проверку реального установленного launcher к сценарию
`editor.test.lua`, задай `FORGE_E2E_INSTALLED_KIT`,
`FORGE_E2E_INSTALLED_PROFILE` и `FORGE_E2E_INSTALLER_BUNDLE` абсолютными
путями. Профиль стенда содержит `home`, `local`, `roaming`, `config`,
`data`, `state` и `cache`. Тест сверяет установленный конфиг с payload,
проверяет backports и открывает файл через Files во встроенном TUI-стенде.

## Команды блока

Из корня репозитория, после отдельной подготовки зависимостей:

```powershell
./scripts/test.ps1 quick
./scripts/test.ps1 e2e -Files @('tests/e2e/setup-sdk-paths.test.lua','tests/install-setup.test.py') -Plan
./scripts/test.ps1 e2e -Files @('tests/e2e/setup-sdk-paths.test.lua','tests/install-setup.test.py')
```

При вызове через `powershell -File` из другого shell передача массива зависит
от shell; переносимый вариант — прямой Python с повторяемым `--file`:

```sh
python3 -B scripts/test-batch.py --nvim nvim --mode e2e --file tests/e2e/setup-sdk-paths.test.lua --file tests/install-setup.test.py --plan
bash scripts/test.sh e2e --file tests/e2e/setup-sdk-paths.test.lua --file tests/install-setup.test.py
```

Windows прямой Python: `python -B ... --nvim .tools/neovim/windows-x64/bin/nvim.exe`.
Список может смешивать зарегистрированные Lua/shell тесты и native
`tests/*.test.py` (installer/release). Неизвестные/повторённые имена отклоняются до E2E.
Выбор через `--file` запускает целые файлы независимо от inherited case filters.
Для отдельного failed case остаётся прямой запуск файла с его documented filter.

## Полный regression

```powershell
./scripts/test.ps1 regression -Plan
./scripts/test.ps1 regression
```

```sh
bash scripts/test.sh regression --plan
bash scripts/test.sh regression
```

`regression` = весь прежний `full` для ОС + все native Python suites из корня
tests/, включая установщик и release inventory.
`full` сохранён для совместимости и охватывает только прежний registry: ранее
он не включал отдельные installer Python suites. На Windows полный registry
также содержит ConPTY и POSIX shell-наборы; последним нужен уже подготовленный
WSL. Старый runner вызывает `wsl.exe` и может запустить установленный дистрибутив;
если он недоступен, будет SKIP. Для блока без POSIX suites этот вызов не нужен.
Команда не устанавливает зависимости, не запускает Docker Desktop и не меняет
WSL configuration. Plan ничего из этого не вызывает.

PASS с SKIP не означает проверку отсутствующей среды; список SKIP надо читать
в `.tests/report.json`. Physical GUI/горячие клавиши на машине владельца —
отдельная проверка. `--plan` выполняет только лёгкое чтение Lua registry.

## Входы Core acceptance

`regression -Plan` показывает `ready` и `missing_inputs`. Core acceptance
требует подготовленный комплект и его отдельный тестовый профиль, либо
подготовленные native inputs. Без них actual batch возвращает2 **до любых
тестов**; Core suite не пропускается и ничего автоматически не устанавливается.

Для установленного комплекта:

```powershell
$env:FORGE_CORE_TEST_KIT='F:/repo/forge-nvim/.tests/my-kit'
$env:FORGE_CORE_TEST_PROFILE='F:/repo/forge-nvim/.tests/my-kit-profile'
```

Для проверки source configuration:

```powershell
$env:FORGE_E2E_DEPS='F:/repo/forge-nvim/.tests/editor-deps'
$env:FORGE_CORE_TEST_RUNTIME='F:/repo/forge-nvim/.tests/my-prepared-runtime'
```

Runtime должен содержать `treesitter/parser/lua.so`; это подготовленный native
runtime, не просто каталог site. POSIX использует те же env names с `export`.
Оба режима запускают прежний Core suite с его readiness/ownership проверками.
`prepared-native-config` не считается подтверждением installed-kit delivery.
Пути выше — примеры: batch их не создаёт и не загружает.

## Время и результаты

Пакет идёт последовательно. Сохраняются plan.json, report.json, exit codes,
время и отдельный log каждой команды в `.tests/batches/<stamp>/`. Для registry
используется прежний tests/run.lua с его таймаутами и `.tests/report.json` /
`.tests/logs`; его отчёт содержит длительность каждого файла. Standalone installer
suite имеет deadline30 минут; timeout прекращает дальнейший batch с ошибкой.
Унаследованные `FORGE_TEST_ID`/`FORGE_*_CASE` очищаются, их имена видны в плане.

Основная цена editor E2E — свежий профиль, копирование prepared plugins и запуск
настоящих LSP/debug/tests, иногда несколько restart. Пока не меняем их изоляцию
и не распараллеливаем тяжёлые suites. Сначала получаем времена большого прогона,
потом отдельно оптимизируем самые дорогие fixtures с сохранением регрессов.

На POSIX редакторские тесты создают приватные runtime-каталоги под `/tmp`.
Neovim получает отдельный `XDG_RUNTIME_DIR` для сокетов. Отчёты остаются в
`.tests` в репозитории. Для ручного `FORGE_TEST_TMPDIR` на POSIX указывай
короткий абсолютный путь, поскольку он входит в адрес сокета.

В существующем Ubuntu driver `tests/containers/tool-paths.sh --batch ...`
тяжёлые installer runtime-копии находятся в `/tmp` контейнера через уже
поддержанный FORGE_INSTALL_STAND_ROOT. На Windows host temp остаётся на диске
репозитория. На bind mount сохраняются доказательства, без повторного копирования
бинарных SDK/архивов. Это не уменьшает состав тестов.

## Shared SDK preflight — IDE-BOOT-40

После developer build frontend (команда выше) native сценарии доступны как
`python -B tests/install-sdk-settings.test.py` (на Linux/macOS — python3).
Нужны готовые Neovim/Node/Go/Rust и Python с venv; SDK тест не устанавливает.
Frontend можно выбрать через `FORGE_INSTALL_UI_BINARY`; по умолчанию используется
подготовленная `.tools/installer-ui/<platform>/fride-setup[.exe]`.
Go root при необходимости задаётся `FORGE_SDK_GO_NEW`.

10 сценариев проверяют реальные SDK/venv, user scope против project/PATH,
относительный/домашний путь и «Авто», ошибки JSON/path/CLI, Core HTTP/cache,
испорченный Core, preview, private setup и запрет SDK внутри заменяемого kit.
Setup stages — fixtures: эти случаи не выдают себя за full Default acceptance.
Ещё1 control проверяет закрытие настоящего HTTP-стенда при ошибке setUpClass:
такая ошибка не должна оставлять suite висеть до внешнего deadline.
Suite автоматически входит в standalone Python inventory `regression` и
выбирается через `-Files` / `--file tests/install-sdk-settings.test.py`.
Для повтора одного случая передайте его имя непосредственно Python suite.

После всего блока запускается один affected batch; повторяются только
failed/affected случаи. Большой checkpoint выполняется отдельно один раз,
с фиксированными SDK/deps и отдельными результатами. Отсутствие prerequisites,
FAIL и неполный прогон нельзя обозначать full PASS. Windows `regression`
содержит POSIX-наборы через WSL и ConPTY; без готового WSL можно проверить
план и native affected batch, это не полный Windows регресс. Mac — отдельно.

## Ошибка POSIX process probe — IDE-117

`scripts/test.sh e2e --file tests/e2e/posix-scope-probe.test.lua` проверяет native
nonzero exit, signal, spawn error и настоящий ps. На Windows этот файл даёт4
platform SKIP; отдельные editor-process/descendants/runtime/project-session и
process-lifecycle проверяют Windows Job backend. Source/target и команды —
[verification](../openspec/changes/capture-posix-scope-probe-failure/verification.md).
В shutdown.json при отказе сохраняется scope.probe_failure: argv, attempt,
elapsed_ms и полный native result либо spawn_error. active_after остаётся
неизвестным, scope.ok=false; повтор stop возвращает то же доказательство.
Это не восстановление причины исторического отказа и не native macOS PASS.

## Go build policy — IDE-BOOT-42

Новый native suite — tests/install-go-toolchain.test.py. Он входит в общий
inventory автоматически; backend и native package fixture разделены в
[verification](../openspec/changes/offer-go-build-toolchain-download/verification.md).
Выбранный developer frontend задаётся FORGE_INSTALL_UI_BINARY. Полный Default
и successful fresh compiler download эти проверки не заменяют. Для повтора
native unittest файла install-ide-tools используйте Tools.test_NAME, для
нового Go suite — короткое test_go_NAME (его main выбирает собственные случаи).


## Версии tools при повторной установке — §281

По умолчанию preserve: установленные Mason tools сохраняются, missing получает
baseline/provider default. Явный --tools-versions baseline возвращает pinned
версии. Go consent независим, receipt/exports обязательны. [Правила](TOOL_VERSIONS.md).
Native tests/install-tool-versions.test.py проверяет8 cases настоящего Mason
с releases native fixture v1/v2; affected batch Windows/Ubuntu выполнен, Mac
отдельно. Это не full Default acceptance; он идёт следующим цельным этапом.


## Завершение процесса подготовки — §282

Ненулевой signal child — отказ установки даже при code0. Runtime probes и
plugins/parsers/tools проверяются общей границей до publication. Ошибка содержит
code/signal/command/log, прежний kit сохраняется. Native regression:
python -B tests/install-process-exit.test.py (POSIX python3). Windows4 PASS8
POSIX SKIP, Ubuntu12 PASS; native Mac отдельно. [Evidence](../openspec/changes/reject-signaled-setup-process/verification.md).


## Готовые tools из пользовательских путей — §283

User tools.json для поддерживаемых runtime keys удовлетворяет setup вместо
Mason package, включая baseline. Strict readiness остальных packages прежняя;
external path/JS Node prerequisites проверяются отдельно. Project overrides —
только runtime, ошибка выбора не заменяется fallback. [Правила](TOOL_PATHS.md#явный-setup-приложения).
Native suite tests/install-external-tools.test.py:14 cases Windows/Ubuntu PASS,
actual tools+Mason fixture. [Evidence](../openspec/changes/reuse-explicit-ide-tools/verification.md).
Нужны подготовленные frontend, gopls, Node/Prettier, Delve и Mason plugins;
tests сами SDK не устанавливают. Native Mac/full Default/publication отдельно.


## Frontend выбранного source — §284

tests/install-ui-source.test.py проверяет native PS/Bash resolver и настоящий
frontend: catalog digest определяет выбор, local .tools не подменяет версию.
tests/install-sdk-settings.test.py включает repo root regression без explicit
UI override. Native37+trace8 PASS/2 info SKIP Windows/Ubuntu, без повторов.
Для developer source без опубликованного catalog передать -InstallerUIPath /
--installer-ui-path явно; normal release download остаётся автоматическим.
Actual Default stand и границы — [verification](../openspec/changes/reject-stale-local-installer-ui/verification.md).


## Повтор после работы IDE и actual archive checkpoint — §285

Ownership проверяет сам kit/tmp, пропускает его временные OS resources, сохраняет
проверки остальных paths. Live/closed native socket и foreign-link regressions:
python -B tests/install-transient-entries.test.py (POSIX python3), нужен существующий
Go SDK для одинакового native socket helper. Windows/Ubuntu5 cases PASS после
affected repeats; previous errors сохранены. [Evidence](../openspec/changes/skip-transient-installation-entries/verification.md).

Actual Default/Custom Core source/Core/Terminal archives прошли install/launch/
tree/search/LuaLS/edit/save/restart/repeat на Windows и Ubuntu с настоящими20
Mason packages/67 Git repos в cached native profile. Это не cold SDK bootstrap
и не закрытие Mac/WSL/installed-language matrix/publication. Metadata/same20
receipts и actual input bounds зафиксированы в verification.

## Языки в установленном приложении — §286–287

После цельного изменения установщика/consumers проверяется уже установленный
owned kit, со своим профилем и настоящими SDK/tools. Диагностика не выполняет
setup и не подставляет исходную конфигурацию вместо установленной:

```powershell
python -B tests/diagnostics/check-installed-languages.py --kit '<stand>/kit' --profile '<stand>/profile' --stand-root '<stand>' --profile-layout stand
```

На Linux/macOS — `python3 -B` с теми же аргументами. `stand` означает каталоги
профиля home/local/config/data/state/cache; для прежнего Core acceptance с
каталогами HOME/XDG_* используется `--profile-layout env`. Нужен ready marker
нашей установки. Пути kit/profile/output обязаны находиться внутри stand.

Один запуск проверяет Go/Rust/Python/Node/Bash/SQL: initialized LSP, настоящая
diagnostics, исправление, native `:Format`, save и исчезновение ошибок.
`--language rust` повторяет только отказавший язык. Времена, clients, diagnostics,
форматированный текст и cleanup записываются в новый installed-languages/<id>.
SDK должны быть готовы, Cargo home — доступен для записи; обычный Cargo может
получать зависимости проекта. Это не cold SDK install и не весь debug/test matrix.
Новые E2E managed entrypoints входят в registry; существующие runners сохранены.

`--workflow runtime` запускает тот же installed driver для Go/Rust/Python/Node:
native F5 default, breakpoint, evaluate42, continue/output и Neotest/output.
Pytest/Jest dependencies подготавливаются offline из прежних native test inputs;
SDK/IDE packages не ставятся. `--language rust` повторяет только Rust. Нужен
cargo-nextest; check явно сообщает его отсутствие. §289 закрывает оба выявленных
в §288 Rust gap: подготовку nextest и root-file filter. Actual installed
Go/Python/Node (§288) и Rust (§289) имеют PASS на Windows/Ubuntu.
[Точные результаты §289](../openspec/changes/complete-rust-test-runtime/verification.md).

Новые regressions: `tests/e2e/rust-test-runtime.test.lua` (5 real cases),
`tests/install-nextest.test.py` (10 installer cases). Они входят в общий batch.
Последний installer case скачивает официальный binary только при явном
`FORGE_NEXTEST_NETWORK_TEST=1`; обычный offline запуск помечает его SKIP.
Для affected пакета выберите эти файлы через `-Files`/`--file` обычных runners.
Затем повторяйте только failed/affected cases; `FORGE_NEXTEST_CASE` выбирает
буквальную подстроку имени одного Rust case при прямом запуске файла.
