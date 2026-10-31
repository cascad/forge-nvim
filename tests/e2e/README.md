# E2E и регресс в целевых средах

Решение владельца, 2026-10-31: **каждая фича имеет e2e; каждый исправленный
баг получает воспроизведение как постоянный регрессионный тест**. Unit и
проверка настроек дополняют e2e. Политика действует для новых изменений;
существующее покрытие постепенно доводим по таблице ниже. Зелёный запуск
имеющихся тестов не означает, что все фичи уже покрыты.

**Основной объект — nvim_forge**, его реальные плагины, проекты и поведение
редактора. WezTerm проверяет внешнюю границу клавиатуры/clipboard/GUI.
Базовый editor e2e уже запускает настоящий Neovim с нашей сборкой,
66 плагинами по lazy-lock.json, изолированным профилем и Git-проектом-фикстурой.
Проверяет запуск, дерево, открытие/изменение/сохранение файла, поиск имени и
содержимого, буферы, фокус и отсутствие фоновых установок. Есть и CLI e2e
инструментов тестирования/диагностики. Каждый шаг roadmap добавляет свои
сценарии: LSP/completion/format,
отладка, тесты, Git/worktree и задачи. См. этап 0.5 в `docs/IDE_ROADMAP.md`.
Сценарии ядра можно проверять через RPC реального редактора; PTY/ConPTY
и GUI дополняют проверку доставки ввода. Прямой вызов приватной функции
плагина с mock-зависимостями не заменяет такой пользовательский сценарий.

## Запуск на целевых машинах и внутри VM

Текущая схема: **Windows native + Ubuntu Docker на Windows + отдельный Mac**.
Mint временно отложен. VM остаётся вариантом для нативных Linux GUI-проверок.

Для Ubuntu на Windows с запущенным Docker Desktop в режиме Linux containers:

```sh
docker compose -f tests/containers/compose.yaml run --build --rm ubuntu quick
docker compose -f tests/containers/compose.yaml run --build --rm ubuntu e2e
docker compose -f tests/containers/compose.yaml run --build --rm ubuntu full
```

Первая команда соберёт образ, последующие используют кэш. Образ:
Ubuntu 24.04 (digest зафиксирован), Neovim 0.12.2 (SHA256 официального
архива проверяется), Python 3 и исходники плагинов по lazy-lock.json. Пакеты apt
пока берутся из репозиториев Ubuntu на момент build; точные версии есть
в build-логе, полный snapshot apt — отдельное улучшение воспроизводимости.
Сборка образа использует сеть; сами тесты запускаются без сети. Чекаут
монтируется read-only, результат доступен на хосте в **`.tests/ubuntu/`**,
отдельно от Windows `.tests/report.json`. Контейнер работает пользователем
`forge`, не root: проверки прав доступа должны сохранять смысл.
Этот mount проверяется на Windows/Docker Desktop; на нативном Linux для
bind-mount нужно согласовать UID/права, либо выполнять `scripts/test.sh` нативно.

Контейнерный full прогоняет доступный консольный регресс. GUI WezTerm,
desktop clipboard и физическая доставка клавиш отмечаются отдельно как
непроверенные. Для них нужен нативный desktop/VM. Отсутствующий WezTerm
даёт SKIP соответствующих наборов; это не подтверждение GUI-сценариев.

Владелец готовит/запускает нужную машину/VM и выполняет команды в ней.
Репозиторий содержит один runner, две тонкие системные обёртки и одинаковые
сценарии. Выбор гипервизора и управление хостом не входят в test runner.

| Прогон | Windows, PowerShell | macOS / Ubuntu |
|---|---|---|
| Короткий | `pwsh -NoProfile -File scripts/test.ps1 quick` | `bash scripts/test.sh quick` |
| E2E | `pwsh -NoProfile -File scripts/test.ps1 e2e` | `bash scripts/test.sh e2e` |
| Полный доступный регресс | `pwsh -NoProfile -File scripts/test.ps1 full` | `bash scripts/test.sh full` |

