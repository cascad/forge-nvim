# Команды агента: что выполняется и что я получаю

Обновлено: 2026-10-31. Рабочая папка: `F:/repo/forge-nvim`.

Это каталог использованных команд и их вариантов, объединённых без повторов.
Это справочник для обсуждения, а не побайтовый журнал всех вызовов: одинаковые
прогоны выполнялись несколько раз, пути и номера строк при чтении менялись.
Разовые скрипты из `.tests` отмечены отдельно. Команды с `<...>` — шаблоны:
перед ручным запуском подставить значение. Команды ниже относятся к PowerShell,
если другой язык или среда не подписаны.

## 1. Как команда доходит до компьютера

Обычно я вызываю инструмент `exec_command` через JavaScript-обёртку
`functions.exec`. Пример формы вызова:

```javascript
const result = await tools.exec_command({
  cmd: "nvim -l tests/run.lua unit e2e wezterm trace",
  workdir: "F:/repo/forge-nvim",
  login: false,
  max_output_tokens: 1200,
  yield_time_ms: 1000
});
text(result);
```

JavaScript здесь управляет инструментами; строка `cmd` исполняется в shell.
Это две разные среды. На этой машине shell — PowerShell. В некоторых вызовах
`workdir` опущен: тогда используется текущая папка проекта.

| Поле | Что означает |
|---|---|
| `cmd` | Текст команды PowerShell |
| `workdir` | Рабочая папка процесса |
| `login: false` | Запуск без загрузки профиля shell; в видимой обёртке PowerShell появляется `-NoProfile` |
| `max_output_tokens` | Ограничение объёма ответа инструмента; не ограничивает число выполненных тестов |
| `yield_time_ms` | Сколько ждать первого ответа перед возвратом ID работающего процесса; это не таймаут теста. На Windows первый ответ часто приходит после 10 секунд |
| `sandbox_permissions: "use_default"` или отсутствие поля | Обычный запуск с действующими разрешениями |
| `sandbox_permissions: "require_escalated"` | Явный запрос запуска с более широким доступом; может вызвать диалог согласования |
| `justification` | Объяснение для такого запроса |
| `prefix_rule` | Предлагаемый префикс для сохранения разрешения похожих команд; не переключатель режима всего приложения |

Независимые чтения или Windows/Ubuntu прогоны я группировал через
`Promise.allSettled`. Его `fulfilled` означает, что вызов инструмента вернулся;
для результата команды отдельно надо смотреть `exit_code` и вывод.

## 2. В каком виде я вижу результат

Обычная команда возвращает структуру примерно такого вида. Значения в этом
примере условные:

```json
{
  "chunk_id": "abc123",
  "exit_code": 0,
  "wall_time_seconds": 0.15,
  "output": "текст stdout/stderr команды"
}
```

Я читаю текст в `output`, а не смотрю непрерывное видео терминала. Если процесс
ещё работает, вместо окончательного `exit_code` возвращается `session_id`:

```json
{
  "session_id": 12345,
  "output": "первая часть вывода"
}
```

Продолжение получаю так:

```javascript
await tools.write_stdin({
  session_id: 12345,
  chars: "",
  max_output_tokens: 1200,
  yield_time_ms: 1000
});
```

Пустой `chars` означает опрос без ввода в процесс. Ответ содержит новую часть
вывода или результат завершения. Отдельно сама JavaScript-обёртка иногда
возвращает `Script running with cell ID ...`: такой строковый ID относится
к обёртке и ожидается через `functions.wait`, а не `write_stdin`.

Длинный ответ может быть сокращён с `Warning: truncated output` и полем
`original_token_count`. Иногда я сам вывожу только хвост или нужные поля.
Тогда полного текста в текущем ответе я не вижу; читаю сохранённый лог или
нужный участок файла отдельной командой. Test runner сохраняет полные логи
дочерних проверок в `.tests/logs`, Ubuntu — в `.tests/ubuntu/logs`.

## 3. Чтение файлов и поиск

Эти команды читают данные и не меняют файлы.

```powershell
Get-Content -Encoding UTF8 -LiteralPath CLAUDE.md
Get-Content -Raw -Encoding UTF8 -LiteralPath .tests/report.json
Get-Content -Encoding UTF8 -LiteralPath nvim_forge/FIXLOG.md -Tail 60
Get-Content -Encoding UTF8 -LiteralPath tests/lib/editor.lua -TotalCount 110
Get-Content -Encoding UTF8 -LiteralPath nvim_forge/lua/plugins/dap.lua | Select-Object -Skip 1400 -First 160

rg --files docs
rg -n 'event_stopped|event_output|repl' nvim_forge/lua/plugins/dap.lua
rg -n -C 3 'MasonTools|ForgeTreesitterInstall' nvim_forge/scripts -g 'install-*.sh'
rg -n 'IDE-003|IDE-004|panic|output' openspec/changes -g '*.md'

Get-ChildItem -LiteralPath openspec/changes -Directory
Get-ChildItem -LiteralPath tests/e2e -Recurse -File
Test-Path -LiteralPath docs/IDE_ROADMAP.md
Get-FileHash -Algorithm SHA256 -LiteralPath README.md,PROBLEMS.md
```

