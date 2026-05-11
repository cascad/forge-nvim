# Шпаргалка на каждый день

Лидер: **Space**.
Все маппинги отображаются в which-key — нажми `<Space>` и подожди.

---

## 1. Файлы / навигация

| Клавиша | Действие |
|---|---|
| `<C-p>` | Find file (Telescope) |
| `<C-S-p>` | Command palette |
| `<C-S-f>` | Live grep по проекту |
| `<C-e>` / `<leader>e` | Toggle file tree (neo-tree) |
| `<leader>E` | Reveal current file in tree |
| `<leader>ff` | Files: find |
| `<leader>fr` | Files: recent |
| `<leader>fg` | Files: live grep |
| `<leader>fb` | Files: buffers |
| `<leader>fc` | Files: changed (git status) |
| `<leader>fj` | Files: jumplist |
| `<leader>fp` / `<leader>op` | **Open recent project** (project.nvim) |
| `<leader>oh` | Open home / Alpha |
| `<S-h>` / `<S-l>` | Prev / next buffer |
| `<leader>bd` | Close buffer |

## 2. Поиск

| Клавиша | Действие |
|---|---|
| `<leader>ss` | Search: workspace grep |
| `<leader>sw` | Search: word под курсором |
| `<leader>sb` | Search: buffer fuzzy |
| `<leader>sd` / `<leader>sD` | Search: buf / workspace diagnostics |
| `<leader>sS` / `<leader>sW` | Search: doc / workspace symbols |
| `<leader>st` | Search: TODO / FIXME / NOTE |
| `<leader>sk` | Search: keymaps (внутренний) |
| `<leader>sr` | Search: resume последний picker |

## 3. LSP / IDE-навигация

| Клавиша | Действие |
|---|---|
| `gd`, `<A-j>`, `F12` | Go to definition |
| `gD` | Go to declaration |
| `gr`, `<S-F12>` | References |
| `gi`, `<C-F12>` | Implementation |
| `gy` | Type definition |
| `K` | Hover |
| `F2`, `<leader>ln` | Rename |
| `<leader>la` | Code action |
| `<leader>lk` | Signature help |
| `<leader>lf`, `<S-A-f>` | Format document |
| `<leader>th` | Toggle inlay hints |
| `F3` / `<S-F3>` | Next / prev diagnostic |
| `]d` / `[d` | Next / prev diagnostic (через trouble) |
| `]f` / `[f` | Next / prev function (TS) |
| `]c` / `[c` | Next / prev class (TS) |
| `<A-n>` / `<A-p>` | Next / prev reference (illuminate) |

### Peek (как Ctrl+Click в IDE)

| Клавиша | Действие |
|---|---|
| `gpd` | Peek definitions |
| `gpr` | Peek references |
| `gpt` | Peek type defs |
| `gpi` | Peek implementations |

### Postфикс-панели

| Клавиша | Действие |
|---|---|
| `<leader>xx` | Trouble: workspace diagnostics |
| `<leader>xX` | Trouble: buffer diagnostics |
| `<leader>xr` | Trouble: LSP refs / defs / impls (panel) |
| `<leader>xs` | Trouble: symbols panel |
| `<leader>so` | Outline (aerial) — Structure window |
| `{` / `}` | Prev / next symbol в outline (когда aerial открыт) |

## 4. Дебаггер (F-клавиши = VS Code)

| Клавиша | Действие |
|---|---|
| `F5` | Continue / start |
| `<S-F5>` | Terminate |
| `F9` | Toggle breakpoint |
| `<leader>dB` | Conditional breakpoint (попросит условие) |
| `F10` | Step over |
| `F11` | Step into |
| `<S-F11>` | Step out |
| `<leader>du` | Toggle DAP UI |
| `<leader>de` | Eval (выражение / выделение) |
| `<leader>dR` | REPL toggle |
| `<leader>dl` | Run last config |

### Rust-специфика (rustaceanvim)

| Клавиша | Действие |
|---|---|
| `<leader>rR` | Runnables |
| `<leader>rD` | Debuggables |
| `<leader>rt` | Testables |
| `<leader>rh` | Hover actions |
| `<leader>rm` | Expand macro |
| `<leader>rc` | Open Cargo.toml |
| `<leader>rp` | Parent module |

### Go-специфика

