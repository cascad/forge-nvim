# RATIONALE — почему конфиг Helix выглядит именно так

Этот файл — **журнал решений**. README отвечает на «как пользоваться»,
а здесь — «что сделано, почему сделано, что осознанно не сделано».
Если в будущем что-то покажется странным — открыть этот файл и понять
логику, не реверс-инжиниря.

Источники, на которых построен конфиг:

* `F:/claude_code/vim/settings.json` — VS Code user settings (Vim-плагин + общие).
* `F:/claude_code/vim/keybindings.json` — VS Code user keybindings.
* Запросы пользователя в чате (поиск, go-to, debugger, vim-управление).
* Пользовательская память (`memory/feedback_editor_modal_keys.md`) —
  закреплённые preference'ы по модальным редакторам.

---

## 1. Стратегия установки

| Решение | Почему |
|---|---|
| Сборка из исходников через `cargo install --path helix-term --locked` | Helix не имеет официальных Windows-пакетов с актуальными релизами; `--locked` даёт воспроизводимую сборку из `Cargo.lock` |
| Клон в `~/src/helix` (можно переопределить `HELIX_SRC_DIR`) | Стандартное место для исходников; не мешает конфигам и не зависит от прав |
| `runtime/` — symlink на Linux/macOS, копия на Windows | Под Windows символические ссылки требуют админ-прав или Developer Mode; копия — fallback, который точно работает |
| `hx --grammar fetch && hx --grammar build` после первой сборки | Без этого не будет подсветки и tree-sitter навигации — встроенные грамматики не идут в комплекте |
| LSP-серверы ставятся **через нативные тулчейны** (`rustup component`, `go install`, `pipx install`) | Это рекомендуемый Helix способ: даёт автообновление вместе с тулчейном и не плодит собственный пакетный менеджер |

---

## 2. Перенос `settings.json` → Helix

### 2.1 Что перенесено в `config.toml`

| VS Code key | Helix эквивалент | Причина |
|---|---|---|
| `files.autoSave: "afterDelay"`, `autoSaveDelay: 200` | `[editor.auto-save] focus-lost = true; after-delay.enable = true; after-delay.timeout = 200` | Дословный перенос — пользователь привык к агрессивному автосейву |
| `editor.formatOnSave: true` | `auto-format = true` (глобально + per-language) | То же поведение: форматтер дёргается на каждом `:w` (или autosave) |
| `editor.cursorSurroundingLines: 999` | `scrolloff = 999` | Курсор всегда в центре экрана; в Helix-памяти зафиксировано как обязательное preference |
| `vim.overrideCopy: false` | `default-yank-register = "+"` | Чтобы `y/d/c` сразу попадали в системный буфер, без явного `"+y` или `Space y` |
| `vim.useCtrlKeys: true` + `vim.handleKeys` | Полный набор `[keys.normal/insert/select]` ремапов на стандартные действия (см. §2.3) | В Helix нет «чёрного списка для Vim-плагина» — нужно явно ремапить каждую клавишу |
| `vim.camelCaseMotion.enable: true` | Не нужно — встроено: `Alt-w`, `Alt-b`, `Alt-e` ходят по subwords | Helix умеет это из коробки |
| `vim.normalModeKeyBindingsNonRecursive: $→g_` | См. §2.4 (фикс выделения с `\n`) | Главный пункт-боль из памяти пользователя |
| `vim.visualModeKeyBindings: $→g_` | То же в `[keys.select]` | См. §2.4 |
| `editor.suggest.insertMode: "replace"` | `completion-replace = true` | То же поведение — completion заменяет, а не вставляет рядом |
| `editor.largeFileOptimizations: false` | Не нужно — Helix эффективен на больших файлах нативно | Это VS Code-специфичный костыль |

### 2.2 Что перенесено в `languages.toml`