| Элемент | Значение |
|---|---|
| `Get-Content` | Содержимое файла; `UTF8` сохраняет читаемую кириллицу |
| `-LiteralPath` | Путь воспринимается буквально, без раскрытия wildcard |
| `-Raw` | Весь файл как одна строка, удобно для JSON |
| `-Tail 60` / `-TotalCount 110` | Последние 60 / первые 110 строк |
| `-Skip 1400 -First 160` | Пропустить 1400 строк и взять следующие 160 |
| `rg --files` | Список файлов с учётом правил поиска/игнорирования |
| `rg -n` | Совпадения с путём и номером строки |
| `-C 3` | По три строки контекста вокруг совпадения |
| `-g '*.md'` | Ограничение поиска по именам файлов |
| `Get-ChildItem` | Файлы и каталоги, с возможностью рекурсивного обхода |
| `Test-Path` | `True`/`False`: существует ли путь |
| `Get-FileHash` | SHA256 содержимого; это сравнение байтов, а не запуск файла |

Использовались и такие операции над результатами:

```powershell
Get-ChildItem -LiteralPath .tests/editor-e2e -Directory |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 3

$forgeReport = Get-Content -Raw -Encoding UTF8 -LiteralPath .tests/report.json | ConvertFrom-Json
$forgeReport.summary | ConvertTo-Json -Depth 4
```

`|` передаёт результат следующей команде; `Where-Object` фильтрует,
`Select-Object` выбирает поля/строки, `ForEach-Object` обрабатывает элементы.
`ConvertFrom-Json` разбирает JSON, `ConvertTo-Json` печатает выбранную структуру.

Для понимания workflow я также читал локальные `SKILL.md` навыков OpenSpec
и OpenAI Docs через тот же `Get-Content`. Это инструкции в текстовых файлах.

## 4. Git и целостность истории

```powershell
git status --short
git diff --stat
git diff --numstat
git diff --check
git diff -- nvim_forge/lua/plugins/dap.lua tests/lib/editor.lua
git rev-parse HEAD
git show HEAD:nvim_forge/FIXLOG.md
git check-ignore -- <path>
git check-attr text -- <path>
git -c safe.directory=F:/repo/forge-nvim diff --stat
```

`status` показывает изменённые/новые файлы; `diff` — правки; `--check` ищет
ошибки whitespace. `show HEAD:...` читает версию из текущего коммита для
сверки со старым журналом. `check-ignore` проверяет игнорирование, `check-attr`
— правила вроде сохранения исходных CRLF/LF архивов.

`-c safe.directory=...` действует только на один вызов Git. Это использовалось
при чтении репозитория/кэша, когда Git проверял владельца каталога.
Подготовка плагинов также вызывает `git archive --format=tar <commit>` для
чтения pinned ревизии из локального кэша. E2E делает `git init <fixture>`
в своём временном проекте. Рабочий Git-репозиторий этими операциями не коммитится.

## 5. Проверки окружения

```powershell
Get-Command go,dlv,python,python3,rustc,cargo,node -ErrorAction SilentlyContinue |
  Select-Object Name,Source
go version
dlv version
Get-ChildItem -LiteralPath E:/ -Directory -Filter 'Go*'
```

Получаю пути найденных программ и версии. Каталоги `E:/go`, `E:/go1.20.2`,
`E:/Go1.23` читались для выяснения реально доступных Go SDK. Версия Go
проверялась также по полному пути `E:/go/bin/go.exe`.

В одном диагностическом вызове использовалось:

```powershell
Get-CimInstance Win32_Process |
  Where-Object { $_.Name -in @('nvim.exe','go.exe','dlv.exe') -and $_.CommandLine -match 'forge-editor|probe-dap|dlv.exe.*dap|__debug_bin' } |
  Select-Object ProcessId,CommandLine
```

Это запрос списка относящихся к probe процессов, не их остановка. В том
запуске инструмент вернул `Отказано в доступе`; список процессов получен не был.

## 6. Явная подготовка тестовых зависимостей

```powershell
python -B tests/e2e/prepare_editor.py --download
python -B tests/e2e/prepare_dap.py --download
```

На Mac/Linux используется `python3`. `-B` запрещает создавать Python bytecode
`__pycache__` при этом запуске.

| Команда | Что читает/создаёт |
|---|---|
| `prepare_editor.py` | Читает lazy-lock и локальный git-кэш, подготавливает 66 pinned плагинов в `.tests/editor-deps`; с явным `--download` скачивает недостающие ревизии |
| `prepare_dap.py` | Явно готовит Go 1.26.0 и Delve 1.26.3 в `.tests/dap-tools`, проверяет SHA256 SDK и версии; использует сеть при подготовке |

Варианты подготовки плагинов: `--cache <lazy-directory>` и
`--output <directory>`. Альтернативные каталоги для тестов задаются
`FORGE_E2E_DEPS` / `FORGE_E2E_DAP_TOOLS`. Системные установки и постоянный PATH
подготовка не меняет. Обычный запуск тестов зависимости не скачивает.

