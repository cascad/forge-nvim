# IDE Modes And Panels

## Start Page / Recent Projects

Плагин: `goolord/alpha-nvim`.

Стартовая страница открывается при обычном запуске `nvim` без конкретного файла. Повторно ее можно открыть командой `:Alpha` или хоткеем `<leader>oh`. Если Alpha уже открыта в текущей вкладке, `<leader>oh` просто переведет фокус в ее окно. Она работает как home screen в VS Code/IDEA:

- `1..8` - открыть один из последних проектов из `project.nvim`.
- `p` - открыть полный session-aware picker проектов.
- `w` - работать в текущей папке без prompt, session restore и автоматического открытия Files layout.
- `o` - ввести путь к папке и открыть ее как проект. В prompt сразу подставляется текущий cwd, его можно править.
- `r` - восстановить сессию для текущей рабочей директории через `persistence.nvim`.
- `f` - найти файл в текущей рабочей директории.
- `q` - выйти.

`<leader>fp` и `<leader>op` открывают тот же session-aware picker проектов без захода на стартовую страницу.
`<leader>ow` закрывает стартовую страницу и оставляет работу в текущем cwd без открытия панелей.
`<leader>of` и `<leader>oP` открывают тот же prompt пути к папке.

Open folder prompt:

Project switching is intentionally VS Code-like: when the selected path is a
different project, the current project session is saved and Neovim uses native
`:restart` to start a fresh server, then changes cwd and restores the selected
project session. This avoids carrying old buffers, LSP clients, file watchers,
debug sessions, or plugin window state into the new workspace. There is no
in-process project-switch fallback: if `:restart` is unavailable or fails, the
switch is aborted with an error.

- Строка ввода стартует с текущего `cwd`, например `F:/work/current-project/`.
- Путь можно редактировать сразу в этой строке.
- Completion mode - `dir`, то есть штатное дополнение директорий от Vim.
- `Tab` дополняет путь и открывает popup со списком папок; повторный `Tab` / `<C-n>` идет вперед по вариантам, `<S-Tab>` / `<C-p>` назад.
- Когда popup открыт, `Enter` принимает выбранную папку как часть пути и закрывает popup. После этого можно снова нажать `Tab` для следующего уровня вложенности.
- Когда popup закрыт, `Enter` подтверждает весь текущий путь и открывает его как проект.
- Для cmdline completion явно включены `wildmenu`, `wildmode=longest:full,full`, `wildoptions=pum,tagfile`, `wildignorecase`.
- Neo-tree в этом сценарии не используется; он остается explorer'ом уже открытого проекта.
- После `Enter` nvim меняет cwd и грузит session, если она есть. Если session нет, остается code-only пустой буфер; Files layout сам не открывается.

При выборе проекта nvim сначала сохраняет сессию текущего проекта, потом переключает рабочую директорию через `project.nvim`. Если для выбранного проекта есть сохраненная сессия `persistence.nvim`, она загружается автоматически; если сессии нет, открывается обычный Files layout.

`project.nvim` ищет корень сначала через LSP, потом по marker-файлам (`.git`, `Cargo.toml`, `go.mod`, `pyproject.toml` и т.д.). Для Neovim 0.11+ добавлен compatibility shim: текущая версия `project.nvim` дергает deprecated `vim.lsp.buf_get_clients()`, а наш config подменяет только `project.find_lsp_root()` на вариант с `vim.lsp.get_clients()`. Это сохраняет LSP-based root detection без warning.

Сессия проекта запоминает открытые файловые буферы, tabs/windows и положение окон. Для отдельных файлов дополнительно включены штатные `mkview/loadview`, чтобы курсор и folds восстанавливались и при обычном открытии файла вне полного session restore.

Tool-windows (`neo-tree`, DAP View, Overseer, neotest, search panels, quickfix) в session-файл не сохраняются. Перед `mksession` они закрываются и вычищаются из buffer list, потому что plugin UI хранит собственное runtime-состояние и плохо переносится через `:source Session.vim`. После открытия проекта панели нужно открывать обычными IDE mode hotkeys (`<leader>mf`, `<leader>md`, `<leader>mt` и т.д.).

Это не отдельная большая IDE-надстройка: `alpha-nvim` рисует стартовый экран, `project.nvim` хранит recent-проекты, `persistence.nvim` отвечает за сессии. Собственный код лежит тонкой прослойкой в `lua/config/start.lua`.

Идея: Neovim работает не как набор одновременно открытых "секций", а как IDE с
режимами рабочего места. Один режим владеет tool-window layout: при переключении
закрываются нерелевантные панели и открывается связанный набор окон.

## Режимы

Главные клавиши:

