# Настройка дебага в Neovim — журнал эпизодов

Это пошаговая хроника того, как мы делали в этом nvim-конфиге
production-ready DAP-стек: какие были проблемы, что пробовали, к чему
в итоге пришли. Источник для серии постов/видео по теме
"настраиваем IDE в Neovim — про дебаг".

Каждый эпизод самостоятельный, можно превращать в отдельный пост.
Первые эпизоды короче (быстрые победы), к концу - глубже (отладка
выходных каналов, версионирование тулз).

Ключевые файлы конфига, на которые ссылаемся:

- `vim/nvim/lua/plugins/dap.lua` — ядро DAP, адаптеры, биндинги
- `vim/nvim/lua/plugins/tasks.lua` — overseer и шаблоны тасков
- `vim/nvim/lua/plugins/lsp.lua` — `mason-tool-installer`, пины тулз
- `vim/nvim/lua/config/panels.lua` — "режимы" UI (debug-mode и пр.)
- `vim/nvim/PANELS.md` — пользовательская документация по слотам/UI
- `D:/rust_repo/lab/.vscode/launch.json` — эталонный шаблон launch.json

---

## Эпизод 0 — Точка отсчёта: что у нас в стеке

**Контекст.** До этой серии у нас уже стоял базовый DAP-стек:

- `mfussenegger/nvim-dap` — клиент DAP (Debug Adapter Protocol)
- `igorlfs/nvim-dap-view` — единое UI: console / scopes / breakpoints
  / threads / watches / repl как секции одного окна
- `theHamsta/nvim-dap-virtual-text` — inline-значения переменных в коде
- `leoluz/nvim-dap-go` — обёртка над delve для Go
- `mfussenegger/nvim-dap-python` — обёртка над debugpy для Python
- `codelldb` — DAP-адаптер для Rust/C/C++ (без `rustaceanvim`)
- `stevearc/overseer.nvim` — task runner + интеграция с DAP через
  `preLaunchTask`

UI-обвязка живёт в `config/panels.lua`: режимы экрана (`mode_debug`,
`mode_tests`, `mode_search`, ...) переключают, какие tool-окна
открыты, и куда возвращать фокус. Подробнее в `PANELS.md`.

**Что работает изначально.** F5 запускает дебаг текущего файла.
Точки останова, шаг, watches, scopes, REPL — всё по нажатию клавиш.
Console-секция dap-view показывает stdout программы (для Rust).

**Что не работает / неудобно** (сюжет для следующих эпизодов):

1. F5 на `main.go` показывает picker с восемью вариантами
   ("Debug", "Debug Package", "Debug test", ...) — выбирать каждый
   раз вручную не то.
2. На разных репо запускать дебаг хочется **по-разному** (разные
   программы, аргументы, env), и это надо как-то конфигурировать
   локально под репо.
3. Запуск на чужой машине / с чужим конфигом ломает кросс-платформенно
   (разные пути компилятора, разные версии тулзовых бинарей).
4. Output-каналы (stdout vs DAP events) ведут себя по-разному в
   разных адаптерах — без стандартизации каждый язык как отдельный
   мир.

---

## Эпизод 1 — Per-project debug config через `.vscode/launch.json`

**Проблема.** F5 каждый раз спрашивает, какой режим запускать.
Нужен **репо-локальный** конфиг: вот в этом проекте `lab` мы дебажим
именно `target/debug/lab.exe` с такими-то аргументами и `cargo build`
перед запуском. В другом репо — другой конфиг.

**Идея.** Использовать формат, который и так понимает большинство IDE:
`.vscode/launch.json` от Visual Studio Code. Это уже стандарт de facto,
работает в VSCode, Cursor, JetBrains (через плагин), и `nvim-dap`
официально поддерживает его через `dap.ext.vscode`.

**Решение.** Свой `dap_continue` в `plugins/dap.lua`:

1. Если уже есть активная сессия — не запускаем новую, а продолжаем.
2. Иначе ищем `.vscode/launch.json` вверх от файла + в cwd.
3. Если нашёлся — фильтруем конфиги по filetype (карта `DAP_TYPE_TO_FILETYPES`).
4. Один подходящий конфиг — запускаем сразу.
5. Несколько — `vim.ui.select` выбор из них.
6. Не нашли launch.json вообще — fallback на дефолтный `dap.continue()`.

**Карта filetype** в `plugins/dap.lua`:

```lua
codelldb -> rust / c / cpp
go       -> go      (через nvim-dap-go, делегируется в delve)
debugpy  -> python  (синоним python)
node     -> javascript / typescript
```

**Эталонный launch.json** для проекта `lab` лежит в
`D:/rust_repo/lab/.vscode/launch.json`. Шаблоны для Rust, Go, Python.

**Что получили.** F5 на `main.rs` — сразу запускает `Rust: lab (debug bin)`.
F5 на `main.go` — сразу `Go: main.go`. Если в launch.json несколько
Rust-конфигов — picker только из них. В новом репо без launch.json —
старое поведение nvim-dap.

---

## Эпизод 2 — JSONC: nvim-dap не парсит реальные launch.json

**Проблема.** Реальные `launch.json` от VSCode почти всегда содержат
комментарии (`// `, `/* */`) и trailing commas. Стандартный
`vim.json.decode` валится на них. Встроенный парсер `nvim-dap`
тоже стрикт.

**Симптом.** Положили в репо реальный launch.json — F5 ругается на
синтаксис, конфиги не появляются.

**Решение.** Препроцессор `strip_jsonc` в `plugins/dap.lua`:

1. Удаляет `//`-комментарии до конца строки.
2. Удаляет `/* ... */` блочные комментарии.
3. Удаляет trailing commas перед `}` / `]`.
4. Уважает escape-последовательности и не лезет внутрь строк.

После препроцессора отдаём результат в
`dap.ext.vscode._load_json` — внутренняя функция nvim-dap, которая
дополнительно резолвит `inputs` (`${input:rustArgs}`) и OS-overrides
(`windows: { ... }`, `linux: { ... }`).

**Дополнительно.** Чтобы не было дублей — отключаем встроенный
provider:

```lua
dap.providers.configs["dap.launch.json"] = function() return {} end
```

Иначе nvim-dap пытается параллельно прочитать тот же launch.json
своим (стриктным) парсером и плодит ошибки.