В Windows допустим `powershell -NoProfile -File ...`, если pwsh отсутствует.
Команды — из корня чекаута. Прямой одинаковый entrypoint на всех ОС:
`nvim -l tests/run.lua e2e`. Аргументы/фильтр существующего runner остаются
доступны через `nvim -l tests/run.lua ...`.

Перед первым нативным `e2e`/`full` отдельно подготовить плагины:

```powershell
python -B tests/e2e/prepare_editor.py --download
```

На Mac/Ubuntu использовать `python3`. Подготовка сначала читает git-объекты
из локального lazy-кэша, затем с явным `--download` скачивает недостающие
ревизии. Без этого флага сеть не используется. Источник ревизий —
`nvim_forge/lazy-lock.json`, адреса репозиториев — `plugin-sources.json`.
Исходный кэш не меняется. Подготовку повторять после изменения lock-файла;
отсутствие/расхождение зависимостей даёт FAIL, а не SKIP. Можно задать
`--cache <lazy-directory>` и `--output <directory>`; тест читает альтернативный
output через `FORGE_E2E_DEPS`. Docker выполняет подготовку при build.

Быстрый запуск только редактора: `nvim -l tests/e2e/editor.test.lua`.

Для DAP перед первым нативным `e2e`/`full` также подготовить совместимые
Go/Delve отдельно:

```powershell
python -B tests/e2e/prepare_dap.py --download
nvim -l tests/e2e/dap-output.test.lua
```

