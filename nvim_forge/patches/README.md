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
`IDE-034-043-neogit-cwd-output`; prepared manifest хранит hashes обоих файлов.

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
Повторный apply/check не пишет оба файла. Неизвестный companion отклоняется
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
остаются временной частью подготовки. Отмена Neogit возвращает оба его
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