| VS Code key | Helix эквивалент | Причина |
|---|---|---|
| `rust-analyzer.check.command: "clippy"` | `[language-server.rust-analyzer.config] check.command = "clippy"` | Дословный перенос — пользователь хочет clippy на check |
| `rust-analyzer.checkOnSave: true` | `checkOnSave = true` | Аналогично |
| `rust-analyzer.diagnostics.disabled: ["unlinked-file"]` | `diagnostics.disabled = ["unlinked-file"]` | Не ругаться на одиночные `.rs` вне Cargo workspace — раздражает |
| `[rust] editor.defaultFormatter: rust-analyzer` | `[[language]] auto-format = true` (для rust) | rust-analyzer форматит через LSP по умолчанию, отдельный formatter не нужен |
| `[go] editor.formatOnSave + source.organizeImports: explicit` | `[[language]] auto-format = true` + `gopls` сам делает organize-imports на формат | gopls имеет это встроенным; явный formatter `gofumpt` опционален |
| `go.formatTool: "goimports"` | gopls делает то же через `gofumpt` (более строгий goimports) | gofumpt = goimports + дополнительные правила; считаю апгрейдом |
| `python.languageServer: "Pylance"` | `pyright` | Pylance закрытый, работает только в VS Code; pyright — открытый аналог от той же команды |
| `[python] editor.formatOnType: true` | Helix не поддерживает format-on-type, только format-on-save | Принципиальное ограничение Helix; формат на `:w` остаётся |

### 2.3 `vim.handleKeys` → раскладка Ctrl-клавиш

В VS Code пользователь явно отключал у Vim-плагина следующие Ctrl-клавиши,
чтобы они работали как в обычной IDE:

```
<C-c> <C-v> <C-f> <C-r> <C-a> <C-S-e> <C-S-f> <C-k> <C-s> <C-w> <C-[> <C-]> <C-h> <C-j>
```

В Helix аналогичного «чёрного списка» нет — нужно прописать каждую
клавишу как явный keybinding. Сделано так:

| Клавиша | Назначение | Где (mode) |
|---|---|---|
| `C-c` | yank в clipboard | normal, select |
| `C-v` | paste из clipboard | normal, insert, select |
| `C-x` | cut | normal, select |
| `C-z` / `C-y` / `C-S-z` | undo / redo / redo | normal, insert (только undo) |
| `C-a` | select all | normal, select |
| `C-f` | search | normal |
| `C-s` | save (`:w`) | normal, insert |
| `C-S-s` | save all | normal |
| `C-p` / `C-S-p` | file picker / command palette | normal |
| `C-b` | buffer picker | normal |
| `C-S-f` | global search | normal |
| `C-/` | toggle comment | normal, insert, select |
| `C-l` | выделить строку без `\n` | normal, select |
| `C-q` / `C-S-q` | quit / quit all | normal |

**Что осознанно пропущено:**

* `<C-h>`, `<C-j>`, `<C-k>`, `<C-w>` — оставлены под Helix-стандарт (`C-w` — window-команды через лидер `C-w h/j/k/l`). Перебивать их = ломать стандарт.
* `<C-[>`, `<C-]>` — Helix использует их для indent/outdent в insert mode, что совпадает с ожиданиями VS Code. Не трогаем.
* `<C-r>` — в Helix это insert register; перебивать не стоит.
* `<C-S-e>` — VS Code Explorer; в Helix это `Space f f`.
* `Ctrl+H` (replace) — нет одной команды; задокументировано использовать `:s/old/new/g`.

### 2.4 Самый болезненный пункт: «выделение строки до конца захватывает `\n`»

**Проблема пользователя.** В Vim `$` выделяет до перевода строки
включительно, поэтому `v$d` удаляет ещё и `\n`, и курсор «прыгает»
на следующую строку. В VS Code Vim это решалось:

```json
"vim.visualModeKeyBindings": [{ "before": ["$"], "after": ["g", "_"] }],
"vim.normalModeKeyBindingsNonRecursive": [{ "before": ["$"], "after": ["g", "_"] }]
```

`g_` идёт до **последнего непробельного** символа в строке.

**В Helix это устроено иначе:**