**Что получили.** Любой реальный `.vscode/launch.json` (с комментариями,
с trailing commas, с inputs) парсится без проблем.

---

## Эпизод 3 — `tasks.json` vs overseer templates

**Контекст.** В launch.json часто стоит `preLaunchTask: "rust: cargo build"`.
В VSCode это ссылка на таск из `.vscode/tasks.json`. У нас `tasks.json`
не используется.

**Решение.** В `plugins/tasks.lua` мы регистрируем overseer-шаблоны
**кодом на Lua**:

```lua
overseer.register_template({
    name = "cargo build (debug)",
    builder = function()
        return {
            cmd = { "cargo" },
            args = { "build" },
            cwd = vim.fn.getcwd(),
            components = { "default" },
        }
    end,
    condition = { filetype = "rust" },
})
```

`overseer.nvim` делает `setup({ dap = true })` (см. `plugins/tasks.lua`),
и встраивается в DAP как обработчик `preLaunchTask`. Когда nvim-dap
встречает в launch.json поле `preLaunchTask: "cargo build (debug)"`,
он зовёт overseer, тот запускает шаблон с этим именем, дожидается
завершения — и только потом стартует дебаг-адаптер.

**Идиоматично.** Один источник правды для тасков (Lua-шаблоны), не
надо дублировать в `tasks.json`. Если когда-нибудь захотим — `nvim-dap`
поддерживает и `tasks.json` тоже, но пока не нужно.

**В launch.json** в `preLaunchTask` пишем просто имя шаблона:
`"preLaunchTask": "cargo build (debug)"`.

---

## Эпизод 4 — Запустить любой конфиг независимо от открытого файла

**Проблема.** F5 фильтрует конфиги по filetype текущего буфера. Это
правильно в 90% случаев, но иногда хочется:

- Запустить дебаг, находясь в README.md / в neo-tree / в терминале.
- Прицельно запустить Python-конфиг, открывая Rust-файл.

**Решение.** Функция `dap_pick_any` в `plugins/dap.lua` + биндинг
`<leader>dP`. Загружает **все** конфиги из launch.json без
фильтрации по filetype, показывает в `vim.ui.select`.

**Биндинги в итоге:**

- `<F5>` — умный запуск: продолжить сессию / launch.json по filetype
  / fallback.
- `<leader>dP` — picker по всем конфигам launch.json без фильтра.

---

## Эпизод 5 — Версии языковых тулз и DAP-адаптеров

**Проблема, конкретный кейс.** Запускаем Go-дебаг, получаем:

```
Go version go1.23.3 is too old for this version of Delve
(minimum supported version 1.24, suppress this error with
--check-go-version=false)
```

`delve` 1.26 (свежий с github releases в PATH) требует Go 1.24+.
У пользователя Go 1.23.3.

**Глубже: вопрос поверх вопроса.** Как вообще идиоматично
управлять версиями языка / тулз / адаптеров на per-project основе?
У меня могут быть три проекта:

- `proj-a` — Rust 1.78, нужен старый clippy
- `proj-b` — Go 1.21, чтобы тестировать под прод
- `proj-c` — Python 3.11 в venv

И всё это на одной машине, без виртуалок.

**Раздел 1: язык.** Каждый язык имеет нативный pin, который понимают
ВСЕ инструменты экосистемы:

| Язык | Файл | Что пинит |
|---|---|---|
| Rust | `rust-toolchain.toml` | `channel = "1.78.0"` — `rustup` сам качает и переключает |
| Go | `go.mod` директива `toolchain go1.24.1` | `go` 1.21+ автоматически качает указанный toolchain |
| Python | `.python-version` (pyenv) или просто `.venv` в репо | `pyenv` или VIRTUAL_ENV переключает интерпретатор |

Никаких путей в конфиге дебаггера. Запускаешь `cargo` / `go` / `python`
из корня репо — оно само разруливается. Это работает кросс-платформенно
**потому что менеджер тулз — он же первичный entrypoint** (нет смысла
запускать `cargo` напрямую без rustup).

**Раздел 2: тулзы редактора (LSP, DAP-адаптеры, форматтеры).** Это уже
не язык, а инструменты редактора. Их идиоматично ставить через
`mason.nvim`. Pin версий — через `mason-tool-installer.nvim`:

```lua
-- plugins/lsp.lua
require("mason-tool-installer").setup({
    ensure_installed = {
        { "delve", version = "v1.23.1" },  -- последний для Go 1.20-1.23
        "rust-analyzer",
        "debugpy",
        ...
    },
})
```

Pin тут важен, потому что **наш Mason-`dlv` независим от системного `dlv`**
в PATH. Mason кладёт его в `~/.local/share/nvim/mason/bin/dlv` (на Linux)
или `%LOCALAPPDATA%\nvim-data\mason\bin\dlv.cmd` (на Windows).

**Раздел 3: чтобы DAP-адаптер взял именно Mason-версию.** Нужен helper:

```lua
local function mason_bin(name)
    -- ищет имя.exe / имя.cmd / имя в mason/bin
end
```

И настройка `nvim-dap-go`:

```lua
require("dap-go").setup({
    delve = {
        path = mason_bin("dlv"),  -- иначе подхватит из PATH
    },
})
```

То же самое для `codelldb`, если он установлен через Mason.

**Кросс-OS моменты:**

- Один и тот же механизм работает на Win/Linux/Mac.
- Единственная разница — расширение бинаря (.cmd / .exe). `mason_bin`
  это инкапсулирует.
- Системный `dlv` / `delve` в PATH остаётся для других нужд (vscode,
  CLI отладка), не конфликтует.

**Альтернатива — `mise` / `asdf`.** Если хочется один инструмент,
который пинит ВСЁ (и язык, и тулзы) per-project через `.mise.toml` —
тоже валидный путь. Но требует от каждого участника команды иметь
mise. Native pins (rust-toolchain.toml, go.mod, .venv) понимают все
без дополнительной установки.

**Финальное решение в этом конфиге.** Native pins для языков +
Mason-pinned версии для адаптеров + `mason_bin` helper для жёсткой
привязки nvim-dap-go к Mason-`dlv`. Это лежит в:

