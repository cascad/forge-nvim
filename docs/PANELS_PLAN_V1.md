# Panels framework — план (edgy.nvim + edgy-group.nvim)

Статус: **готов к работе**. Реализуется в `nvim_forge/`.

> История: прежняя версия этого документа описывала собственный
> мини-фреймворк (`lua/ide/panels.lua` + `components.lua` + `layouts.lua`).
> Решение пересмотрено в пользу готового стека (см. §1). Старый текст
> доступен в git history.

## 1. Контекст и выбор стека

Существующий `nvim_forge/lua/config/panels.lua` (~791 строка) реализует
mode-based IDE-режимы: `mode_X` / `close_X` / `toggle_X` / `focus_X`
на каждое сочетание, ручной `close_activity(except)`. Биндинги
`<leader>m{m,f,b,g,d,t,j,s,o,c,q,Q,0,],[}`. Архитектурно нормально,
но много бойлерплейта и UX-нюансов (фокус, sessions, edge cases с
DapView).

Вместо переписывания на своё ядро берём поддерживаемый стек:

- **[`folke/edgy.nvim`](https://github.com/folke/edgy.nvim)** —
  движок edgebar'ов (left/right/bottom/top). Auto-capture окон по
  filetype/filter, pinned views, collapse, animations, buffer-local
  keymaps. От автора lazy.nvim, дефолт в LazyVim. Активный
  maintenance (push 2025-10-28, 1100+ ★).
- **[`lucobellic/edgy-group.nvim`](https://github.com/lucobellic/edgy-group.nvim)** —
  расширение для **группировки views в одном edge** с переключением
  между группами. Это наш «слой/комбинация» из исходного запроса.
  Активный maintenance (sep 2025).
- **Наш тонкий wrapper** (`nvim_forge/lua/ide/layouts.lua`, ~40 LoC) —
  именованные пресеты `code / files / git / debug / tests / search /
  jobs` поверх `edgy-group.open_groups_by_key`.

Всё остальное (`panels.lua` mode-механика, ручные `is_visible` /
`close_windows` / `focus_later`) — выкидывается. Чистый минус ~600
строк своего кода.

## 2. Цели и не-цели

### Цели

- Декларативно описать наши tool-окна как **edgy views**.
- Описать **«слои»** через edgy-group groups для каждого edge.
- Дать **именованные layout-пресеты** (`apply_layout("debug")`) одной
  командой переключающие комбинацию групп.
- Сохранить рабочие старые биндинги `<leader>m*` на время миграции.
- Не написать ни строчки своего window-manager кода.

### Не-цели

- Не таскаем `ldelossa/nvim-ide` (живёт в отдельной сборке `nvim-ide/`).
- Не строим стек/таб бар для tool-окон (edgy сам отрисовывает edgebar).
- Не сохраняем persistance layout между сессиями в первой итерации
  (опциональный пункт §12).

## 3. Архитектура

```
nvim_forge/
├── lua/
│   ├── ide/
│   │   └── layouts.lua          -- НАШ wrapper: пресеты + apply/select
│   ├── plugins/
│   │   ├── edgy.lua             -- edgy.nvim + view-spec для всех плагинов
│   │   └── edgy-group.lua       -- edgy-group.nvim + groups
│   └── config/
│       ├── options.lua          -- patched: laststatus=3, splitkeep=screen
│       ├── keymaps.lua          -- patched: добавляем <leader>p* и <leader>e*
│       └── panels.lua           -- остаётся до Этапа 7 (см. §10)
```

Поток управления:

1. Открыть Neo-Tree / DapView / Aerial / Overseer / ... как обычно
   (своими командами этих плагинов).
2. edgy.nvim **перехватывает** окно по `ft` + `filter` и кладёт в
   соответствующий edgebar.
3. edgy-group.nvim видит views по их `title` и группирует их в
   «слои» внутри edge.
4. `require("ide.layouts").apply("debug")` дёргает
   `edgy-group.open_groups_by_key` для каждого edge, переключая
   видимую группу.

## 4. Pre-flight: Neovim options

edgy требует следующие настройки. Добавить в
`nvim_forge/lua/config/options.lua` (проверить, не выставлены ли уже):

```lua
vim.opt.laststatus = 3   -- global statusline; без этого collapsed views ломаются
vim.opt.splitkeep  = "screen"  -- main splits не прыгают, когда edgy открывает edgebar
```

Если `laststatus` уже `3` — пропустить. Если стоит `2` — поменять,
проверить, что наш statusline (lualine?) не сломался.

## 5. Каталог views для edgy

`nvim_forge/lua/plugins/edgy.lua` (примерно ~150 LoC, в основном
конфиг). Каждый view следует спецификации edgy:

```lua
{
  title    = "Neo-Tree",        -- ID, по нему edgy-group выбирает группы
  ft       = "neo-tree",        -- filetype окна
  filter   = function(buf, win) -- доп. фильтр, например по source
    return vim.b[buf].neo_tree_source == "filesystem"
  end,
  size     = { height = 0.5 },  -- доля edge'а
  pinned   = false,             -- true = всегда виден в edgebar (даже без окна)
  collapsed = false,            -- true = стартует свёрнутым
  open     = "Neotree position=left filesystem",  -- команда для pinned views
}
```

### Левый edge (`left = { ... }`)

| Title              | Source                                              | filter                                              |
|--------------------|-----------------------------------------------------|-----------------------------------------------------|
| `Neo-Tree`         | `ft = "neo-tree"`, open=`Neotree filesystem reveal left` | `vim.b[buf].neo_tree_source == "filesystem"`     |
| `Neo-Tree Buffers` | same ft, open=`Neotree buffers reveal left`         | `vim.b[buf].neo_tree_source == "buffers"`           |
| `Neo-Tree Git`     | same ft, open=`Neotree git_status reveal left`      | `vim.b[buf].neo_tree_source == "git_status"`        |

### Правый edge (`right = { ... }`)

| Title             | Source                                              | filter / ft                                          |
|-------------------|-----------------------------------------------------|------------------------------------------------------|
| `Outline`         | aerial, `:AerialOpen right`                         | `ft = "aerial"`                                      |
| `DAP`             | `ft = "dap-view"` (захватывает основное DapView окно) | без filter (DapView сам делит свой split на секции) |
| `Neotest Summary` | `:lua require'neotest'.summary.open()`              | `ft = "neotest-summary"`                             |
| `Neogit`          | `:Neogit kind=vsplit`                                | `ft = "NeogitStatus"` или `ft = "Neogit*"` (точное значение проверить в runtime) |

> Замечание про DAP. `nvim-dap-view` сам управляет split'ами внутри
> своего окна (scopes / breakpoints / stacks / watches). edgy
> захватывает корневое окно DapView как один view; переключение
> секций — по-прежнему через `:DapViewShow <section>` или через
> внутренние биндинги DapView. Это **сознательное упрощение**: мы не
> мапим каждую DAP-секцию на отдельный edgy view, потому что
> DapView не публикует их по отдельным filetypes.

### Нижний edge (`bottom = { ... }`)

| Title           | Source                                                   | filter / ft                                          |
|-----------------|----------------------------------------------------------|------------------------------------------------------|
| `DAP Console`   | dap-view nested console buffer, `:DapViewShow console`   | `ft = "dap-view-term"`                               |
| `DAP REPL`      | `:DapViewShow repl` или нативный dap-repl                | `ft = "dap-repl"`                                    |
| `Test Output`   | `:lua require'neotest'.output_panel.open()`              | `ft = "neotest-output-panel"`                        |
| `Tasks`         | `:OverseerOpen bottom`                                   | `ft = "OverseerList"`                                |
| `Search`        | `:botright vertical GrugFar` (или просто `:GrugFar`)     | `ft = "grug-far"`                                    |
| `Trouble`       | `:Trouble diagnostics`                                   | `ft = "trouble"` (filter по `mode`?)                 |
| `QuickFix`      | `:copen`                                                 | `ft = "qf"`                                          |

> Точные filetypes для DapView (`dap-view-term` vs другие) и Neogit
> (`NeogitStatus` vs `Neogit*`) валидируем на этапе 2 через
> `:set filetype?` в живом окне. План корректируем по факту.

## 6. Groups: «слои» для каждого edge

`nvim_forge/lua/plugins/edgy-group.lua`. Дефолтная конфигурация:

```lua
{
  groups = {
    left = {
      { icon = "f", pick_key = "f", titles = { "Neo-Tree" } },
      { icon = "b", pick_key = "b", titles = { "Neo-Tree Buffers" } },
      { icon = "g", pick_key = "g", titles = { "Neo-Tree Git" } },
    },
    right = {
      { icon = "o", pick_key = "o", titles = { "Outline" } },
      { icon = "d", pick_key = "d", titles = { "DAP" } },
      { icon = "t", pick_key = "t", titles = { "Neotest Summary" } },
      { icon = "n", pick_key = "n", titles = { "Neogit" } },
    },
    bottom = {
      { icon = "c", pick_key = "c", titles = { "DAP Console", "DAP REPL" } },
      { icon = "p", pick_key = "p", titles = { "Test Output" } },
      { icon = "j", pick_key = "j", titles = { "Tasks" } },
      { icon = "s", pick_key = "s", titles = { "Search" } },
      { icon = "x", pick_key = "x", titles = { "Trouble" } },
      { icon = "q", pick_key = "q", titles = { "QuickFix" } },
    },
  },
  toggle = true,
  statusline = {
    -- В первой итерации не интегрируем со statusline. Включим, когда
    -- разберёмся с lualine — см. §12.
    clickable = false,
    colored = false,
  },
}
```

> Важно: `pick_key` в edgy-group **должен быть уникален в пределах
> position**. Конфликтов между позициями (одна `t` для left и
> другая для bottom) — нет, ключ разрешается через `position`.

> В `bottom` группа `c` содержит две title'а (`DAP Console`,
> `DAP REPL`) — обе будут показаны вместе при выборе группы.
> Это специально, потому что в дебаге часто хочется видеть оба.

## 7. Layouts wrapper

`nvim_forge/lua/ide/layouts.lua`, ~40 LoC:

```lua
local M = {}

local presets = {
  code   = { left = nil, right = nil, bottom = nil },
  files  = { left = "f", right = "o", bottom = nil },
  git    = { left = "g", right = "n", bottom = nil },
  debug  = { left = "f", right = "d", bottom = "c" },
  tests  = { left = "f", right = "t", bottom = "p" },
  search = { left = nil, right = nil, bottom = "s" },
  jobs   = { left = nil, right = nil, bottom = "j" },
}

local positions = { "left", "right", "bottom" }

local function close_pos(pos)
  pcall(function() require("edgy").close(pos) end)
end

local function open_group(pos, key)
  pcall(function()
    require("edgy-group").open_groups_by_key(key, { position = pos, toggle = false })
  end)
end

function M.apply(name)
  local p = presets[name]
  if not p then
    vim.notify("unknown layout: " .. tostring(name), vim.log.levels.WARN)
    return
  end
  for _, pos in ipairs(positions) do
    if p[pos] == nil then
      close_pos(pos)
    else
      open_group(pos, p[pos])
    end
  end
end

function M.select()
  local items = vim.tbl_keys(presets)
  table.sort(items)
  vim.ui.select(items, { prompt = "Layout: " }, function(choice)
    if choice then M.apply(choice) end
  end)
end

function M.register(name, def)
  presets[name] = def
end

return M
```

## 8. Биндинги

В `nvim_forge/lua/config/keymaps.lua` добавляем блок (старые
`<leader>m*` пока **не трогаем**):

```lua
-- Edgy groups: ручной cycle и выбор по pick_key
nm("<leader>el", function() require("edgy-group").open_group_offset("left",   1) end, "Edgy: next left group")
nm("<leader>eh", function() require("edgy-group").open_group_offset("left",  -1) end, "Edgy: prev left group")
nm("<leader>er", function() require("edgy-group").open_group_offset("right",  1) end, "Edgy: next right group")
nm("<leader>eR", function() require("edgy-group").open_group_offset("right", -1) end, "Edgy: prev right group")
nm("<leader>eb", function() require("edgy-group").open_group_offset("bottom", 1) end, "Edgy: next bottom group")
nm("<leader>eB", function() require("edgy-group").open_group_offset("bottom",-1) end, "Edgy: prev bottom group")
nm("<leader>ep", "<cmd>EdgyGroupSelect<CR>", "Edgy: pick group")

-- Edgy edgebar operations
nm("<leader>eL", function() require("edgy").toggle("left")   end, "Edgy: toggle left edgebar")
nm("<leader>eK", function() require("edgy").toggle("right")  end, "Edgy: toggle right edgebar")
nm("<leader>eJ", function() require("edgy").toggle("bottom") end, "Edgy: toggle bottom edgebar")
nm("<leader>e0", function() require("edgy").goto_main()      end, "Edgy: focus main editor")

-- Layout presets
local L = require("ide.layouts")
nm("<leader>pp", L.select,                              "Layout: select")
nm("<leader>pc", function() L.apply("code")   end,      "Layout: code only")
nm("<leader>pf", function() L.apply("files")  end,      "Layout: files")
nm("<leader>pg", function() L.apply("git")    end,      "Layout: git")
nm("<leader>pd", function() L.apply("debug")  end,      "Layout: debug")
nm("<leader>pt", function() L.apply("tests")  end,      "Layout: tests")
nm("<leader>ps", function() L.apply("search") end,      "Layout: search")
nm("<leader>pj", function() L.apply("jobs")   end,      "Layout: jobs")
nm("<leader>pq", function() L.apply("code")   end,      "Layout: close all")
```

Готовые edgy buffer-local keymaps (`q` close, `<C-q>` hide, `Q` close
edgebar, `]w` / `[w` next/prev открытый, `]W` / `[W` next/prev
loaded, `<C-w>+/-/>/<` resize, `<C-w>=` equalize) — оставляем
включёнными по дефолту, переопределять не надо.

## 9. Этапы реализации

Каждый этап = один атомарный коммит, может быть протестирован отдельно.

### Этап 1 — Pre-flight (5 минут)

- `nvim_forge/lua/config/options.lua`: добавить `laststatus=3`,
  `splitkeep="screen"`. Проверить, что не задано иначе.
- Smoke: `:lua print(vim.opt.laststatus:get(), vim.opt.splitkeep:get())`.

### Этап 2 — edgy.nvim + views (1-1.5 часа)

- Новый файл `nvim_forge/lua/plugins/edgy.lua` с конфигом из §5.
- Не пинить ничего сразу: `pinned = false` для всех views.
  Когда дойдём до тонкой настройки — добавим `pinned = true` для
  Neo-Tree (filesystem) и Outline (aerial), чтобы они оставались
  в edgebar даже когда закрыты.
- Прогон smoke:
  - `:Neotree` → должно встать в left edgebar.
  - `:AerialOpen` → должно встать в right edgebar.
  - `:OverseerOpen bottom` → должно встать в bottom edgebar.
  - `:DapViewOpen` → должно встать в bottom edgebar (или right,
    решим по факту, см. §12 q3).
  - Окно с кодом не дёргается, не схлопывается.
- Точные filetypes/titles валидируем здесь, корректируем конфиг
  до полного совпадения с реальностью.

### Этап 3 — edgy-group.nvim + groups (~45 минут)

- Новый файл `nvim_forge/lua/plugins/edgy-group.lua` с конфигом из §6.
- Smoke: `:EdgyGroupSelect` — должен показать список групп.
- Smoke: `:EdgyGroupNext left` / `:EdgyGroupPrev left` — переключает
  между Neo-Tree filesystem / buffers / git.

### Этап 4 — layouts wrapper (~30 минут)

- Новый файл `nvim_forge/lua/ide/layouts.lua` из §7.
- Smoke: `:lua require("ide.layouts").apply("debug")` — открывает
  Neo-Tree слева, DapView справа, DAP Console внизу. Без ошибок.
- Smoke: `:lua require("ide.layouts").apply("code")` — закрывает всё.

### Этап 5 — keymaps (~20 минут)

- Дополнить `nvim_forge/lua/config/keymaps.lua` блоком из §8.
- which-key должен подхватить новые группы (`<leader>e`, `<leader>p`).
- Старые `<leader>m*` оставляем нетронутыми.

### Этап 6 — миграция `panels.lua` (~1 час)

Для каждого `mode_X` в `panels.lua`:

- Тело функции заменить на `require("ide.layouts").apply("X")`.
- Внутренние `close_X` / `focus_X` / `toggle_X` либо
  редиректить на edgy API (`edgy.close(pos)`, `edgy.toggle(pos)`),
  либо удалить, если зовутся только из `mode_X`.
- `prepare_session_save`: заменить на
  `require("ide.layouts").apply("code")` — это то же самое, что
  раньше делал `close_activity(nil)`.
- `select_mode` оставить или переписать на `layouts.select()`.

### Этап 7 — cleanup (~15 минут)

После 1-2 недель использования:

- Удалить `nvim_forge/lua/config/panels.lua`.
- Из `keymaps.lua` убрать `<leader>m*` (или оставить как алиасы
  на `<leader>p*` — на вкус).
- В `nvim_forge/QUICKSTART.md` обновить cheatsheet: убрать
  упоминания `<leader>m*`, добавить `<leader>p*` / `<leader>e*`.

## 10. Совместимость со старым `panels.lua`

Этапы 2-5 **не трогают** существующий `panels.lua`. Биндинги
`<leader>m*` продолжают вызывать старые функции, которые работают как
раньше. Новые `<leader>p*` / `<leader>e*` идут поверх через edgy.

Возможные конфликты во время сосуществования:

- Старый `panels.mode_files()` зовёт `Neotree filesystem reveal left`
  и `M.close_activity("files")`. Это **совместимо с edgy**: edgy
  захватит neo-tree окно и положит в left edgebar; ручной
  `close_activity` закроет все остальные tool-окна тоже корректно
  (через filetype matching).
- DapView: старый `M.mode_debug()` использует `:DapViewOpen` +
  `:DapViewShow <section>`. Это совместимо: edgy захватит DapView
  как view, секции переключаются командой как обычно.

Никакой ручной отвязки не нужно. Старое и новое могут жить в одной
сессии.

## 11. Что мы НЕ переносим из старого `panels.lua`

После миграции (этапы 6-7) **выкидываем**:

- `is_visible` / `find_window` / `has_buffer_filetype` / `close_windows`
  — это edgy сам делает.
- `focus_later` / `focus_window` / `focus_code_later` / `focus_code_window`
  — `edgy.goto_main()` покрывает.
- `next_mode_window` / `prev_mode_window` / `focus_mode_slot`
  — edgy buffer-local `]w` / `[w` и `EdgyGroupNext/Prev` покрывают.
- `select_mode` — `layouts.select()`.
- `tool_filetypes` / `session_unsafe_filetypes` table — edgy сам
  знает, какие окна tool-окна (они зарегистрированы как views).

Что **остаётся** в виде нового кода:

- `ide/layouts.lua` (~40 LoC).
- Plugin specs `plugins/edgy.lua` (~150 LoC, в основном таблицы) и
  `plugins/edgy-group.lua` (~30 LoC).
- Биндинги в `keymaps.lua` (~30 LoC).

Итого: ~250 LoC нового, ~600 LoC удалено. Чистая дельта **−350 LoC**.

## 12. Open questions / known gotchas

1. **DapView positioning**. По дефолту dap-view может открыть свои
   окна по-разному (см. `dap-view` config `winbar`, `windows.position`).
   Нужно зафиксировать одно положение (предположительно `bottom` для
   console/repl и `right` для scopes/breakpoints/stacks/watches) и
   описать соответствующие views. На Этапе 2 это валидируется на
   живой DAP-сессии.

2. **Diffview**. Diffview берёт всё табное пространство (tabpage),
   а не edgebar. **Не захватываем** через edgy. Оставляем как есть —
   `<leader>gdd` открывает Diffview в новом табе, после `:DiffviewClose`
   возврат в основной таб без edgy-вмешательства.

3. **Telescope / which-key / lazy / mason UIs**. Это всё floating
   windows, edgy их не трогает (он работает только со split
   windows).

4. **Trouble.nvim mode**. Может иметь несколько mode'ов
   (`diagnostics`, `lsp_references`, `quickfix`, ...). По умолчанию
   все они одного `ft = "trouble"`. Если хочется разделить — можно
   делать filter по `vim.b[buf].trouble.mode`, но в первой итерации
   это не нужно.

5. **Statusline integration**. edgy-group.nvim даёт `get_statusline(pos)`
   для отрисовки активных групп с иконками в lualine/bufferline.
   В первой итерации **выключаем** (`statusline.clickable = false`).
   Включаем отдельным мини-этапом, когда хотим иконки.

6. **Persistence layout между сессиями**. edgy сам не сохраняет
   layout. Если когда-то понадобится — `auto-session` callback
   `pre_save` вызовет `layouts.apply("code")`, а `post_restore` —
   `layouts.apply(last_active)`. Off-scope для первой итерации.

7. **`pinned` views и стартовое состояние**. Если `pinned = true`
   для Neo-Tree filesystem, то при старте Neovim edgebar будет
   видим даже без явного `:Neotree`. Это может быть удобно (как
   автостарт), но может раздражать (всегда тратится место). Решаем
   на Этапе 2 после собственного теста.

8. **`vim.opt.laststatus = 3`**. Уже стоит у тебя в `options.lua`?
   Если стоит `2` (per-window statusline) и lualine это любит — при
   `3` lualine просто покажет один statusline снизу, ничего не
   ломается, но визуал меняется. Проверить на Этапе 1.

## 13. Definition of Done

Минимальный «работает»:

- `:lua require("ide.layouts").apply("debug")` открывает Neo-Tree
  слева, DapView справа, DAP Console снизу. Без ошибок.
  Основное окно с кодом остаётся видно.
- `:lua require("ide.layouts").apply("code")` закрывает все edgebars.
- `<leader>p{c,f,g,d,t,s,j}` работают.
- `<leader>e]` / `<leader>e[` переключают группы (= «слои») в edge.
- `:EdgyGroupSelect` показывает picker.
- Старые `<leader>m*` биндинги работают как раньше.

После Этапа 7:

- `panels.lua` удалён.
- `QUICKSTART.md` обновлён.

---

## TL;DR

```
nvim_forge/lua/plugins/edgy.lua        -- ~150 LoC: views для всех плагинов
nvim_forge/lua/plugins/edgy-group.lua  -- ~30 LoC: groups для каждого edge
nvim_forge/lua/ide/layouts.lua         -- ~40 LoC: пресеты + apply/select
nvim_forge/lua/config/keymaps.lua      -- +30 LoC: <leader>p* и <leader>e*
nvim_forge/lua/config/options.lua      -- +2 LoC: laststatus=3, splitkeep=screen
```

Старый `panels.lua` живёт рядом, миграция отдельным этапом. Чистая
дельта по коду после уборки: **−350 LoC**.
