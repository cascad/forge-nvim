# Исправление тормозов Rust-навигации в Neovim на Windows

## Проблема

В Rust-проектах `go to definition` нормально работал внутри файлов проекта, но резко начинал тормозить при прыжке в большие файлы стандартной библиотеки Rust, например в `std::fs::File` или `std::path::PathBuf`.

Выглядело это так:

- первый `gd` в большой файл stdlib проходил быстро;
- прыжок назад давал небольшую задержку;
- следующий `gd` в такой же внешний файл мог подвесить Neovim на 10-20 секунд;
- после фриза переход все-таки завершался.

На первый взгляд казалось, что rust-analyzer плохо проиндексировал проект. Но основная проблема была не в этом.

## Реальная причина

rust-analyzer уже индексировал workspace и умел быстро найти definition. Тормоза появлялись после того, как Neovim открывал целевой файл из стандартной библиотеки.

Когда `gd` открывал файл из `rust-src`, например `fs.rs` на 3000+ строк, несколько возможностей Neovim и UI-плагинов начинали относиться к нему как к обычному проектному буферу:

- Treesitter парсил большой Rust-файл ради подсветки, indent, textobjects, навигационных queries и folds.
- `foldexpr = nvim_treesitter#foldexpr()` мог многократно вычисляться в этом большом файле.
- `vim-illuminate` мог отправлять в LSP запросы `textDocument/documentHighlight`.
- `barbecue.nvim` / `nvim-navic` могли отправлять в LSP запросы `textDocument/documentSymbol`, чтобы построить breadcrumbs.
- semantic tokens и document highlights от rust-analyzer могли запрашиваться достаточно рано, чтобы добавить тяжелую фоновую работу.
- `project.nvim` мог принять `.rustup` / `rust-src` / cargo registry за проектную область и вмешаться в cwd/project detection.

LSP-запросы фактически идут через одну очередь клиента. Поэтому следующий `gd` был медленным не потому, что rust-analyzer не знал ответ. Он был медленным потому, что очередь клиент/сервер уже была забита тяжелыми запросами, которые появились после открытия большого внешнего файла.

Коротко:

> Сам `gd` был нормальный. Фриз происходил после открытия целевого буфера, потому что Neovim просил слишком много от rust-analyzer и Treesitter для stdlib/vendor-файлов.

## Идея фикса

Фикс разделяет Rust-файлы на две категории:

- проектные Rust-файлы, где должны оставаться полноценные IDE-фичи;
- внешние Rust-файлы, например stdlib и cargo registry, где навигация должна быть быстрой, а тяжелые UI-фичи должны быть отключены.

Внешние Rust-файлы определяются по пути:

- `.rustup`
- `rustlib/src`
- `.cargo/registry`
- `.cargo/git`
- пути toolchain

Это специально сделано по path-based логике, а не через cwd. Проверка через cwd хрупкая: project-плагины могут менять cwd на `BufEnter`, и тогда внешний файл легко классифицировать неправильно.

## Какие файлы изменены

### `lua/config/rust_external.lua`

Добавлен маленький helper-модуль, который централизованно определяет внешние Rust-буферы.

Он экспортирует:

- `is_path(path)` - проверяет, относится ли путь к внешним rustup/cargo/toolchain sources;
- `is_buf(bufnr)` - проверяет путь текущего буфера;
- `mark(bufnr)` - ставит `vim.b[bufnr].rust_external = true` для внешних Rust-буферов.

Это убирает дублирование path-checks в разных plugin configs.

### `lua/plugins/lsp.lua`

Поведение rust-analyzer изменено в двух местах.

Во-первых, существующая логика external-buffer теперь использует `config.rust_external`, а не пересчитывает cwd/home/path прямо внутри `lsp.lua`.

Во-вторых, rust-analyzer теперь отключает две тяжелые capabilities уже на `on_init`:

- `semanticTokensProvider`
- `documentHighlightProvider`

Это важно, потому что отключать их только в `LspAttach` может быть слишком поздно. Некоторые плагины или core-поведение Neovim могут запросить semantic tokens или highlights сразу после attach. Отключение во время initialization не дает этим запросам попасть в очередь вообще.

Diagnostics и inlay hints по-прежнему отключаются для внешних Rust-буферов. Обычные проектные файлы сохраняют полезные возможности rust-analyzer.