Для сборки Delve скрипт запускает в собственном окружении:

```text
<private-go> install github.com/go-delve/delve/cmd/dlv@v1.26.3
```

Временные `GOTOOLCHAIN`, `GOBIN`, `GOPATH`, `GOCACHE`, `GOSUMDB`, `GOPROXY`
и `GOENV` здесь относятся к subprocess подготовки. При тестировании DAP
используются `GOTOOLCHAIN=local`, `GOPROXY=off`, `GOENV=off`.

## 7. Запуск тестов

Использованные прямые команды:

```powershell
nvim -l tests/run.lua unit e2e wezterm trace
nvim -l tests/run.lua unit e2e trace
nvim -l tests/run.lua e2e --id IDE-BOOT-2
nvim -l tests/e2e/editor.test.lua
nvim -l tests/e2e/dap-output.test.lua
nvim -l tests/lib/dap_output.test.lua
```

`nvim -l` исполняет Lua-скрипт. В первой команде это test runner: он запускает
зарегистрированные проверки отдельными процессами, разбирает `ok/FAIL/SKIP`
и записывает отчёт. В одиночных командах запускается конкретный файл тестов.

| Suite/аргумент | Область |
|---|---|
| `unit` | Изолированные проверки логики, форматов и конфигурации |
| `e2e` | CLI и настоящая сборка редактора/адаптеры |
| `wezterm` | Проверки конфигурации на доступном бинарнике WezTerm |
| `install` | Установщики в песочницах |
| `trace` | Связь требований/кода/проверок |
| `conpty` | Отдельная Windows-проверка доставки клавиш |
| `--id <ID>` | Фильтр по требованию или префиксу, например `IDE-DAP` |

Тонкие обёртки, которые тоже проверялись:

```powershell
powershell -NoProfile -File scripts/test.ps1 quick
pwsh -NoProfile -File scripts/test.ps1 e2e
```

POSIX-вариант: `bash scripts/test.sh quick|e2e|full`, где выбирается одно
значение режима. Доступен и Windows `full`, но native ConPTY в текущем шаге
не прогонялся. Перечень режимов и подготовки: [E2E README](../tests/e2e/README.md).

Файлы результатов: `.tests/report.json`, `.tests/logs/*.log`,
`.tests/editor-e2e/<run>/`. PASS одного набора не означает полного покрытия
всех возможностей IDE; SKIP/MANUAL/UNCOVERED учитываются отдельно.

## 8. Ubuntu через Docker

```powershell
docker compose -f tests/containers/compose.yaml build ubuntu
docker compose -f tests/containers/compose.yaml run --rm ubuntu full
docker compose -f tests/containers/compose.yaml run --rm --entrypoint nvim ubuntu -l tests/e2e/dap-output.test.lua
docker compose -f tests/containers/compose.yaml run --rm --entrypoint nvim ubuntu -l tests/run.lua e2e --id IDE-BOOT
```

`build` готовит образ и скачивает фиксированные зависимости. Обычный
entrypoint образа — `bash scripts/test.sh`; `--entrypoint nvim` позволяет
запустить один Lua-файл или прямые аргументы runner. `--rm` удаляет завершённый
контейнер; результаты сохраняются отдельно в `.tests/ubuntu` на хосте.
Чекаут в контейнере read-only, тестовый runtime без сети, пользователь не root.

Dockerfile при build выполняет `apt-get`, `curl`, проверку `sha256sum`,
распаковку `tar`, явный `go install` и `python3 prepare_editor.py --download`.
Точные команды закреплены в [Dockerfile](../tests/containers/Dockerfile).

## 9. Что происходит внутри E2E Neovim

Внешний `nvim -l tests/e2e/editor.test.lua` запускает второй Neovim примерно
с такими аргументами. `<profile>` — временный профиль теста:

```text
nvim --headless --embed -i NONE --cmd "lua dofile('<observer>')" -u <profile>/config/nvim_forge/init.lua
```

Harness копирует туда настоящую сборку и pinned плагины, изолирует HOME,
config/data/state/cache и создаёт проект. Затем подключает UI по Msgpack-RPC.

| RPC-метод | Для чего используется |
|---|---|
| `nvim_ui_attach` | Подключить UI 140×45; происходят настоящие UIEnter/VeryLazy |
| `nvim_input` | Ввести пользовательские клавиши: `<F5>`, `<F9>`, `<CR>`, ` mc` и т. п. |
| `nvim_exec_lua` | Прочитать состояние, буферы/окна или настроить наблюдатели |
| `nvim_get_mode` | Быстро узнать режим и блокирующий hit-enter |
| уведомления `redraw` | Получить перерисовку и восстановить текст экрана |

Например, F5 отправляется вводом, после чего тест ждёт реальный breakpoint.
События DAP записывает наблюдатель; Delve остаётся настоящим. Готовность выбора
Telescope дополнительно читается документированным getter выбранного элемента.
Открытие результата всё равно выполняет Enter, а не вызов действия из теста.