| Команда | Что делает |
|---|---|
| `gl` (`goto_line_end`) | курсор на символ перед `\n` — **без** newline. Уже корректно |
| `gh` (`goto_line_start`) | курсор на первый символ строки |
| `x` (`extend_line_below`) | выделяет всю строку **с** `\n` — **вот источник боли** |
| `X` (`extend_to_line_bounds`) | расширяет текущее выделение до границ строки, **с** `\n` |
| `_` (`trim_selections`) | удаляет ведущие/завершающие whitespace из выделения, включая `\n` |

**Решение.** Переопределяем `x` (и зеркально `$` в select-режиме):

```toml
[keys.normal]
x = ["extend_to_line_bounds", "trim_selections"]

[keys.select]
x = ["extend_to_line_bounds", "trim_selections"]
$ = "goto_line_end"
```

Теперь `x` ведёт себя как `g_` в Vim: выделяет всю строку, но `\n`
обрезается, курсор остаётся на текущей строке. Последующие `d/c/y`
работают корректно.

**Альтернативу `select_line_*` без `\n` Helix не предоставляет** —
последовательная композиция через `trim_selections` это единственный
надёжный способ.

---

## 3. Перенос `keybindings.json` → Helix

### 3.1 Что перенесено

| VS Code | Helix | Заметки |
|---|---|---|
| `Alt+J` → revealDefinition | `A-j` = `goto_definition` (normal) | Дублирует стандартный `gd` |
| `Alt+[` / `Alt+]` → navigateBack/Forward | `A-[` / `A-]` = `jump_backward` / `jump_forward` | Дублирует стандартный `C-o` / `C-i` |
| `Shift+Alt+K` → smartSelect.expand | `S-A-k` = `expand_selection` | Дублирует стандартный `A-o` |
| `Shift+Alt+J` → smartSelect.shrink | `S-A-j` = `shrink_selection` | Дублирует стандартный `A-i` |
| `Alt+Win+L` → formatDocument | `S-A-f` = `:format` | Win-клавиша из терминала не передаётся, выбран ближайший VS Code-стандарт `Shift+Alt+F` |
| `Ctrl+Enter` → runSelectedText в терминале | `C-ret` = `:pipe-to bash` | Helix не имеет встроенного терминала; `:pipe-to` отправляет выделение в внешний процесс |
| `Ctrl+J` / `Ctrl+K` → selectNext/PrevSuggestion | `C-j` / `C-k` в **insert** = `move_line_down` / `move_line_up` | В Helix completion popup листается курсором — `move_line_*` именно это и делает |

### 3.2 Что **не** перенесено и почему

| VS Code | Почему не перенесено |
|---|---|
| `-selectPrevSuggestion ctrl+up`, `-selectNextSuggestion ctrl+down` | В Helix эти стрелки не конфликтуют с новыми `C-j/C-k`; «отключать» нечего |
| `-editor.action.formatDocument shift+alt+f` | Наоборот, **переиспользовали** `S-A-f` под `:format` — это и есть желаемое поведение |
| `editor.action.formatDocument.none` | VS Code-внутренний no-op для случая «нет форматтера»; в Helix не имеет смысла |
| `notebook.formatCell` | Helix не работает с `.ipynb` нативно — нет ячеек |
| `-selectNextCodeAction down`, `-selectPrevCodeAction up` | Picker'ы Helix принимают и стрелки, и `C-n/C-p` без всяких отключений |
| `when`-контексты (`suggestWidgetVisible`, `actionWidgetVisible`) | Helix не поддерживает условные keybinds — биндинг работает универсально, а попап перехватывает событие сам |

---

## 4. Решения по IDE-фичам поверх стандарта Helix

### 4.1 Поиск

Запрос пользователя: «нужен нормальный поиск».