На Mac/Ubuntu — `python3`. Скрипт ставит Go 1.26.0 (официальный SHA256 из
[go.dev/dl](https://go.dev/dl/)) и Delve 1.26.3 в `.tests/dap-tools`,
проверяет версии, не меняет системный PATH или установленный Go. Нужная
директория добавляется в PATH только дочернего тестового редактора.
Можно использовать `FORGE_E2E_DAP_TOOLS=<directory>` либо уже совместимые
Go/Delve в PATH. Delve 1.26 требует Go >= 1.24: сочетание системного Go 1.23
и нового Delve даёт понятный FAIL, а не вечное ожидание breakpoint.
При подготовке Delve проверка Go-модулей включена для этого subprocess;
пользовательские GOENV/GOSUMDB не изменяются. На Mac инструменты отладки
могут требовать локальной подготовки Xcode/подписи — Mac ещё не проверен.
Docker уже включает эти версии при build; тестовый runtime остаётся без сети.

DAP-сценарии используют настоящие F5/F9, launch.json и stdlib Go-проект:
первый/повторный запуск, stdout/stderr до паузы и после выхода, раннее сообщение
адаптера о сборке, Go remote + integratedTerminal, скрытие панелей и panic.
Ожидание второго breakpoint синхронизируется файлом-сигналом реального процесса.
Наблюдатели записывают настоящие DAP events; результат проверяется в видимом
REPL. Артефакты дополнены `dap-events.json`, `dap.log` и `tool-versions.txt`.
Это Go/Delve E2E; Python/debugpy, Rust/codelldb и физические клавиши остаются
отдельными проверками. Шесть unit дополнительно проверяют поздние ответы
exceptionInfo после continue, смены сессии/паузы и отсутствие capability.

Go/neotest требует ещё C compiler (clang/gcc; Windows clang также требует
линкер/SDK) и явную подготовку после двух preparer выше:

```powershell
python -B tests/e2e/prepare_tests.py --download
nvim -l tests/e2e/test-runner.test.lua
```

На Mac/Ubuntu — `python3`. Скрипт собирает Go parser из ревизии каталога
pinned Treesitter, проверяет его загрузку в текущем Neovim, ставит gotestsum
v1.13.0 с проверкой Go-модулей. Результат — `.tests/test-deps` либо `--output`,
тест читает его через `FORGE_E2E_TEST_DEPS`. Компилятор — PATH/CC/`--cc`.
Подготовленный Go SDK берётся из `.tests/dap-tools`/`FORGE_E2E_DAP_TOOLS`,
иначе из PATH. Runtime тестов не скачивает инструменты. Docker включает всё
при build; после изменения preparer/lock пересобрать с `--build`.

Пять сценариев используют реальный neotest, Go parser, gotestsum и Delve:
nearest без запуска соседа, падающий nearest → весь файл → pass/fail/output
→ сохранение кода, eval без сессии, Esc/q из float и из кода, debug nearest
с breakpoint/eval 42/continue. Проект расположен в пути с пробелами. JSON
результатов runner идёт через файл, а не терминальный PTY, одинаково на ОС.
Debug DAP у upstream даёт skipped в neotest; реальный PASS проверяется в REPL.
Артефакты включают `test-results.json`, `neotest.log`, `neotest-golang.log`.
Известные WARN об отсутствующих инструментах сохраняются в snapshot; ERROR
при открытии Go-файла проваливает сценарий. Доставка клавиш через WezTerm
и Mac/Python/Rust остаются отдельным долгом.

Completion/snippet: `nvim -l tests/e2e/snippet-input.test.lua` или общий runner
с `--id IDE-SNIP-1`. Новых бинарников/подготовки нет: штатный VSCode loader
читает fixture .code-snippets, реальный cmp_luasnip показывает меню, Ctrl+j
и Enter принимают snippet. Дальше ввод идёт только клавишами. 11 сценариев:
нетронутые/заполненные параметры, Tab/Shift-Tab, Esc, passive/Unicode,
текст равен default, undo/redo, удаление нескольких диапазонов/разделителей,
многострочный вызов, два буфера с фоновой правкой, сложный блок.
Фоновая правка скрытого буфера выполняется публичным Neovim buffer API;
наблюдение не заменяет LuaSnip/cmp. Проверяется общий snippet engine,
не качество completion-ответов gopls/других LSP и не доставка клавиш WezTerm.

Обнаружение codelldb: `nvim -l tests/e2e/dap-discovery.test.lua` или общий runner
с `--id IDE-DAP-4`. Три negative E2E: Go/open/breakpoint, F9 в .txt и F5
с настоящей launch.json → повтор → сохранение файла. PATH дочернего процесса
не включает каталоги с codelldb, private LOCALAPPDATA/Mason пусты; отсутствие
binary и доступность Git проверяются явно. Если codelldb делит обязательный
PATH-каталог с Git/другими tools, нужен подготовленный профиль/гость без него.
Подмены DAP или фиктивного debugger нет; штатная установленная копия на хосте
не меняется. Positive Rust/C/C++ debugging по-прежнему требует своих E2E.

Run & Debug panels: `nvim -l tests/e2e/debug-panels.test.lua`, фильтры
`--id IDE-PANEL-1/2` в общем runner. Четыре сценария: прежний alias и скрытие
всей sidebar-группы без сессии; реальный Delve breakpoint/struct Value=42,
Enter и русское wd; help/Esc/направления; Output zoom/restore/REPL ввод/q/
восстановление и внешнее закрытие source; затем явный F5 и итоговый stdout.
Проверяется та же session/thread/frame на всех UI-переходах. RPC ru/en ввод
не доказывает физическую раскладку/доставку WezTerm; Mac и PTY других
адаптеров остаются отдельным долгом.

Outline: `nvim -l tests/e2e/outline.test.lua` или
`nvim -l tests/run.lua e2e --id IDE-PANEL-3`. Шесть сценариев используют
настоящий Aerial и встроенный в Neovim Lua Treesitter parser: старые aliases
и замена Explorer в одном left-слоте; h/l и Enter без autojump; фокус/помощь/
zoom/Enter/q/Esc с сохранением геометрии; смена файла и отсутствие backend;
быстрые переключения Explorer/Outline; q после штатного AerialOpen.
Фикстуры — `fixtures/outline/`; отдельные LSP/парсеры не скачиваются.
Проверяется отсутствие ERROR, установок и DAP-сессии. Это не проверка
documentSymbol каждого LSP: остальные языки проходят свой этап матрицы.
Red прежнего обхода менеджера — `.tests/windows-outline-baseline-replay.txt`,
источник `.tests/baselines/outline-before`, воспроизведение через
`FORGE_E2E_CONFIG_SOURCE`. Первый пробный прогон теста создавал лишний split
через Space w 0 на dashboard; setup исправлен на обычный `:edit`, продукт
ради этого не менялся. Пустая панель ожидается до завершения render/backend,
а не проверяется немедленно после открытия. Mac/GUI не проверены.

Полный Windows регресс затем поймал Neo-tree follow ERROR (Invalid win),
`.tests/windows-outline-regression.txt`, artifact `3730754149400`. Отдельный
replay до lifecycle-исправления — `.tests/windows-outline-lifecycle-replay.txt`:
наблюдатель after_open читает, есть ли окно у tree.bufnr. Это не подмена
backend и не вызов таймера. Он фиксирует опасную фазу детерминированно:
`closed-tree-refs.json` с tree_buf/visible_buf; при исправлении список пуст.
12 быстрых циклов дополнительно проверяют реальные отложенные события.
Нагрузочный параллельный запуск также сохранил позднее открытие Explorer
(artifact `4156763449400`): после интеграции after_render слот снова согласован.
ERROR не принимается как ожидаемый prompt. Финальные полные логи:
`.tests/windows-outline-final-regression.txt`, `.tests/ubuntu-outline-final-full.txt`.

Дерево файлов: `nvim -l tests/e2e/file-explorer.test.lua` или
`nvim -l tests/run.lua e2e --id IDE-FILE` / `--id IDE-PANEL-4`.
Семь сценариев используют настоящие Neo-tree/Nui и private project на диске:
создание каталога/файла с пробелами и Unicode и запись через редактор;
rename открытого файла/каталога с дочерним буфером; m с полным путём и записью
по новому адресу; x/p в выбранный каталог и отмена занятого пути;
отмена a/r/m и конфликт rename; source selector/Space w e/help/Esc/q;
zoom Enter и rename именно выбранной строки с сохранением исходных окон.
Диалоги открываются клавишами; fs_actions/vim.ui.input и файловые callback
не подменяются. Сохранённые буферы могут получить новый id — проверяются
путь/содержимое/возможность редактирования. Во всех сценариях проверяются
ERROR, установки и DAP-сессия. Только известный WARN конфликта rename может
быть принят как hit-enter с сохранением экрана.

Ожидания UI: настоящий renderer _ready и видимый элемент. '/' у Neo-tree —
fuzzy finder, поэтому locator читает строки и вводит normal G, повторно
находя элемент после Git/render. Литерал '<' передаётся nvim_input как <lt>.
Эти уточнения исправляют транспорт теста, не поведение редактора.
При смене источников наблюдатель читает публичный ide.current() на реальном
after_open: чтение в промежутке без окна не должно терять выбор backend.
Вариант до requested-state воспроизводит сбой Files → Buffers.

Red Move — `.tests/windows-files-move-replay.txt`, исходник
`.tests/baselines/files-before`; red source-state — windows-files-source-red.txt,
config-source artifact `5700386164500`; red zoom — windows-files-zoom-replay.txt,
config-source artifact `5534595085400`. Дубликат старого пути/ENOENT после
rename сохранён в windows-files-controls-first.txt и artifact `5358716713000`
(точный каталог указан строкой artifacts в логе). Финальные полные логи —
windows-files-complete-regression.txt и ubuntu-files-complete-recheck-full.txt в `.tests/`.
Прежние `*-files-final-*` содержат найденный позднее Esc FAIL (§82): runtime
содержал <esc> и <Esc> одновременно. Исправление проверяется одним каноническим
Esc в runtime mappings и пятью циклами help → дерево → код. Red точного
конфликта — windows-files-esc-replay.txt, источник config-source `5949438588300`.
Диагностические wrappers cancel удалены; постоянные тесты действия не подменяют.
В ubuntu-files-complete-full.txt все editor E2E прошли, но unit key-ownership
получил 30s timeout дочернего nvim_keymaps (код 124). Причина не установлена;
полный параллельный Windows прогон тоже был медленнее обычного. Отдельная
проверка — ubuntu-files-key-ownership-recheck.txt, 46 PASS. Полный Ubuntu
recheck выполнен отдельно после завершения Windows, таймауты не увеличивались.
Mac/GUI, несохранённые буферы, отдельные copy/delete/trash, case-only rename,
cross-volume/network FS и LSP file-operation матрица пока не проверены.

На Mac для отдельной проверки дерева из корня репо:

```sh
python3 tests/e2e/prepare_editor.py --download
nvim -l tests/e2e/file-explorer.test.lua
```

Первая команда — явная подготовка закреплённых плагинов. Если они уже
подготовлены для актуального lock, достаточно второй. Go SDK/парсеры/LSP для
этих текстовых файлов не нужны. Общая команда гостя остаётся scripts/test.sh e2e.

Go E2E разделяют compiler cache одного прогона в native temp через
`FORGE_E2E_GO_CACHE`; прямой Lua-файл получает отдельный temp cache.
Windows/Docker bind mount для runtime cache не используется. Source/flags
проверяет сам Go; результат go test не подменяется. Холодная сборка может показать штатный
adapter-slow WARN; он сохраняется в артефактах, hit-enter снимается, тест ждёт
настоящий breakpoint с deadline. ERROR не игнорируется.
`ack_warning` принимает только точный разрешённый caller-ом WARN; другие
сообщения и ERROR не снимаются автоматически.

Сейчас `quick` = unit; `e2e` = реализованные end-to-end сценарии; `full` =
unit + e2e + WezTerm + установщики + trace, на Windows ещё ConPTY. Полный
прогон установщиков использует песочницы; реальную установку в личный HOME
ради теста не выполняет. `full` не означает, что пробелы покрытия устранены.

Подготовка гостя отдельно: git, Neovim 0.12+, Python 3; WezTerm и GUI для
его сценариев; Bash и зависимости fixture-наборов установщиков (см.
основной tests/README.md). Для будущих языковых e2e — инструменты из
зафиксированного каталога. Пакеты не скачиваются из startup/prompt/test runner.
Снимок чистого гостя используем для install/upgrade-сценариев, отдельный
подготовленный снимок — для быстрого регресса IDE. Пользовательские проекты,
профили и реальные remote Git в фикстурах не используются.

После прогона сохранять **всю `.tests/`** отдельно по среде/commit: report.json,
logs и sandbox. Перед следующим запуском скопировать каталог в артефакты VM,
поскольку runner обновляет отчёт. Сведения о точном дистрибутиве/версии гостя,
GUI X11/Wayland, раскладке и версии тулчейнов пока прикладываются к результату
вручную; расширение метаданных runner — задача каркаса.

Артефакты редактора: `.tests/editor-e2e/<run>/` (в Docker —
`.tests/ubuntu/editor-e2e/<run>/`): сообщения, notifications, дочерние процессы,
буферы/окна, stderr, текст remote UI, проект после действий, копия конфига и
manifest ревизий. При сбое сохраняется отдельный snapshot с именем сценария.
`notifications.json` получает настоящий vim.notify через RPC push даже за
error/hit-enter prompt; наблюдатель сохраняет штатное отображение сообщений.
Обычно source — текущий nvim_forge. Для явного red replay допускается
`FORGE_E2E_CONFIG_SOURCE=<config-source>` с тем же lock; config-origin.txt
записывает выбор. В Docker snapshot должен быть в `.tests/ubuntu/`, потому
что контейнерный `.tests` перекрыт отдельным mount.
Большой runtime с плагинами живёт в приватном временном каталоге ОС: это
избегает задержки копирования через Windows/Docker bind mount. Пользовательские
data/state/config не используются. Нативные исполняемые инструменты берутся
из PATH; состав PATH не считается зафиксированным языковым окружением.

RPC-клиент подключает настоящий Neovim UI, получает redraw и запускает
`UIEnter`/`VeryLazy`. Одного `--headless` без UI для этого недостаточно.
Ввод идёт через публичный `nvim_input`, результат читается через API редактора;
плагины не подменяются. Ожидания проверяют готовность окна, insert mode,
файла в асинхронном дереве или результата поиска. Отдельное окно наблюдения
после VeryLazy перекрывает прежний 3-секундный таймер Mason.

## Границы настоящего e2e

- CLI: настоящий entrypoint отдельным процессом, аргументы, cwd/env, stdout,
  stderr, exit code и изменения файлов.
- IDE: настоящий Neovim с нашей сборкой и проектом-фикстурой, пользовательские
  команды/ввод, проверка результата и окон. Отладчик/runner/LSP реальные там,
  где проверяется их интеграция. Вызов приватной Lua-функции с mock DAP — unit.
- TUI: PTY (POSIX) или ConPTY (Windows), отправка ввода, ожидание состояния
  по условию с deadline. Снимок экрана — вспомогательное доказательство.
- Терминал/desktop: настоящий WezTerm и GUI гостя для доставки модификаторов,
  clipboard, фокуса и раскладок. RPC `nvim_input` не доказывает, что Cmd+C
  или Ctrl+Shift+F прошли через WezTerm и системный стек ввода.

Сценарии и assertions общие. Системные различия находятся в backend ввода,
shell/process/clipboard и подготовке VM. Крупные sleep, перезапуск до зелёного
и автоматическое обновление expected-результата не считаются исправлением.

## Контракт сценария и завершения работы

1. Стабильный ID фичи/бага, Given/When/Then, фикстура и поддерживаемые среды.
2. Для бага — исходное воспроизведение и красный результат на прежнем коде
   либо сохранённые доказательства исходного сбоя на целевой машине.
3. Исправление/фича и e2e в одном change; дополняющие unit по необходимости.
4. PASS на целевых средах с commit/версией/логами. SKIP, MANUAL и отсутствие
   реализации — незакрытое покрытие. Если прогон ждёт владельца VM, так и пишем.
5. Не затронутые ОС проверяются общим регрессом; платформенный сценарий
   отдельно запускается в применимых средах. Платформенная неприменимость
   описывается явно, а не превращается в PASS.

До реализации автоматического coverage gate таблица ниже — явный список
долга, а review change проверяет наличие e2e. Автоматический gate, сбор
артефактов и PTY/GUI-backends — следующие задачи каркаса, ещё не реализованы.
Путь к `cs2d` запрошен; его конкретный подход пока не изучен.

## Матрица исходных проблем

| ID / область | Обязательный сценарий | Текущее e2e-покрытие |
|---|---|---|
| IDE-001, исходная задержка | zsh в новой вкладке, Enter/clear внутри и вне Go-проекта; без загрузок SDK | Нет, нужны данные и прогон Mac |
| Диагностический CLI IDE-001 | Запуск на временном HOME, report/exit code, отсутствие исполнения/записи | Реализован: `shell-diagnostics.test.lua`, Windows и Ubuntu PASS; Mac ждёт прогона |
| Команды тестов | quick/e2e → правильный suite argv; неверный режим → ошибка | Реализован: `entrypoints.test.lua`, проверяет реальный entrypoint и дочерний CLI stub |
| IDE-002, clipboard | Реальное выделение WezTerm/Visual/copy mode → copy → clipboard, пустое выделение | GUI-сценарий не реализован; unit не закрывают баг |
| IDE-003, debug output | Первый/повторный запуск → stdout/stderr видны; Go remote + integratedTerminal | `dap-output.test.lua`: Go/Delve Windows/Ubuntu PASS; исходный конфиг владельца и остальные адаптеры ещё сверить |
| IDE-004, panic | Panic → stop event → текст в Output на паузе, сохранён после выхода | `dap-output.test.lua`: Go/Delve Windows/Ubuntu PASS; Mac/Python/Rust не проверены |
| IDE-005, фокус | Код → Locals → Output → код; paused-сессия сохраняется | `debug-panels.test.lua`: Windows/Ubuntu PASS; Mac/GUI открыты |
| IDE-006, ближайший тест | nearest/failing/file, результат/output; debug breakpoint/eval/continue, Esc/q | `test-runner.test.lua`: 5 Go E2E Windows/Ubuntu PASS; Mac/Python/Rust открыты; debug skipped в панели, итог в REPL |
| IDE-007, snippet | Completion → ручной ввод вне поля → хвост отменён, текст сохранён | `snippet-input.test.lua`: 11 cmp/LuaSnip E2E Windows/Ubuntu PASS; Mac/ответы реальных LSP открыты |
| IDE-012, codelldb discovery | Go/F9 без чужого WARN; F5 без binary → понятное сообщение, повтор, редактирование | `dap-discovery.test.lua`: 3 negative E2E Windows/Ubuntu PASS; Mac и positive Rust/C/C++ DAP открыты |
| IDE-005/009 и IDE-014, Debug панели | Space w, real paused Locals/Output, q/Esc/help/zoom, внешний close, сохранность сессии/вывода | `debug-panels.test.lua`: 4 E2E Windows/Ubuntu PASS; Mac/GUI и остальные панели открыты |
| IDE-008, Outline и IDE-015 | Открыть слева → найти/раскрыть символ → перейти в код → вернуться; Explorer/файлы/zoom и pending callbacks | `outline.test.lua`: 6 real Aerial E2E Windows/Ubuntu PASS; Mac/GUI и остальные языковые backend открыты |
| IDE-009, панели | Одни действия навигации/отмены/скрытия во всех панелях | Debug, Outline и Neo-tree покрыты; Git IDE/tests/поиск/задачи ещё не реализованы |
| Базовое ядро редактора | Запуск, открыть/изменить/сохранить, дерево, имя/содержимое, буферы, фокус | `editor.test.lua`: Windows и Ubuntu PASS; Mac ждёт прогона |
| IDE-BOOT-1/2 | Старт без установки инструментов, отсутствие предупреждения Go в .txt | `editor.test.lua`: Windows и Ubuntu PASS; Mac ждёт прогона; наличие gopls в Windows не фиксируется, отсутствие подтверждено в Ubuntu |
| IDE-016–019, управление файлами | Создать/переименовать/переместить, cut/paste, отмена/конфликт, сохранённые буферы, общий маршрут/selector/zoom | `file-explorer.test.lua`: 7 real editor E2E; границы и результаты ниже |
| Git/worktree | Локальный bare remote → worktree → изменение → diff → commit/push | Не реализован |
| Shell/jobs | Открыть terminal, job, закрыть/восстановить фокус | Не реализован; смена/закрытие файлов и базовый фокус покрыты ядром |
| Языки | Для каждого языка LSP/format/run/debug/tests в применимых сочетаниях | Не реализован |

## Матрица VM

| Среда | Общие сценарии | Специальные проверки | Состояние |
|---|---|---|---|
| Windows native | CLI/IDE/languages | ConPTY, clipboard, ru/en, пути/venv | unit/e2e/wezterm/trace: 27 файлов PASS, включая 10 core, 4 Go/Delve, 5 Go/neotest/eval, 11 snippet, 3 codelldb-discovery, 4 Debug, 6 Outline и 7 File explorer E2E; GUI/остальное IDE-покрытие по таблице выше |
| macOS | CLI/IDE/languages | zsh startup, Cmd, clipboard, arm64 при наличии | Ждёт VM/машину владельца |
| Ubuntu | CLI/IDE/languages | apt/version check, bash/zsh, X11/Wayland по целевой сессии | Docker: 28 PASS, 0 FAIL, 3 SKIP, включая 10 core, 4 Go/Delve, 5 Go/neotest/eval, 11 snippet, 3 codelldb-discovery, 4 Debug, 6 Outline и 7 File explorer E2E; GUI не проверен |
| Mint | CLI/IDE/languages | apt/version check, bash/zsh, desktop clipboard | Временно отложен владельцем |

Этот набор дополняет существующие `wezterm`, `install`, `trace`, `conpty`;
их доказательства учитываются по фактической границе проверки, а не просто
переносятся под ярлык e2e.

Прогон 2026-10-31, рабочее дерево HEAD `1bc3c0f` с текущими изменениями:
Windows Neovim 0.12.2, Ubuntu 24.04/Neovim 0.12.2. Ubuntu SKIP: реальная
загрузка WezTerm (бинарник отсутствует), две дополнительные ветки установщиков
под Bash 3.2 (интерпретатор отсутствует). Основные sandbox-сценарии
установщиков под Bash 5 прошли. Windows ConPTY в этой сессии не прогонялся.
