# Panels framework — план v2 (edgy + наш state-layer)

Статус: **готов к работе**. Старая редакция в `PANELS_PLAN_V1.md`.

> Изменения от v1: убран `edgy-group.nvim`, добавлен собственный
> state-layer (`lua/ide/state.lua` + `lua/ide/registry.lua`),
> расширены компоненты под VS Code spec, добавлены Outline /
> Terminal / "No files"-заглушка, обработка Diffview как
> editor-buffer.

## 1. Что такое edgy-group и почему уходим

**`edgy.nvim`** (folke) — это window manager. Он перехватывает окна
с заданными filetypes и кладёт их в один из edgebar'ов
(left/right/bottom/top). По умолчанию edgy показывает views
**accordion-style** — если в left edgebar три views, ты видишь все
три (свёрнутые/раскрытые блоки).

**`edgy-group.nvim`** (lucobellic) — это надстройка над edgy.
Добавляет понятие "**группа**": views с одним `pick_key` показываются
вместе, остальные группы спрятаны. Cycle между группами через
`EdgyGroupNext/Prev/Select`.

Проблемы edgy-group, с которыми мы столкнулись на v1:

1. **`open_groups_by_key` не открывает views с нуля** — только
   переключает между **уже созданными** окнами. Если DapView /
   Overseer / GrugFar никогда не запускались — переключение
   ничего не делает. Пришлось в `layouts.apply` дёргать прямые
   open-команды плагинов. Edgy-group в `apply` фактически не
   участвовал.
2. **Дополнительный слой**, конфигурация через `pick_key` +
   `titles`, ещё одна точка синхронизации, ещё один источник
   путаницы.
3. **Не даёт нам гарантий FSM** — нет понятия "main editor",
   "никогда не закрываем code window", "open file from explorer
   идёт в main".

Поэтому в v2 пишем **свой тонкий state-layer** поверх edgy. edgy
остаётся для window placement / animations / sizing. Наш слой
держит FSM и инварианты.

## 2. VS Code-style spec → forge mapping

Пользователь хочет VS Code-подобный UX:

### 2.1 Слева (Primary Sidebar)

| VS Code activity     | forge component       | Источник                                  | Статус         |
|----------------------|-----------------------|-------------------------------------------|----------------|
| File Explorer        | `explorer`            | `Neotree filesystem reveal left`          | есть           |
| Buffers              | `buffers`             | `Neotree buffers reveal left`             | есть           |
| Git file marks       | `git_status`          | `Neotree git_status reveal left`          | есть           |
| Outline (symbols)    | `outline`             | `AerialOpen left`                         | **активировать** (aerial в lock есть, spec нет) |
| Timeline (file history) | `timeline`         | `DiffviewFileHistory %`                   | **новый wrapper** |
| Run & Debug          | `debug.sidebar`       | DapView в left position                   | **переконфигурировать DapView** |
| Tests                | `tests`               | `require('neotest').summary.open()`       | есть (сейчас справа) |
| Search               | `search`              | оставляем снизу (grug-far)                | есть, не двигаем |
| Git (status overview)| `neogit.split`        | `Neogit kind=split`                       | есть           |

### 2.2 Справа (Secondary Sidebar)

Опционально. По умолчанию — пусто. Можно повесить туда `outline`
или `tests`, если пользователь захочет два sidebar'а одновременно
(VS Code разрешает Primary + Secondary).

В v2 справа держим:
- `tests` — пока оставляем тут, потом юзер решит, переносить ли влево.
- `neogit.split` — Git status panel, если нужен наряду с git_status в neo-tree.

### 2.3 Снизу (Panel)

| VS Code panel    | forge component       | Источник                                  | Статус         |
|------------------|-----------------------|-------------------------------------------|----------------|
| Problems         | `trouble`             | `Trouble diagnostics`                     | **активировать spec** |
| Output           | `tasks_output`        | `Overseer` task output                    | есть (через `OverseerOpen`) |
| Debug Console    | `dap.console`         | `DapViewShow console`                     | есть           |
| Debug REPL       | `dap.repl`            | `DapViewShow repl` или native `dap-repl`  | есть           |
| Terminal         | `terminal`            | **`akinsho/toggleterm.nvim`**             | **новый плагин**  |
| Search           | `search`              | `GrugFar`                                 | есть           |
| Test Output      | `tests_output`        | `require('neotest').output_panel.open()`  | есть           |
| Quickfix         | `quickfix`            | `:copen`                                  | есть           |

### 2.4 Editor Group (центр)

**Главное правило**: editor group **никогда не закрывается** state
machine'ой. Diff'ы / Git Graph / любые "центральные" виртуальные
buffer'ы попадают сюда как обычные buffers с `:edit`.

