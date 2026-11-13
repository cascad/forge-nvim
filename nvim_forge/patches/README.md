# Временные исправления плагинов

IDE-034: Neogit `d7bb91b42f984416adc6116d6ba8fba287857af3` ставит переход
в main в очередь, но начинает `git worktree remove` раньше него. На Windows
удаление текущего каталога возвращает `Permission denied`. Один scheduler
после `chdir` дожидается перехода до запуска Git. Исправление общее для ОС.

IDE-043 добавляет на том же pin companion `lua/neogit/lib/util.lua`:
полный OSC title/hyperlink с BEL/ST удаляется до CSI, видимый текст остаётся.
Исключение byte 155 из CSI взято из [upstream](https://github.com/NeogitOrg/neogit/blob/697ad3ee86a73cf6b6758b838d7a7d76cf3b9f86/lua/neogit/lib/util.lua):
этот byte бывает продолжением UTF-8. Обычные пути не фильтруются.
Worktree primary и его SHA не менялись. ID декларации теперь
`IDE-034-043-neogit-cwd-output`; этот этап затрагивал два файла.

IDE-123/IDE-GIT-13 добавляет companion `lua/neogit/lib/git/rebase.lua` на том
же pin. Native Abort sequence editor возвращал Git error в двух строках;
Git Windows пишет `there was`, Ubuntu — `There was`. Прежняя проверка только
stdout[1] принимала отмену за конфликт. Classification-copy объединяет строки
и сравнивает ASCII-регистр; настоящий stdout/настоящие conflicts не подавляются.
Это local fix: [upstream](https://github.com/NeogitOrg/neogit/blob/master/lua/neogit/lib/git/rebase.lua)
проверен 2026-11-13, blobed8aa001577a31ada0ae76e8342d6db0e314bfd8 содержит тот же
старый pattern. Новый ID `IDE-034-043-123-neogit-cwd-output-sequence`, у Neogit
теперь3 hash-guarded files, у всех plugins6 dependencies/14 files. Source RED,
Windows/Ubuntu3 native sequence cases и15 preparation checks сохранены (§212).
После готового upstream fix убрать только этот companion с теми же cases.

`plugins.json` содержит ревизию, точную замену и SHA256 файла до/после.
`ide/backports.lua` — общий applier для Lazy и явной подготовки тестов.
Hash нормализует CRLF→LF; запись сохраняет исходные переводы строк.
Неизвестные ревизии/файлы не изменяются. Повторная подготовка не пишет файл.

На существующей установке один раз выполнить **`:Lazy build neogit`**, затем
перезапустить редактор. Новая установка/явное восстановление через Lazy
используют тот же build hook. При обычном открытии Git конфиг только проверяет
готовность и подсказывает эту команду, если требуется подготовка.
После обновления IDE-043 build повторить и для уже подготовленной IDE-034
установки: primary-after/util-before обновляется явно, primary не переписывается.
Повторный apply/check не пишет подготовленные файлы. Неизвестный companion отклоняется
до любой записи; каждый подготовленный файл заменяется атомарно.
Если установлена другая ревизия Neogit, сначала восстановить её из lock
командой `:Lazy restore neogit`, затем выполнить build.

Вне редактора (из корня репозитория, с тем же NVIM_APPNAME/XDG_DATA_HOME,
что у установленного Forge):

```sh
nvim -l nvim_forge/scripts/prepare-plugins.lua
nvim -l nvim_forge/scripts/prepare-plugins.lua --check
```

Явный каталог Lazy можно передать через `--plugin-root /absolute/path/to/lazy`.
Для тестов этот CLI вызывает `python[3] -B tests/e2e/prepare_editor.py --download`;
`--nvim /absolute/path/to/nvim` выбирает интерпретатор. В prepared manifest
записываются базовый pin, ID и итоговый hash backport. Тесты проверяют файл,
не исправляют его; подготовка не меняет пользовательский Lazy cache.

Версия Neogit закреплена в конфиге через декларацию; `Lazy update` её не двигает.
Локальный patch отображается Git как изменение файлов плагина. Перед заменой
версии отменить **только известное исправление**:

```sh
nvim -l nvim_forge/scripts/prepare-plugins.lua --plugin-root /absolute/path/to/lazy --plugin neogit --revert
```

После подтверждённого upstream исправления отдельным шагом обновить pin,
удалить декларацию/build guard и прогнать `tests/e2e/active-worktree.test.lua`
и `tests/e2e/git-errors.test.lua` на Windows/Ubuntu/macOS. До этого патчи
остаются временной частью подготовки. Отмена Neogit возвращает все три его
известных файла; выбранный плагин задаётся через `--plugin neogit`.
Он не устраняет удержание cwd сторонним процессом и IDE-035 (Gitsigns attach).

## IDE-035: Gitsigns и исчезнувшая папка

Для Gitsigns `dd3f588bacbeb041be6facf1742e42097f62165d` добавлен отдельный
проверяемый backport двух файлов. Обычный command builder передаёт нестабильный
cwd через `git -C`. Repo-команды получают явный process cwd в общем git-dir,
который сохраняется при удалении linked; файловые команды дополнительно
получают `-C` выбранного worktree. Object reads `show` используют выбранный
явный git-dir/HEAD без перехода в linked (IDE-038). Это работает и когда
сам редактор уже находится в linked; наследовать его cwd недостаточно.
При исчезновении пути/metadata сам Git возвращает nonzero/stderr; исключение
запуска `vim.system` не блокирует initial diff. Семантика пути сохраняется,
см. [Git -C](https://git-scm.com/docs/git). Глобальные ошибки редактора не
перехватываются, результаты Git не подменяются.

На существующей установке один раз `:Lazy build gitsigns.nvim`, затем
перезапустить редактор. При другой установленной ревизии сначала
`:Lazy restore gitsigns.nvim`. Обычная загрузка проверяет результат без записи.
Default CLI готовит/проверяет все декларации; для отдельного плагина:

```sh
nvim -l nvim_forge/scripts/prepare-plugins.lua --plugin-root /absolute/path/to/lazy --plugin gitsigns.nvim
nvim -l nvim_forge/scripts/prepare-plugins.lua --plugin-root /absolute/path/to/lazy --plugin gitsigns.nvim --check
nvim -l nvim_forge/scripts/prepare-plugins.lua --plugin-root /absolute/path/to/lazy --plugin gitsigns.nvim --revert
```

Неизвестное имя/содержимое не изменяет файлы. Companion files одной декларации
проверяются и рассчитываются до начала записи; каждый файл пишется атомарно.
Manifest включает hashes обоих файлов. Снятие патча перед заменой pin
и подтверждение upstream fix выполняются отдельно с тем же E2E
`tests/e2e/gitsigns-worktree.test.lua` и `gitsigns-live-read.test.lua`.
Прежний известный payload IDE-035 с hash `6ae5b933…` обновляется тем же
явным build/CLI: декларация previous хранит его точные SHA/фрагмент.
Check прежней версии не пишет файл и просит build; apply переводит её
в текущую, revert — в upstream. Чужие изменения по-прежнему отклоняются.
Этот backport не исправляет системные
тормоза Windows, редкие CLI timeouts или удержание папки другим процессом.

## Neotest: native paths и смена файла (IDE-070)

Прежний primary IDE-051 nearest realpath сохраняется. Три companions pinned
27bf921498043f7ecd821d6db68d05de244bbd02 нормализуют native пути в
client _update_positions, library files.parent/path.real и adapter-group root.
BufAdd directory
path с `/` на Windows смешивался с discovery tree `\`: positions.merge мог
бесконечно оборачивать drive root. Несогласованные parent/real также создавали
дубли roots и присоединяли tests другого workspace. Это причина конкретных
воспроизведённых SQL UI зависаний, не диагноз системных тормозов Windows.

На существующей установке явно `:Lazy build neotest`, затем restart.
`nvim -l nvim_forge/scripts/prepare-plugins.lua --plugin-root <lazy> --plugin neotest`
использует тот же applier; --check/--revert проверяют/возвращают все четыре файла.
Ревизия и 67 pins не менялись. Неизвестный последний companion отклоняется
до записи primary и предыдущих companions. LF/CRLF сохраняются; повтор/check
не меняет mtime. Native process E2E находятся в plugin-backports.test.lua,
настоящие file-switch/stop/workspace E2E — sql-tests.test.lua.
Source RED использует точные before-файлы в private runtime, prepared SDK
не откатывается. Штатный GREEN идёт без diagnostic watchdog.

## Neo-tree: согласованный snapshot и ожидающие раскрытия (IDE-104)

Pin `84c75e7a7e443586f60508d12fc50f90d9aee14e`, native filesystem scanner и
init companion. Исходные фрагменты Neo-tree — [MIT](licenses/neo-tree.nvim.txt),
copyright/notice сохранены из pinned source. Кеширует поколение полного запроса, сохраняет intent раскрытия
перед IO и принимает snapshot с уже раскрытыми каталогами. Если каталог
раскрылся после начала snapshot, штатный async scan включает его до замены
live tree. Watchers меняются при принятии результата; obsolete IO не добавляет refs.
Native IO/filters/renderer и async/follow остаются, отдельного scanner/queue нет.
IDE-105: coherence retry применяется только к обычному full snapshot;
native search_pattern и explicit force_open_folders сохраняют собственный вид.
Иначе фильтр/его очистка могут бесконечно пересканировать исключённые папки.

На существующей установке явно `:Lazy build neo-tree.nvim`, затем restart.
При несовпадении установленной ревизии сначала `:Lazy restore neo-tree.nvim`.
Обычный startup только проверяет готовность. CLI тот же:

```sh
nvim -l nvim_forge/scripts/prepare-plugins.lua --plugin-root /absolute/lazy --plugin neo-tree.nvim
nvim -l nvim_forge/scripts/prepare-plugins.lua --plugin-root /absolute/lazy --plugin neo-tree.nvim --check
nvim -l nvim_forge/scripts/prepare-plugins.lua --plugin-root /absolute/lazy --plugin neo-tree.nvim --revert
```

Primary/companion проходят общий preflight до записи; LF/CRLF сохраняются,
repeat/check не переписывают файлы. Pins не обновлены. Условие удаления —
upstream версия, которая проходит `file-scan-order.test.lua` и `file-filter.test.lua` вместе с обычным
Files workflow и проверками watchers на Windows/Ubuntu/macOS. Отклонённый
generation-only prototype из §179 к принятому payload не относится.

Для уже готового Ubuntu image с теми же67 pins доступен маленький offline
слой явной подготовки; Neovim/tools берутся из локального base image:

```sh
docker build --network=none --pull=false --build-arg BASE_IMAGE=forge-nvim-tests:ubuntu24.04-nvim0.12.2 -f tests/containers/refresh-editor.Dockerfile -t forge-nvim-tests:editor-refresh .
```

Обычный full build основного Dockerfile также поддержан. Новый image проверяется
E2E до смены основного тега; refresh не запускает Desktop/WSL и не делает сетевой
setup. При других pins/байтах lock refresh завершается ошибкой и требует full build.