| Что | Решение |
|---|---|
| По файлу | `/` `?` `n` `N` — стандарт Helix, не трогаем |
| По проекту | `Ctrl+Shift+F` или `Space s s` — `global_search` (использует ripgrep) |
| По буферам | `Ctrl+B` или `Space f b` |
| По символам файла | `Space l s` — `symbol_picker` |
| По символам workspace | `Space l w` или `Space s W` — `workspace_symbol_picker` |
| По диагностикам | `Space l e` (текущий буфер) / `Space l E` (workspace) |
| По командам | `Ctrl+Shift+P` или `Space ?` — `command_palette` |
| По jumplist | `Space f j` |

Всё через picker'ы с fuzzy-search — работает «как Telescope» / VS Code Quick Open.

### 4.2 Go-to (definition / implementation / references)

Запрос: «go to переходы к имплементации или наоборот».

Стандарт Helix покрывает всё:

| | Helix | F-клавиша (VS Code-style) |
|---|---|---|
| Definition | `g d` | `F12` |
| References | `g r` | `Shift+F12` |
| Implementation | `g i` | `Ctrl+F12` |
| Type definition | `g y` | — |
| Declaration | `g D` | — |

Добавлены F-клавиши, чтобы мышечная память VS Code продолжала работать.

### 4.3 Debugger

Запрос: «визуальный дебаггер как в VS Code хотя бы».

**Что Helix может:** встроенный DAP-клиент (тот же протокол, что у VS
Code), полные функции — breakpoints, step in/out/over, eval, variables,
stack. Адаптеры:

| Язык | Adapter | Установка |
|---|---|---|
| Rust | `codelldb` | вручную из релизов vadimcn/codelldb (см. §5 install-helix.sh) |
| Go | `dlv dap` | `go install github.com/go-delve/delve/cmd/dlv@latest` |
| Python | `debugpy` | `pip install --user debugpy` |

Прописаны DAP-templates в `languages.toml` — F5 запускает picker
шаблонов (binary / test / source / attach), чтобы не вводить аргументы
руками.

**Чего Helix не может (и почему это всё равно ОК):**

* Нет постоянной side-panel с переменными/стеком/watch как в VS Code.
  Данные показываются через picker'ы по запросу (`Space d v`, `:debug-eval`).
* Нет UI для условных breakpoints в стиле «правый клик → Edit Breakpoint».
  Делается через `:debug-breakpoint <condition>`.
* Нет hover-tooltip с значением переменной при наведении мышью.
  Замена — `:debug-eval <выражение>` или `Space d e`.

**Когда этого мало** — задокументировано в README: оставить Helix для
редактирования, переключаться в VS Code/JetBrains только для
дебаг-сессии.

### 4.4 Vim-управление

Запрос: «нужна поддержка vim управления (базовая)».

Базовые движения в Helix **те же**, что в Vim: `hjkl`, `wbe`, `iaIAoO`,
`/?nN`, `:w :q :wq :e`, `ypdc`, `u`, `m`, `q` (recording), `.` (repeat).

**Главное отличие** — порядок операций (Kakoune-модель):

* Vim: **глагол + объект** → `diw`, `ci{`, `yap`
* Helix: **объект + глагол** → `miw d`, `mi{ c`, `map y`

Это не баг, это другая дизайн-философия: в Helix всегда что-то
выделено и видно на экране. Пользователь сначала «целится» (выделяет),
потом действует.

В README дана таблица переводов и совет про `hx --tutor` (30 минут —
и переключение становится естественным).

**Сознательно не делаем «vim-mode плагин»** — он бы сломал
selection-first ядро Helix и потерял половину преимуществ редактора
(multiselection, surround, structural editing).

---

## 5. Структура установочного скрипта

`install-helix.sh` — линейный bash, не требует sudo, работает на
Linux/macOS/Windows (Git Bash). Логика:

