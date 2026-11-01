# Временные исправления плагинов

IDE-034: Neogit `d7bb91b42f984416adc6116d6ba8fba287857af3` ставит переход
в main в очередь, но начинает `git worktree remove` раньше него. На Windows
удаление текущего каталога возвращает `Permission denied`. Один scheduler
после `chdir` дожидается перехода до запуска Git. Исправление общее для ОС.

`plugins.json` содержит ревизию, точную замену и SHA256 файла до/после.
`ide/backports.lua` — общий applier для Lazy и явной подготовки тестов.
Hash нормализует CRLF→LF; запись сохраняет исходные переводы строк.
Неизвестные ревизии/файлы не изменяются. Повторная подготовка не пишет файл.

На существующей установке один раз выполнить **`:Lazy build neogit`**, затем
перезапустить редактор. Новая установка/явное восстановление через Lazy
используют тот же build hook. При обычном открытии Git конфиг только проверяет
готовность и подсказывает эту команду, если требуется подготовка.
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
Локальный patch отображается Git как изменение файла плагина. Перед заменой
версии отменить **только известное исправление**:

```sh
nvim -l nvim_forge/scripts/prepare-plugins.lua --plugin-root /absolute/path/to/lazy --revert
```

После подтверждённого upstream исправления отдельным шагом обновить pin,
удалить декларацию/build guard и прогнать `tests/e2e/active-worktree.test.lua`
на Windows/Ubuntu/macOS. До этого патч остаётся временной частью подготовки.
Он не устраняет удержание cwd сторонним процессом и IDE-035 (Gitsigns attach).