- `<leader>mm` - выбрать режим из списка.
- `<leader>mf` - Files: дерево проекта слева.
- `<leader>mb` - Buffers: открытые буферы в neo-tree слева.
- `<leader>mg` - Git: измененные файлы в neo-tree слева.
- `<leader>md` - Debug: единая DAP View-панель.
- `<leader>mt` - Tests: neotest summary + test output.
- `<leader>mj` - Jobs: overseer task list/build output.
- `<leader>ms` - Search: project search/replace.
- `<leader>mo` - Output: нижний DAP output без остальных activity-панелей.
- `<leader>mc` - Code only: закрыть tool-windows и вернуться к коду.
- `<leader>mq` / `<leader>mQ` - закрыть IDE-комбайн; активный debug будет
  принудительно остановлен.
- `<leader>m0` - вернуть фокус в код.
- `<leader>m]` / `<leader>m[` - next/previous окно текущего режима.
- `<leader>m1` ... `<leader>m6` - быстрый переход к tool-буферам текущего режима.
- `Alt+h` / `Alt+l` - previous/next открытый файл в верхней tabline; работает из normal, insert, visual и terminal.
- `Alt+w` - закрыть текущий файл/контекст.
- `Alt+e` / `F7` - перейти в редактируемый файл/код; в Diffview выбирает рабочую версию файла, а не дерево.
- `Alt+q` - закрыть текущий контекст: Diffview, tool-window или текущий файл.
- `F4` / `Ctrl+F4` - то же закрытие, запасной вариант.
- `Ctrl+PageDown` / `Ctrl+PageUp` - следующий/предыдущий открытый файл.
- Команды-эквиваленты: `:ForgeBufferNext`, `:ForgeBufferPrev`, `:ForgeFocusEditor`,
  `:ForgeCloseContext`.

Это заменяет старую схему с `folke/edgy.nvim`: она была удобна как edge-accordion,
но смешивала Git/Files/Tests/Debug/Search в одном общем наборе окон. Теперь
layout переключается целиком.

## Keyboard Layouts

Хоткеи дублируются для English QWERTY и Russian ЙЦУКЕН на уровне
`lua/config/ru_keys.lua`. Модуль оборачивает `vim.keymap.set` до загрузки
остальной конфигурации, поэтому обычные keymaps и lazy.nvim `keys` получают
alias автоматически. Для встроенных Vim-команд (`w`, `b`, `gg`, `^`, `$`, `ciw` и т.п.)
дополнительно включен штатный `langmap`: русские буквы в normal/visual/operator-pending
режимах понимаются как соответствующие английские команды, а insert mode не трогается.

Ограничение OS/terminal layout: символы, которые русская раскладка отдает как обычный ASCII,
нельзя надежно отличить от английской раскладки внутри Neovim. Например physical `Shift+6`
на русской раскладке приходит в терминал как `:`, ровно как английский `:`. Маппить `:` в `^`
нельзя без поломки командной строки Vim. Полностью чистое решение для таких клавиш - пользоваться
встроенным Vim `keymap=russian-jcukenwin` для ввода русского текста вместо системной раскладки
внутри Neovim.

Примеры:

- `<leader>md` работает и как `<leader>ьв`.
- `gd` работает и как `пв`.
- `<C-S-d>` при наличии соответствующего terminal event дублируется в `<C-S-в>`.

F-клавиши, arrows, Enter, Escape и похожие special keys от раскладки не зависят.
Внутренние tables навигации `nvim-cmp` и Telescope тоже расширяются через этот
же helper. В других plugin-specific UI, где маппинги задаются не через
`vim.keymap.set`, авто-alias может не сработать; такие места добавляются отдельно
по надобности.

## Навигация Внутри Режима

Общие правила:

- `<leader>m0` всегда возвращает в основной code window.
- `<leader>m]` и `<leader>m[` циклически ходят по окнам текущего режима, включая код.
- `<leader>m1..m6` ходят только по tool-буферам текущего режима.

Слоты по режимам:

- Files/Buffers/Git: `m1` - neo-tree.
- Search: `m1` - search/replace buffer.
- Tests: `m1` - test summary, `m2` - test output.
- Debug: `m1` - console, `m2` - scopes, `m3` - breakpoints, `m4` - threads,
  `m5` - watches, `m6` - REPL. По <leader>md / F5 фокус по умолчанию на
  Console (PTY текущего процесса со stdout/stderr/stdin). REPL - для
  интерактивных DAP-команд (eval, :Continue и т.п.).
- Output: `m1` - console.
- Jobs: `m1` - overseer task list.

## Закрытие IDE Layout

Когда нужно закрыть весь набор панелей сразу:

- `<leader>mq` или `<leader>mQ` - закрыть все tool-windows.
- `:IdeClose` - то же самое командой.
- `:IdeMode` - открыть selector режимов.

Если в этот момент есть активная DAP-сессия, `IdeClose` сначала вызывает
terminate/disconnect для debuggee, потом закрывает DAP UI, explorer, tests,
search и quickfix. Обычный `<C-w>` остается закрытием текущего буфера.

## Files / Buffers / Git

Плагин: `nvim-neo-tree/neo-tree.nvim`.

Что можно делать:

- Смотреть дерево проекта.
- Открывать файлы, split/vsplit.
- Создавать, удалять, переименовывать, копировать и перемещать файлы.
- Смотреть открытые буферы.
- Смотреть git status в виде дерева измененных файлов.

Клавиши:

- `<leader>mf` - режим Files.
- `<leader>mb` - режим Buffers.
- `<leader>mg` - режим Git.
- `<leader>e` - toggle Files.
- `<leader>E` - reveal текущий файл в Files.
- `<leader>gS` - toggle Git side panel.
- `<C-e>` - focus/unfocus explorer.
- `<C-b>` или `<leader>bb` - открыть меню открытых файлов. В меню `Ctrl+j` / `Ctrl+k`
  двигают выбор, ввод фильтрует список, `Enter` открывает выбранный файл, `Esc` закрывает.
  Меню показывает все listed buffers, включая еще не загруженные файлы из восстановленной session.
  Текущий файл скрыт, поэтому первый пункт - последний активный файл кроме текущего.
- `]b` / `[b` - следующий / предыдущий открытый файловый буфер. Это самый надежный Vim-вариант.
- `Ctrl+PageDown` / `Ctrl+PageUp` - следующий / предыдущий буфер, если терминал пропускает эти клавиши.
- `<leader>bn` / `<leader>bp` - следующий / предыдущий буфер через leader.
- `L` / `H` - следующий / предыдущий буфер, короткий вариант.
- `Tab` / `Shift-Tab` - следующий / предыдущий буфер, дополнительный вариант; в некоторых терминалах может не доходить до Neovim.
- `<leader>bd` / `<C-w>` - закрыть текущий буфер.

`S` - это штатная Vim-команда `substitute line`: она удаляет текущую строку и переходит в insert.
Она не используется для переключения файлов.

Внутри neo-tree остаются вкладки `Files / Buffers / Git`; `<` и `>` переключают
source, а `bf`, `bb`, `bg` прыгают прямо к нужному source. В Files source `u` / `-`
поднимают дерево на уровень вверх, а `O` открывает выбранную папку как проект. Внутренние
neo-tree mappings тоже расширены под русскую раскладку: физические `h/j/k/l` работают как
`close/down/up/open` и на ЙЦУКЕН.

## Debug

Плагины: `mfussenegger/nvim-dap`, `rcarriga/nvim-dap-ui`,
`theHamsta/nvim-dap-virtual-text`, `telescope-dap.nvim`,
`stevearc/overseer.nvim`.