1. **detect_os** — единое место принятия решений по платформе.
2. **check_build_deps** — fail fast при отсутствии git/cargo/cc; явное сообщение, что поставить и откуда.
3. **clone_or_update** — `--depth 1` по умолчанию для скорости; `--update` делает `git pull --ff-only`.
4. **build_helix** — `cargo install --path helix-term --locked`.
5. **setup_runtime** — symlink/copy + `hx --grammar fetch/build`.
6. **install_lsp_*** — каждое LSP в отдельной функции, чтобы можно было пропускать через `--no-lsp` или ловить ошибки независимо.
7. **install_dap_*** — DAP-адаптеры. `codelldb` имеет ручную инструкцию (нет официального cargo-пути).
8. **install_configs** — копирует конфиги с бэкапом существующих (`*.bak.YYYYmmdd-HHMMSS`), чтобы случайно не потереть пользовательскую правку.

`verify-helix.sh` отделён намеренно — установка бывает прервана, а
проверка должна быть запускаемой повторно.

---

## 6. Что осознанно **не** добавлено в конфиг

| Что | Почему |
|---|---|
| Кастомная цветовая тема | `onedark` встроен в Helix; пользователь сам сменит через `:theme <name>` если захочет |
| Плагины (Helix их не имеет) | Это феноменологическое ограничение Helix — всё нужное вшито в ядро (LSP, DAP, tree-sitter, multi-cursor, surround) |
| `windows-style` keybinds на каждый чих | Сохранён баланс: VS Code-биндинги добавлены поверх Helix-биндингов, но не заменяют их. Пользователь может пользоваться обоими стилями |
| Привязка `Ctrl+H` к replace | В Helix нет одной replace-команды; костыль из `:sh sed -i` хуже, чем `:s/old/new/g` |
| Format-on-type для Python | Helix не поддерживает on-type formatting в принципе |
| Notebook-поддержка | Helix не работает с Jupyter; задача вне scope |
| Live-share / collab | Не существует в Helix |
| Git side-panel как в VS Code | Helix имеет gutter-индикаторы и `Space g`-команды; полноценный TUI-git вынесен наружу (lazygit/gitui через `:sh`) |

---

## 7. Чек-лист после установки

После `bash install-helix.sh` стоит проверить:

* [ ] `bash verify-helix.sh` → 0 ошибок
* [ ] `hx --health rust` → все строки зелёные
* [ ] `hx --health go` → все строки зелёные
* [ ] `hx --health python` → все строки зелёные
* [ ] В `hx .` работает `Ctrl+P` (file picker) и `Ctrl+Shift+F` (global search)
* [ ] В `hx file.rs`: `g d` прыгает на definition, `g i` — на implementation
* [ ] `Ctrl+C` копирует выделение **в системный буфер** (вставить в браузер)
* [ ] `x` выделяет строку **без** перевода строки (курсор остаётся на текущей)
* [ ] `F9` ставит breakpoint, `F5` запускает дебаг
* [ ] Изменение файла + 200мс простоя → файл сохранился без `:w` (autosave)
* [ ] Курсор всегда около центра экрана при движении

Если что-то не работает — `5. Troubleshooting` в README.md или
обновление Helix через `bash install-helix.sh --update` (часть фич
вроде `default-yank-register` появилась только в 24.07+).

---

## 8. Хронология изменений

* **Шаг 1** — базовый набор: install-скрипт, languages.toml (Rust/Go/Python LSP), config.toml (IDE-style биндинги), verify, README.
* **Шаг 2** — пользователь попросил поиск, go-to, дебаггер, базовый vim. Добавлены DAP-адаптеры (codelldb, dlv, debugpy), DAP-templates в languages.toml, F-клавиши под VS Code, раздел в README про Vim → Helix.
* **Шаг 3** — пользователь дал `settings.json`. Перенесены autosave (200мс), scrolloff=999, default-yank-register=+, VS Code-style Ctrl-биндинги, фикс `x` без `\n`, rust-analyzer.diagnostics.disabled. Сохранена память про preference'ы модальных редакторов.
* **Шаг 4** — пользователь дал `keybindings.json`. Перенесены Alt+J (goto def), Alt+[/], Shift+Alt+J/K, Shift+Alt+F (format), Ctrl+Enter (pipe-to bash), Ctrl+J/K (completion popup в insert).
* **Шаг 5** — этот файл (RATIONALE.md) — чтобы все «почему» были в одном месте.
