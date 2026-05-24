# DEBUG_JOURNEY

Журнал нетривиальных багов и их исправлений в `nvim_forge` конфиге.
Каждая запись — отдельная история «что было — что сделали — почему
именно так». Материал растёт по мере того, как мы решаем настоящие
проблемы; пишется в первую очередь для самого себя через полгода, и
во вторую — как заготовка для постов.

Содержание:

- [1. Rust + codelldb: `println!` теряется в Debug Console (Windows)](#1-rust--codelldb-println-теряется-в-debug-console-windows)

---

## 1. Rust + codelldb: `println!` теряется в Debug Console (Windows)

**Когда:** при дебаге Rust-проекта на Windows внизу panel'и пусто или
обрезан вывод. До первого `println!` пусто, а на втором запуске
вообще ничего не приходит. На Linux/macOS тех же симптомов нет.

### Симптомы

Программа:

```rust
fn main() {
    println!("shit!");
    let mut a = 5 + 5;
    let b = a + 4;
    println!("{}", b);
    a += 12;
    println!("some shit!!!");
}
```

Bottom panel показывала:

```
14
some shit!!!
```

— первый `println!` съеден. На втором F5 panel пустая полностью.

### Окружение

- Neovim 0.11 на Windows 10/11 (msys64).
- `nvim-dap` (mfussenegger).
- `nvim-dap-ui` (rcarriga) для sidebar Variables/Watch/Call Stack/Breakpoints.
- `edgy.nvim` (folke) как window manager — кладёт tool-окна в left/
  right/bottom edgebar.
- `codelldb` как DAP-адаптер для Rust.
- Раньше у нас на тех же тестах всё работало (см. git
  `c3fc6fb`) — но в той конфигурации был `nvim-dap-view`, а не
  `nvim-dap-ui`, и не было `edgy`.

### Корни проблемы

Их оказалось три, и они складывались.

#### Корень №1: `terminal_win_cmd` без `winnr`

`nvim-dap-ui` в `lua/dapui/elements/console.lua` ставит:

```lua
dap.defaults.fallback.terminal_win_cmd = get_buf
```

где `get_buf` — closure, возвращающая **только bufnr** (без winnr).
В `nvim-dap/lua/dap/session.lua` это значит:

```lua
buf, terminal_win = create_terminal_buf(win_cmd, config)
-- terminal_win == nil
```

И дальше:

```lua
vim.api.nvim_buf_call(terminal_buf, function()
    termopen(args, {
        ...
        height = terminal_win and api.nvim_win_get_height(terminal_win)
                                or math.ceil(vim.o.lines / 2),
        width  = terminal_win and api.nvim_win_get_width(terminal_win)
                                or vim.o.columns,
        term   = true,
    })
end)
```

На Windows запуск ConPTY без живого окна (через `nvim_buf_call`
вместо открытого split'а) — это известная категория багов: ранние
байты stdout debuggee теряются, потому что PTY ещё не зарегистрирован
в основном цикле UI. Первый `println!` улетает в никуда.

В старом конфиге (`nvim-dap-view`) этого не было: dap-view вообще не
трогал `terminal_win_cmd`, использовался дефолтный
`'belowright new'` — он **сначала** открывает новое окно с новым
буфером, **потом** `termopen` происходит уже с живым `winnr`. ConPTY
получал корректный размер и привязку к окну с первой же миллисекунды.

#### Корень №2: pool переиспользуемых терминал-буферов

В `nvim-dap/lua/dap/session.lua`:

```lua
local terminals = {}
do
  local pool = {}

  function terminals.acquire(win_cmd, config, filetype)
    local buf = next(pool)
    if buf then
      pool[buf] = nil
      if api.nvim_buf_is_valid(buf) then
        vim.bo[buf].modified = false
        return buf       -- ⚠ возврат RECYCLED bufnr, минуя win_cmd
      end
    end
    ...
    buf, terminal_win = create_terminal_buf(win_cmd, config)
    ...
  end

  function terminals.release(b) pool[b] = true end
end
```

То есть на **второй** debug-сессии `terminals.acquire` отдаёт
recycled буфер из пула **напрямую**, не вызывая наш
`terminal_win_cmd` вообще. Любой workaround, который мы пытаемся
сделать в `terminal_win_cmd`, на втором запуске не отрабатывает.

Плюс: `termopen` на уже-terminal-mode буфере, у которого был
завершённый job, на Windows ведёт себя нестабильно — новый job
прикручивается «поверх» старого, и output теряется молча.

#### Корень №3: попытка чинить «правильно» через listener — adapter timeout

Первая попытка фикса была:

```lua
-- delete dapui_console buf перед каждым launch
local function reset_dapui_console_buf()
    local b = require("dapui").elements.console.buffer()
    vim.api.nvim_buf_delete(b, { force = true })
end
dap.listeners.before.launch.console_reset = reset_dapui_console_buf
```

Идея была: убить buf до старта — инвалидируется pool-entry, на
следующем `terminals.acquire` сваливаемся в fallback и вызываем
`terminal_win_cmd`.

Но `dap.listeners.before.launch` выполняется **синхронно**, прямо
внутри callback'а обработки RPC-сообщения от адаптера.
`nvim_buf_delete` каскадно фиатит `force_buffers` autocmd у dap-ui,
тот лазит по окнам и делает `set_current_buf`. Вся эта мешанина
происходит посреди обработки сообщения адаптера → следующий пакет
адаптера разбирается с задержкой → срабатывает таймаут
`Debug adapter didn't respond` на 5 секунд.

Урок: **никогда не дёргать UI каскад внутри `dap.listeners`** —
эти listener'ы реагируют на трафик с адаптером в real-time.

#### Корень №4 (попутно): `vim.cmd("redraw")` внутри `terminal_win_cmd`

Думал, что redraw до termopen «дотянет» edgy ресайз и termopen
возьмёт стабильные width/height. На самом деле `terminal_win_cmd`
тоже вызывается синхронно из обработчика RPC-сообщения
`runInTerminal`. Redraw там же делает всё хуже: триггерит
CursorMoved/WinScrolled/etc., которые пытаются работать с окнами,
которые ещё не до конца созданы. Adapter timeout снова. Убрал.

### Решение

Перешли на собственный terminal-канал, точно копирующий поведение
старого `nvim-dap-view` setup'а:

#### Шаг 1. Свой `terminal_win_cmd`

`nvim_forge/lua/plugins/dap.lua`:

```lua
local _last_dap_terminal_buf = -1

local function dap_terminal_win_cmd(_config)
    if vim.api.nvim_buf_is_valid(_last_dap_terminal_buf) then
        pcall(vim.api.nvim_buf_delete, _last_dap_terminal_buf, { force = true })
    end

    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].filetype = "dap-terminal"
    vim.bo[buf].buflisted = false
    _last_dap_terminal_buf = buf

    local current_win = vim.api.nvim_get_current_win()
    pcall(vim.cmd, "botright sbuffer " .. buf)
    local win = vim.api.nvim_get_current_win()
    if vim.api.nvim_win_is_valid(current_win) and current_win ~= win then
        pcall(vim.api.nvim_set_current_win, current_win)
    end
    return buf, win
end

-- Перезаписываем dap-ui's set:
dap.defaults.fallback.terminal_win_cmd = dap_terminal_win_cmd
```

Каждый вызов:

- создаёт **свежий** scratch-buffer (`nvim_create_buf(false, true)` —
  unlisted, scratch);
- ставит `filetype = "dap-terminal"` ДО открытия окна, чтобы edgy
  поймал его на `BufWinEnter` и положил в bottom edgebar
  (см. `plugins/edgy.lua → bottom views`);
- открывает реальный split через `:botright sbuffer N`;
- возвращает `(buf, winnr)` — оба живые, ConPTY стартует корректно;
- фокус возвращает в исходное окно, чтобы курсор не уехал из кода.

#### Шаг 2. Инвалидация pool-entry — но ДО `dap.run`, не в listener

```lua
local function reset_dap_terminal_buf()
    if vim.api.nvim_buf_is_valid(_last_dap_terminal_buf) then
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            if vim.api.nvim_win_is_valid(win)
                and vim.api.nvim_win_get_buf(win) == _last_dap_terminal_buf then
                pcall(vim.api.nvim_win_close, win, true)
            end
        end
        pcall(vim.api.nvim_buf_delete, _last_dap_terminal_buf, { force = true })
    end
    _last_dap_terminal_buf = -1
end

local function run_debug_choice(dap_mod, choice)
    local cfg = choice.config
    if not cfg then return end
    open_debug_for_config(cfg)
    if type(cfg) == "table" and cfg.type == "codelldb" then
        reset_dap_terminal_buf()  -- ← здесь, ДО dap.run
    end
    run_config(dap_mod, cfg)
end
```

Ключевое: `reset_dap_terminal_buf()` зовётся **в нашем коде**, до
`dap.run`. Мы не в RPC-callback, no adapter timeout. Старый buf
прибит, его pool-entry в nvim-dap станет невалидным
(`nvim_buf_is_valid → false`) на следующем
`terminals.acquire` → fallthrough → `create_terminal_buf` →
наш `dap_terminal_win_cmd` → свежий buf+win.

Поведение в итоге: каждый F5 на Rust = новый PTY-buffer, новое
окно, новый ConPTY. **Никаких pool-сюрпризов.**

#### Шаг 3. Edgy ловит `dap-terminal` filetype

`nvim_forge/lua/plugins/edgy.lua`:

```lua
bottom = {
    ...
    {
        title = "DAP Terminal",
        ft = "dap-terminal",
        size = { height = 0.30 },
        pinned = false,
    },
    ...
},
```

Плюс `dap-terminal` добавлен в `TOOL_FILETYPES`, чтобы `buflisted=false`
автоматически (не торчит в bufferline как обычный файл).

#### Шаг 4. ide-component `dap.terminal`

`nvim_forge/lua/ide/init.lua`:

```lua
{
    id = "dap.terminal", slot = "bottom", title = "DAP Terminal",
    filetypes = { "dap-terminal" },
    open = function() --[[ пассивный: окно создаёт terminal_win_cmd ]] end,
    close = function() --[[ закрыть окно с ft=dap-terminal ]] end,
    is_open = function() return any_window_with_ft("dap-terminal") end,
},
```

И debug-layout:

```lua
debug = { left = "dap.sidebar", right = nil, bottom = "dap.terminal" },
```

Для Go (delve, internalConsole) и Python (debugpy, internalConsole)
output идёт через DAP `output` events → `dap-repl`. Их `section_for_config`
возвращает `"repl"` и они получают `ide.show("dap.repl")` в bottom.

#### Шаг 5. `show_debug_section("terminal", false)` — не открывает bottom

```lua
elseif section == "terminal" then
    -- НЕ открываем сами dap.terminal — окно создаётся нашим
    -- dap_terminal_win_cmd когда codelldb пришлёт runInTerminal.
    -- Закрываем предыдущий bottom (на случай Go/Python repl от
    -- прошлой сессии).
    require("ide").hide_slot("bottom")
end
```

Это важно. Если бы мы тут сами вызывали `ide.show("dap.terminal")`,
то компонент попытался бы открыть пустой буфер БЕЗ `termopen`, и при
последующем `runInTerminal`-запросе у нас бы оказалось два окна с
`dap-terminal` — конфликт с edgy.

### Финальная архитектура

| Адаптер   | `console=...`         | bottom-секция                  | Канал output       |
|-----------|-----------------------|--------------------------------|---------------------|
| codelldb  | `integratedTerminal`  | `dap.terminal` (наш свежий)    | runInTerminal → PTY |
| delve     | `internalConsole`     | `dap.repl`                     | DAP output events   |
| debugpy   | `internalConsole`     | `dap.repl`                     | DAP output events   |
| любой adapter с `console="integratedTerminal"` в `.vscode/launch.json` | `integratedTerminal` | `dap.terminal` | runInTerminal → PTY |

`dap-ui`'s sidebar (scopes/watches/stacks/breakpoints) работает как
обычно — это `dapui.open({layout=1})` в left edgebar. Мы заменили
ТОЛЬКО bottom canvas, не трогая VS Code-style multi-panel sidebar.

### Что попутно стало понятно

1. **`dap.listeners.before.*` — это горячий путь.** Любая тяжёлая
   операция (UI, file IO, buffer manipulation) здесь приводит к
   adapter timeout. Только лёгкие вещи: `dap.repl.clear()`, флаги,
   мелкие сохранения state.

2. **`vim.cmd("redraw")` нельзя дёргать в callback'ах RPC-сообщений.**
   Та же причина: каскад autocmd блокирует трафик с адаптером.

3. **Pool nvim-dap агрессивно переиспользует buffer'ы.** Если задача
   — иметь свежий PTY на каждую сессию, недостаточно сделать свой
   `terminal_win_cmd` — нужно ещё гарантировать, что pool-entry
   инвалидирован к следующему `terminals.acquire`.

4. **edgy.nvim прекрасно ловит filetype-based views даже у
   terminal-буферов.** Если на момент `:botright sbuffer N` буфер
   уже имеет нужный filetype, edgy переносит окно в edgebar
   синхронно через свой `BufWinEnter` autocmd. С terminal mode это
   совместимо.

5. **VS Code-style «свежий Debug Console на каждую сессию»** —
   правильный default. Post-mortem output старой сессии остаётся
   видимым до момента следующего F5, а потом плавно заменяется
   новым окном.

### Файлы, затронутые фиксом

- `nvim_forge/lua/plugins/dap.lua` — `dap_terminal_win_cmd`,
  `reset_dap_terminal_buf`, вызов из `run_debug_choice` и
  `dap_pick_any`; `section_for_config` теперь возвращает
  `"terminal"` для codelldb.
- `nvim_forge/lua/plugins/edgy.lua` — view для `dap-terminal` в
  bottom, добавление в `TOOL_FILETYPES`.
- `nvim_forge/lua/ide/init.lua` — компонент `dap.terminal`,
  layout `debug` → `bottom = "dap.terminal"`.
- `nvim_forge/lua/config/panels.lua` — ветка `section == "terminal"`
  в `show_debug_section` (закрываем старый bottom, новый не
  открываем).

### Тесты, которые покрывают

Ручные acceptance (нет автоматизации):

1. F5 на свежем `main.rs` со `println!` × 3 → видны все три строки.
2. Прибить через `<S-F5>`, повторно F5 → новое окно DAP Terminal,
   снова видны все три строки.
3. F5 на Python-скрипте с `print()` → output идёт в DAP REPL (как
   раньше), не в DAP Terminal.
4. F5 на Go-программе с `fmt.Println` → output в DAP REPL.
5. `:IdeStatus` после старта Rust-сессии → `bottom: dap.terminal`.
6. `<leader>Pb` циклит bottom между `dap.terminal`, `dap.repl`,
   `dap.console`, `tasks_output`, `tests_output`, `search`,
   `trouble`, `qf`, `terminal`.

---
