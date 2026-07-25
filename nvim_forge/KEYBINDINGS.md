# Keybindings reference (nvim_forge)

Полный справочник по всем хоткеям конфигурации. `<leader>` = `Space`.
`<localleader>` = `\`. Режим в графе **Mode**: `n` normal, `i` insert,
`v` visual, `x` visual+select, `t` terminal, `c` cmdline. Если не
указан — `n`.

Содержание:

1. [IDE layouts (`<leader>p*`)](#1-ide-layouts)
2. [IDE slots (`<leader>P*`)](#2-ide-slots-ручное-управление-панелями)
3. [Files / Explorer](#3-files--explorer)
4. [Buffers (вкладки)](#4-buffers-вкладки)
5. [Windows / focus](#5-windows--focus)
6. [Search (поиск)](#6-search-поиск)
7. [Git](#7-git)
8. [Debug (DAP)](#8-debug-dap)
9. [Tests (`<leader>T*`)](#9-tests-leadert)
10. [Tasks / Jobs (`<leader>j*`)](#10-tasks--jobs-leaderj)
11. [LSP / Code (`<leader>l*`, `g*`)](#11-lsp--code)
12. [Outline / Symbols (`<leader>s*`, `<leader>l*`)](#12-outline--symbols)
13. [Terminal (`<leader>t*`)](#13-terminal-leadert)
14. [Trouble / Diagnostics (`<leader>x*`)](#14-trouble--diagnostics)
15. [Toggles (`<leader>t*`)](#15-toggles)
16. [Project / Session (`<leader>o*`, `<leader>q*`)](#16-project--session)
17. [Legacy panels (`<leader>m*`)](#17-legacy-panels-mode-based-старая-система)
18. [Universal close/focus (F-keys, Alt)](#18-universal-closefocus-f-keys-alt)
19. [Editing / IDE shortcuts (VS Code-style)](#19-editing--ide-shortcuts-vs-code-style)
20. [Cmp / Completion popup](#20-completion-popup)
21. [Commands (`:Cmd`)](#21-commands)

---

## 1. IDE layouts

`<leader>p*` применяет именованный layout-пресет (atomic transition,
закрывает старые view'ы и открывает новые в нужных слотах).

| Keymap        | Layout    | Slots applied                                          |
| ------------- | --------- | ------------------------------------------------------ |
| `<leader>pp`  | picker    | `vim.ui.select` со всеми layouts                       |
| `<leader>pc`  | `code`    | всё закрыто                                            |
| `<leader>pf`  | `files`   | left = explorer                                        |
| `<leader>po`  | `outline` | left = outline (aerial)                                |
| `<leader>pg`  | `git`     | left = git_status, right = neogit                      |
| `<leader>pd`  | `debug`   | left = dap.sidebar, bottom = dap.console               |
| `<leader>pt`  | `tests`   | left = explorer, right = tests, bottom = tests_output  |
| `<leader>ps`  | `search`  | bottom = search (grug-far)                             |
| `<leader>pj`  | `jobs`    | bottom = tasks_output (overseer)                       |
| `<leader>px`  | `trouble` | bottom = trouble                                       |
| `<leader>pT`  | `term`    | bottom = terminal (toggleterm)                         |
| `<leader>pq`  | `code`    | алиас `pc`                                             |

---

## 2. IDE slots (ручное управление панелями)

`<leader>P*` (uppercase) — операции над отдельными слотами:
переключение компонентов, скрытие, фокус, toggle всего слота.

### 2.1 Quick toggle (открыть/закрыть весь слот одной командой)

Главные хоткеи, если нужно «спрятать левую/нижнюю панель сейчас, потом
показать обратно». Поведение как **VS Code Ctrl+B / Ctrl+J**: одна и
та же клавиша туда-обратно. Если слот был пуст — открывается последний
показанный компонент (или fallback, см. ниже).

| Keymap                       | Action                  | Modes      | Fallback (если ничего не было) |
| ---------------------------- | ----------------------- | ---------- | ------------------------------ |
| **`<C-b>`** / `<leader>Pt`   | Toggle **left** panel   | n / i / t  | `explorer` (Neo-Tree)          |
| **`<C-j>`** / `<F8>` / `<leader>Py` | Toggle **bottom** panel | n / t (`<F8>` ещё и i) | `terminal` (toggleterm) |
| `<leader>Pu`                 | Toggle **right** panel  | n          | `tests` (neotest summary)      |

> **Важно про терминальные коды.**
> Изначально были `<C-S-b>` / `<C-S-j>` (как в VS Code), но в Windows
> Terminal / cmd / ConPTY / RDP shift+ctrl+letter **неотличим** от
> ctrl+letter — терминал шлёт те же байты. Поэтому теперь биндинг
> прямо на `<C-b>` / `<C-j>`. Старый `<C-b>` (buffers picker из
> telescope) убран; buffers остаются на `<leader>bb` / `<leader>fb`.
>
> Если у тебя `<C-j>` всё равно не доходит до nvim (бывает в RDP-сессиях,
> старых терминалах, WSL2 с конкретной TTY-конфигурацией) — используй
> `<F8>` или `<leader>Py`, они работают везде.

> **Чем отличается от `<leader>e`?** `<leader>e` тоггит **конкретный**
> компонент (Neo-Tree filesystem). Если в левом слоте сейчас, например,
> outline (aerial), `<leader>e` закроет outline и откроет файлы.
> `<C-b>` (= `<leader>Pt`) просто тогглит **весь слот** — что было
> открыто, то и закроется; следующее нажатие вернёт его же обратно.

### 2.2 Cycle / hide / focus

| Keymap        | Action                                          |
| ------------- | ----------------------------------------------- |
| `<leader>Pl`  | left slot: next group (explorer→buffers→git→outline→dap.sidebar→…) |
| `<leader>Ph`  | left slot: prev group                           |
| `<leader>Pr`  | right slot: next (tests↔neogit)                 |
| `<leader>PR`  | right slot: prev                                |
| `<leader>Pb`  | bottom slot: next (terminal→repl→console→tests_output→…) |
| `<leader>PB`  | bottom slot: prev                               |
| `<leader>PL`  | hide left slot                                  |
| `<leader>PK`  | hide right slot                                 |
| `<leader>PJ`  | hide bottom slot                                |
| `<leader>P0`  | focus main editor                               |
| `<leader>P/`  | focus left slot                                 |
| `<leader>P.`  | focus right slot                                |
| `<leader>P,`  | focus bottom slot                               |

---

## 3. Files / Explorer

| Keymap         | Action                                | Mode |
| -------------- | ------------------------------------- | ---- |
| `<leader>e`    | Explorer: toggle (Neo-Tree filesystem)| n    |
| `<leader>E`    | Explorer: reveal current file         | n    |
| `<leader>bB`   | Explorer: buffers panel               | n    |
| `<leader>gS`   | Git: side panel (Neo-Tree git_status) | n    |
| `<C-e>`        | Explorer: focus / unfocus             | n    |
| `<C-S-e>` / `<C-A-e>` / `<A-E>` / `<S-A-e>` | то же, разные терминальные кодировки | n |
| `<C-p>`        | Find file (telescope)                 | n    |
| `<C-S-p>`      | Command palette (`:Telescope commands`)| n   |
| `<leader>ff`   | Files: find                           | n    |
| `<leader>fr`   | Files: recent (oldfiles)              | n    |
| `<leader>fg`   | Files: live grep                      | n    |
| `<leader>fb`   | Files: buffers picker                 | n    |
| `<leader>fc`   | Files: changed (git_status picker)    | n    |
| `<leader>fj`   | Files: jumplist                       | n    |
| `<leader>fh`   | Files: help tags                      | n    |
| `<leader>fp`   | Files: recent projects                | n    |

---

## 4. Buffers (вкладки)

| Keymap         | Action                                | Mode |
| -------------- | ------------------------------------- | ---- |
| `<leader>bd`   | Close buffer (alpha если последний)   | n    |
| `<leader>bb`   | Buffers picker (telescope, MRU)       | n    |
| `<leader>bn`   | Next buffer                           | n    |
| `<leader>bp`   | Previous buffer                       | n    |
| `<leader>bB`   | Buffers panel (Neo-Tree)              | n    |
| `<S-l>` / `<Tab>` / `]b` / `<C-PageDown>` / `<A-l>` | Next buffer | n |
| `<S-h>` / `<S-Tab>` / `[b` / `<C-PageUp>` / `<A-h>` | Prev buffer | n |
| `<C-q>` / `<A-w>` / `<A-q>` / `<F4>` / `<C-F4>` | Smart close (file/tool window/diffview) | n/i/v/t |

> `<C-b>` ранее открывал buffers picker; теперь это **toggle left panel**
> (см. § 2.1). Buffers picker: `<leader>bb` или `<leader>fb`.

---

## 5. Windows / focus

| Keymap         | Action                                | Mode |
| -------------- | ------------------------------------- | ---- |
| `<leader>wv`   | Vertical split                        | n    |
| `<leader>ws`   | Horizontal split                      | n    |
| `<leader>wh/j/k/l` | Move to left/down/up/right window | n    |
| `<leader>wq`   | Close window                          | n    |
| `<leader>wo`   | Keep only current window              | n    |
| `<F6>` / `<S-F6>` | Cycle next/prev window focus       | n/i/v/t |
| `<F7>` / `<A-e>` | Focus editable editor window        | n/i/v/t |
| `<C-w>h/j/k/l` | Native vim split move (не remap'нут)  | n    |

---

## 6. Search (поиск)

| Keymap         | Action                                | Mode |
| -------------- | ------------------------------------- | ---- |
| `<C-f>`        | Find в текущем буфере (как `/`)       | n/i  |
| `<C-h>`        | Replace в буфере (`:%s/`)             | n    |
| `<C-S-f>`      | Search: project-wide panel (grug-far) | n    |
| `<leader>sF` / `<leader>sR` | Search: panel (grug-far)        | n    |
| `<leader>sV`   | Search within visual selection        | v    |
| `<leader>ss`   | Telescope live_grep                   | n    |
| `<leader>sw`   | Telescope grep word under cursor      | n    |
| `<leader>sb`   | Telescope current buffer fuzzy find   | n    |
| `<leader>sd`   | Telescope buffer diagnostics          | n    |
| `<leader>sD`   | Telescope workspace diagnostics       | n    |
| `<leader>sS`   | Telescope document symbols            | n    |
| `<leader>sW`   | Telescope workspace symbols           | n    |
| `<leader>sk`   | Telescope keymaps                     | n    |
| `<leader>sr`   | Telescope resume last picker          | n    |
| `<leader>st`   | TODOs (todo-comments)                 | n    |

---

## 7. Git

### Gitsigns (in current buffer)

| Keymap         | Action                                |
| -------------- | ------------------------------------- |
| `]h`           | Next git hunk                         |
| `[h`           | Prev git hunk                         |
| `<leader>ghs`  | Git: stage hunk                       |
| `<leader>ghr`  | Git: reset hunk                       |
| `<leader>ghp`  | Git: preview hunk                     |
| `<leader>ghb`  | Git: blame line (full)                |
| `<leader>ghB`  | Git: toggle inline line blame         |
| `<leader>ghd`  | Git: diff this buffer                 |
| `<leader>ghD`  | Git: diff buffer vs HEAD~             |
| `<leader>ghu`  | Git: undo stage hunk                  |

### Neogit / Diffview

| Keymap         | Action                                |
| -------------- | ------------------------------------- |
| `<leader>gg`   | Neogit status (tab)                   |
| `<leader>gG`   | Neogit status (split, right edgebar)  |
| `<leader>gS`   | Neo-Tree git_status panel             |
| `<leader>gd`   | Diffview: changed files diff          |
| `<leader>gD`   | Diffview: file history (`%`)          |
| `<leader>gq`   | Diffview: close                       |
| `<leader>gF`   | Diffview: focus files panel           |

### Внутри Diffview

| Keymap         | Action                                |
| -------------- | ------------------------------------- |
| `q`            | Close diff view                       |
| `<C-e>`        | Toggle changed files list             |
| `<A-j>` / `<C-PageDown>` | Next changed file           |
| `<A-k>` / `<C-PageUp>`   | Previous changed file       |
| `<A-h>`        | Focus old (left) side                 |
| `<A-l>` / `<A-e>` | Focus new (right) side             |
| `<leader>b`    | Toggle changed files tree             |
| `<leader>e`    | Close diffview and open Explorer      |

---

## 8. Debug (DAP)

### F-keys (как VS Code Run-меню)

| Keymap         | Action                                | Mode |
| -------------- | ------------------------------------- | ---- |
| `<F5>`         | Continue / start                      | n/t  |
| `<S-F5>`       | Terminate                             | n/t  |
| `<C-S-F5>`     | Restart                               | n/t  |
| `<F9>`         | Toggle breakpoint                     | n    |
| `<F10>`        | Step over                             | n/t  |
| `<F11>`        | Step into                             | n/t  |
| `<S-F11>`      | Step out                              | n/t  |

### `<leader>d*` (helix space.d)

| Keymap         | Action                                |
| -------------- | ------------------------------------- |
| `<leader>ds`   | Start / continue                      |
| `<leader>dc`   | Continue                              |
| `<leader>db`   | Toggle breakpoint                     |
| `<leader>dB`   | Conditional breakpoint (prompt)       |
| `<leader>do`   | Step over                             |
| `<leader>di`   | Step into                             |
| `<leader>dO`   | Step out                              |
| `<leader>dr`   | Restart                               |
| `<leader>dq`   | Terminate                             |
| `<leader>dp`   | Pause                                 |
| `<leader>dl`   | Run last config                       |
| `<leader>dP`   | Pick any launch.json config           |
| `<leader>dL`   | Show DAP logs                         |
| `<leader>dD` / `<leader>du` / `<C-S-d>` | Toggle debug view (sidebar + bottom) |
| `<leader>de`   | Eval hover (`dap.ui.widgets.hover`)   |
| `<leader>dw`   | Watch expression (prompt с `<cword>`) |
| `<leader>dw`   | Watch selection (visual)              |
| `<leader>dR`   | Open DAP REPL (sidebar + repl bottom) |

### Per-language

| Keymap         | Action                          | Filetype |
| -------------- | ------------------------------- | -------- |
| `<leader>dt`   | Debug Go test under cursor      | go       |
| `<leader>dT`   | Debug last Go test              | go       |
| `<leader>dt`   | Debug Python test method        | python   |
| `<leader>dT`   | Debug Python test class         | python   |

### Debug focus jumps (`<leader>D*`) — переключаться между окнами во время паузы

Любая смена фокуса (`<C-w>*` или эти прыжки) **не ломает** останов на
брейкпоинте. Сессия живёт, пока ты сам не нажмёшь Continue (`F5`),
Step (`F10`/`F11`), Terminate (`<S-F5>`) или Restart (`<C-S-F5>`).
Поэтому смело инспектируй переменные, лазь по стеку, набирай выражения
в REPL — состояние сохраняется.

| Keymap         | Куда прыгает                                            |
| -------------- | ------------------------------------------------------- |
| `<leader>Dv`   | **V**ariables (scopes) — левый sidebar                  |
| `<leader>Dw`   | **W**atch — левый sidebar                               |
| `<leader>Ds`   | call **S**tack — левый sidebar                          |
| `<leader>Db`   | **B**reakpoints — левый sidebar                         |
| `<leader>Dc`   | **C**onsole / REPL / Terminal — нижняя панель (что есть) |
| `<leader>D0`   | Обратно в редактор (главное окно с кодом)               |

Если соответствующая секция закрыта, прыжок сначала её откроет
(`ide.show("dap.sidebar")`), потом сфокусирует.

### Внутри DAP-окон (общее vim-поведение)

| Keymap         | Где                       | Action                       |
| -------------- | ------------------------- | ---------------------------- |
| `<C-w>j` / `<C-w>k` | Левый DAP-sidebar    | Между Variables/Watch/Stack/Breakpoints (они стэкаются вертикально) |
| `<CR>` или `o` | `dapui_scopes`, `dapui_watches` | Развернуть/свернуть переменную |
| `i`            | `dapui_watches`           | Добавить новое watch-выражение (prompt) |
| `<CR>`         | `dapui_stacks`            | Перейти в frame стека (курсор в коде) |
| `<CR>`         | `dapui_breakpoints`       | Перейти к breakpoint в коде  |
| `dd`           | `dapui_breakpoints`       | Удалить breakpoint           |
| `q` / `<F4>` / `<C-q>` | любое DAP-окно   | Закрыть это окно (slot скроется) |
| `i` / `a` / `A` | `dap-repl`               | Включить insert (ввод выражения), `<CR>` отправить |
| `<Esc><Esc>`   | `dap-terminal`            | Выйти из terminal-режима в normal (но процесс продолжает писать) |

> **Подсказки UX:**
> - В Watch (`<leader>Dw`) нажми `i` для добавления выражения. Альтернатива
>   из любого места: `<leader>dw` (prompt с `<cword>`).
> - Если хочешь временно убрать левый sidebar, чтобы код занял всю ширину —
>   `<C-b>` (toggle left). Сессия не пострадает. `<C-b>` ещё раз вернёт его
>   обратно с теми же 4 секциями.
> - Аналогично `<C-j>` / `<F8>` тогглят нижнюю панель (REPL/console/terminal).

---

## 9. Tests (`<leader>T*`)

(Используется neotest. **Заглавная** T — чтобы не конфликтовать с
`<leader>t*` toggles.)

| Keymap         | Action                                |
| -------------- | ------------------------------------- |
| `<leader>Tp`   | Tests: side panel (toggle)            |
| `<leader>Tt`   | Run nearest test                      |
| `<leader>Tf`   | Run all in current file               |
| `<leader>TA`   | Run all in cwd                        |
| `<leader>Td`   | Debug nearest test (strategy=dap)     |
| `<leader>Ts`   | Stop running tests                    |
| `<leader>Ta`   | Attach to running test                |
| `<leader>To`   | Open output (split)                   |
| `<leader>TO`   | Output panel toggle                   |
| `<leader>Tw`   | Toggle watch for current file         |

---

## 10. Tasks / Jobs (`<leader>j*`)

(Overseer.nvim — VS Code-style task runner)

| Keymap         | Action                                |
| -------------- | ------------------------------------- |
| `<leader>jj`   | Jobs: panel (old panels mode_jobs)    |
| `<leader>jr`   | OverseerRun (выбор задачи)            |
| `<leader>jt`   | OverseerToggle bottom                 |
| `<leader>ja`   | OverseerTaskAction                    |
| `<leader>js`   | OverseerShell (свободная shell-задача)|

---

## 11. LSP / Code

### `g*` (стандартные vim-биндинги)

| Keymap         | Action                                |
| -------------- | ------------------------------------- |
| `gd`           | Go to definition                      |
| `gD`           | Go to declaration                     |
| `gr`           | Find references                       |
| `gi`           | Go to implementation                  |
| `gy`           | Go to type definition                 |
| `K`            | Hover documentation                   |

### F-keys (как VS Code)

| Keymap         | Action                                |
| -------------- | ------------------------------------- |
| `<F12>`        | Go to definition                      |
| `<S-F12>`      | Find references                       |
| `<C-F12>`      | Go to implementation                  |
| `<F2>`         | Rename                                |
| `<F3>`         | Next diagnostic (with float)          |
| `<S-F3>`       | Previous diagnostic                   |
| `<A-j>`        | Go to definition (VS Code alt)        |

### `<leader>l*`

| Keymap         | Action                                |
| -------------- | ------------------------------------- |
| `<leader>la`   | LSP: code action                      |
| `<leader>ln`   | LSP: rename                           |
| `<leader>lh`   | LSP: hover                            |
| `<leader>lk`   | LSP: signature help                   |
| `<leader>ld`   | LSP: definition                       |
| `<leader>lr`   | LSP: references                       |
| `<leader>li`   | LSP: implementation                   |
| `<leader>lt`   | LSP: type definition                  |
| `<leader>lD`   | LSP: declaration                      |
| `<leader>lR`   | LSP: references (telescope picker)    |
| `<leader>lI`   | LSP: implementations (telescope)      |
| `<leader>lT`   | LSP: type defs (telescope)            |
| `<leader>lf`   | Format buffer (conform.nvim)          |
| `<leader>lo`   | Outline / Aerial toggle               |
| `<S-A-f>`      | Format document (VS Code Shift+Alt+F) |

### Diagnostics

Сами по себе сообщения не раскрываются: пассивно — знак в gutter + подчёркивание
и лёгкая заливка ровно под ошибочными символами. Текст — по `gl`: оверлей поверх
кода плюс подсветка того самого диапазона, о котором говорит окно. Гаснет при
движении курсора, код не сдвигается.

| Keymap         | Action                                          |
| -------------- | ----------------------------------------------- |
| `gl`           | Диагностика под курсором: окно + подсветка места |
| `gl` (повторно)| Перейти внутрь окна (скролл/копирование)        |
| `<Esc>`        | Убрать окно, не двигая курсор                   |
| `q`            | Закрыть окно, находясь внутри него              |
| `<C-W>d`       | То же окно без подсветки (дефолт Neovim)        |
| `<leader>td`   | Inline-режим: off → current line → all → off    |
| `<leader>sd`   | Telescope buffer diagnostics                    |
| `<leader>sD`   | Telescope workspace diagnostics                 |

---

## 12. Outline / Symbols

| Keymap         | Action                                |
| -------------- | ------------------------------------- |
| `<leader>lo`   | Aerial toggle (left)                  |
| `<leader>so`   | AerialToggle!                         |
| `<leader>sn`   | AerialNavToggle (popup)               |
| `<leader>sS`   | LSP document symbols (telescope)      |
| `<leader>sW`   | LSP workspace symbols (telescope)     |
| `{` / `}`      | Prev/next symbol (в буфере с aerial)  |
| `<A-n>` / `<A-p>` | Next/prev illuminate reference     |

---

## 13. Terminal (`<leader>t*`)

| Keymap         | Action                                |
| -------------- | ------------------------------------- |
| `<leader>tt`   | Toggleterm: horizontal (bottom edgebar) |
| `<leader>tT`   | Toggleterm: float                     |
| `<leader>tV`   | Toggleterm: vertical split            |
| `<C-\>` / `<C-t>` | Quick toggle (VS Code-style)       |
| `<Esc><Esc>`   | Терминал → normal mode                |

---

## 14. Trouble / Diagnostics

| Keymap         | Action                                |
| -------------- | ------------------------------------- |
| `<leader>xx`   | Trouble: workspace diagnostics        |
| `<leader>xX`   | Trouble: buffer diagnostics           |
| `<leader>xs`   | Trouble: symbols (focus=false)        |
| `<leader>xr`   | Trouble: LSP refs/defs/impls          |
| `<leader>xL`   | Trouble: location list                |
| `<leader>xQ`   | Trouble: quickfix                     |

---

## 15. Toggles

| Keymap         | Action                                |
| -------------- | ------------------------------------- |
| `<leader>tw`   | Toggle: wrap                          |
| `<leader>tn`   | Toggle: relativenumber                |
| `<leader>th`   | Toggle: LSP inlay hints (буфер)       |
| `<leader>ts`   | Toggle: spell                         |
| `<leader>td`   | Toggle: diagnostics (DiagToggle)      |

> Конфликт по namespace `<leader>t*` с Terminal и Tests: для Tests
> используется ЗАГЛАВНАЯ `<leader>T*`, для Terminal — `<leader>tt/T/V`,
> остальные `<leader>t*` — toggles.

---

## 16. Project / Session

### Open

| Keymap         | Action                                |
| -------------- | ------------------------------------- |
| `<leader>fp`   | Files: recent projects picker         |
| `<leader>op`   | Open: recent project                  |
| `<leader>ow`   | Open: work in current folder          |
| `<leader>of` / `<leader>oP` | Open: folder path prompt |
| `<leader>oC`   | Open: this config (`init.lua`)        |

### Session (persistence.nvim)

| Keymap         | Action                                |
| -------------- | ------------------------------------- |
| `<leader>qs`   | Session: restore for cwd              |
| `<leader>qS`   | Session: select                       |
| `<leader>ql`   | Session: restore last                 |
| `<leader>qd`   | Session: don't save current           |

### Quit

| Keymap         | Action                                |
| -------------- | ------------------------------------- |
| `<leader>qq`   | Quit all (`:qa`)                      |
| `<leader>qw`   | Save & quit all (`:wqa`)              |

---

## 17. Legacy panels (mode-based, старая система)

`<leader>m*` — старые "режимы" из `config/panels.lua`. Они оставлены
как backwards-compat поверх нового ide framework'а. Если ты доволен
новыми `<leader>p*` — этот раздел можешь игнорировать. Будут удалены
позже (этап 10 плана).

| Keymap         | Action                                |
| -------------- | ------------------------------------- |
| `<leader>mm`   | Mode: select picker                   |
| `<leader>mf`   | Mode: files (Neo-Tree filesystem)     |
| `<leader>mb`   | Mode: buffers (Neo-Tree buffers)      |
| `<leader>mg`   | Mode: git (Neo-Tree git_status)       |
| `<leader>md`   | Mode: debug                           |
| `<leader>mt`   | Mode: tests                           |
| `<leader>mj`   | Mode: jobs (overseer)                 |
| `<leader>ms`   | Mode: search (grug-far)               |
| `<leader>mo`   | Mode: output (debug console)          |
| `<leader>mc`   | Mode: code only                       |
| `<leader>mq` / `<leader>mQ` | Mode: close IDE          |
| `<leader>m0`   | Mode: focus code                      |
| `<leader>m]`   | Mode: next window                     |
| `<leader>m[`   | Mode: previous window                 |
| `<leader>m1..6`| Mode: focus slot N                    |

---

## 18. Universal close/focus (F-keys, Alt)

Работают в любых окнах и режимах.

| Keymap         | Action                                | Mode |
| -------------- | ------------------------------------- | ---- |
| `<F4>` / `<C-F4>` / `<A-w>` / `<A-q>` / `<C-q>` | Smart close current context | n/i/v/t |
| `<F6>` / `<S-F6>` | Cycle window focus (next/prev)     | n/i/v/t |
| `<F7>` / `<A-e>` | Focus editor window                 | n/i/v/t |
| `<C-PageDown>` / `<A-l>` | Next buffer                 | n/i/v/t |
| `<C-PageUp>` / `<A-h>`   | Previous buffer             | n/i/v/t |

---

## 19. Editing / IDE shortcuts (VS Code-style)

### Clipboard

| Keymap         | Action                                | Mode |
| -------------- | ------------------------------------- | ---- |
| `<C-s>`        | Save                                  | n/i/v |
| `<C-a>`        | Select all                            | n/i  |
| `<C-c>`        | Copy selection                        | v    |
| `<C-x>`        | Cut selection                         | v    |
| `<C-v>`        | Paste                                 | n/v/i/c |
| `<C-z>`        | Undo                                  | n/i  |
| `<C-y>`        | Redo                                  | n/i  |

### Comments / Indent

| Keymap         | Action                                | Mode |
| -------------- | ------------------------------------- | ---- |
| `<C-/>` / `<C-_>` | Toggle comment line                | n/i/x |
| `<C-]>`        | Indent line                           | n/i/v |
| `<` / `>`      | Indent left/right (сохраняет visual)  | v    |

### Movement

| Keymap         | Action                                | Mode |
| -------------- | ------------------------------------- | ---- |
| `<A-Up>` / `<A-Down>` | Move line up/down              | n/i/v |
| `<S-A-Up>` / `<S-A-Down>` | Duplicate line up/down     | n/v  |
| `<A-[>` / `<A-]>` | Jumplist back/forward              | n    |
| `$` / `<End>`  | End of line **без** newline (`g_`)    | n/v  |
| `j` / `k`      | gj / gk при wrap                      | n/v  |

### Selection

| Keymap         | Action                                | Mode |
| -------------- | ------------------------------------- | ---- |
| `<C-l>`        | Select line без `\n`                  | n    |
| `<Esc>`        | Clear search highlight                | n    |
| `<C-CR>`       | Run selection через `pwsh -Command -` | v    |

---

## 20. Completion popup

(`nvim-cmp` в insert mode, когда popup виден)

| Keymap         | Action                                |
| -------------- | ------------------------------------- |
| `<C-j>` / `<C-Down>` | Select next item                |
| `<C-k>` / `<C-Up>`   | Select previous item            |
| `<C-Space>`    | Manual trigger                        |
| `<C-e>`        | Abort completion                      |
| `<CR>`         | Confirm (replace, no auto-select)     |
| `<Tab>`        | Confirm / expand snippet / fallback   |
| `<S-Tab>`      | Snippet jump back                     |
| `<C-u>` / `<C-d>` | Scroll docs window up/down         |

В cmdline (`:`):

| Keymap         | Action                                |
| -------------- | ------------------------------------- |
| `<Tab>`        | Accept wildmenu или trigger cmp       |
| `<CR>`         | Accept wildmenu или submit            |
| `<C-v>`        | Paste from system clipboard           |

---

## 21. Commands

### IDE framework

| Command                    | Action                              |
| -------------------------- | ----------------------------------- |
| `:IdeStatus`               | Дамп текущего layout + slots        |
| `:IdeLayout <name>`        | Apply layout по имени               |
| `:IdeShow <component>`     | Открыть компонент явно              |

### DAP

| Command            | Action                                  |
| ------------------ | --------------------------------------- |
| `:DapShowLog`      | Открыть DAP log                         |
| `:DapPythonInfo`   | Показать выбранные Python/debugpy пути  |
| `:DapGoDlvInfo`    | Кандидаты Delve и выбранный             |

### Forge custom

| Command            | Action                                  |
| ------------------ | --------------------------------------- |
| `:ForgeFocusNext`  | Cycle window focus (next)               |
| `:ForgeFocusPrev`  | Cycle window focus (prev)               |
| `:ForgeFocusEditor`| Focus editor window                     |
| `:ForgeCloseContext`| Smart close current context            |
| `:ForgeBufferNext` | Next listed file buffer                 |
| `:ForgeBufferPrev` | Previous listed file buffer             |

### Health

| Command                     | Action                       |
| --------------------------- | ---------------------------- |
| `:checkhealth`              | Стандартная nvim проверка    |
| `:Healthcheck` / `:HealthCheck` | Алиасы для muscle-memory |
| `cnoreabbrev healthcheck`   | Автозамена `healthcheck` → `checkhealth` в cmdline |

---

## Cheat sheet: что главное

Если коротко, минимальный набор на каждый день:

| Категория     | Key             | Что делает                         |
| ------------- | --------------- | ---------------------------------- |
| Поиск файла   | `<C-p>`         | Find file (telescope)              |
| Поиск кода    | `<leader>ss`    | Live grep                          |
| Explorer      | `<leader>e`     | Toggle Neo-Tree                    |
| Левая панель  | `<C-b>`         | Toggle whole left slot (VS Code Ctrl+B) |
| Нижняя панель | `<C-j>` / `<F8>`| Toggle whole bottom slot (VS Code Ctrl+J) |
| Закрыть       | `<F4>` / `<C-q>`| Smart close (alpha если последний) |
| Сохранить     | `<C-s>`         | Save                               |
| Layouts       | `<leader>pp`    | Picker всех layouts                |
| Debug start   | `F5`            | Continue/start (выберет config)    |
| Debug step    | `F10` / `F11`   | Step over / into                   |
| Watch expr    | `<leader>dw`    | Add to watch panel                 |
| Terminal      | `<leader>tt`    | Bottom terminal                    |
| LSP defs/refs | `gd` / `gr`     | Go to def / find refs              |
| Hover         | `K`             | Documentation                      |
| Code action   | `<leader>la`    | LSP code action menu               |
| Format        | `<leader>lf`    | Format buffer                      |
| Comment line  | `<C-/>`         | Toggle comment                     |
| Git diff      | `<leader>gd`    | DiffviewOpen                       |
| Git status    | `<leader>gg`    | Neogit (tab)                       |

---

## Notes

- **Описание**: запускай `:Telescope keymaps` или `<leader>sk` — даст
  интерактивный picker по всем зарегистрированным маппингам с preview
  правой колонкой.
- **Which-key**: после нажатия `<leader>` появляется popup с группами
  (`p` Layouts, `P` IDE, `d` Debug, `g` Git, `l` LSP, `s` Search, …).
  Подождать `timeoutlen` (по умолчанию 300ms) и оно само покажет.
- **Russian layout**: все `<leader>*` и `<C-*>` мapping'и работают и
  с включённой русской раскладкой через `langmap` + `ru_keys`. Это
  значит `<leader>фф` ≡ `<leader>aa` и т.д.