Что должно идти в editor group:
- **Diff файлов** (Diffview) — `:DiffviewOpen` открывает в текущем
  табе с собственным layout. Должно НЕ захватываться edgy.
- **Git Graph** — `:Neogit log` (или плагин `isakbm/gitgraph.nvim`)
  открывает full-screen graph buffer.
- **Neogit kind=tab** — открывается в отдельном tabpage, тоже не
  edgy-managed.

Реализация:
- В `plugins/edgy.lua` явно `filter`'ом отсеять Diffview/Neogit
  tab буферы (`vim.b[buf].edgy_disable = true` через autocmd по
  ft).

### 2.5 "No files" — заглушка

Когда последний обычный code-buffer закрыт, не оставаться с
безымянным "Noname" буфером. Открыть **alpha.nvim** start screen
(в forge уже настроен в `plugins/start.lua`).

Точка интервенции: функция `close_buffer` в `lua/config/keymaps.lua`
(она уже умеет искать альтернативный буфер). Заменяем алгоритм:

```
close_buffer(force):
  alt = find_listed_code_buffer_other_than(current)
  if alt:
    switch all windows showing current → alt
    bdelete current
  else:
    -- последний code-буфер; не создаём scratch, открываем alpha
    require("alpha").start(false)
    bdelete current
```

## 3. Архитектура

### 3.1 Модули

```
nvim_forge/lua/ide/
├── registry.lua    -- реестр компонентов: id → spec
├── state.lua       -- FSM: текущее состояние, transitions, инварианты
├── layouts.lua     -- именованные пресеты поверх state
├── empty.lua       -- "no code files" → alpha fallback
├── ui.lua          -- (опц.) Activity Bar в edgy winbar; пока stub
└── init.lua        -- setup(), реэкспорт API
```

### 3.2 Типы

```lua
---@class ide.Component
---@field id        string              -- "explorer", "outline", "dap.console"
---@field slot      "left"|"right"|"bottom"
---@field title     string              -- человекочитаемое имя
---@field open      fun()               -- открыть компонент
---@field close     fun()               -- закрыть (если открыт)
---@field is_open   fun(): boolean
---@field focus?    fun()               -- сфокусироваться (default: find window by ft)
---@field filetypes? string[]           -- для edgy filter и is_open fallback
---@field icon?     string              -- иконка для Activity Bar

---@class ide.Layout
---@field left?    string|nil           -- component id, либо nil
---@field right?   string|nil
---@field bottom?  string|nil

---@class ide.State
---@field slots       table<string, string|nil>  -- slot → active component id
---@field layout      string|nil                  -- last applied layout name
---@field components  table<string, ide.Component>
---@field layouts     table<string, ide.Layout>
```

### 3.3 API

```lua
local ide = require("ide")

-- Registration (вызывается из plugins/* через VeryLazy hook)
ide.register_component({ id = "explorer", slot = "left", title = "Explorer",
                          open = ..., close = ..., is_open = ... })
ide.register_layout("debug", { left = "explorer", right = nil, bottom = "dap.console" })

-- Transitions (для биндингов и команд)
ide.show(id)              -- открыть компонент в его слоте, закрыть прежний
ide.hide(id)              -- закрыть конкретный компонент
ide.hide_slot(slot)       -- закрыть активный в слоте
ide.toggle(id)            -- show/hide
ide.cycle(slot, dir)      -- следующий/предыдущий в группе слота
ide.apply_layout(name)    -- атомарная смена layout
ide.focus_main()          -- курсор → editor group
ide.focus_slot(slot)      -- курсор → компонент в слоте
ide.current()             -- { slots, layout }

-- Helper
ide.is_main_window(win)   -- true если win — editor group
ide.find_main_window()    -- nvim_win_id of main; nil если только tools
```

### 3.4 Инварианты

1. **Editor group существует всегда**. `ide.find_main_window()`
   возвращает window id или создаёт новое (через `:enew`).
2. В каждом слоте **ровно один** компонент visible или nil.
3. После любого transition: `ide.current()` соответствует реальному
   состоянию окон.
4. `apply_layout(L)` идемпотентна: вызов с тем же L дважды подряд
   не должен ничего менять (после первого вызова).
5. `open_file_from_explorer(path)`: файл уходит в editor group.
   Если editor group занят tool-окном (не должно случаться, но
   защищаемся) — создаём split в основном направлении.

## 4. Каталог компонентов

### 4.1 Готовы к регистрации (уже есть в forge)