> **Архитектурная заметка (актуально для текущего edgy+dap-ui setup'а).**
>
> Sidebar Variables/Watch/Call Stack/Breakpoints — это 4 отдельных
> окна `dap-ui`'s layout=1, который edgy.nvim кладёт в left edgebar.
>
> Bottom debug panel:
>
> - **DAP Terminal** (`ft = "dap-terminal"`) — для Rust/codelldb.
>   Это НЕ `dapui_console`. Это наш собственный PTY-buffer, который
>   создаётся свежим на каждую сессию через `dap_terminal_win_cmd`.
>   Причина — на Windows nvim-dap-ui's console-element + pool
>   nvim-dap recycled-буферов теряли первые `println!`. См. подробный
>   разбор в `DEBUG_JOURNEY.md` §1.
> - **DAP REPL** (`ft = "dap-repl"`) — для Go (delve) и Python
>   (debugpy) с `internalConsole`. Output идёт через DAP
>   `output`-events.
> - **DAP Console** (`ft = "dapui_console"`) — `dapui.open(layout=2)`.
>   Сейчас не используется как дефолтный bottom, но компонент
>   зарегистрирован — циклится через `<leader>Pb`, на случай если
>   проектный launch.json явно использует non-codelldb-адаптер с
>   `console = "integratedTerminal"`.
>
> Ниже в этом разделе часть описаний может ссылаться на старый
> `nvim-dap-view` setup (`<leader>m1..m6` и т.п.) — это легаси от
> pre-edgy конфига. Актуальный workflow по дебагу — `COOKBOOK.md` §8.

Что можно делать:

- Запускать или продолжать debug-сессию.
- Продолжать выполнение после breakpoint через `<F5>`.
- Step over / into / out.
- Ставить обычные и условные breakpoints.
- Смотреть scopes, stack, watches, breakpoints.
- Смотреть stdout/stderr в секции `console` внутри DAP View.
- Переключать debug-секции `console/scopes/breakpoints/threads/watches/repl` в одном окне.
- Перед запуском Rust debug автоматически выполняется overseer task `cargo build (debug)`;
  если артефакты свежие, Cargo ничего не пересобирает.
- Оставлять debug layout и вывод видимыми после завершения программы.

Клавиши:

- `<leader>md` - открыть Debug layout.
- `<leader>mo` - сфокусировать debug output.
- `<leader>mc` - закрыть tool-windows.
- `<leader>m0` - вернуться в код.
- `<leader>m1..m6` - console / scopes / breakpoints / threads / watches / REPL.
- `<F5>` - start/continue.
- `<S-F5>` - terminate.
- `<C-S-F5>` - restart.
- `<F9>` - toggle breakpoint.
- `<F10>` / `<F11>` / `<S-F11>` - step over / into / out.
- `<leader>dD` или `<C-S-d>` - toggle Debug layout.
- `<leader>dP` - выбрать любой config из `.vscode/launch.json` независимо от
  filetype текущего буфера (полезно из README/terminal/git status).
- `<leader>dL` или `:DapShowLog` - открыть DAP/adapter logs.
- `<leader>dw` - добавить watch expression в DAP View.
- `<leader>dR` - перейти в секцию REPL.

Поведение:

- Если активной сессии нет, `<F5>` собирает picker: сначала все configs из
  `.vscode/launch.json` без фильтра по filetype, затем generated `Current ...`
  configs для текущего Rust/Go/Python файла. Один пункт запускается без меню,
  несколько пунктов идут через `vim.ui.select`.
- Сломанный `.vscode/launch.json` не блокирует F5: при ошибке парсинга идет
  notification, а generated current-file configs все равно добавляются.
- При открытии Debug layout фокус возвращается в код, чтобы можно было сразу
  продолжать редактирование или жать F-клавиши.
- При `<F5>` DAP View открывается сразу, а перед реальным launch закрывается с `!`
  и заново открывается на `event_initialized`; это дает видимый debug layout и свежую
  console-секцию без ручного управления окнами.
- После `event_exited`/`event_terminated` DAP View не закрывается сам.
- Для codelldb используется `terminal = "integrated"` и
  `console = "integratedTerminal"`: stdout/stderr идут в DAP Console.
  F-клавиши в terminal-mode перехватываются отдельными маппингами, чтобы F5
  оставался continue.
- Если launch падает до старта программы (`Error on launch: Failed to launch`),
  это не LSP/линтер. Смотреть нужно DAP logs через `<leader>dL` или
  `:DapShowLog`: там открываются `dap.log` и adapter stderr/stdout logs
  (`dap-codelldb-stderr.log`, `dap-go-stderr.log` и т.п.). Логирование DAP
  включено на `TRACE`, чтобы ошибки launch были видны без повторной настройки.
- DAP View держит console, scopes, breakpoints, threads, watches и REPL как секции одного окна,
  поэтому нижние debug-буферы не могут поменяться местами как два split'а `dap-ui`.
- Rust получает PTY через `runInTerminal` (`console = "integratedTerminal"`):
  stdout/stderr/stdin идут в **Console** секцию dap-view. Python не получает
  отдельный terminal: `internalConsole` + `redirectOutput=true` шлют
  stdout/stderr через DAP `output` events в **REPL**. Go тоже смотрим в REPL
  через `outputMode = "remote"`.
  См. ниже "Output: console vs REPL".
- В terminal-mode F-клавиши принудительно переводятся в Normal mode и вызывают
  `nvim-dap`, поэтому второй `<F5>` должен быть именно continue.
- Inline debug values используют `virt_text_pos = "inline"` на Neovim 0.10+,
  чтобы значения жили рядом с кодом, а не висели далеко справа в `eol`.
- Для Rust launch config передается `sourceLanguages = { "rust" }`: CodeLLDB
  подхватывает Rust data formatters из активного toolchain, поэтому стандартные
  типы вроде `Vec`, `String`, map/set и похожие структуры обычно выглядят
  существенно читабельнее. Если LLDB пишет `<variable not available>`, это уже
  не проблема DAP View: значение может быть moved, вне live range или скрыто
  оптимизациями/debug info, и UI не может восстановить его из воздуха.
- `target.inline-breakpoint-strategy always` не включаем глобально для Rust:
  на macro-heavy строках вроде `println!` LLDB может поставить несколько
  breakpoint locations на одну строку и остановиться там дважды при `<F5>`.
  Нормальная настройка у LLDB есть: `target.inline-breakpoint-strategy` со
  значениями `never` / `headers` / `always`. Оставляем штатное поведение LLDB
  (`headers`), потому что оно ищет inline locations в заголовочных/include-like
  файлах, но не размножает обычные implementation line breakpoints. `always`
  нужен для специальных C/C++ проектов, где `.c/.cpp` файлы включаются через
  `#include` или код сильно комбинируется build system'ой; для обычного Rust
  это не дефолт и на макросах ведёт себя хуже.
  Не делаем авто-фильтр "если второй stop на той же строке, продолжить":
  это был бы костыль на уровне UI/DAP, который может пропустить реальную
  остановку на другой breakpoint location.

### Output: console vs REPL

Внутри dap-view есть две похожие секции, разница важна:

- **Console** (`<leader>m1`) - реальный PTY-буфер, открытый адаптером
  через `runInTerminal` reverse-request. stdin / stdout / TTY-фичи
  (цвета, курсор) - всё работает как в обычном терминале. Это наш
  стандартный канал для вывода программы. Если в активной сессии
  PTY ещё не открыт - секция показывает `No terminal for the current
  session`.
- **REPL** (`<leader>m6`, `<leader>dR`) - канал DAP-протокола: тут
  работают `:Continue`, `:Next`, evaluate выражений, и в него же
  падают `output` ивенты, которые адаптер шлёт в обход PTY (например,
  логи самого адаптера). Stdin программы тут не работает.
  Подтверждается `lazy/nvim-dap/lua/dap/session.lua`: `Session:event_output
  -> repl.append(...)`.

Стандарт в нашем `dap.lua` и явных `launch.json` configs:
**Rust использует `console = "integratedTerminal"`, Python использует
`console = "internalConsole"` + `redirectOutput = true`, Go использует
`outputMode = "remote"`**.

| Адаптер | Конфиг | Output идёт в |
|---|---|---|
| **codelldb** (Rust/C/C++) | `console = "integratedTerminal"` | Console |
| **delve** (Go)            | `outputMode = "remote"`           | REPL    |
| **debugpy** (Python)      | `console = "internalConsole"` + `redirectOutput = true` | REPL |

**Почему Go - исключение.** В `mode = "debug"` delve компилит и
запускает бинарь сам через `go build`, и НЕ уважает поле
`console = "integratedTerminal"` (по крайней мере в v1.23.x: stdout
просто теряется). `outputMode = "remote"` - нативный delve-флаг,
который надёжно шлёт stdout через DAP `output` events. Поэтому для
Go вывод программы лежит в **REPL**, а не в Console. После старта
Go-сессии переключаешься в REPL: `<leader>m6` или `<leader>dR`.

Почему не `internalConsole` / `outputMode = "remote"` (захват stdout
адаптером и DAP-ивенты в REPL):

- **codelldb на Windows** не захватывает stdout от Rust бинарей с
  `internalConsole` - REPL остаётся пустым. Известная проблема
  адаптера, не наш баг. С `integratedTerminal` PTY получает всё.
- **debugpy** с `integratedTerminal` на Windows может открывать отдельный
  системный console-subprocess для python, который висит как левое окно и
  перехватывает фокус. Поэтому для Python используем `internalConsole` +
  `redirectOutput=true`; stdout/stderr идут через DAP `output` events в REPL.
  Generated Python configs уже такие; проектные `launch.json` надо писать так
  же явно.
- **delve**: оба варианта живут, но `integratedTerminal` гомогенизирует
  поведение со всеми остальными.

В `launch.json.example` рядом с этим nvim-конфигом лежит эталонный шаблон
только с явными проектными configs. Когда заводится новый `.vscode/launch.json`
в проекте - копируется оттуда и правятся пути. Проектная копия остается
локальной и не коммитится в этот nvim-дистрибутив.

Current-file запуск не хранится в `.vscode/launch.json`, а генерируется в
`plugins/dap.lua`, чтобы не копировать одинаковые пункты в каждый проект. После
явных launch configs nvim добавляет для текущего файла:

- Rust: `Current Rust file bin` и `Current Rust file bin (args)`.
- Go: `Current Go package` и `Current Go package (args)`.
- Python: `Current Python file` и `Current Python file (args)`.

`(args)`-варианты спрашивают строку через `vim.ui.input` и разбирают её в argv
с поддержкой пробелов в кавычках.

Для Rust `program` резолвится через `cargo metadata`: если текущий файл является
Cargo `bin`/`example` target, запускается именно он; иначе используется package
bin или единственный доступный target. Перед стартом работает
`preLaunchTask = "cargo build (debug)"` через Overseer.

Для Go generated config берёт папку текущего файла через `${fileDirname}` и отдаёт
её delve как `program`. Это штатный DAP/VS Code вариант для `dlv debug
<package-dir>`. Вывод Go, как и раньше, идёт в REPL через `outputMode = "remote"`,
поэтому после старта Go-сессии смотреть `<leader>m6`.

`default_section = "console"` в dap-view (`plugins/dap.lua`) и
`mode_debug` (`config/panels.lua`) - после F5 сразу видно вывод
программы. Если нужны watches / breakpoints / scopes / repl -
переключаешься через `<leader>m2..m6`.

### Per-Project Debug Configs (`.vscode/launch.json`)

DAP-овский идиоматичный формат - VS Code-овский `.vscode/launch.json`. Тот же
файл читают VS Code, Helix, Zed, IntelliJ и сам nvim-dap, поэтому коммитится
в репо и переносится между редакторами.

Поведение в этом конфиге:

- Файл ищется вверх от текущего буфера (`vim.fs.find`) и в CWD. Найденные
  configs всегда идут первыми в F5 picker и не фильтруются по текущему filetype.
- После явных configs nvim добавляет generated current-file configs для текущего
  Rust/Go/Python файла. Так можно держать проектные сценарии в `launch.json`, а
  типовые "запусти текущий файл" - в общей nvim-логике.
- Один итоговый config -> F5 запускает без меню. Несколько -> `vim.ui.select` с
  названием и источником (`launch.json` или `current file`) каждого пункта.
- Поддерживается JSONC: `// line` и `/* block */` комментарии, trailing
  commas. Pre-pass снимает их вручную, поэтому файл парсится и на старых
  nvim, где `vim.json.decode` не знает `skip_comments`.
- Дальше конфиг прогоняется через `dap.ext.vscode._load_json`, что даёт
  бесплатно две VS Code-фичи:
  - **OS overrides**: ключи `windows`, `linux`, `osx` на верхнем уровне
    конфига сливаются в основной (`vim.tbl_extend("force", ...)`), так что
    можно держать кросс-OS-варианты `program` в одном файле.
  - **Inputs**: `${input:<id>}` в значениях полей резолвится из секции
    `inputs` лаунча. `type: "promptString"` -> `vim.ui.input`,
    `type: "pickString"` -> `vim.ui.select`. Прокидываются прямо в
    `dap.run` через `__call` metatable, поэтому каждый запуск спрашивает
    значения заново.
- При ошибке парсинга - notification, явные configs пропускаются, но generated
  current-file configs все равно остаются доступными, F5 не зависает.
- Активной сессии F5 не показывает picker, а делает обычный `dap.continue()`.

Минимальный пример:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Run cmd/server",
      "type": "go",
      "request": "launch",
      "mode": "debug",
      "program": "${workspaceFolder}/cmd/server",
      "args": ["--config", "configs/dev.yaml"],
      "env": { "LOG_LEVEL": "debug" }
    },
    {
      "name": "Attach :2345",
      "type": "go",
      "request": "attach",
      "mode": "remote",
      "host": "127.0.0.1",
      "port": 2345
    }
  ]
}
```

Поддерживаемые макросы (общие DAP/VS Code): `${workspaceFolder}`, `${file}`,
`${fileBasenameNoExtension}`, `${env:VAR}`. Поля `args`/`program` могут быть
строкой, массивом или (в Lua-варианте) функцией; в JSON - только строкой
или массивом.

### Версии тулзов (delve, debugpy, codelldb)

Идиоматическая модель в этом конфиге: разные слои отвечают за разное.

- **Language toolchain** (`go`, `rustc`, `python`, `node`) - это не задача
  nvim. Управляется системно или через `mise`/`asdf`/`rustup`/`pyenv`. Пин
  на проект - стандартными файлами (`go.mod` toolchain directive,
  `rust-toolchain.toml`, `.python-version`, `.tool-versions`).
- **Editor tooling** (`delve`, `debugpy`, `gopls`, `rust-analyzer` и т.п.) -
  может уже быть установлен системой, VS Code/GoLand или руками через
  `go install`. Mason остается bootstrap/fallback для новой машины.
- **DAP plugin glue** - `nvim-dap-go`/`nvim-dap-python`/наша обвязка в
  `plugins/dap.lua`. Версии плагинов фиксируются в `lazy-lock.json`.

Delve не ставится Go "по одной копии на каждую версию Go". Обычная установка:

```bash
go install github.com/go-delve/delve/cmd/dlv@latest
```

`go install` кладет executable в `GOBIN`, а если `GOBIN` пустой - в
`GOPATH/bin` (`~/go/bin` или `%USERPROFILE%\go\bin` по умолчанию). IDE вроде
VS Code Go по умолчанию тоже используют `$GOPATH/bin`, если не задан отдельный
tools path.

Наша логика выбора `dlv`:

1. явный override: `vim.g.forge_dlv_path`, `$FORGE_DLV_PATH`, `$DLV_PATH`;
2. Go tool bin: `GOBIN/dlv`, затем все `GOPATH/bin/dlv`;
3. `dlv` из `PATH`;
4. Mason-managed `dlv` из `stdpath("data")/mason/bin`.

Если найдено несколько `dlv`, выбирается самый новый по `dlv version`.
Посмотреть, что реально найдено и что выбрано: `:DapGoDlvInfo`.

Не использовать `--check-go-version=false` как постоянное решение: Delve
ставит этот check не случайно, рассинхрон версий runtime и debugger дает
тонкие баги в чтении стека/goroutine state.

Python debug uses two separate paths:

1. **Project Python** - the interpreter used to run your code. Resolver order:
   `vim.g.forge_python_path` / `$FORGE_PYTHON_PATH`, active `VIRTUAL_ENV`,
   active `CONDA_PREFIX`, project `.venv`/`venv`/`.env`/`env`, then `python3`
   or `python` from `PATH`.
2. **debugpy adapter** - the DAP adapter process. Resolver order:
   `vim.g.forge_debugpy_adapter` / `$FORGE_DEBUGPY_ADAPTER`, project venv
   `debugpy-adapter`, `debugpy-adapter` from `PATH`, then Mason
   `debugpy-adapter.exe` as bootstrap fallback. Mason's `python.exe` is only a
   last fallback if no adapter executable exists.

Check what will be used with `:DapPythonInfo`.

## Icons / Fonts

Красивые DAP/devicons требуют поддержки glyph'ов в шрифте терминала. Neovim не
может принести эти glyph'ы сам: если Windows Terminal/WezTerm/Alacritty
использует обычный шрифт без Nerd Font/Codicons, вместо иконок будут ромбы с
вопросами.

По умолчанию включен безопасный ASCII fallback. После настройки шрифта терминала
на Nerd Font можно включить красивые иконки:

```lua
vim.g.have_nerd_font = true
```

Эту строку нужно поставить до загрузки `plugins/dap.lua`, например в
`lua/config/options.lua`.

## Tests

## Jobs / Tasks

Плагин: `stevearc/overseer.nvim`.

Что можно делать:

- Запускать проектные задачи из `cargo`, `make`, `.vscode/tasks.json` и других источников.
- Смотреть список задач и их статус в нижней панели.
- Открывать output завершенных задач, в том числе после окончания build.
- Использовать `preLaunchTask` для DAP: Rust debug запускает `cargo build (debug)` через overseer.

Клавиши:

- `<leader>mj` - режим Jobs.
- `<leader>jj` - открыть Jobs panel.
- `<leader>jr` - выбрать и запустить задачу.
- `<leader>jt` - toggle task list снизу.
- `<leader>ja` - действие над задачей.
- `<leader>js` - shell-команда как overseer task.

## Tests

Плагин: `nvim-neotest/neotest`.

Адаптеры:

- Rust: `rouge8/neotest-rust`.
- Go: `nvim-neotest/neotest-go`.
- Python: `nvim-neotest/neotest-python`.

Что можно делать:

- Смотреть дерево тестов.
- Запускать ближайший тест, текущий файл или весь проект.
- Запускать ближайший тест под DAP.
- Смотреть output текущего теста или общий output panel.
- Включать watch для текущего файла.

Клавиши:

- `<leader>mt` - режим Tests.
- `<leader>Tp` - toggle Tests panel.
- `<leader>Tt` - run nearest.
- `<leader>Tf` - run current file.
- `<leader>TA` - run all from current working directory.
- `<leader>Td` - debug nearest test.
- `<leader>Ts` - stop.
- `<leader>Ta` - attach.
- `<leader>To` - output for selected/nearest test.
- `<leader>TO` - output panel.
- `<leader>Tw` - watch current file.

Prerequisites:

- Rust adapter использует `cargo-nextest`: `cargo install cargo-nextest`.
- Go использует обычный `go test`.
- Python настроен на `pytest`.

## Search

Плагин: `MagicDuck/grug-far.nvim`.

Что можно делать:

- Искать по проекту через `ripgrep`.
- Делать project-wide replace.
- Отправлять результаты в quickfix.

Клавиши:

- `<leader>ms` - режим Search.
- `<C-S-f>` - Search panel.
- `<leader>sF` - Search panel.
- `<leader>sR` - Search/replace panel.
- В visual mode `<leader>sV` - поиск внутри выделения.

Prerequisite: нужен `rg` (`ripgrep`) в PATH.

## Git

Плагины: `gitsigns.nvim`, `Neogit`, `diffview.nvim`, `neo-tree git_status`.

Что можно делать:

- Видеть изменения в gutter.
- Навигироваться по кускам изменений.
- Добавлять в будущий коммит, отменять и просматривать отдельные куски изменений.
- Открывать Git mode с измененными файлами.
- Открывать полноценный Magit-like UI.
- Открывать IDE-style diff: слева дерево только измененных файлов, справа diff выбранного файла.
- Редактировать актуальную версию файла прямо в правой части diff view.
- Открывать историю файла.

Клавиши:

- `<leader>mg` - режим Git.
- `]h` / `[h` - следующий/предыдущий кусок изменений.
- `<leader>ghs` - добавить текущий кусок изменений в будущий коммит.
- `<leader>ghr` - отменить текущий кусок изменений.
- `<leader>ghp` - посмотреть текущий кусок изменений.
- `<leader>ghu` - убрать текущий кусок из будущего коммита, но оставить изменения в файле.
- `<leader>ghb` - показать историю текущей строки.
- `<leader>ghB` - включить/выключить inline-историю строки.
- `<leader>gg` - Neogit status tab.
- `<leader>gG` - Neogit status split.
- `<leader>gd` - открыть diff view по измененным файлам.
- `<leader>gF` - перейти в дерево файлов внутри diff view.
- `Ctrl+E` внутри diff/history view - показать или скрыть список измененных файлов/коммитов, как `<leader>b`.
- `Alt+j` / `Ctrl+PageDown` внутри diff view - следующий измененный файл из дерева diff, без перехода к обычным открытым вкладкам.
- `Alt+k` / `Ctrl+PageUp` внутри diff view - предыдущий измененный файл из дерева diff.
- `Alt+h` внутри diff view - левая сторона diff: старая/index-версия.
- `Alt+l` / `Alt+e` / `F7` внутри diff view - правая редактируемая рабочая версия файла.
- `<leader>gq` или `q` внутри diff view - закрыть diff view.
- `<leader>gD` - история текущего файла.

Diff view устроен как в IDE-review:

- Слева дерево измененных файлов с реальной структурой папок.
- `Enter`/`l` на файле открывает его diff.
- `h`/`l` на папках сворачивает/разворачивает дерево.
- `Ctrl+E` показывает или скрывает список слева/снизу. В file history это список коммитов.
- `Alt+j` / `Alt+k` переключает только измененные файлы внутри diff view; обычные открытые вкладки сюда не попадают.
- `Alt+h` / `Alt+l` переключает фокус между левой и правой сторонами diff.
- `Alt+e` / `F7` переводит фокус в правую редактируемую рабочую версию файла.
- `<leader>e` закрывает Diffview и переключает workspace в File Explorer.
- Справа две версии файла: слева старая/индекс, справа актуальный файл.
- Редактировать надо правую часть: это рабочий файл на диске.
- Неизмененные строки не сворачиваются автоматически; весь файл остается видимым.
- Левая и правая стороны diff включают native Vim `scrollbind`/`syncbind`, поэтому при прокрутке выбранного файла должны двигаться вместе.
- Внутристрочные изменения подсвечиваются усиленными highlight-группами Diffview, чтобы добавленные/удаленные символы были видны жестче, чем в обычной теме.

## Output Wrapping

Для output-буферов включен перенос строк по ширине окна:

- `dap-repl`
- `dapui_console`
- `dap-terminal` (наш свежий PTY-buffer для codelldb на каждую сессию)
- `OverseerList`
- `neotest-output-panel`

Настройка лежит в `lua/config/options.lua`.

> **Note.** Если в коде встретятся ссылки на `dap-view` / `dap-view-term`
> — это легаси от старого pre-edgy конфига (см. git `c3fc6fb`).
> Сейчас debug bottom — `dap-terminal` (для Rust/codelldb) или
> `dap-repl` (для Go/Python+internalConsole). Подробнее почему именно
> так — в `DEBUG_JOURNEY.md` §1.

## Как Добавлять Новый Режим

1. Добавить plugin spec в `lua/plugins/<area>.lua`.
2. Добавить `mode_*`, `open_*` или `toggle_*` функцию в `lua/config/panels.lua`.
3. Внутри `mode_*` закрыть чужие панели через `close_activity("<mode>")`.
4. Добавить keymap в `lua/config/keymaps.lua`.
5. Добавить группу/подсказку в `lua/plugins/ui.lua`, если нужен новый leader group.
6. Если режим создает output-буфер, добавить его filetype в wrap-настройку.