- `plugins/lsp.lua` — `mason-tool-installer` ensure_installed
- `plugins/dap.lua` — `mason_bin` + nvim-dap-go opts

---

## Эпизод 6 — "No terminal for the current session": битва с output

**Это самый длинный эпизод, и он показателен.** Внутри одной фразы
"output дебаг-программы" сидит **три разных механизма**, которые
ведут себя по-разному в каждом адаптере. Разбираемся.

### 6.1 Симптом

Разные языки ведут себя по-разному в одинаковом UI:

- **Rust** (codelldb по дефолту) — output виден в Console-секции
  dap-view. Всё хорошо.
- **Go** (delve) — Console-секция показывает `No terminal for the
  current session`, output вообще не появляется.
- **Python** (debugpy) — вроде работает, но непонятно куда что идёт.

### 6.2 Теория: три способа доставки output в DAP

В DAP-протоколе у адаптера есть три способа отдавать stdout/stderr
debuggee:

1. **DAP `output` events.** Адаптер сам читает stdout/stderr процесса
   и шлёт текст в клиент через protocol-сообщения `event: output`.
   nvim-dap сшивает их в **REPL-секцию** dap-view. Stdin тут
   невозможен (write-only канал).

2. **`runInTerminal` reverse-request.** Адаптер просит клиента
   "открой мне настоящий PTY вот по такой команде". Клиент создаёт
   терминал-буфер, запускает в нём debuggee, отдаёт PID обратно.
   Дальше адаптер прицепляется к этому процессу. Stdin / stdout
   / TTY-фичи — всё работает. У нас этот PTY показывается в
   **Console-секции** dap-view.

3. **Локальный (внутренний) терминал самого адаптера.** Адаптер
   считает, что у клиента есть собственный терминал, и пишет туда
   напрямую. Если клиент его не открыл — ловит ошибку **"No terminal
   for the current session"**. Это легаси delve-режим, который сейчас
   почти никто не поддерживает.

### 6.3 Дефолты адаптеров (вот тут самое мерзкое)

| Адаптер | Поле в launch.json | Дефолт |
|---|---|---|
| codelldb | `console: "integratedTerminal"` (default) / `"internalConsole"` / `"externalTerminal"` | integratedTerminal → способ #2 |
| delve | `console: "integratedTerminal"` / `outputMode: "remote"` | если не указать — способ #3 ("local terminal") → ошибка |
| debugpy | `console: "internalConsole"` (default) / `"integratedTerminal"` | internalConsole → способ #1, НО на Windows ещё спавнит левый системный console-subprocess |

То есть:

- Go ломался потому, что delve по дефолту хочет писать в локальный
  терминал, который мы не открываем. Лечится `outputMode: "remote"`
  (способ #1) или `console: "integratedTerminal"` (способ #2).
- Rust работал потому, что codelldb по дефолту использует способ #2
  (PTY → Console-секция).
- Python работал смешанно — output шёл через DAP events в REPL,
  но Windows плодил левый процесс-консоль.

### 6.4 Первая попытка стандартизации: "всё в REPL"

Логика: REPL — write-only, не требует PTY, кросс-платформенно
работает. Сделать всё через DAP events:

- codelldb: `console: "internalConsole"`
- delve: `outputMode: "remote"`
- debugpy: `console: "internalConsole"` (+ `redirectOutput: true`)

Поменяли `default_section` в dap-view на `"repl"`. Поменяли
`mode_debug` в `panels.lua` на `show_debug_section("repl")`.

**Что сломалось:**

- **codelldb на Windows с `internalConsole` не захватывает stdout
  Rust-бинарей.** REPL пуст. Известная проблема адаптера, не наш баг.
- **debugpy без `redirectOutput`** всё равно открывает левый системный
  console-subprocess рядом.
- **Фокус прыгал на REPL** — гонка между `:DapViewShow repl` и
  `focus_code_later` в `panels.open_debug`.

### 6.5 Финальная стандартизация: "всё через PTY в Console"

Откатились к тому, что изначально работало для Rust:
**`console: "integratedTerminal"` во всех конфигах**. Один способ
доставки — `runInTerminal` (способ #2). Один канал отображения —
Console-секция dap-view.

Что это даёт:

1. **Кросс-платформенно работает** на всех адаптерах без квирков.
2. **Stdin / stdout / TTY-фичи** — единое поведение, не надо
   разводить "обычный" и "interactive" варианты.
3. **Никаких левых окон** — `nvim-dap-view` через `dap-defaults.lua`
   переопределяет `dap.defaults.fallback.terminal_win_cmd` на
   `vim.api.nvim_create_buf(false, false)` — буфер без окна, потом
   сам показывает его в Console-секции.
4. **Никакого `No terminal for the current session`**, потому что PTY
   создаётся всегда.

REPL-секция остаётся, но используется только для **DAP-команд**:
evaluate выражений (`:DapEval`), `:Continue`, `:Next` и т.п.

**Конкретные правки:**

- `plugins/dap.lua` дефолтный codelldb-конфиг: `console = "integratedTerminal"`
- `plugins/dap.lua` `default_section = "console"` в dap-view opts
- `config/panels.lua` `mode_debug` → `show_debug_section("console", false)`
- `D:/rust_repo/lab/.vscode/launch.json` — все конфиги переписаны на
  `console: "integratedTerminal"` (Rust/Go/Python)
- `PANELS.md` — раздел "Output: console vs REPL" обновлён, объяснено
  почему не пошли в `internalConsole`/`outputMode=remote`

### 6.6 Stale state в Console-секции

**Доп. проблема.** После завершения предыдущей сессии в Console
оставался PTY-буфер старого процесса. dap-view сам подхватывает
новый PTY текущей сессии, но между концом старой и стартом новой
успевает мелькнуть `No terminal for the current session`.

**Решение.** `reset_dap_view_console` в `plugins/dap.lua` — очищает
`state.last_session_buf` и закрывает `state.term_winnr` перед стартом
новой сессии. Подвешено на `dap.listeners.before.attach` /
`before.launch`.

### 6.7 Что в итоге работает одинаково

После всех правок поведение F5 на любом языке:

1. nvim-dap читает `.vscode/launch.json`, фильтрует по filetype.
2. Если один конфиг — запускает; если несколько — picker.
3. Адаптер сообщает `runInTerminal`.
4. nvim-dap создаёт буфер без окна (через `terminal_win_cmd`
   override).
5. dap-view показывает этот буфер в Console-секции.
6. `panels.mode_debug` открывает dap-view снизу с фокусом на Console.
7. `focus_code_later` возвращает фокус в код.
8. Программа пишет stdout/stderr — видно в Console.
9. Если программа читает stdin — можно набирать там же.

---

## Эпизод 6.8 — "Invalid buffer id": когда костыль ломает больше, чем чинит

**Контекст.** В Эпизоде 6.6 мы добавили `reset_dap_view_console`, чтобы
между сессиями подчищать stale `state.last_session_buf` в dap-view -
он показывал "No terminal for the current session" с прошлой сессии.
Решение казалось безобидным: удалить буфер, обнулить ссылку.

**Симптом.** На повторных запусках Rust периодически вылетает:

```
vim.schedule callback: ...dap-view/console/view.lua:229: Invalid buffer id: 34
stack traceback:
    setup_term_buf at view.lua:229
    listener at listeners.lua:75
    call_listener at session.lua:1072
```

То работает, то падает. Вместе с этим:
`Debug adapter didn't respond` и `breakpoint rejected unknown source:1`.

**Раскопки.** Лезем в `nvim-dap/lua/dap/session.lua`. Там есть
**внутренний пул** terminal-буферов:

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
        return buf  -- РЕЦИКЛ старого буфера
      end
    end
    -- иначе создать новый
    ...
  end

  function terminals.release(b)
    pool[b] = true
  end
end
```

Когда дебагги-процесс exit'ится, on_exit job-а зовёт `terminals.release(buf)`.
Буфер уходит в пул для повторного использования. На следующем
запуске `terminals.acquire` ВЫТАСКИВАЕТ его обратно и возвращает как
готовый term_buf нового сеанса.

**Что мы делали ломая это:**

1. Сессия 1: создан buf 34. session1.term_buf = 34. dap-view сохранил
   `state.last_session_buf = 34`.
2. Программа закончилась. on_exit → `terminals.release(34)`. В пуле
   nvim-dap: `pool = { [34] = true }`.
3. Юзер жмёт F5 заново. Наш `before.launch` →
   `reset_dap_view_console` → `nvim_buf_delete(34, force)`. **Буфер 34
   физически уничтожен.** Но в пуле nvim-dap всё равно `pool[34] = true`.
4. Сессия 2: `terminals.acquire` → `next(pool)` → 34 → проверка
   `nvim_buf_is_valid(34)` → false → fallback, создаётся свежий buf Y.
   `session2.term_buf = Y`.

И тут начинается интересное. dap-view's `setup_term_buf` идёт через
`fetch_term_buf(session)`, **который шагает по цепочке `session.parent`**:

```lua
M.fetch_term_buf = function(session)
    local parent = session
    while parent ~= nil do
        if parent.term_buf then
            return parent.term_buf
        end
        parent = parent.parent
    end
end
```

Если codelldb (или delve / debugpy) при каких-то условиях создаёт
дочернюю сессию, чей `term_buf == nil`, fetch_term_buf поднимается
к parent и берёт **stale 34**, удалённый нами. Дальше
`vim.bo[34].filetype = ...` → "Invalid buffer id".

**Решение.** Самим Console-секцию dap-view трогать НЕЛЬЗЯ. Удалили
`reset_dap_view_console` целиком. Оставили только `reset_dap_repl`
(чистка REPL-секции — она безопасна, потому что nvim-dap её не
кеширует).

**Кто решает stale-state теперь.** Сам dap-view: в его
`listeners.lua` есть `on_session` listener, который при появлении
новой сессии вызывает `term.fetch_term_buf(new) → switch_term_buf()`
и переключает Console на свежий term_buf. Так что между сессиями
Console сама обновляется на актуальный PTY.

**Мораль.** Прежде чем "подчищать" чужое состояние внешним кодом —
изучи, как этот плагин управляет жизненным циклом своих ресурсов.
Особенно если у плагина есть пул / кеш / подписки. nvim-dap пишет
в пуле "буфер 34 свободен", а мы за спиной этот буфер удалили.
Классический рассинхрон владельцев ресурса.

**Файлы:**

- `vim/nvim/lua/plugins/dap.lua` — удалена `reset_dap_view_console`,
  listeners `before.attach` / `before.launch` подвешены только на
  `reset_dap_repl`.
- Доказательство в `nvim-dap/lua/dap/session.lua`: `terminals.acquire`
  и `terminals.release`, пул как `local pool = {}`.

---

## Эпизод 6.9 — Когда стандарт не работает: исключение для Go и шумные warnings

После Эпизода 6.8 (убрали ломающий костыль) Rust и Python поехали.
А Go — нет. Картина: scopes показываются, REPL что-то логирует,
но **stdout программы (`fmt.Println`) нигде не виден**.

**Раскопки про Go.** Лезем в `nvim-dap-go/lua/dap-go.lua`.
Видим, что собственные конфиги плагина (Debug, Debug Package, ...)
все ставят `outputMode = configs.delve.output_mode`, а defaults в
`default_config` — `output_mode = "remote"`. Никаких `console`-полей
плагин для своих конфигов не использует.

Параллельно лезем в delve-доку. Для DAP-режима у delve **два**
независимых поля:

- `console` (default `"internalConsole"`) — определяет, ГДЕ запустить
  процесс debuggee. `"integratedTerminal"` → reverse-request `runInTerminal`,
  PTY у клиента.
- `outputMode` (default `"local"`) — определяет, КУДА delve льёт
  stdout/stderr debuggee, **если console не дал PTY**.
  `"remote"` → DAP `output` events. `"local"` → во внутренний терминал
  delve, которого в headless DAP-режиме нет → `No terminal for the
  current session`.

Теория: `console = "integratedTerminal"` должен победить, и delve
должен запросить PTY через runInTerminal. Stdout debuggee → PTY →
Console-секция dap-view.

**На практике в delve v1.23.1 этого не происходит.** В режиме
`mode = "debug"` (когда delve сам компилирует исходник через
`go build`, без отдельного бинаря на диске) delve игнорирует
`console = "integratedTerminal"` и запускает скомпилированный бинарь
своим внутренним способом. PTY не открывается. Stdout уходит в
`/dev/null` (на Windows — куда-то в дебри).

**Fix.** Делаем для Go нативное delve-поведение: `outputMode = "remote"`,
`console`-поле убираем. Stdout идёт через DAP events → REPL-секция
dap-view.

**Цена решения — нарушенный стандарт.** Для Rust и Python вывод в
Console-секции, для Go — в REPL. Это **документировано в PANELS.md**,
но юзер должен помнить: после старта Go-сессии переключайся в REPL
(`<leader>m6`).

Конфиг для Go в `D:/rust_repo/lab/.vscode/launch.json`:

```json
{
    "name": "Go: main.go",
    "type": "go",
    "request": "launch",
    "mode": "debug",
    "program": "${workspaceFolder}/main.go",
    "cwd": "${workspaceFolder}",
    "args": [],
    "outputMode": "remote"
}
```

### Шумный warning от Python: `command python ... exited with 1`

После того, как Python начал работать, при завершении дебагги-скрипта
вылазил безобидный, но раздражающий WARN:

```
command `python` of adapter `debugpy` exited with 1.
Run :DapShowLog to open logs.
```

**Раскопки.** Источник — `nvim-dap/lua/dap/session.lua`,
функция `get_badexit_msg`. Срабатывает, когда процесс DAP-адаптера
(не debuggee, а сам `python -m debugpy.adapter`) выходит с
ненулевым кодом. На Windows `debugpy.adapter` при штатном disconnect
**всегда выходит с кодом 1**. Это известный квирк адаптера, не баг
конфига.

**Fix.** Monkey-patch `dap.utils.notify` в нашем `plugins/dap.lua`:
оборачиваем оригинал, ловим `WARN` сообщения, фильтруем по списку
известных безобидных паттернов, остальные пропускаем дальше:

```lua
local utils = require("dap.utils")
local original_notify = utils.notify
local benign_patterns = {
    "command `python` of adapter `debugpy` exited with %d+",
    "command `python%d?%-?%d*` of adapter `debugpy` exited with %d+",
    "command `dlv` of adapter `go` exited with %d+",
    "command `dlv%.exe` of adapter `go` exited with %d+",
}
utils.notify = function(msg, log_level)
    if log_level == vim.log.levels.WARN and type(msg) == "string" then
        for _, pattern in ipairs(benign_patterns) do
            if msg:match(pattern) then
                return
            end
        end
    end
    return original_notify(msg, log_level)
end
```

**Почему monkey-patch, а не listener в DAP.** nvim-dap вообще не
эмитит этот warning через listener — он идёт прямо в `utils.notify`
из внутренней функции `spawn_server_executable`. Перехватить его
можно только заменой самого `notify`. Делаем это разово при setup'е
плагина, остальной код nvim-dap ничего не замечает.

### Stale breakpoint от прошлого файла

Ещё один косметический момент. Юзер дебажил `1.py`, оставил там
breakpoint, потом запустил Rust. В Console:

```
Breakpoint rejected unknown source:1: could not find file D:\rust_repo\lab\1.py
```

**Это нормальное поведение nvim-dap.** Breakpoints хранятся
глобально (по абсолютным путям), и при старте новой сессии все
известные breakpoints шлются текущему адаптеру. codelldb получает
breakpoint в `1.py`, обоснованно отвечает "не знаю такого файла".

**Fix.** Не системный, на стороне юзера: `:DapClearBreakpoints`
(сносит все), либо открыть `1.py` и снять `<F9>` в нужной строке.
Можно повесить на `<leader>dC` для удобства.

В систему встраивать фильтр "только из buffers моего filetype"
не стали — иногда нужно ставить breakpoints в файлах, которые
не открыты как buffer (например в зависимости из `~/.cargo/registry`).
Лучше пусть будет шумно, чем тихо терять breakpoints.

---

## Эпизод 6.10 — Контекст-зависимый default section

**Контекст.** После Эпизода 6.9 у нас Go выводит в REPL, остальные —
в Console. По дефолту dap-view фокусируется на Console — для Go это
значит "после F5 надо вручную ткнуть `<leader>m6`", чтобы увидеть
вывод. Раздражает.

**Решение.** Сделать выбор секции зависимым от типа адаптера
запускаемой сессии. Helper в `plugins/dap.lua`:

```lua
local function section_for_config_type(type_)
    if type_ == "go" or type_ == "delve" then
        return "repl"
    end
    return "console"
end

local function open_debug_for_config(cfg)
    if cfg and cfg.type then
        panels.show_debug_section(section_for_config_type(cfg.type), false)
    else
        panels.open_debug()
    end
end
```

И применить в трёх местах:

1. **`dap_continue`** — после того как выбрали конфиг (один из
   project_launch_configs или из picker), зовём `open_debug_for_config(cfg)`
   ПЕРЕД `dap.run(cfg)`. dap-view сразу открывается на правильной секции.
2. **`dap_pick_any`** — то же самое после выбора в picker.
3. **`event_initialized` listener** — резерв на случай, когда
   `dap.continue()` или сторонний код запускают сессию мимо наших
   функций. Берёт `dap.session().config.type` и тоже зовёт
   `panels.show_debug_section`.

**Subtle момент 1.** В начале `dap_continue` мы всё равно зовём
`panels.show_debug_section(...)` для нужной секции. Если сессии
ещё нет — открываем Console как нейтральный default. Если потом
окажется, что выбранный конфиг — Go, секция перефокусируется в
REPL до старта сессии.

**Subtle момент 2 — фикс по follow-up жалобе.** Первая итерация
этого эпизода в начале `dap_continue` всегда звала `panels.open_debug()`
с дефолтным Console — даже если сессия УЖЕ идёт. Юзер запустил Go,
смотрит вывод в REPL, жмёт F10 (step over) — и фокус перескакивает
в Console. Лечится тем, что в начале `dap_continue` (и `dap_pick_any`,
и в `panels.mode_debug` для `<leader>md`) мы СНАЧАЛА проверяем
`dap.session()`: если есть, берём `section_for_config_type` от её
типа. Только если сессии нет — нейтральный Console.

`panels/mode_debug` теперь тоже знает про dap (через `pcall(require, "dap")`,
чтобы не привязываться к загрузке плагина):

```lua
function M.mode_debug()
    local section = "console"
    local ok, dap = pcall(require, "dap")
    if ok then
        local session = dap.session()
        local type_ = session and session.config and session.config.type
        if type_ == "go" or type_ == "delve" then
            section = "repl"
        end
    end
    M.show_debug_section(section, false)
end
```

**Цена.** Для Go при первом нажатии F5 видно мелькание Console →
REPL (миллисекунды). Не страшно. На повторных F5/F10/F11 фокус
остаётся в REPL.

**Файлы:**

- `plugins/dap.lua` — `section_for_config_type`, `open_debug_for_config`,
  обновлены `dap_continue`, `dap_pick_any`, `open_debug_view` listener.
- `config/panels.lua` — `mode_debug` тоже опрашивает `dap.session()`,
  чтобы `<leader>md` не сбивал секцию во время Go-сессии.

---

## Эпизод 6.11 — `${file}` из dap-view: гонка фокуса

После Эпизода 6.10 (контекст-зависимый фокус) словили follow-up баг.

**Симптом 1 — Python:**

```
OSError: [Errno 22] Invalid argument:
'D:\\rust_repo\\lab\\dap-view:\\main'
```

**Симптом 2 — Rust:** дебаг просто не запускается.

**Что общего.** Оба запуска используют переменные `launch.json`,
которые резолвятся через **текущий буфер**:

- Python: `program: "${file}"`
- Rust: `preLaunchTask: "cargo build (debug)"` → overseer template
  `cargo_root()` смотрит имя текущего буфера и идёт вверх по дереву
  ища `Cargo.toml`.

`nvim-dap` резолвит `${file}` через `vim.fn.expand("%:p")` (см.
`nvim-dap/lua/dap.lua` `var_placeholders`). Если current buffer —
это `dap-view-term` (Console-секция), то `expand("%:p")` берёт его
имя `dap-view://main` (или похожее) и режет/расширяет до
`D:\rust_repo\lab\dap-view:\main`. debugpy ловит "Invalid argument".
Аналогично `cargo_root()` от dap-view-буфера не находит `Cargo.toml`,
сборка идёт в неправильной cwd.

**Откуда баг.** Виновата вот эта последовательность в `dap_continue`:

```lua
local function dap_continue()
    leave_terminal_mode()
    remember_launch_buffer()           -- сохранили source-буфер в vim.g
    panels.show_debug_section(...)     -- ОТКРЫЛИ dap-view, current buf теперь = dap-view
    vim.schedule(function()
        ...
        dap.run(cfg)                   -- ${file} expand'ится из current buf = dap-view
    end)
end
```

`panels.show_debug_section` синхронно открывает dap-view, и current
window/buffer переходит туда. `focus_code_later` шедулит возврат
фокуса в код, но через `vim.schedule` — а наш `dap.run` тоже в
`vim.schedule`. Гонка: какая schedule отстреляется первой? У нас —
`dap.run` стрельнул раньше, current buf = dap-view, ${file} битый.

Можно было бы поменять порядок (`dap.run` сначала, открытие
dap-view после), но это убивает мгновенный UI feedback на F5.

**Fix.** Helper `with_launch_buffer(fn)`: оборачивает `fn` в
`vim.api.nvim_buf_call(launch_buf, fn)`. Внутри коллбэка
`vim.fn.expand("%:p")`, `vim.api.nvim_get_current_buf()`,
`vim.fn.bufname()` и весь код, читающий "current buffer", видят
`launch_buf` (наш сохранённый source-буфер), а не dap-view.

```lua
local function with_launch_buffer(fn)
    local buf = vim.g.user_dap_launch_buf
    if type(buf) == "number" and vim.api.nvim_buf_is_valid(buf) then
        return vim.api.nvim_buf_call(buf, fn)
    end
    return fn()
end

local function run_config(dap_mod, cfg)
    with_launch_buffer(function()
        dap_mod.run(cfg)
    end)
end
```

Применили в `dap_continue` и `dap_pick_any`: все вызовы `dap.run`
теперь через `run_config`. Туда же завернули fallback `dap.continue()`.

`remember_launch_buffer` сохраняется ДО открытия dap-view (в самом
начале `dap_continue`), и фильтрует dap-view-буферы — не запоминает
их даже если current buf — dap-view. Так что у нас всегда есть
ссылка на последний реальный source-буфер юзера.

**Урок.** Когда меняешь UI-фокус и одновременно вызываешь "API,
который читает current buffer" через `vim.schedule`, у тебя
race-condition. Дешевле всего лечить через `nvim_buf_call`, а не
синхронизировать порядок schedule'ов.

**Файлы:**

- `plugins/dap.lua` — добавлены `with_launch_buffer` и `run_config`,
  `dap_continue` / `dap_pick_any` обновлены.

---

## Эпизод 7 — UI / "режимы экрана" под дебаг

**Контекст.** В этом конфиге нет статичного "IDE layout". Вместо
этого есть концепция **режимов** (`mode_debug`, `mode_tests`,
`mode_search`, `mode_files`, ...) — переключатели tool-окон, которые
открывают/закрывают/фокусируют нужные панели для текущей задачи.

См. `PANELS.md` для пользовательского описания.

**`mode_debug` делает:**

1. Закрывает прочие activity-окна (тестовый summary, search, и т.п.).
2. Открывает dap-view снизу (`:DapViewOpen`).
3. Переключает секцию на нужную (`:DapViewShow console` после Эп. 6).
4. Возвращает фокус в код-окно (`focus_code_later` через `vim.schedule`).

**Слоты в режиме debug** (через `<leader>m1..m6`):

- `m1` — Console (PTY текущего процесса)
- `m2` — Scopes
- `m3` — Breakpoints
- `m4` — Threads
- `m5` — Watches
- `m6` — REPL (для DAP-команд)

**Биндинги управления:**

- `<F5>` — start/continue (умный запуск)
- `<S-F5>` — terminate
- `<leader>dP` — picker по всем конфигам launch.json (без фильтра)
- `<leader>dL` — `:DapShowLog` (логи адаптера, очень помогает при
  непонятных падениях)
- `<leader>dw` — добавить watch
- `<leader>dR` — переключиться в REPL

---

## Эпизод 8 — Финальная архитектура (для сверки)

После всех итераций конфиг устаканился. Это раздел-снимок, чтобы
было с чем сверяться, когда что-то пойдёт не так.

### 8.1 Что куда положили

```
plugins/dap.lua (~930 строк)
├── helpers: mason_bin, codelldb_path, cargo_root
├── state:   remember_launch_buffer (vim.g.user_dap_launch_buf)
├── jsonc:   strip_jsonc, find_launch_json
├── load:    load_launch_configs, project_launch_configs
├── ui:      section_for_config_type, open_debug_for_config
├── safety:  with_launch_buffer, run_config (nvim_buf_call wrap)
├── flow:    dap_continue, dap_pick_any, dap_action
└── plugin specs:
    ├── nvim-dap (с keys, config: adapters/listeners/notify-monkey-patch)
    ├── nvim-dap-view (default_section=console, terminal=below)
    ├── nvim-dap-go (delve.path = mason_bin("dlv"))
    └── nvim-dap-python (debugpy_python из mason)

plugins/tasks.lua
└── overseer.nvim setup({dap=true})
    └── register_template "cargo build (debug)"

plugins/lsp.lua
└── mason-tool-installer.ensure_installed:
    └── { "delve", version = "v1.23.1" }  -- pin под Go 1.23

config/panels.lua
└── mode_debug() / show_debug_section()
    └── pcall(require, "dap").session().config.type → repl или console
```

### 8.2 Полный путь от F5 до stdout в окне

Что происходит, когда юзер открывает `main.rs` и жмёт `<F5>`:

**1. Хук `<F5>` → `dap_continue` (синхронно).**

```lua
1.1  leave_terminal_mode()         -- если фокус был в терминале
1.2  remember_launch_buffer()      -- vim.g.user_dap_launch_buf = main.rs buf
                                   -- (фильтрует dap-view, не запоминает чужое)
1.3  определяем активную сессию:
     - есть → секция по её типу (для последующих F10/F11 во время сессии)
     - нет  → нейтральный Console
1.4  panels.show_debug_section(...) -- открывает dap-view снизу
                                    -- ВАЖНО: после этого current win = dap-view
```

**2. Запланировано на следующий tick: `vim.schedule(launcher)`.**

```lua
2.1  if dap.session() then dap.continue() return  -- идёт сессия → step/continue
2.2  иначе load .vscode/launch.json:
     find_launch_json()           -- от cargo_root() ИЛИ от vim.g.user_dap_launch_buf
     load_launch_configs():
         readfile + strip_jsonc   -- удалили //, /* */, trailing ,
         dap.ext.vscode._load_json -- + OS-overrides + ${input:...} resolver
     project_launch_configs(ft)   -- фильтр по filetype через DAP_TYPE_TO_FILETYPES
2.3  если нашёлся 1 конфиг — берём его
     если несколько — vim.ui.select picker
     если 0 — fallback dap.continue() (использует встроенные dap.configurations)
2.4  open_debug_for_config(cfg)   -- перефокус на нужную секцию
                                    Rust → console, Go → repl, Python → console
2.5  run_config(dap, cfg):
     with_launch_buffer(function()
         dap.run(cfg)
     end)
```

**3. Внутри `nvim_buf_call(launch_buf, fn)`:**

`current_buf` теперь = main.rs (не dap-view). Все `vim.fn.expand("%:p")`,
`vim.api.nvim_buf_get_name(0)`, `vim.bo.filetype` видят main.rs.

**4. `dap.run(cfg)` синхронно:**

```
4.1 listeners.on_config["dap.expand_variable"] разворачивает:
    ${file}              → main.rs path (через current buf, см. п.3)
    ${workspaceFolder}   → vim.fn.getcwd()
    ${input:rustArgs}    → vim.ui.input prompt (если есть)
4.2 если cfg.preLaunchTask:
    overseer.dap.M.listener (зарегистрирован через overseer.enable_dap):
       - заводит coroutine
       - overseer.run_task("cargo build (debug)") стартует таск
       - builder() читает cargo_root() из current buf (= main.rs) ✓
       - таск выполняется, on_complete → coroutine.resume
       - launcher продолжается
4.3 dap.adapters.codelldb стартует:
       - спавнит codelldb.exe с --port ${port}
       - JSON-RPC handshake
4.4 codelldb запрашивает runInTerminal:
       - nvim-dap.terminals.acquire берёт буфер из пула
         (или создаёт через dap-view's terminal_win_cmd override)
       - открывает PTY-job в этом буфере
       - session.term_buf = bufnr
       - возвращает PID процесса в codelldb
4.5 codelldb запускает lab.exe в PTY
4.6 codelldb шлёт event: initialized
```

**5. `dap.listeners.after.event_initialized.dapview_config = open_debug_view`:**

```lua
5.1 reset_dap_repl()                    -- очистили старые DAP-сообщения в REPL
5.2 panels.show_debug_section(
        section_for_config_type(dap.session().config.type),
        false  -- не фокусить dap-view, focus_code_later вернёт в код
    )
5.3 dap-view's listeners.lua после configurationDone:
    term.setup_term_buf() — wires up term_buf to console section
    term.switch_term_buf() — показывает PTY в Console
```

**6. lab.exe пишет stdout/stderr → PTY → виден в Console-секции dap-view.**

Для Go всё то же, но в п.4.4 delve НЕ открывает PTY (известный баг
v1.23.x в `mode=debug`), а вместо этого шлёт `event: output` с stdout
debuggee. nvim-dap кидает их в REPL. Поэтому в `section_for_config_type`
для go/delve возвращаем "repl".

### 8.3 Список костылей: что есть и зачем

| # | Костыль | Файл | Уровень | Можно убрать? |
|---|---|---|---|---|
| 1 | `strip_jsonc` препроцессор | dap.lua | необходимость | нет, пока vim.json.decode стриктный |
| 2 | `dap.providers.configs["dap.launch.json"] = function() return {} end` | dap.lua | необходимость | можно, если разобраться с upstream-парсером (низкий ROI) |
| 3 | `section_for_config_type` хардкод `go`/`delve` | dap.lua | компромисс | нет, пока delve не починит integratedTerminal в mode=debug |
| 4 | monkey-patch `dap.utils.notify` для шумных WARN | dap.lua | компромисс | можно, если nvim-dap добавит фильтр notify по адаптеру |
| 5 | `with_launch_buffer` + `nvim_buf_call(launch_buf, ...)` | dap.lua | архитектурный компромисс | можно, если перевернуть порядок: `dap.run` сначала, UI потом (потеря: визуальный лаг при F5) |
| 6 | `reset_dap_repl` на каждый launch | dap.lua | гигиена | можно, если REPL-история нужна между сессиями |
| 7 | `mason_bin` helper для `dlv` | dap.lua | необходимость | нет (PATH-конфликт версий dlv) |
| 8 | `terminal_map(<F5>, ...)` чтобы F-ключи не уходили в debuggee | dap.lua | необходимость | нет |
| 9 | `DAP_TYPE_TO_FILETYPES` ручная карта | dap.lua | спецификация | нет (это VS Code контракт) |
| 10 | `dap.set_log_level("TRACE")` всегда | dap.lua | удобство | можно сделать `WARN` по дефолту, но при отладке useful |
| 11 | `mode_debug` через `pcall(require, "dap")` | panels.lua | защита | необходимость, panels не должен жёстко зависеть от dap |
| 12 | `cargo metadata` parsing в `rust_program` для определения bin | dap.lua | фича | нет, ради корректного выбора `target/debug/X.exe` |

**Что я бы НЕ трогал.**

Костыли #1, #3, #4, #5 — это адаптация к багам/особенностям сторонних
тулов (vim.json.decode, delve, debugpy, dap-view). Каждый
зафиксирован комментарием и эпизодом в этом файле, чтобы можно
было снести когда сторонний тул починит свою сторону.

**Что почистил по ходу ревью.**

- Убрал мёртвые зануления `dap.listeners.before.event_terminated.dapview_config = nil`
  и братьев. dap-view регистрирует свои listeners под ключом `SUBSCRIPTION_ID`,
  наш `dapview_config` там никогда не существовал — было защитой "от
  призраков", не нужно.

### 8.4 Опорные точки при сверке поведения

Если что-то сломалось — куда смотреть:

| Симптом | Точка контроля |
|---|---|
| F5 не запускает дебаг | `dap_continue` → `project_launch_configs(ft)` возвращает nil? Открой `:lua print(vim.inspect(require("plugins.dap")))` нельзя; смотри `:DapShowLog` |
| `${file}` или cargo_root указывает не туда | `vim.g.user_dap_launch_buf` устарел? `:lua print(vim.api.nvim_buf_get_name(vim.g.user_dap_launch_buf))` |
| Не видно вывода Rust/Python | сам ли запустился процесс? `:DapShowLog` → ищи `runInTerminal` request и Response с PID |
| Не видно вывода Go | переключись в REPL `<leader>m6` или `<leader>dR` |
| Фокус прыгает не туда | `panels.mode_debug` определяет секцию по `dap.session().config.type`. Если сессия странная (sub-session js-debug-adapter) — может промахнуться |
| Шумные WARN | проверь, что `benign_patterns` в monkey-patch покрывает текущий формат сообщения |
| Breakpoint rejected на чужом файле | by design, `:DapClearBreakpoints` |
| "Invalid buffer id" в dap-view | НЕ ставь `nvim_buf_delete` на term-буферы dap-view — пул nvim-dap держит на них ссылки |

---

## Что осталось / TODO для следующих серий

Идеи на будущее, чтобы было что снимать дальше:

- **Conditional breakpoints + logpoints** — UX как у JetBrains, чтобы
  по `<leader>db` быстро задавать условия.
- **Remote debugging** — attach к running Go/Python через delve
  headless / debugpy listen. Нужен отдельный пресет в шаблоне
  launch.json.
- **JS/TS debugging** через `vscode-js-debug` (node-адаптер) — пока
  есть в карте `DAP_TYPE_TO_FILETYPES`, но конфиг не отлажен.
- **Telescope-dap пикеры** — `:Telescope dap commands / frames /
  variables / breakpoints` уже подключены, дать им хоткеи.
- **Авто-перезапуск дебага** при пересохранении файла (для длинных
  итераций) — overseer уже умеет watch-режим тасков.

---

## TL;DR карта решений

```
Проблема                           | Решение                                | Файл
-----------------------------------|----------------------------------------|----------------------
F5 спрашивает шаблон каждый раз    | .vscode/launch.json + dap_continue     | plugins/dap.lua
JSONC не парсится                  | strip_jsonc + dap.ext.vscode._load_json| plugins/dap.lua
preLaunchTask                      | overseer.register_template + dap=true  | plugins/tasks.lua
Запуск не по filetype              | dap_pick_any + <leader>dP              | plugins/dap.lua
Версия Go ≠ версия delve           | mason-tool-installer + mason_bin       | plugins/lsp.lua, plugins/dap.lua
"No terminal for current session"  | console = integratedTerminal           | launch.json + plugins/dap.lua
Output разный в разных адаптерах   | стандарт integratedTerminal везде      | launch.json + PANELS.md
Stale Console между сессиями       | dap-view сам через on_session listener | (ничего не делать)
"Invalid buffer id" в setup_term_buf| убрать reset_dap_view_console (лезли в пул nvim-dap) | plugins/dap.lua
Go: stdout не виден                | outputMode = remote (delve игнорит integratedTerminal в mode=debug) | launch.json
"command python ... exited with 1" | monkey-patch dap.utils.notify, фильтр benign patterns | plugins/dap.lua
Stale breakpoint от прошлого файла | :DapClearBreakpoints (поведение by design)| -
Go-сессия фокусится в Console (пусто)| section_for_config_type → REPL для go/delve | plugins/dap.lua
${file} = "dap-view:\\main"        | with_launch_buffer + nvim_buf_call вокруг dap.run | plugins/dap.lua
Лишний Python console на Windows   | то же — integratedTerminal             | launch.json
Фокус прыгает при F5               | default_section = console + focus_code | plugins/dap.lua, panels.lua
```

---

_Последнее обновление: эпизоды 0–8 (включая 6.8 про "Invalid buffer id",
6.9 про Go-исключение и warnings, 6.10 про контекст-зависимый default
section, 6.11 про гонку фокуса и `${file}` из dap-view, 8 — финальная
архитектура и ревью костылей). По мере доработок — продолжение._