| id              | slot   | filetype(s)              | open                                            |
|-----------------|--------|--------------------------|-------------------------------------------------|
| `explorer`      | left   | `neo-tree` + filter      | `Neotree filesystem reveal left`                |
| `buffers`       | left   | `neo-tree` + filter      | `Neotree buffers reveal left`                   |
| `git_status`    | left   | `neo-tree` + filter      | `Neotree git_status reveal left`                |
| `tests`         | right  | `neotest-summary`        | `require'neotest'.summary.open()`               |
| `neogit.split`  | right  | `NeogitStatus`           | `require'neogit'.open({ kind = 'split' })`      |
| `dap.console`   | bottom | `dap-view-term`          | `DapViewOpen` + ensure section console          |
| `dap.repl`      | bottom | `dap-repl` / `dap-view`  | `DapViewOpen` + `DapViewShow repl`              |
| `tasks_output`  | bottom | `OverseerList`           | `OverseerOpen bottom`                           |
| `tests_output`  | bottom | `neotest-output-panel`   | `require'neotest'.output_panel.open()`          |
| `search`        | bottom | `grug-far`               | `GrugFar`                                       |
| `trouble`       | bottom | `trouble`                | `Trouble diagnostics`                           |
| `quickfix`      | bottom | `qf`                     | `copen`                                         |

### 4.2 Нужно добавить

| id              | slot   | плагин                                              | оценка трудозатрат |
|-----------------|--------|-----------------------------------------------------|---------------------|
| `outline`       | left   | **активировать `aerial.nvim`** (уже в lock)         | 10 минут            |
| `timeline`      | left   | через `Diffview` (`DiffviewFileHistory %`)          | 20 минут (wrapper)  |
| `terminal`      | bottom | **новый `akinsho/toggleterm.nvim`**                  | 30 минут            |
| `debug.sidebar` | left   | конфиг DapView с `position = "left"` для секций scopes/breakpoints/stacks/watches | 1 час (нетривиально) |
| `git_graph`     | center | опц. `isakbm/gitgraph.nvim` или `neogit log`        | 30 минут            |

### 4.3 Зачем `debug.sidebar` отдельно

В VS Code "Run and Debug" — это **сайдбар слева**. У нас сейчас
DapView идёт **снизу** одним монолитом со всеми секциями. Чтобы
повторить VS Code UX:

- Конфиг DapView: `windows.position = "left"` для секций
  scopes/breakpoints/stacks/watches (Variables/Watch/Call Stack/
  Breakpoints в VS Code).
- Секции console/repl/terminal остаются **снизу**.

В DapView это управляется в `nvim_forge/lua/plugins/dap.lua`
(строка 1437: `windows.position = "below"`). Нужно вытащить часть
секций в отдельный split.

Альтернатива: оставить DapView снизу как есть, и не воспроизводить
VS Code 1-в-1. Простее, и пользователь сказал "по смыслу", не "буква
в букву". Решаем на месте.

## 5. Default layouts

| Layout    | left            | right            | bottom            |
|-----------|-----------------|------------------|-------------------|
| `code`    | nil             | nil              | nil               |
| `files`   | `explorer`      | nil              | nil               |
| `outline` | `outline`       | nil              | nil               |
| `git`     | `git_status`    | `neogit.split`   | nil               |
| `timeline`| `timeline`      | nil              | nil               |
| `debug`   | `debug.sidebar` (или `explorer`) | nil | `dap.console` |
| `tests`   | `explorer`      | `tests`          | `tests_output`    |
| `search`  | nil             | nil              | `search`          |
| `jobs`    | nil             | nil              | `tasks_output`    |
| `trouble` | nil             | nil              | `trouble`         |
| `term`    | nil             | nil              | `terminal`        |

## 6. Биндинги

### 6.1 Layouts

```
<leader>pp    layouts.select() (vim.ui.select)
<leader>pc    apply "code"
<leader>pf    apply "files"
<leader>po    apply "outline"
<leader>pg    apply "git"
<leader>pl    apply "timeline"
<leader>pd    apply "debug"
<leader>pt    apply "tests"
<leader>ps    apply "search"
<leader>pj    apply "jobs"
<leader>px    apply "trouble"
<leader>pT    apply "term"
<leader>pq    apply "code" (= close all)
```

### 6.2 State control

```
<leader>P1..9      focus_slot by component index в bottom (cycle через group)
<leader>Pl / Ph    cycle next/prev в left
<leader>Pr / PR    cycle next/prev в right
<leader>Pb / PB    cycle next/prev в bottom
<leader>P0         focus_main()
<leader>PL/PK/PJ   hide_slot left/right/bottom
```

### 6.3 Per-component direct toggles

