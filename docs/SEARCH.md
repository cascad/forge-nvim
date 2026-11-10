# Поиск и optional native fzf

`Ctrl+P` / `Space f f` ищут файл по имени, `Space f g` — содержимое через rg,
`Space s w` — слово под курсором, `Space s b` — текст текущего буфера.
В picker: ввод фильтрует список, `Ctrl+j/k` меняют выбор, `Enter` открывает
результат, `Esc` закрывает. Поиск сохраняет штатное управление Telescope.

Native fzf — необязательное ускорение. Если закреплённая библиотека загружается,
она используется независимо от наличия CMake/компилятора в PATH. При отсутствии
или ошибке загрузки остаётся Lua fallback; обычный поиск и переходы работают.
Расширенный синтаксис fzf (`alpha !.md$` и т.п.) относится к native режиму.
Открытие редактора/picker не запускает сборку или скачивание sorter.

`:checkhealth forge` показывает секцию `search sorter`: `native fzf` либо
`Lua fallback` с причиной загрузки. Если Telescope ещё не загружен —
`Telescope not loaded`: health не загружает UI только ради проверки.
Существующая DAP-интеграция может загрузить Telescope раньше первого picker.
Если режим ещё не определён, открой Ctrl+P и повтори health.
Флаг loaded в Lazy не является доказательством выбранного native sorter.

Для пользовательского профиля с CMake и C toolchain (Windows: MSVC Build Tools;
Linux/macOS: штатный GCC/Clang + make) явная сборка:

```vim
:Lazy build telescope-fzf-native.nvim
```

После неё перезапусти редактор, чтобы повторить загрузку. Pins не меняются.

Для тестового SDK из корня репозитория:

```sh
python3 -B tests/e2e/prepare_editor.py --download
python3 -B tests/e2e/prepare_fzf.py
nvim -l tests/e2e/search-sorter.test.lua
```

На Windows — `python` и выбранный Neovim SDK, как в tests/e2e/README.
`prepare_fzf.py --editor-deps <path>` использует уже подготовленные pinned
исходники, сеть не нужна. `--build-root <path>` меняет только build temp;
по умолчанию это `.tests/tmp` текущего checkout. В SDK остаётся одна DLL/SO,
в manifest — pin, platform, SHA исходников и artifact. Нативные Windows/Ubuntu
проверки не заменяют macOS/ARM64 и физическую клавиатуру/GUI.