| Клавиша | Действие |
|---|---|
| `<leader>dt` | Debug test under cursor |
| `<leader>dT` | Debug last test |
| `:DapGoDlvInfo` | Show selected Delve binary and all candidates |

### Python-специфика

| Клавиша | Действие |
|---|---|
| `<leader>dt` | Debug test method |
| `<leader>dT` | Debug test class |

## 5. Git (gitsigns)

| Клавиша | Действие |
|---|---|
| `]h` / `[h` | Next / prev hunk |
| `<leader>ghs` | Stage hunk |
| `<leader>ghr` | Reset hunk |
| `<leader>ghp` | Preview hunk |
| `<leader>ghb` | Blame line |
| `<leader>ghd` | Diff buffer vs index |
| `<leader>ghD` | Diff buffer vs HEAD~ |
| `<leader>ghB` | Toggle current-line blame |

## 6. VS Code-style биндинги

| Клавиша | Действие |
|---|---|
| `<C-s>` | Save (везде) |
| `<C-z>` / `<C-y>` | Undo / redo |
| `<C-c>` / `<C-x>` / `<C-v>` | Copy / cut / paste из системного буфера |
| `<C-a>` | Select all |
| `<C-f>` | Find в буфере |
| `<C-h>` | Replace в буфере (`:%s/`) |
| `<C-/>` | Toggle comment |
| `<C-l>` | Select line без `\n` |
| `<A-[>` / `<A-]>` | Jumplist back / forward |
| `<A-Up>` / `<A-Down>` | Move line up / down |
| `<S-A-Up>` / `<S-A-Down>` | Duplicate line up / down |
| `<S-A-K>` / `<S-A-J>` | Smart-select expand / shrink (treesitter) |
| `<S-A-F>` | Format document |
| `<C-CR>` | Запустить выделение в pwsh (visual) |

## 7. Окна / сплиты

| Клавиша | Действие |
|---|---|
| `<leader>wv` / `<leader>ws` | Vsplit / hsplit |
| `<leader>wh/j/k/l` | Перейти в окно слева / снизу / сверху / справа |
| `<leader>wq` / `<leader>wo` | Закрыть текущее / оставить только текущее |

## 8. Терминал

| Клавиша | Действие |
|---|---|
| `<leader>tt` | Открыть pwsh снизу |
| `<Esc><Esc>` | Из терминала в normal mode |

## 9. Сессии (persistence)

| Клавиша | Действие |
|---|---|
| `<leader>qs` | Восстановить сессию для cwd |
| `<leader>qS` | Выбрать из списка |
| `<leader>ql` | Восстановить последнюю |
| `<leader>qd` | Не сохранять текущую |

## 10. Управление плагинами

| Клавиша | Действие |
|---|---|
| `<leader>L` | Lazy UI (плагины) |
| `<leader>M` | Mason UI (LSP/DAP/форматтеры) |

| Команда | Действие |
|---|---|
| `:Lazy update` | Обновить плагины |
| `:Lazy log` | Лог последних операций lazy |
| `:MasonToolsUpdate` | Обновить инструменты mason |
| `:TSUpdate` | Обновить treesitter-парсеры |
| `:checkhealth` | Полный отчёт по подсистемам |
| `:LspInfo` | Активные LSP-клиенты в текущем буфере |
| `:LspLog` | Лог LSP |
| `:messages` | Все сообщения с момента старта |

## 11. Редко, но полезно

| Команда | Действие |
|---|---|
| `:FormatDisable` | Отключить format-on-save глобально |
| `:FormatDisable!` | … для текущего буфера |
| `:FormatEnable` | Вернуть |
| `:Glance definitions` | Peek definition |
| `:AerialToggle` | Outline panel |
| `:Trouble diagnostics` | Problems panel |

---

## Где что лежит

* **Конфиг**: `%LOCALAPPDATA%\nvim` на Windows, `~/.config/nvim` на Linux/macOS
* **Плагины**: `%LocalAppData%\nvim-data\lazy\`
* **Mason**: `%LocalAppData%\nvim-data\mason\`
* **Treesitter parsers**: `%LocalAppData%\nvim-data\site\parser\`
* **Undo / shada / sessions**: `%LocalAppData%\nvim-data\`
* **Лог LSP**: `%LocalAppData%\nvim-data\lsp.log`

Перезагрузить конфиг без рестарта — `:source $MYVIMRC`. Но для правок в
`lua\plugins\*` проще `:Lazy reload <plugin>` либо рестарт.