```
<leader>e          toggle explorer (как сейчас)
<leader>E          reveal explorer
<C-`>              toggle terminal (toggleterm default)
```

## 7. Этапы реализации (на завтра)

### Этап 0 — Подготовка (10 минут)

- Проверить, что v1 `plugins/edgy-group.lua` можно безопасно
  удалить. Удалить.
- Проверить, что `plugins/edgy.lua` существует (после v1 он есть).

### Этап 1 — Новые плагины (~40 минут)

- `plugins/outline.lua`: spec для `stevearc/aerial.nvim` + `:AerialOpen left`.
- `plugins/terminal.lua`: spec для `akinsho/toggleterm.nvim`.
- (опц.) `plugins/git-graph.lua`: spec для `isakbm/gitgraph.nvim`.
- Запустить `:Lazy sync`, убедиться, что все три (или два)
  плагина встали.
- Smoke: `:AerialOpen left` / `:ToggleTerm` работают.

### Этап 2 — `lua/ide/registry.lua` (~30 минут)

- Простой реестр: `register_component(spec)`, `get(id)`,
  `list(slot?)`. Один файл, ~50 LoC.
- Никакой логики window manipulation тут нет.

### Этап 3 — `lua/ide/state.lua` (~1.5 часа, ключевой)

- FSM (см. §3.2-3.4).
- `show`, `hide`, `toggle`, `cycle`, `apply_layout`,
  `focus_main`, `focus_slot`, `current`, `find_main_window`,
  `is_main_window`.
- Инварианты enforced в каждом transition.
- `find_main_window`: ищем window с `vim.b[buf].edgy_disable ~= true`
  и `buftype == ""`. Если нет — `:enew` создаёт.

### Этап 4 — `lua/ide/layouts.lua` (~20 минут, упрощённый)

- Тонкий wrapper: `register_layout(name, def)`, `apply(name)`,
  `select()`. Всё ложится поверх `state.show` / `state.hide_slot`.
- Без своих open-команд (в отличие от v1) — это уже в registry.

### Этап 5 — `lua/ide/empty.lua` (~20 минут)

- `is_only_code_buffer()` helper.
- `replace_with_alpha()`: открыть alpha-nvim screen в main window.
- `close_buffer_safe(force)`: новая версия для keymaps.lua.

### Этап 6 — `lua/ide/init.lua` (~20 минут)

- `setup({ components = {...}, layouts = {...} })`.
- Регистрирует все компоненты из §4.1-4.2.
- Регистрирует все layouts из §5.
- Вызывается из `nvim_forge/init.lua` после `require("config.lazy")`
  (или через VeryLazy hook).

### Этап 7 — Перепись keymaps (~30 минут)

- `lua/config/keymaps.lua`: блок `<leader>p*` / `<leader>P*`
  переходит на `require("ide")` API.
- `close_buffer` → использует `ide.empty.close_buffer_safe`.
- Старые `<leader>m*` оставляем в `panels.lua` как тонкие
  алиасы на `ide.apply_layout(...)` (для backwards-compat).

### Этап 8 — `plugins/edgy.lua` пересмотр (~30 минут)

- Убрать комментарии про edgy-group (его больше нет).
- Добавить view для `aerial`, `toggleterm`, `outline` aliases.
- **Diffview filter**: для buffers с `ft = "DiffviewFiles"` /
  `ft = "DiffviewFileHistory"` устанавливаем `vim.b.edgy_disable = true`
  через autocmd, чтобы они шли в editor group, а не в edgebar.
- Аналогично для `NeogitLog` (если используем neogit log как git
  graph).

### Этап 9 — Smoke + valid checks (~30 минут)

- DoD из §10.
- Reload nvim_forge.cmd, прогнать каждый layout.
- Особое внимание:
  - `<leader>pf` → explorer слева, файл по клику открывается в main.
  - `<leader>pd` → debug sidebar/console.
  - Закрыть последний файл → alpha screen, не Noname.
  - `:DiffviewOpen` → diff в main, не в edgebar.

### Этап 10 — Cleanup (опционально, отдельно)

- Удалить `lua/config/panels.lua`.
- Из `keymaps.lua` убрать `<leader>m*` или оставить как алиасы.

**Суммарно**: ~5 часов чистого времени, реально 6-7 с тестами и
правками.

## 8. Открытые вопросы

### 8.1 DapView секции — split в left или всё в bottom?

VS Code: Variables/Watch/Call Stack/Breakpoints **слева**, Debug
Console **снизу**. У нас DapView объединяет всё в одном split'е
снизу со своим winbar для переключения секций.

Варианты:
- **(a)** Оставить DapView как монолит снизу, не делать
  `debug.sidebar`. Простое, работает.
- **(b)** Переконфигурировать DapView: vars/watch/stacks/breakpoints
  → `position = "left"`, console/repl → `position = "below"`.
  Сложнее, но ближе к VS Code.

Решаем в Этапе 1 — попробуем `(b)`, если в DapView это не делается
одним config-полем, откатываемся на `(a)`.

### 8.2 Outline через aerial — отдельная ли вкладка слева?

В VS Code Outline — отдельная activity. У нас два варианта:
- Зарегистрировать `outline` как отдельный компонент с `slot =
  "left"` — переключение между explorer/outline через cycle.
- Сделать `outline` в `slot = "right"` — два sidebar'а одновременно.

Решение: **`slot = "left"`** (VS Code-style: одна activity видна).
Cycle переключает.

### 8.3 Persistence layouts между сессиями?

Off-scope для v2 первой реализации. Когда понадобится:
- `auto-session` pre-save callback → `ide.apply_layout("code")` +
  `vim.g.ide_last_layout = ide.current().layout`.
- post-restore → `ide.apply_layout(vim.g.ide_last_layout)`.

### 8.4 Activity Bar UI

Опционально. Это иконки в edgy winbar или в lualine, показывающие
все доступные компоненты слота с подсветкой активного. Не делаем в
первой реализации — для v2 достаточно `<leader>p*` биндингов.

Если потом захотим — `lua/ide/ui.lua` ~ 80 LoC heirline-style
provider.

### 8.5 Git Graph

`isakbm/gitgraph.nvim` — лёгкий, активный. Альтернатива — `:Neogit
log`. Решение: **сначала пробуем Neogit log** (нулевая зависимость),
если не нравится визуал — добавляем `gitgraph.nvim`.

## 9. Risk register

- **DapView windows.position split** (§8.1) — может не делиться
  чисто. Если так — оставляем монолит снизу.
- **Diffview edgy_disable** — Diffview сам создаёт несколько окон
  в layout'е. Все должны быть not-edgy. Тестируем на Этапе 8.
- **toggleterm как новый плагин** — может конфликтовать с tasks.lua
  (overseer тоже терминал). Проверяем filetype'ы не пересекаются.
- **aerial spec missing** — он сейчас в lock как сирота. Нужно
  убедиться, что наш spec корректен. Stevearc обычно ничего не
  ломает.
- **alpha как fallback** — при `close_buffer` в момент когда уже
  нет main, `require("alpha").start(false)` может не справиться.
  Защищаем pcall'ом.

## 10. Definition of Done

После всех 9 этапов:

- [ ] `:lua require("ide").apply_layout("debug")` → explorer (или
      debug.sidebar) слева, dap.console снизу, всё видно. Без
      ошибок.
- [ ] `<leader>pp` → picker, выбор любого пресета работает.
- [ ] Закрыть последний обычный buffer (`<leader>bd`) → alpha
      screen. **НЕ** Noname.
- [ ] Открыть файл из NeoTree → файл попадает в editor group.
- [ ] `:DiffviewOpen` → diff виден в editor group, не в edgebar.
- [ ] `:Neogit log` (или git graph) → открывается в editor group.
- [ ] `<leader>pT` → terminal внизу через toggleterm.
- [ ] `<leader>po` → aerial слева как outline.
- [ ] `<leader>P0` → курсор в editor.
- [ ] Старые `<leader>m*` всё ещё работают как алиасы.

## 11. TL;DR

```
plugins/outline.lua             -- spec aerial.nvim         (новый, ~20 LoC)
plugins/terminal.lua            -- spec toggleterm.nvim     (новый, ~40 LoC)
plugins/edgy.lua                -- обновление + Diffview filter
plugins/edgy-group.lua          -- удалить
ide/registry.lua                -- реестр компонентов       (~50 LoC)
ide/state.lua                   -- FSM, инварианты          (~250 LoC)
ide/layouts.lua                 -- пресеты, упрощённо       (~50 LoC)
ide/empty.lua                   -- alpha-fallback           (~50 LoC)
ide/init.lua                    -- setup, регистрация       (~80 LoC)
config/keymaps.lua              -- <leader>p* / <leader>P*  (~50 LoC доп.)
init.lua                        -- +1 строка: require("ide").setup{}
```

Около **600 LoC нового**, минус **~150 LoC** (старые `edgy-group.lua`
+ упрощение `layouts.lua` + куски `keymaps.lua`). Чистая дельта в
коде: **+450 LoC**.

Когда удалим `config/panels.lua` (Этап 10): **−800 LoC**, итого
**−350 LoC** в репо при существенно большем функционале.