### `lua/plugins/treesitter.lua`

Добавлен guard `slow_rust_file()`.

Treesitter отключается для:

- внешних Rust-буферов, найденных через `rust_external.mark(bufnr)`;
- Rust-файлов больше 2500 строк.

Guard применяется к:

- Treesitter highlight;
- Treesitter indent;
- Treesitter textobject selection;
- Treesitter textobject movement;
- Treesitter textobject swapping.

Также конфиг отключает Treesitter folds для таких буферов, переключая окно на:

- `foldmethod = manual`
- `foldexpr = 0`

Это важно, потому что Treesitter fold expressions могут многократно вычисляться и заметно тормозить на больших файлах.

Проектные Rust-файлы продолжают использовать Treesitter как обычно.

### `lua/plugins/ide.lua`

LSP-тяжелые UI-плагины обновлены так, чтобы они раньше и надежнее учитывали внешние Rust-буферы.

Для `vim-illuminate`:

- внешние Rust-буферы помечаются до configure;
- `should_enable()` вызывает `rust_external.mark(bufnr)`;
- illuminate не отправляет LSP document highlight requests для stdlib/cargo-файлов.

Для `barbecue.nvim` / `nvim-navic`:

- кастомный update autocmd теперь вызывает `rust_external.mark(args.buf)`;
- breadcrumbs не обновляются для внешних Rust-буферов;
- это предотвращает дорогие `textDocument/documentSymbol` requests на больших stdlib-файлах.

### `lua/plugins/editor.lua`

Расширен `project.nvim.exclude_dirs`:

- `~/.rustup/*`
- `*/.cargo/*`
- `*/.rustup/*`
- `*/rustlib/src/*`

Это не дает project root detection воспринимать toolchain или cargo registry files как обычные проекты при прыжках в definition.

## Почему это убрало фриз

После фикса прыжок в `rust-src` открывает целевой файл, но не запускает тяжелую фоновую работу, которая раньше блокировала следующий navigation request.

Главное изменение поведения:

- rust-analyzer все еще находит definitions;
- LSP все еще attach-ится, поэтому hover и navigation могут работать;
- тяжелые diagnostics, inlay hints, document highlights, semantic tokens, document symbols, Treesitter parsing и Treesitter folds пропускаются для внешних Rust sources.

В итоге stdlib/vendor-файлы ведут себя как read-only library source view, а не как полноценные project files.

Это ближе к тому, как внутри работают JetBrains/VS Code-style IDE: проектные файлы получают полный semantic service, а library source views оптимизируются так, чтобы навигация оставалась отзывчивой.

## Что осталось включенным

Фикс не убирает Rust-поддержку.

Для обычных проектных файлов конфиг по-прежнему сохраняет:

- rust-analyzer;
- cargo all features;
- build scripts;
- proc macros;
- diagnostics;
- clippy on save;
- inlay hints;
- formatting;
- Treesitter;
- Go/Python/Lua LSP setup.

Оптимизация касается только внешних Rust source files и очень больших Rust-файлов.

## Проверка

Проблемный сценарий был проверен вручную:

1. Открыть Rust-проект.
2. Дождаться завершения rust-analyzer indexing.
3. Сделать `gd` на символах вроде `fs::File` или `PathBuf`.
4. Прыгнуть назад.
5. Снова сделать `gd`.

После изменения навигация больше не зависает на 10-20 секунд.

Cursor/IDE Lua diagnostics также были проверены для измененных файлов и не показали linter errors.

Единственная проверка, которую не удалось запустить из agent shell, - headless startup Neovim, потому что `nvim` не был доступен в `PATH` той shell-сессии.

## Если проблема вернется

Если похожие фризы снова появятся, следующий шаг - смотреть LSP log во время воспроизведения:

```vim
:LspDebug debug
:LspLog
```

Искать повторяющиеся или медленные requests вокруг момента фриза, особенно:

- `textDocument/documentSymbol`
- `textDocument/documentHighlight`
- `textDocument/semanticTokens/full`
- `textDocument/inlayHint`
- diagnostics pull requests

Если один из таких запросов появляется прямо перед фризом, ответственный плагин надо заставить пропускать буферы с `vim.b.rust_external`.