Я получаю JSON-снимки окон/буферов, messages, notifications и процессов;
снимок содержит до первых 80 строк каждого видимого буфера. Также сохраняется
текстовая реконструкция UI 140×45 — диагностический текст, не PNG-скриншот.
Есть проект после действий, копия конфига и manifest плагинов. DAP добавляет
`dap-events.json`, `dap.log`, `tool-versions.txt`. Это можно читать обычным
`Get-Content`. В Lua-клиенте RPC nil приходит как `vim.NIL`, что нельзя
ошибочно принимать за истинное условие готовности.

Этот ввод проверяет работу редактора после получения клавиши. Физическая
доставка Cmd/Ctrl через WezTerm/ОС требует отдельного PTY/ConPTY/GUI-прогона.

## 10. Разовые диагностические команды

```powershell
nvim -l .tests/probe-dap.lua
python -B .tests/verify-history.py
python -B nvim_forge/scripts/diagnose-shell.py
```

| Скрипт | Назначение |
|---|---|
| `.tests/probe-dap.lua` | Разовый реальный запуск до breakpoint/panic, запись events/exceptionInfo/UI для поиска причины |
| `.tests/verify-history.py` | Разовая сверка архивов SHA256, ссылок и сохранности прежнего FIXLOG; читает источники по manifest, включая старую папку истории |
| `diagnose-shell.py` | Пассивное чтение shell/Go-конфигов для IDE-001; Go и shell-профили не запускает |

Первые два файла временные и не входят в Git; после очистки `.tests` могут
отсутствовать. Самостоятельно перепрогонять их для обычного регресса не нужно.
Старый `F:/claude_code/vim` использовался как источник описательных архивов;
текущая разработка и изменения исходников идут в `F:/repo/forge-nvim`.

## 11. OpenSpec

Используется фиксированный CLI, а не произвольная новая версия:

```powershell
npx.cmd --yes @fission-ai/openspec@1.13.2 list --json
npx.cmd --yes @fission-ai/openspec@1.13.2 list --specs
npx.cmd --yes @fission-ai/openspec@1.13.2 context --json
npx.cmd --yes @fission-ai/openspec@1.13.2 new change fix-dap-output-lifecycle
npx.cmd --yes @fission-ai/openspec@1.13.2 status --change fix-dap-output-lifecycle --json
npx.cmd --yes @fission-ai/openspec@1.13.2 instructions apply --change fix-dap-output-lifecycle --json
npx.cmd --yes @fission-ai/openspec@1.13.2 validate fix-dap-output-lifecycle --type change --strict --no-interactive
```

`instructions` вызывался также для `proposal`, `specs`, `design`, `tasks`.
Он возвращает JSON с путями артефактов, шаблоном, требованиями и состоянием.
`new change` создаёт каталог/метаданные, `validate` проверяет формат change.
Валидация OpenSpec сама по себе не запускает E2E редактора. `npx --yes`
убирает вопрос самого npm об установке пакета, а не диалог разрешений приложения.

## 12. Редактирование и веб-источники

Правки файлов делались инструментом `apply_patch`, например:

```diff
*** Begin Patch
*** Update File: <path>
@@
-прежняя строка
+новая строка
*** End Patch
```

Это отдельный инструмент, не PowerShell-команда. Я получаю результат применения
или ошибку несовпадения контекста, после чего читаю файл/diff и проверяю результат.

Для официальных checksum Go, исходников Delve и объяснения permissions
использовался веб-инструмент `web__run`: `search_query`, `open`, `find`.
Он возвращает текст страницы, URL и данные поиска. Это ещё один канал данных,
отдельный от локального shell и тестового RPC UI.

## 13. Что произошло с запросами разрешений

В старом ограниченном режиме встречались сетевой EACCES и отказ доступа
к временному проекту; тогда запускались вызовы с `require_escalated`.
После сообщения о Full access я продолжал передавать этот флаг для OpenSpec,
не проверив обычный путь. Та же одиночная validate-команда без него успешно
вернула `Change is valid` за 2,3 с без нового запроса.

Это доказательство для конкретного вызова: составной запуск позднее всё ещё
получал EACCES, поэтому по одному успеху нельзя утверждать снятие всех
ограничений. Рабочее правило — обычный запуск по умолчанию, проверка фактической
ошибки и отсутствие автоматического переноса старой эскалации. Подробности
инцидента записаны в FIXLOG §67. Режим приложения, разрешённый префикс и
параметры конкретного вызова стоит разбирать отдельно.

