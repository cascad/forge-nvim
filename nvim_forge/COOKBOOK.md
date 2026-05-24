# Cookbook (nvim_forge)

Пошаговые рецепты для типичных сценариев в IDE: от открытия проекта
до коммита и дебага. Каждый шаг подписан клавишей. Где есть несколько
способов сделать одно и то же — приводится альтернатива.

Полный справочник всех хоткеев: `KEYBINDINGS.md`.

Содержание:

1. [Запуск и открытие проекта](#1-запуск-и-открытие-проекта)
2. [Навигация по файлам](#2-навигация-по-файлам)
3. [Редактирование](#3-редактирование)
4. [Поиск и замена](#4-поиск-и-замена)
5. [Code navigation (LSP)](#5-code-navigation-lsp)
6. [Code actions / refactoring](#6-code-actions--refactoring)
7. [Git workflow](#7-git-workflow)
8. [Debug](#8-debug)
9. [Tests](#9-tests)
10. [Tasks / Build / Run](#10-tasks--build--run)
11. [Diagnostics / Trouble](#11-diagnostics--trouble)
12. [Outline / Symbols](#12-outline--symbols)
13. [Terminal](#13-terminal)
14. [Layouts / Panels](#14-layouts--panels)
15. [Sessions](#15-sessions)
16. [Закрытие / выход](#16-закрытие--выход)

---

## 1. Запуск и открытие проекта

### 1.1 Открыть проект из терминала

```pwsh
nvim_forge.cmd D:\path\to\project
```

Результат: Neo-Tree слева, alpha welcome справа (если файлов нет), все
плагины подняты в изоляции от других конфигов (см. `nvim_forge.cmd`).

### 1.2 Открыть недавний проект (изнутри nvim)

1. `<leader>fp` или `<leader>op` — picker недавних проектов.
2. Выбрать → `<CR>`.

Альтернатива: `<leader>oP` — открыть проект по пути (prompt).

### 1.3 «Открыть папку как проект» (текущий cwd)

`<leader>ow` — Open: work in current folder. Использует уже текущую
рабочую директорию nvim как проект (без переоткрытия).

### 1.4 Открыть свой конфиг для редактирования

`<leader>oC` — открывает `init.lua` конфига nvim_forge.

---

## 2. Навигация по файлам

### 2.1 Найти и открыть файл по имени (Ctrl+P style)

1. `<C-p>` (или `<leader>ff`) — telescope find_files.
2. Начать печатать имя — fuzzy match.
3. `<C-j>` / `<C-k>` — вниз/вверх по списку.
4. `<CR>` — открыть.

### 2.2 Открыть недавно редактированный файл

`<leader>fr` — telescope oldfiles.

### 2.3 Открыть из Neo-Tree explorer

1. `<leader>e` — открыть Neo-Tree (если закрыт).
2. `<C-e>` — фокус в explorer.
3. `j` / `k` — навигация.
4. `l` или `<CR>` — раскрыть папку / открыть файл.
5. `h` — свернуть папку.
6. `<C-e>` снова — вернуться в editor.

### 2.4 Reveal текущий файл в Neo-Tree

`<leader>E` — раскрыть дерево до места, где лежит открытый сейчас файл.

### 2.5 Переключиться между открытыми буферами

- `<S-l>` или `<Tab>` или `]b` или `<A-l>` или `<C-PageDown>` — next.
- `<S-h>` или `<S-Tab>` или `[b` или `<A-h>` или `<C-PageUp>` — prev.
- `<leader>bb` или `<C-b>` — picker всех buffers (с MRU sort).

### 2.6 Открыть файл по jumplist (как в браузере «назад»)

- `<A-[>` — назад (по jump history).
- `<A-]>` — вперёд.
- `<leader>fj` — telescope jumplist (визуальный picker).

### 2.7 Открыть терминал и из него файл

1. `<leader>tt` — открыть toggleterm снизу.
2. Запустить, например, `code .` или `git diff` для просмотра.
3. `<C-\>` или `<leader>tt` снова — закрыть терминал.

---

## 3. Редактирование

### 3.1 Сохранить файл

`<C-s>` — works в normal / insert / visual mode.

### 3.2 Сохранить всё и выйти

- `<leader>qw` — save & quit all (`:wqa`).
- `<leader>qq` — quit all без save.

### 3.3 Закрыть текущий файл (как `Ctrl+W` в VS Code)

- `<C-q>` или `<leader>bd` или `<F4>` или `<A-w>`.
- Если это был последний файл — появится alpha welcome screen (не Noname).
- Если фокус в Neo-Tree / DAP / etc — закроется это окно, не файл.

### 3.4 Закомментировать строку

- `<C-/>` или `<C-_>` — toggle comment line (в normal/insert).
- В visual mode выделить и `<C-/>` — toggle на selection.

### 3.5 Indent / outdent

- `<C-]>` или `>>` — indent right (normal/insert).
- `<<` — indent left.
- В visual: `>` / `<` (сохраняют выделение).

### 3.6 Переместить строку вверх/вниз

- `<A-Up>` / `<A-Down>` — move line (normal/insert/visual).
- `<S-A-Up>` / `<S-A-Down>` — duplicate.

### 3.7 Undo / Redo

- `<C-z>` — undo.
- `<C-y>` — redo (или `<C-r>`).

### 3.8 Copy / Paste из системного буфера

(Clipboard уже = `unnamedplus`, так что `y` / `p` тоже работают.)

- `<C-c>` — copy selection (в visual).
- `<C-x>` — cut.
- `<C-v>` — paste.
- `<C-a>` — select all.

### 3.9 Запустить выделение как pwsh-команду

В visual mode выделить → `<C-CR>` — прогон через `pwsh -NoLogo -NoProfile -Command -`.

### 3.10 Smart-select (расширить выделение по AST)

`gnn` запускает treesitter incremental_selection, потом:
- `grn` — расширить (grow node).
- `grm` — сузить (shrink).
- `grc` — расширить до класса/функции.

(Используется nvim-treesitter, см. `plugins/treesitter.lua`.)

---

## 4. Поиск и замена

### 4.1 Найти текст в текущем файле

- `<C-f>` или `/` — стандартный vim search.
- `n` / `N` — next / prev match.
- `<Esc>` — очистить highlight.

### 4.2 Найти текст в проекте

1. `<leader>ss` или `<leader>fg` — telescope live_grep.
2. Печатать — результаты обновляются.
3. `<C-j>` / `<C-k>` — навигация.
4. `<CR>` — открыть найденное место.
5. `<C-q>` (в picker'е) — отправить всё в quickfix list.

### 4.3 Поиск слова под курсором по проекту

`<leader>sw` — telescope grep_string с уже подставленным `<cword>`.

### 4.4 Заменить в одном файле

`<C-h>` → откроется командная строка `:%s/`. Ввести `pattern/replacement/g<CR>`.

### 4.5 Найти и заменить в проекте (grug-far)

1. `<C-S-f>` или `<leader>sF` или `<leader>sR` — открыть GrugFar.
2. Search field — ввести pattern.
3. Replace field — ввести замену (опционально).
4. Files / paths filter — указать.
5. `<CR>` на match → preview + переход в файл.
6. После проверки нажать `:GrugFarReplace<CR>` (или используя UI команду в самом GrugFar).

Closer:
- `<leader>pc` — закрыть search panel.

### 4.6 Поиск только в visual-выделении

В visual режиме `<leader>sV` — `:'<,'>GrugFarWithin`.

### 4.7 Найти TODO / FIXME / NOTE

`<leader>st` — TodoTelescope.

---

## 5. Code navigation (LSP)

### 5.1 Go to definition

- `gd` или `<F12>` или `<A-j>` или `<leader>ld`.
- Telescope picker (с preview): `<leader>lR` для refs.

### 5.2 Go to declaration

`gD` или `<leader>lD`.

### 5.3 Find references

- `gr` или `<S-F12>` или `<leader>lr` — встроенный quickfix.
- `<leader>lR` — telescope picker с preview (лучше для большого списка).

### 5.4 Go to implementation

`gi` или `<C-F12>` или `<leader>li` (или `<leader>lI` в picker'е).

### 5.5 Type definition

`gy` или `<leader>lt` (или `<leader>lT` в picker'е).

### 5.6 Hover (документация / тип)

`K` или `<leader>lh`.

### 5.7 Signature help (в момент написания вызова)

`<leader>lk` — отдельно. Или начни печатать `func(` — должно появиться
автоматически от nvim-cmp.

### 5.8 Document / workspace symbols

- `<leader>sS` — telescope LSP document symbols.
- `<leader>sW` — telescope LSP workspace symbols.

### 5.9 Outline (как side panel)

- `<leader>lo` или `<leader>so` — Aerial toggle (left edgebar).
- `{` / `}` — prev/next symbol в файле (когда aerial активен).

---

## 6. Code actions / refactoring

### 6.1 Code action menu (light bulb)

`<leader>la` — открывает меню code actions (rename file, organize
imports, extract, inline, и т.п. — что предложит LSP).

### 6.2 Rename symbol

- `<F2>` или `<leader>ln`.
- Появится prompt с дефолтом — `<cword>`. Ввести новое имя.
- LSP применит во всех файлах проекта.

### 6.3 Format buffer

- `<leader>lf` или `<S-A-f>` — conform.nvim → выбранный formatter.
- Для большинства языков auto-format on save тоже работает (см.
  `plugins/format.lua` для setup).

### 6.4 Toggle inlay hints

`<leader>th` — toggle per-buffer (не глобально).

---

## 7. Git workflow

### 7.1 Посмотреть статус репозитория

- `<leader>gg` — Neogit в новой табе (как `git status` + stage UI).
- `<leader>gG` — Neogit в split (правый edgebar).
- `<leader>gS` — Neo-Tree git_status (только модифицированные файлы).

### 7.2 Stage / unstage / reset hunk в текущем буфере

(gitsigns, работает прямо в коде)

| Шаг | Действие |
|---|---|
| Подсветка изменений | `<leader>ghp` — preview hunk |
| Stage hunk | `<leader>ghs` |
| Reset hunk (отменить) | `<leader>ghr` |
| Undo stage | `<leader>ghu` |
| Blame line (полный) | `<leader>ghb` |
| Inline blame toggle | `<leader>ghB` |
| Next/prev hunk | `]h` / `[h` |

### 7.3 Diff текущего файла

- `<leader>ghd` — diff buffer vs index.
- `<leader>ghD` — diff buffer vs HEAD~.
- `<leader>gd` — DiffviewOpen (полный side-by-side diff проекта).

### 7.4 Полный workflow: посмотреть → stage → commit

1. `<leader>gd` — открыть Diffview (все изменения).
2. `<C-e>` — toggle список изменённых файлов слева.
3. `<A-j>` / `<A-k>` — переключаться между файлами.
4. В нужном файле: `<leader>ghs` на каждом hunk (или `s` в самом Diffview).
5. `q` или `<leader>gq` — закрыть Diffview.
6. `<leader>gg` — открыть Neogit.
7. В Neogit-окне `c c` — commit (откроет редактор для message).
8. Написать message → `:wq`.
9. В Neogit `P p` — push (если remote настроен).

### 7.5 Просмотреть историю файла

`<leader>gD` — DiffviewFileHistory % (текущий файл).

В Diffview:
- `<A-j>` / `<A-k>` — листать коммиты.
- `<CR>` на файле → diff.
- `q` или `<leader>gq` — закрыть.

### 7.6 Посмотреть diff с другой веткой

`:DiffviewOpen main..feature-branch` (или `HEAD~5`, или любой git revspec).

### 7.7 Создать new branch / checkout

В Neogit (`<leader>gg`):
- `b b` — create branch.
- `b c` — checkout.

(см. подсказки в попап-меню Neogit под `?`.)

---

## 8. Debug

### 8.1 Первый запуск (Rust / Go / Python)

1. Открыть файл, который хочешь дебажить.
2. Поставить breakpoint в нужной строке: **`<F9>`** или `<leader>db`.
3. `<F5>` — continue / start.
4. Если в `.vscode/launch.json` есть >1 config — telescope picker.
5. Иначе автоконфиг "Current file" из `plugins/dap.lua`.

После старта:
- Слева — sidebar c **Variables / Watch / Call Stack / Breakpoints**
  (4 окна dap-ui, edgy edgebar).
- Снизу — **DAP Terminal** для Rust/codelldb (PTY-буфер с прямым
  выводом программы; свежий на каждую сессию) ИЛИ **DAP REPL** для
  Go (delve) / Python (debugpy) — там output идёт через DAP
  `output`-events.

Если launch.json явно прописывает `"console": "integratedTerminal"`
для любого языка — bottom тоже будет DAP Terminal.

> **Почему так:** см. `DEBUG_JOURNEY.md` §1 — на Windows
> внутри `nvim-dap-ui`'s console-element ConPTY-канал терял первый
> `println!`, плюс pool nvim-dap recycled буферы. Свой свежий PTY
> на каждую сессию решает обе проблемы.

### 8.2 Шаги по коду

| Key | Action |
|---|---|
| `<F5>` | Continue |
| `<F10>` | Step over |
| `<F11>` | Step into |
| `<S-F11>` | Step out |
| `<S-F5>` | Terminate |
| `<C-S-F5>` | Restart |
| `<leader>dp` | Pause |

Дублируются на `<leader>dc/do/di/dO/dq/dr/dp`.

### 8.3 Conditional breakpoint

`<leader>dB` — prompt с условием. Например, `i == 50` — стопнется только
на 50-й итерации.

### 8.4 Evaluate выражения (hover)

- В коде, наведя курсор на переменную: `<leader>de` — `dap.ui.widgets.hover()`.
- Или в DAP REPL (снизу): `p variable_name` (codelldb / gdb-style).

### 8.5 Добавить watch expression

- `<leader>dw` (normal) — prompt c дефолтом `<cword>`.
- `<leader>dw` (visual) — взять выделение.
- Появится в WATCH секции слева.

### 8.5.1 Переключаться между DAP-окнами на паузе (без слома сессии)

Останов на брейкпоинте — это **состояние адаптера** на стороне отладчика.
Любые фокус-операции (`<C-w>*`, `nvim_set_current_win`, прыжки по
keymap'ам) только перемещают курсор по окнам Neovim и **никак не влияют
на дебаг-сессию**. Adapter отпускает программу только когда ты сам
вызываешь Continue (`F5`), Step (`F10`/`F11`), Terminate (`<S-F5>`),
Restart (`<C-S-F5>`).

Прямые прыжки:

| Key            | Куда                                                |
|----------------|-----------------------------------------------------|
| `<leader>Dv`   | **V**ariables (scopes) — левый sidebar              |
| `<leader>Dw`   | **W**atch                                           |
| `<leader>Ds`   | call **S**tack                                      |
| `<leader>Db`   | **B**reakpoints                                     |
| `<leader>Dc`   | REPL / **C**onsole / DAP Terminal — нижняя панель   |
| `<leader>D0`   | Обратно в редактор (главное окно с кодом)           |

Альтернативы (универсальные, не только для DAP):

- `<leader>P/` — фокус на первое окно левого слота (обычно `scopes`).
- `<leader>P,` — фокус на нижний слот (REPL/console/terminal).
- `<leader>P0` — фокус в редактор.
- `<F6>` / `<S-F6>` — циклить по всем окнам (включая DAP).
- `<F7>` или `<A-e>` — снова в редактор.
- `<C-w>j` / `<C-w>k` внутри левого sidebar — между Variables / Watch /
  Stack / Breakpoints (они стэкаются вертикально в edgebar).

Скрыть/показать панели (без потери состояния DAP):

- `<C-b>` (или `<leader>Pt`) — toggle левого sidebar. На второе нажатие
  все 4 секции вернутся обратно.
- `<C-j>` / `<F8>` (или `<leader>Py`) — toggle нижней панели.

Что делает разные секции:

- **scopes** — `<CR>` или `o` развернуть/свернуть переменную.
- **watches** — `i` добавить выражение, `dd` удалить, `<CR>` развернуть.
- **stacks** — `<CR>` переключиться на frame (курсор в коде на нужной
  строке, scopes/watches обновляются под этот frame).
- **breakpoints** — `<CR>` перейти к точке в коде, `dd` удалить.

### 8.6 Выбрать конкретный launch.json config вручную

`<leader>dP` — telescope picker по всем configs из `.vscode/launch.json`.

### 8.7 Run last config (без выбора)

`<leader>dl` — `dap.run_last()`.

### 8.8 Дебаг теста

- Go: `<leader>dt` — debug nearest Go test.
- Go: `<leader>dT` — debug last Go test.
- Python: `<leader>dt` — debug test method.
- Python: `<leader>dT` — debug test class.
- Универсально через neotest: `<leader>Td`.

### 8.9 REPL для интерактивной отладки

`<leader>dR` — открыть DAP REPL снизу. Доступен после старта сессии.

Команды в REPL (зависят от адаптера):
- codelldb: `p var`, `bt`, `frame select N`.
- delve: `p var`, `bt`, `frame N`.
- debugpy: `print(var)`, обычный Python REPL.

REPL и DAP Terminal — это **разные** bottom-компоненты, оба
mutually-exclusive в bottom slot:

- DAP Terminal (`dap.terminal`) — живой PTY-buffer программы, видим
  её `println!`/`print()`. Создаётся `terminal_win_cmd` при
  `runInTerminal` от адаптера (Rust + любой `integratedTerminal`).
- DAP REPL (`dap.repl`) — интерактивная DAP-консоль, можно вводить
  команды адаптера. Доступна всем адаптерам, output `internalConsole`-
  программ идёт туда.

Переключение между ними — `<leader>Pb` (cycle bottom).

### 8.10 Diagnose: что-то не работает

- `<leader>dL` или `:DapShowLog` — DAP log.
- `:DapPythonInfo` — выбранные Python/debugpy пути (только Python).
- `:DapGoDlvInfo` — Delve кандидаты (только Go).
- `:IdeStatus` — состояние ide slots.

### 8.11 Закрыть debug UI (но не завершать сессию)

`<leader>dD` или `<leader>du` или `<C-S-d>` — toggle debug view (закроет
sidebar + bottom).

### 8.12 Завершить сессию полностью

`<S-F5>` или `<leader>dq`.

### 8.13 Применить debug layout без запуска

`<leader>pd` — открыть debug panels (пустые, если сессии нет — пригодится
для просмотра старых breakpoint'ов).

---

## 9. Tests

### 9.1 Запустить ближайший тест

`<leader>Tt` — neotest run nearest.

Результат отображается в:
- Sign column (✓ pass, ✗ fail).
- Test Summary panel (right edgebar).

### 9.2 Запустить все тесты в файле

`<leader>Tf`.

### 9.3 Запустить ВСЕ тесты в проекте

`<leader>TA`.

### 9.4 Посмотреть вывод теста

- `<leader>To` — open output (in-place split, enter=true).
- `<leader>TO` — toggle Test Output panel (bottom edgebar).

### 9.5 Открыть Tests Summary panel

`<leader>Tp` или сразу `<leader>pt` (layout tests).

### 9.6 Watch mode (auto re-run при изменении)

`<leader>Tw` — toggle watch для текущего файла.

### 9.7 Debug тест

`<leader>Td` — запустить ближайший тест под дебаггером (strategy=dap).
Дальше — обычный DAP workflow (F10/F11 и т.д.).

### 9.8 Остановить запущенные тесты

`<leader>Ts`.

### 9.9 Layout «работаю с тестами»

`<leader>pt` — applies layout `tests`:
- left = explorer
- right = Test Summary
- bottom = Test Output

---

## 10. Tasks / Build / Run

(Overseer.nvim — VS Code-style task runner.)

### 10.1 Запустить task из template'а

1. `<leader>jr` или `:OverseerRun` — picker задач.
2. Выбрать (cargo build / npm test / pytest / ...).
3. Result в bottom panel.

### 10.2 Toggle bottom panel со списком задач

- `<leader>jt` — OverseerToggle bottom.
- Или layout: `<leader>pj`.

### 10.3 Действия над задачей (rerun, stop, dispose)

`<leader>ja` — OverseerTaskAction (выбор задачи → выбор действия).

### 10.4 Запустить произвольную shell-команду

`<leader>js` — OverseerShell. Prompt → ввести команду.

### 10.5 Workflow: build → test → debug

1. `<leader>jr` → выбрать `cargo build` → `<CR>`.
2. Дождаться (build progress в `<leader>jt`).
3. `<F5>` — debug собранного бинарника.
4. После — `<F9>` поставить breakpoint, дальше обычный debug.

---

## 11. Diagnostics / Trouble

### 11.1 Перейти на следующее предупреждение

`<F3>` — next diagnostic с float.
`<S-F3>` — prev.

### 11.2 Все diagnostics буфера

`<leader>sd` (telescope) или `<leader>xX` (trouble в bottom).

### 11.3 Все diagnostics проекта

`<leader>sD` (telescope) или `<leader>xx` (trouble — recommended).

### 11.4 Toggle diagnostics глобально

`<leader>td` — DiagToggle.

### 11.5 LSP refs/defs/impls во всём workspace через Trouble

`<leader>xr` — Trouble lsp с preview справа.

---

## 12. Outline / Symbols

### 12.1 Открыть outline текущего файла

`<leader>lo` (или `<leader>so`) — Aerial slidebar слева.

### 12.2 Navigate по символам

- `}` / `{` — next / prev symbol (когда в коде с aerial).
- В самом aerial: `j` / `k` / `<CR>` (jump).

### 12.3 Picker по символам

- `<leader>sS` — telescope document symbols.
- `<leader>sW` — telescope workspace symbols (fuzzy по всему проекту).

### 12.4 Popup nav (как VS Code Ctrl+Shift+O)

`<leader>sn` — AerialNavToggle (float popup со стеком символов).

### 12.5 Highlight ссылок на текущий символ

Авто-включён через illuminate. Переход между ссылками:
- `<A-n>` / `<A-p>` — next / prev reference.

---

## 13. Terminal

### 13.1 Открыть терминал снизу

`<leader>tt` или `<C-\>` или `<C-t>`.

Persistent: те же хоткеи — toggle (закрывает но не уничтожает),
след. раз восстановит сессию.

### 13.2 Открыть terminal в float

`<leader>tT` — большой floating терминал.

### 13.3 Terminal в vertical split (справа)

`<leader>tV`.

### 13.4 Выйти из терминал-режима в normal

`<Esc><Esc>`.

### 13.5 Запустить команду из выделенного кода

В visual → `<C-CR>`. Pипется в pwsh.

### 13.6 Закрыть terminal

`<leader>tt` снова (toggle) или `:q` внутри.

---

## 14. Layouts / Panels

### 14.1 Переключиться на готовый layout

`<leader>p*`:
- `<leader>pc` — code only (всё закрыто).
- `<leader>pf` — files (explorer слева).
- `<leader>pd` — debug.
- `<leader>pt` — tests.
- `<leader>pg` — git.
- `<leader>ps` — search.
- `<leader>pj` — jobs.
- `<leader>px` — trouble.
- `<leader>pT` — terminal.
- `<leader>po` — outline.

### 14.2 Picker всех layouts

`<leader>pp` — `vim.ui.select`.

### 14.3 Cycle компонент в одном слоте

Не меняя layout, циклим внутри слота:
- `<leader>Pl` / `<leader>Ph` — left next / prev.
- `<leader>Pr` / `<leader>PR` — right.
- `<leader>Pb` / `<leader>PB` — bottom.

Например: открыт layout debug → `<leader>Pb` циклит bottom между
`dap.terminal` → `dap.repl` → `dap.console` → `tasks_output` →
`tests_output` → `search` → `trouble` → `qf` → `terminal` → (по кругу).

### 14.4 Скрыть один слот

- `<leader>PL` — left.
- `<leader>PK` — right.
- `<leader>PJ` — bottom.

### 14.5 Фокус на слот

- `<leader>P0` — main editor.
- `<leader>P/` — left.
- `<leader>P.` — right.
- `<leader>P,` — bottom.

### 14.6 Посмотреть текущее состояние

`:IdeStatus` — печатает текущий layout + slots.

### 14.7 Открыть конкретный компонент явно (минуя layout)

`:IdeShow <component>` — например `:IdeShow tasks_output`, `:IdeShow neogit`.

---

## 15. Sessions

(persistence.nvim — сохраняет состояние workspace.)

### 15.1 Восстановить session для текущего cwd

`<leader>qs`.

### 15.2 Выбрать одну из сохранённых

`<leader>qS` — picker.

### 15.3 Восстановить последний сessionon

`<leader>ql`.

### 15.4 Сказать «не сохранять эту сессию»

`<leader>qd` — отключает auto-save для текущего nvim-инстанса.

---

## 16. Закрытие / выход

### 16.1 Закрыть текущий буфер

`<C-q>` или `<leader>bd` или `<F4>` или `<A-w>`.

Если последний code-buffer — появится alpha welcome.

### 16.2 Закрыть только окно (не буфер)

`<leader>wq` или `<C-w>q`.

### 16.3 Закрыть всё и выйти

- `<leader>qq` — `:qa` (без save).
- `<leader>qw` — `:wqa` (с save).

### 16.4 Закрыть IDE-панели (оставить только код)

`<leader>pc` — applies layout `code` (atomic: закроет всё).

Или одно за другим: `<leader>PL` (left), `<leader>PK` (right), `<leader>PJ` (bottom).

---

## Композитные workflow'ы

### A. Полный «открыл проект → нашёл баг → поправил → закомитил»

1. `nvim_forge.cmd D:\project` — открыли.
2. `<C-p>` — find file → выбрать.
3. `gd` на функции → перешли в реализацию.
4. `<F3>` — глянули diagnostic.
5. `<leader>la` — code action (quick fix).
6. `<C-s>` — save.
7. `<leader>gg` — Neogit.
8. `s` на файле → stage; `c c` → commit message → `:wq`.
9. `P p` → push.

### B. «Запустил, поймал баг, дебажу»

1. `<leader>jr` → `cargo run` (или `<F5>` сразу если есть launch.json).
2. Увидели ошибку в bottom output → `<F4>` закрыть.
3. `<F9>` — breakpoint в подозрительной строке.
4. `<F5>` — debug.
5. На остановке: `<leader>dw` — добавить watch с проблемной переменной.
6. `<F10>` × N — step over.
7. Поняли проблему → `<S-F5>` — terminate.
8. Поправили → `<C-s>` → опять `<F5>`.

### C. «Нашёл фрагмент кода в проекте → отрефакторил везде»

1. `<leader>sw` — grep word under cursor → видим все вхождения.
2. `<C-q>` в picker'е → отправить в quickfix.
3. `<leader>xQ` — открыть Trouble quickfix.
4. По одному файлу: `<CR>` → перейти → `<F2>` rename → ...
5. Альтернатива: `<C-S-f>` GrugFar → search/replace по всем сразу.

### D. «Большой PR: смотрю diff коллеги»

1. `git fetch origin pr/123` (в терминале или `<leader>tt`).
2. `:DiffviewOpen main..pr/123` — side-by-side.
3. `<C-e>` toggle files list.
4. `<A-j>` / `<A-k>` — листать файлы.
5. По каждому файлу: `j/k` по hunks, читать.
6. Закомментировать в Neogit можно через `<leader>gg` потом.

### E. «Прохожу TDD цикл»

1. `<leader>pt` — layout tests.
2. `<leader>Tw` — watch текущего теста файла.
3. Пишу код в main editor.
4. На каждом save (или ручном `<leader>Tt`) — тесты пере-гоняются.
5. `<leader>To` — посмотреть вывод upon fail.
6. Если нужен debug: `<leader>Td` — debug nearest test.

---

## Tips

- **Which-key popup**: после `<leader>` ждать 300ms — покажется
  визуальный список доступных групп и команд. Помогает запомнить.
- **Telescope keymaps**: `<leader>sk` — picker по всем хоткеям с
  preview, что они делают.
- **Picker внутри picker'а**: в любом Telescope picker'е `<C-q>` —
  отправить результаты в quickfix list (потом открыть через `<leader>xQ`).
- **Layouts vs. slots**: layouts (`<leader>p*`) — преднастроенные
  сочетания; slots (`<leader>P*`) — точечное управление одним слотом.
  Layout сбрасывает другие слоты, slot — нет.
- **Где смотреть, какой компонент сейчас открыт**: `:IdeStatus`.
- **Что-то поломалось — `:IdeLayout code`** — приведёт всё в чистое
  состояние, и оттуда можно строить заново.
- **Расследования по нетривиальным багам** (Rust+codelldb на Windows,
  pool nvim-dap, adapter timeout'ы и т.п.) лежат в `DEBUG_JOURNEY.md` —
  читать, если debug-стек выглядит странно или для понимания, почему
  bottom для Rust ведёт себя не как для Python.