Официальное описание переключателей: [OpenAI Docs — Permissions](https://learn.chatgpt.com/docs/permission-modes).

## 14. Добавления IDE-006: тесты Go и DAP eval

```powershell
python -B tests/e2e/prepare_editor.py --download
python -B tests/e2e/prepare_dap.py --download
python -B tests/e2e/prepare_tests.py --download
nvim -l tests/e2e/test-runner.test.lua
nvim -l tests/run.lua e2e --id IDE-TEST
nvim -l tests/run.lua e2e --id IDE-DAP-3
nvim -l tests/run.lua unit e2e wezterm trace > .tests/windows-ide006-regression.txt 2>&1
docker compose -f tests/containers/compose.yaml build ubuntu > .tests/ubuntu-test-runner-build.txt 2>&1
docker compose -f tests/containers/compose.yaml run --rm ubuntu full > .tests/ubuntu-ide006-full.txt 2>&1
npx.cmd --yes @fission-ai/openspec@1.13.2 validate fix-test-runner-and-dap-popup --type change --strict --no-interactive
```

`prepare_tests.py` собирает parser из каталога Treesitter по lock, проверяет
ABI настоящим Neovim и ставит gotestsum v1.13.0 через частный SDK Go из
prepare_dap.py. Это явная сетевая подготовка; в тесте загрузок нет. Нужен
C compiler (`CC`/`--cc`/PATH), на Windows clang — ещё линкер и SDK.
На Mac/Ubuntu вместо `python` — `python3`. Альтернативный каталог:
`--output <directory>` и `FORGE_E2E_TEST_DEPS=<directory>` при тесте.

Для изучения upstream использовались `git ls-remote --tags <url> 'v1.*'`,
`Invoke-WebRequest -Uri <raw-github-url> -OutFile .tests/<file>` и
`git diff --no-index -- <before-file> <after-file>` (код 1 означает различия).
Для короткого чтения JSON: `Get-Content -Raw <snapshot.json> | ConvertFrom-Json`,
потом `Select-Object` нужных полей. Полный snapshot в одну строку может быть
огромным; его обрезка инструментом не означает, что тест не выполнился.

Эти запуски выполнялись обычным `exec_command` без поля sandbox_permissions:
текущая среда сообщает danger-full-access и approval policy never. Старые
инциденты в §13 описывают прежнюю среду.

## 15. Добавления IDE-007: ручной ввод после snippet

```powershell
nvim -l tests/e2e/snippet-input.test.lua > .tests/windows-ide007.txt 2>&1
nvim -l tests/run.lua e2e --id IDE-SNIP-1
docker compose -f tests/containers/compose.yaml run --rm --entrypoint nvim ubuntu -l tests/e2e/snippet-input.test.lua > .tests/ubuntu-ide007.txt 2>&1
nvim -l tests/run.lua unit e2e wezterm trace > .tests/windows-ide007-regression.txt 2>&1
docker compose -f tests/containers/compose.yaml run --rm ubuntu full > .tests/ubuntu-ide007-full.txt 2>&1
npx.cmd --yes @fission-ai/openspec@1.13.2 validate fix-snippet-manual-input --type change --strict --no-interactive
```

Исходные красные запуски тех же сценариев сохранены как
`.tests/windows-ide007-red.txt` и `.tests/ubuntu-ide007-red.txt`.
Здесь `--entrypoint nvim` заменяет штатную shell-обёртку контейнера и запускает
один Lua-файл напрямую; общий full по-прежнему использует scripts/test.sh.
Новых установок нет, подготовленные плагины те же. Меню completion и LuaSnip
настоящие; fixture .code-snippets загружается публичным loader. Я вижу результаты
assertions, snapshot буферов/окон и текст RPC UI в editor-e2e, не видео терминала.

## 16. Добавления IDE-012: проверка codelldb при запуске

```powershell
nvim -l tests/e2e/dap-discovery.test.lua > .tests/windows-ide012.txt 2>&1
nvim -l tests/run.lua e2e --id IDE-DAP-4
docker compose -f tests/containers/compose.yaml run --rm --entrypoint nvim ubuntu -l tests/e2e/dap-discovery.test.lua > .tests/ubuntu-ide012.txt 2>&1
nvim -l tests/run.lua unit e2e wezterm trace > .tests/windows-ide012-regression.txt 2>&1
docker compose -f tests/containers/compose.yaml run --rm ubuntu full > .tests/ubuntu-ide012-full.txt 2>&1
nvim --headless -u NONE -i NONE '+lua assert(loadfile("nvim_forge/lua/plugins/dap.lua"))' +qa
npx.cmd --yes @fission-ai/openspec@1.13.2 validate defer-codelldb-check-until-launch --type change --strict --no-interactive
```

Исходный red: `.tests/windows-ide012-red.txt` / `.tests/ubuntu-ide012-red.txt`.
После улучшения наблюдателя повторён на том же старом production-коде:
`windows-ide012-red-observed.txt` / `ubuntu-ide012-red-observed.txt`.
Первый вариант видел timeout RPC за экраном ошибки; push-наблюдатель
показал точную missing adapter ошибку без такого запроса.

`loadfile` здесь только проверяет Lua-синтаксис; сам конфиг не выполняется.
Это дополняет настоящий editor E2E. codelldb исключается только из PATH
тестового редактора; установленный debugger хоста не удаляется и не меняется.

Новый вид наблюдения: существующий observer vim.notify сохраняет штатный
вызов и дополнительно отправляет `vim.rpcnotify(1, "forge_e2e_notify", ... )`
по stdio RPC встроенного Neovim. Родитель принимает его без blocking API
запроса и пишет `notifications.json`. Это реальные сообщения приложения,
а не сгенерированный ответ теста; работает и за hit-enter prompt.

## 17. Диагностика Starship/Git на Windows (IDE-013)

```powershell
starship --version
starship print-config | Select-String -Pattern '^(command_timeout|scan_timeout)\s*='
starship timings --path F:/repo/forge-nvim
starship module git_status --path D:/rust_repo/cs2d
git -C D:/rust_repo/cs2d config --show-origin --get-regexp '^core\.(fsmonitor|untrackedcache|preloadindex|fscache)$'
$env:STARSHIP_LOG='trace'
starship module git_status --path D:/rust_repo/cs2d > .tests/starship-cs2d-git-trace.txt 2>&1
```

Trace включался только в отдельном процессе инструмента с `-NoProfile`,
профиль терминала и постоянные env не менялись. Повторные запуски измерялись
через `[System.Diagnostics.Stopwatch]::StartNew()`; это тёплые замеры, а не
воспроизведение первого таймаута. `git_status` запускается отдельно, поэтому
языковые модули prompt и rustup/Go toolchains в этой проверке не вызываются.

Профили читались через Get-Content/rg; Starship logs —
`$HOME/.cache/starship/session_*.log`. Точный logger v1.21.1 прочитан из
[официального исходника](https://github.com/starship/starship/blob/v1.21.1/src/logger.rs):
одинаковые WARN подавляются по содержимому session log. Для изучения исходник
скачан Invoke-WebRequest в `.tests/starship-logger-v1.21.1.rs`. Ничего в cs2d
или постоянных настройках Starship не правилось.

## 18. Пилот панелей Space w

```powershell
nvim -l tests/e2e/debug-panels.test.lua
nvim -l tests/run.lua e2e --id IDE-PANEL
nvim -l tests/run.lua unit e2e wezterm trace > .tests/windows-panels-regression.txt 2>&1
docker compose -f tests/containers/compose.yaml run --rm ubuntu full > .tests/ubuntu-panels-full.txt 2>&1
npx.cmd --yes @fission-ai/openspec@1.13.2 validate unify-debug-panel-controls --type change --strict --no-interactive
docker desktop status
docker desktop start
```

После перезагрузки движок был выключен; desktop start поднял Docker штатно.
Для прерванного собственного контейнерного теста проверялись Path/Args через
`docker inspect --format '{{json .Path}} {{json .Args}}' <id>`; затем
`docker stop --timeout 2 <id>`. Старое имя флага --time даёт deprecation warning.
Зависшие собственные native тесты находились Get-CimInstance Win32_Process
по точному `-l tests/e2e/debug-panels.test.lua`; останавливались их PID и
дочерний editor через Stop-Process. Это уборка процессов теста, не файлов.

Red q/sidebar — windows-panels-red.txt и ubuntu-panels-red.txt. Для Ubuntu
исходный config-source Windows snapshot скопирован в
`.tests/ubuntu/baselines/panels-before`; явный replay:

```powershell
docker compose -f tests/containers/compose.yaml run --rm -e FORGE_TEST_ID=IDE-PANEL-1 -e FORGE_E2E_CONFIG_SOURCE=/workspace/.tests/baselines/panels-before --entrypoint nvim ubuntu -l tests/e2e/debug-panels.test.lua
```

Плагины не подменяются: source lock обязан совпасть с подготовленным,
config-origin.txt записывает источник. Без env проверяется текущий nvim_forge.
Отдельный red Satellite — `.tests/windows-panels-satellite-red.txt` и
`.tests/ubuntu-panels-satellite-red.txt`; те же постоянные E2E после исправления.
Go compiler cache — native temp одного прогона, `FORGE_E2E_GO_CACHE`;
ранняя попытка `.tests/go-build-cache` на bind mount заменена на native FS.
Итоговые логи после всех исправлений:
`.tests/windows-panels-final-regression.txt` и `.tests/ubuntu-panels-final-full.txt`.
Дополнительный red старого ожидания DAP за adapter-slow WARN:
`.tests/ubuntu-panels-slow-red.txt`. Caller явно принимает только этот WARN,
сохраняя экран в accepted-warning-prompt.txt; ошибки не принимаются.

## 19. Outline: IDE-008, настоящий Aerial и регресс

```powershell
npx.cmd --yes @fission-ai/openspec@1.13.2 new change integrate-outline-panel
npx.cmd --yes @fission-ai/openspec@1.13.2 status --change integrate-outline-panel --json
npx.cmd --yes @fission-ai/openspec@1.13.2 instructions proposal --change integrate-outline-panel --json
npx.cmd --yes @fission-ai/openspec@1.13.2 instructions specs --change integrate-outline-panel --json
npx.cmd --yes @fission-ai/openspec@1.13.2 instructions design --change integrate-outline-panel --json
npx.cmd --yes @fission-ai/openspec@1.13.2 instructions tasks --change integrate-outline-panel --json
npx.cmd --yes @fission-ai/openspec@1.13.2 instructions apply --change integrate-outline-panel --json
nvim --headless -u NONE -c "lua print(pcall(vim.treesitter.language.add, 'lua'))" -c q
nvim -l tests/e2e/outline.test.lua > .tests/windows-outline-second.txt 2>&1
nvim -l tests/run.lua unit e2e wezterm trace > .tests/windows-outline-regression.txt 2>&1
docker compose -f tests/containers/compose.yaml run --rm ubuntu full > .tests/ubuntu-outline-full.txt 2>&1
npx.cmd --yes @fission-ai/openspec@1.13.2 validate integrate-outline-panel --type change --strict --no-interactive
git diff --check
```

Вывод parser-пробы — `true true nil`: настоящий Lua parser уже есть в
Neovim 0.12.2. Aerial E2E читает фикстуры Lua; символы не подменяются.
Шесть сценариев печатают ok/FAIL и путь artifacts; snapshot JSON содержит
окна/буферы/уведомления, screen TXT — сетку RPC UI. Это текстовый снимок UI,
не скриншот WezTerm и не подтверждение физических сочетаний.

Для red перед правками скопирована только сборка в новый каталог:

```powershell
New-Item -ItemType Directory -Force -Path '.tests/baselines' | Out-Null
Copy-Item -LiteralPath nvim_forge -Destination '.tests/baselines/outline-before' -Recurse
$env:FORGE_E2E_CONFIG_SOURCE = (Resolve-Path -LiteralPath '.tests/baselines/outline-before').Path
try {
  nvim -l tests/e2e/outline.test.lua > .tests/windows-outline-baseline-replay.txt 2>&1
} finally {
  Remove-Item Env:/FORGE_E2E_CONFIG_SOURCE
}
```

Нельзя перезаписывать baseline новой сборкой: это снимок исходного поведения.
Окончательный тест на нём ловит Explorer/Outline mismatch; остальные новые
сценарии не находят ещё отсутствующий Space w a. Артефакты текущей сборки
пишутся в отдельный запуск. В PowerShell finally выполняет очистку env;
для red читается результат самого Neovim в логе, а не exit code finally.

В этой работе также использовались rg/Get-Content/Select-Object для исходников
Aerial, controls и документации; Get-CimInstance Win32_Process — наблюдение
за своими тестовыми nvim; Get-FileHash SHA256 — сохранность старого FIXLOG.
JSON-отчёт читается целиком (`Get-Content .tests/ubuntu/report.json -Raw |
ConvertFrom-Json`), затем выбирается summary. `-TotalCount 1` для многострочного
JSON не годится. Первые неудачные прогоны самого теста сохранены в
windows-outline-first.txt; исправлены setup dashboard и ожидание render.

Расширение после найденных регрессом Neo-tree ошибок:

```powershell
Copy-Item -LiteralPath nvim_forge -Destination '.tests/baselines/outline-lifecycle-before' -Recurse
nvim -l tests/e2e/outline.test.lua > .tests/windows-outline-lifecycle-red.txt 2>&1
docker compose -f tests/containers/compose.yaml run --rm --entrypoint nvim ubuntu -l tests/e2e/outline.test.lua > .tests/ubuntu-outline-lifecycle-fixed.txt 2>&1
nvim -l tests/run.lua unit e2e wezterm trace > .tests/windows-outline-final-regression.txt 2>&1
docker compose -f tests/containers/compose.yaml run --rm ubuntu full > .tests/ubuntu-outline-final-full.txt 2>&1
```

Baseline lifecycle сохранён до исправлений событий; replay использует тот же
FORGE_E2E_CONFIG_SOURCE с этим каталогом и лог windows-outline-lifecycle-replay.txt.
Наблюдатель записывает closed-tree-refs.json; старый вариант содержит ссылку
на закрытый буфер, исправленный — пустой массив. Он ничего не меняет в backend.
Red q после AerialOpen также сохранён в lifecycle-red/replay. Подробности
первого Windows ERROR — в editor-e2e/3730754149400/notifications.json и screen TXT.
Для сравнения upstream был скачан renderer без изменения подготовленных плагинов:

```powershell
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/nvim-neo-tree/neo-tree.nvim/v3.x/lua/neo-tree/ui/renderer.lua' -OutFile '.tests/neo-tree-renderer-upstream.lua'
git diff --no-index -- .tests/editor-deps/lazy/neo-tree.nvim/lua/neo-tree/ui/renderer.lua .tests/neo-tree-renderer-upstream.lua
```

Версии зависимостей остались прежними; интеграция использует события Neo-tree.

FIXLOG дописан через `[System.IO.File]::AppendAllText` в UTF-8 без BOM:
до записи проверен прежний SHA256, после — Python сравнил байтовый префикс с
baseline outline-before/FIXLOG.md. Старые записи сохранились побайтово;
префикс SHA256 `fc6dd46429ab480e6c88d3847bd9ad4757d7caea822bb72caf7f753aaee5f59a`.

## 20. Дерево файлов: IDE-FILE-1/2 и IDE-PANEL-4

```powershell
npx.cmd --yes @fission-ai/openspec@1.13.2 new change integrate-file-explorer
npx.cmd --yes @fission-ai/openspec@1.13.2 status --change integrate-file-explorer --json
npx.cmd --yes @fission-ai/openspec@1.13.2 instructions proposal --change integrate-file-explorer --json
npx.cmd --yes @fission-ai/openspec@1.13.2 instructions specs --change integrate-file-explorer --json
npx.cmd --yes @fission-ai/openspec@1.13.2 instructions design --change integrate-file-explorer --json
npx.cmd --yes @fission-ai/openspec@1.13.2 instructions tasks --change integrate-file-explorer --json
npx.cmd --yes @fission-ai/openspec@1.13.2 instructions apply --change integrate-file-explorer --json
Copy-Item -LiteralPath nvim_forge -Destination '.tests/baselines/files-before' -Recurse
nvim -l tests/e2e/file-explorer.test.lua > .tests/windows-files-seven.txt 2>&1
docker compose -f tests/containers/compose.yaml run --rm --entrypoint nvim ubuntu -l tests/e2e/file-explorer.test.lua > .tests/ubuntu-files-esc-fixed.txt 2>&1
nvim -l tests/run.lua unit e2e wezterm trace > .tests/windows-files-complete-regression.txt 2>&1
docker compose -f tests/containers/compose.yaml run --rm ubuntu full > .tests/ubuntu-files-complete-full.txt 2>&1
npx.cmd --yes @fission-ai/openspec@1.13.2 validate integrate-file-explorer --type change --strict --no-interactive
git -c core.safecrlf=false diff --check
Get-FileHash -Algorithm SHA256 -LiteralPath nvim_forge/FIXLOG.md
```

Семь настоящих сценариев печатают PASS/FAIL и artifact-путь. Файлы готовятся
в private project, действия — nvim_input: A/a/r/m/x/p и ввод в Nui, затем
проверяются буферы и диск. API читает готовность/видимые строки; locator вводит
обычный G и повторяет поиск строки после перерисовки. Попытка использовать /
попадала в fuzzy finder; `<lt>` — транспорт литерала < в RPC, не иной хоткей.

Запуски с фильтрами и старым config-source:

```powershell
$env:FORGE_TEST_ID = 'IDE-FILE-2'
$env:FORGE_E2E_CONFIG_SOURCE = (Resolve-Path -LiteralPath '.tests/baselines/files-before').Path
try {
  nvim -l tests/e2e/file-explorer.test.lua > .tests/windows-files-move-replay.txt 2>&1
} finally {
  Remove-Item Env:/FORGE_TEST_ID
  Remove-Item Env:/FORGE_E2E_CONFIG_SOURCE
}
```

Так же выполнены replay с IDE-PANEL-4 и config-source из artifact:
`5700386164500` → windows-files-source-red.txt (потеря выбора источника),
`5534595085400` → windows-files-zoom-replay.txt (открыт прежний файл),
`5949438588300` → windows-files-esc-replay.txt (два канонических Esc).
Источники — `.tests/editor-e2e/<id>/config-source`, lock сверяется каркасом.
`FORGE_TEST_ID=IDE-FILE` отдельно запускал пять файловых сценариев
(windows-files-operations-first.txt). Finally чистит env; red читается по FAIL
самого Neovim в логе, а не по shell exit code после очистки.

`*-files-final-*` — полный прогон до исправления Esc, `*-files-complete-*` —
после него. Для диагностики Esc временный observer читал maparg/debug.getinfo
и WinEnter, сохраняя focus-trace.json. На Ubuntu он показал native cancel
вместо общего cancel; постоянный E2E теперь только читает runtime mappings
и выполняет реальные клавиши. Диагностические обёртки убраны.
Также читались snapshot JSON/notifications через Get-Content -Raw |
ConvertFrom-Json, процессы — Get-CimInstance Win32_Process; docker logs/top
использовались для своего контейнера. К моменту чтения он уже завершился,
поэтому Docker ответил No such container; повторного запуска ради этого не было.

До дописывания FIXLOG сохранён SHA256
`bc0f25499d7fbad3f78993b41119e27f374d64160b4b51bb9e38fc97e05d28e0`.
После AppendAllText проверяется побайтовое совпадение префикса с
`.tests/baselines/files-before/FIXLOG.md`.

Один полный Ubuntu запуск после Esc-исправления получил 30s timeout дочернего
nvim_keymaps в key-ownership. Все editor E2E прошли. Сам timeout не объявлен
исправленным: причина не установлена, повторные проверки выполнены отдельно,
после завершения параллельного Windows прогона. Лимиты не менялись:

```powershell
docker compose -f tests/containers/compose.yaml run --rm --entrypoint nvim ubuntu -l tests/wezterm/key-ownership.test.lua > .tests/ubuntu-files-key-ownership-recheck.txt 2>&1
docker compose -f tests/containers/compose.yaml run --rm ubuntu full > .tests/ubuntu-files-complete-recheck-full.txt 2>&1
```

Первый recheck — 46 PASS. Исходный сбой сохранён в ubuntu-files-complete-full.txt;
окончательный полный результат — в ubuntu-files-complete-recheck-full.txt.
