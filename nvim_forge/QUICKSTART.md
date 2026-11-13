# Шпаргалка на каждый день

> **Windows + WezTerm:** часть сочетаний (`Ctrl+Shift+буква`, `Ctrl+Enter`, `Ctrl+Space`, `Ctrl+/`, `Ctrl+.`, F-клавиши с модификаторами) через ConPTY до nvim не доходит (WT-KBD-6); сочетания nvim_forge WezTerm доставляет подменой. Список и альтернативы — `docs/WEZTERM.md`, раздел 12.

Лидер: **Space**.
Все маппинги отображаются в which-key — нажми `<Space>` и подожди.

Windows: после явной `powershell -NoProfile -File scripts/prepare-windows-sdk.ps1 -Download`
запускай `.\nvim_forge.cmd`: он использует SDK с исправлением ConPTY.
Прямой `nvim` остаётся системным. На Linux/macOS — `./nvim_forge.sh` и
официальный SDK; сборка ничего не устанавливает при обычном старте.
Подготовка/диагностика: `tests/diagnostics/README.md`.

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
| `<leader>of` / `<leader>oP` | Open folder path as project |
| `<leader>oh` | Open home / Alpha |
| `<A-h>` / `<A-l>` | Prev / next open file tab |
| `<A-w>` | Close current file/context |
| `<S-h>` / `<S-l>` | Prev / next buffer |
| `<leader>bd` | Close buffer |
| `<leader>br` | Вернуть последний закрытый файл с курсором |

Файловые вкладки сверху, picker `Space b b` / `Space f b` и цикл используют
одну модель: обычные listed буферы, включая ещё не загруженные; панели и
terminal в файловый цикл не входят. Из панели выбор/переключение переводит
файл в существующее окно кода. Neovim tabpages и вкладки WezTerm от этого
не меняются.

При закрытии изменённого файла (`Space b d`, `F4`, `Alt+w`) сначала выбери
`s` — Save, `d` — Discard, `c`/Esc/Enter — Cancel (Cancel по умолчанию).
До решения окна и текст сохраняются; autosave закрываемого буфера временно
приостановлен. При ошибке Save файл остаётся открытым. Для unnamed сначала
задай имя через `:write путь` — отдельный Save As dialog пока не добавлен.
После последнего файла появляется alpha; `Space b r` возвращает последний
закрытый существующий файл и курсор в том же окне. История хранит до 20 путей
в текущем процессе, без копий отброшенного текста. В terminal сначала `F7`
для фокуса в коде либо Esc Esc для normal; затем работают normal-команды.

Если файл/worktree удалён с диска, открытый текст остаётся в буфере.
Предупреждение Files показывается без остановки ввода; autosave после
обнаружения удаления удерживается. `:write` явно восстановит файл, если
родительская папка существует; `:saveas путь` сохранит в другое место.
После успешной записи autosave возвращается. `Space b d` закрывает буфер
с прежним Save/Discard/Cancel. Повторная проверка файла не требует Enter.

### Общий маршрут рабочих панелей — Space w

В **normal mode**:

| Клавиши | Действие |
|---|---|
| `Space w h/j/k/l` | Фокус в соседнее окно |
| `Space w d` | Открыть/сфокусировать Locals |
| `Space w c` | Сфокусировать/вернуть текущий debug Output |
| `Space w a` | Открыть/сфокусировать Outline слева |
| `Space w e` | Открыть/сфокусировать Files слева |
| `Space w g` | Открыть/сфокусировать Neogit status справа |
| `Space w t` | Открыть/сфокусировать Tests справа |
| `Space w r` | Открыть/сфокусировать Test Output снизу |
| `Space w f` | Открыть/сфокусировать Search снизу |
| `Space w i` | Общая консоль IDE Logs: ошибки, missing tools, native журналы |
| `Space w b` | Открыть/сфокусировать Tasks снизу |
| `Space w T` | Открыть/сфокусировать managed Terminal |
| `Space w x` | Открыть/сфокусировать Problems/Trouble |
| `Space w 0` | Вернуться в код |
| `Space w q` | Скрыть рабочую панель; в коде — прежнее закрытие окна |
| `Space w z` | Развернуть текущую рабочую панель / вернуть её на место |
| `Space w ?` | Помощь по управлению |

В этих панелях normal `q` скрывает панель, `?` открывает помощь, `Esc` возвращает
из развёрнутого вида, иначе переводит фокус в код. Левая группа Debug
(Locals/Watch/Stack/Breakpoints) скрывается целиком. Enter и j/k сохраняют
штатные действия списка/дерева. `[focus]` в заголовке показывает активную область.
В Terminal/Trouble q скрывает текущее окно, сохраняя другие views и jobs.
Trouble: Enter/zo/zc используют выбор из zoom, `g?` открывает штатную справку.
Все основные сочетания — в [краткой шпаргалке](../docs/PANEL_KEYS.md).
Навигация и скрытие не продолжают/не завершают сессию и не очищают Output.

Возврат Debug в код пропускает terminal и floating preview. `Space w 0`
при отсутствии main может создать обычное окно; `F7` фокусирует существующее
окно редактора и сохраняет отдельное поведение Diffview.

`Space w c` и `Space D c` возвращают видимый/последний канал Debug Output.
`Space m d` открывает Debug View, `Space du`/`Space dD` переключают всю группу;
после hide или завершения сессии они сохраняют канал и его текст. Без запусков
используется REPL. Явные `Space dR` (REPL) и `Space m o` (Console) запоминаются;
`Space D v` открывает Variables. F5 выбирает канал запуска: Rust/CodeLLDB и
integratedTerminal — PTY, Go remote — REPL независимо от console, остальные
internalConsole — REPL. Продолжение возвращает существующий PTY, следующий
запуск получает свежий. Открытие панели само не запускает отладку.

В insert/terminal печатные q/? остаются вводом. Из terminal сначала
`Esc`, `Esc` для normal или `F7` для фокуса в коде. Прежние `Space D v`, `Space D c`,
`Space D 0`, `F6/F7`, `Space w s/v/o` и команды раскладок сохранены.

Tests: `Enter` раскрывает список, `i` открывает выбранный тест в коде,
`r` запускает его, `o` показывает вывод, `g?` — полная справка Neotest.
`Space w r` возвращает последний Test Output без повторного запуска.
Tasks: `Enter` — меню действия, `o` — вывод, `Ctrl+s/v` — вывод в split,
`g?` — справка Overseer. Скрытие списка не останавливает работающую задачу.
Search: `i` — ввод запроса, `Tab` — следующее поле, normal `Enter` — найденное
место в коде, `g?` — search/replace. `q` и смена нижней панели сохраняют
запрос и результаты; переход из zoom использует выбранную там строку.

Outline: `Space l o` и `Space s o` переключают панель, `Space p o` применяет
раскладку Outline. `j/k` выбирают символ, `h/l` сворачивают/раскрывают дерево,
`Enter`/`o` переходят в код, `v/s` открывают символ в split, `g?` показывает
полную справку Aerial. Переход подтверждается явно; движение по списку не
прокручивает код. Источник — LSP, затем Treesitter; без backend виден `No symbols`.
При смене файла список обновляется. Outline и Explorer используют один левый
слот и заменяют друг друга; переключение не закрывает открытые файлы.

Дерево Files: `Space e` переключает панель, `Space E` показывает текущий файл.
`bf/bb/bg` и `</>` переключают Files/Buffers/Git, `g?` показывает полную
штатную справку. `[focus]` виден рядом с selector, подписи на узкой панели
сокращаются. Управление файлами в Files:

| Клавиши | Действие |
|---|---|
| `a` / `A` | Создать файл / каталог |
| `r` | Переименовать файл или каталог |
| `m` | Переместить: диалог с полным путём назначения |
| `x`, затем каталог и `p` | Вырезать / вставить в выбранный каталог |
| `y`, затем каталог и `p` | Копировать файл или каталог |
| `c` | Копировать с новым именем |
| `d`, затем `y`, `Enter` | Удалить чистый файл / каталог; `n`, `Enter` или `Esc` отменяют |
| `Enter` / `o` | Открыть файл в коде |
| `h/l` | Свернуть / открыть узел |

В диалоге `Enter` подтверждает, `Esc` отменяет только ввод; q/? остаются
обычным текстом. В дереве `Esc` возвращает фокус в код, сохраняя панель.
Подтверждение или файловая команда из zoom сначала возвращает выбранную
строку в исходное окно, затем выполняет действие. Переименование/перемещение
сохранённого открытого файла обновляет путь буфера; каталог — пути дочерних
буферов. При занятом имени rename отменяется; move предлагает другой путь,
`Esc` сохраняет оба файла. Copy читает версию на диске и сохраняет правки
исходного буфера. `d` отменяется, если файл или скрытый descendant каталога
имеет несохранённый текст; повторная проверка идёт после Yes. Сохрани файл
или явно закрой его с Discard и повтори. Modified rename/move имеют отдельный
штатный диалог и ещё не входят в проверенную матрицу.
Клавиши и границы — [Files workflow](../docs/FILES_WORKFLOW.md).

### Toggle панелей по слотам

Одна клавиша туда-обратно: первое нажатие открывает последний показанный
компонент в слоте, второе — закрывает весь слот.

| Клавиша | Что тогглит | Если слот был пуст — откроет |
|---|---|---|
| **`<C-b>`** / `<leader>Pt` | Левую панель (Explorer / Outline / DAP sidebar / …) | Neo-Tree explorer |
| **`<C-j>`** / `<F8>` / `<leader>Py` | Нижнюю панель (Terminal / DAP console / Tests output / …) | toggleterm |
| `<leader>Pu` | Правую панель | Neotest summary |
| `<leader>PL` / `<leader>PJ` / `<leader>PK` | Только **закрыть** левый / нижний / правый слот | — |

- `<C-b>` работает в normal / insert / terminal — старый buffers picker
  на `<C-b>` убран (buffers: `<leader>bb` / `<leader>fb`).
- `<C-j>` работает в normal / terminal (в insert mode `<C-j>` занят cmp:
  select next item в автокомплите). В insert mode используй `<F8>` или
  `<leader>Py`.
- `<F8>` — универсальный fallback во всех режимах, если терминал ест
  `<C-j>` (RDP, старые TTY).

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

Формат документа: `Space l f`, `Shift+Alt+f` или `:Format`. Если языковой
formatter доступен, используется он; иначе — подключённый LSP, затем общая
очистка пробелов. Без обоих остаётся очистка. Наличие trim больше не блокирует
gopls fallback. Для Go этот сценарий проверен на Windows/Ubuntu; Mac ещё требует
запуска. Настройки остальных языков — в [матрице](../docs/LANGUAGE_MATRIX.md).

Подсветка вхождений и эти переходы работают для слов до 4096 байт UTF-8.
На более длинном слове файл остаётся доступен для редактирования/сохранения;
на обычном слове подсветка возобновляется. Короткие слова в длинных строках
и файлах на 5000+ строк сохраняют переходы.

### Peek (как Ctrl+Click в IDE)

| Клавиша | Действие |
|---|---|
| `gpd` | Peek definitions |
| `gpr` | Peek references |
| `gpt` | Peek type defs |
| `gpi` | Peek implementations |

В списке Peek: `j`/`k` — выбор и обновление preview, `l`/`h` — раскрыть/
свернуть группу файла, `Enter` — перейти, `v`/`s` — перейти в вертикальный/
горизонтальный split. `q`, `Esc` или `Q` закрывают список и возвращают исходный
курсор. `Space l` переключает список ↔ preview; из preview закрывать через `Q`
(обычный `q` там остаётся клавишей редактора). Результаты даёт подключённый LSP;
поддержка типов/реализаций зависит от сервера.

### Postфикс-панели

| Клавиша | Действие |
|---|---|
| `<leader>xx` | Trouble: workspace diagnostics |
| `<leader>xX` | Trouble: buffer diagnostics |
| `<leader>xr` | Trouble: LSP refs / defs / impls (panel) |
| `<leader>xs` | Trouble: symbols panel |
| `<leader>so` | Outline (aerial) — Structure window |
| `{` / `}` | Prev / next symbol в outline (когда aerial открыт) |

### Автодополнение и параметры вызова

`Ctrl+j` / `Ctrl+k` выбирают предложение, `Enter` принимает выбранное.
В развёрнутой сигнатуре ввод заменяет выделенное поле; `Tab` / `Shift+Tab`
переходят между параметрами, когда меню completion закрыто.

Если уйти из текущего поля и начать ручной ввод, нетронутые предлагаемые
параметры исчезнут, а введённые аргументы сохранятся. Например,
`combine(42, right)` → перейти за вызов → `;` → `combine(42);`.
Само движение курсора текст не меняет. Очистка и новый ввод отменяются одним
`u`; `Ctrl+r` повторяет их. Это работает для простых списков параметров,
в том числе многострочных. Блочные/динамические шаблоны сохраняют свой текст.
Явный `Esc` на выделенном поле по-прежнему сворачивает весь вызов до `foo()`.

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
| `<leader>de` | Eval на паузе (выражение / выделение); `q` / `Esc` закрывает окно |
| `<leader>dR` | REPL toggle |
| `<leader>dl` | Run last config |

Go с `outputMode = "remote"` показывает stdout/stderr в нижнем REPL,
в том числе при оставшемся `console = "integratedTerminal"` в launch.json.
Текст panic появляется на паузе как `[DAP exception]` из сведений адаптера;
это не требует продолжения процесса. После продолжения добавляется настоящий
stderr. Вывод сохраняется после завершения и очищается перед новой сессией.
`<leader>dR` открывает REPL, `F7` возвращает фокус в код.

codelldb ищется при запуске конфигурации Rust/C/C++, которой он нужен.
Его отсутствие не мешает открывать Go/обычные файлы и ставить breakpoint.
При попытке запуска появится сообщение с установкой: macOS/Linux —
`:MasonToolsInstall` или `:MasonInstall codelldb`; Windows — codelldb в PATH
или `%LocalAppData%/codelldb/adapter/`. Автоматической установки при старте нет.

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
| `:DapPythonInfo` | Show selected Python/debugpy paths |

### Тесты (neotest)

Leader — пробел, команды ниже из normal mode:

| Клавиши | Действие |
|---|---|
| `Space T t` | Ближайший тест, без отладчика |
| `Space T f` | Тесты текущего файла |
| `Space T d` | Отладка ближайшего теста; `F9` — breakpoint, `F5` — continue |
| `Space T p` | Панель тестов |
| `Space T O` | Показать/скрыть Test Output |
| `Space T s` | Остановить тест |

Go-тестам нужен `gotestsum`: явно установить через `:MasonToolsInstall`
или `go install gotest.tools/gotestsum@v1.13.0`. Для discovery нужен Go parser
(`:ForgeTreesitterInstall`), для отладки — Delve. После обновления сборки
восстановить плагины из lock командой `:Lazy restore` и перезапустить Neovim.
Обычный запуск показывает pass/fail в панели и открывает Test Output.
При debug итог и `t.Log` видны в DAP REPL; адаптер помечает этот запуск
`skipped` в neotest — это ограничение интеграции, а не успешный результат.
Eval работает только на паузе; `Esc` закрывает его и после возврата в код.

## 5. Git

`Space w g` и прежний `Space g G` открывают status справа; `Space g g`
сохраняет полный отдельный tab. В status `Tab` раскрывает файл/hunk,
`s/u` выполняют stage/unstage выбранного файла или hunk, `g?` показывает
родную справку Neogit. Общая помощь — `?`.

Обычный путь без мыши: `b c` → выбрать исходную ветку → имя новой;
`c c` → сообщение commit → `Esc`, `ZZ` для подтверждения. `P u` выполняет
push в upstream (для новой ветки предлагает remote). `l l` открывает историю
текущей ветки, `b b` выбирает ветку. В log/diff сохраняются родные клавиши.

Если push отклонён: `n` отказывается от предложения force-with-lease.
В status `$` открывает историю Git-команд: найди push, `Tab` раскроет его
вывод с причиной; `q` закрывает историю, `Esc` возвращает фокус в код.
Сообщение `Press ENTER…` подтверждается Enter; недоступный remote может
показать несколько fatal сообщений подряд. Локальный commit сохраняется.
После согласования истории или исправления origin повтори `P u` в той же
сессии. HTTP credentials: Username подтверждается Enter, пароль скрыт звёздочками;
Esc отменяет ввод. После неверного пароля Enter подтверждает `Authentication
Failed`, затем Neogit снова спрашивает пароль (до трёх попыток, Username помнит).
Отмена не удаляет local commit; повтор — `P u`. Проверены synthetic HTTP Basic
на Windows/Ubuntu (§213–214); OAuth/SSH agent/real account и Mac отдельно.

Конфликты: `m m` запускает merge с выбранной веткой, `r e` — rebase на
выбранный ref. После остановки `Space g d` открывает Diffview. `Space g F`
фокусирует дерево, `Alt+e` — редактируемый результат, в том числе среднее
окно diff3; `Alt+h/l` — крайние стороны. `[x`/`]x` переходят между конфликтами,
`Space c o`/`Space c t` выбирают ours/theirs. Можно править результат обычным
вводом. Сохрани `:w`, закрой просмотр `Space g q`, открой status `Space w g`
и выполни `s` на файле. Затем `m m` завершает merge, `r r` продолжает rebase;
commit editor подтверждается `Esc`, `ZZ`. `m a`/`r a` и Yes отменяют операцию.
При rebase ours — уже перенесённая история на новой основе, theirs —
переносимый commit; это [семантика Git](https://git-scm.com/docs/git-rebase),
а не постоянные подписи «моё/чужое».

Interactive rebase: из status `r i`, в native списке commits выбери нижний
commit диапазона и Enter. В todo `j/k` выбирают строку, `gk/gj` переставляют,
`f` делает fixup в предыдущий commit. `Ctrl-c Ctrl-c` применяет список,
`Ctrl-c Ctrl-k` отменяет изменения todo и сохраняет исходную историю.
Штатная отмена теперь сообщает `Rebase aborted`; настоящий conflict остаётся
ERROR с обычным `r a`/Yes. Проверено Windows/Ubuntu (§212); после обновления
повтори `:Lazy build neogit` и перезапусти редактор.

Worktree: `w W` → путь → исходный ref → имя ветки; `w g` — список/посещение;
`w D` — выбор и подтверждение удаления. На dirty worktree второй вопрос
предлагает force: ответ No сохраняет данные. При удалении текущего worktree
Neogit сначала возвращается в основной, даже если затем отказать force.

После обновления существующей установки один раз выполнить `:Lazy build neogit`
и `:Lazy build gitsigns.nvim`, затем перезапустить редактор. Первая команда
готовит исправления удаления текущей папки, очистки Git output и sequence
abort classification (IDE-034/043/123),
вторая — фоновых Git
запросов, если worktree исчез до завершения initial signs (IDE-035),
и ненужного cwd живого object read (IDE-038). После обновления этого
исправления повторить Gitsigns build; прежний известный payload обновляется явно.
После обновления IDE-043 повторить Neogit build, даже если он уже выполнялся
для IDE-034, затем перезапустить редактор. Ошибка/история сохраняют полезный
текст и обычные пути без служебного title/hyperlink терминала.
Для чистого worktree лишнего force prompt больше нет; отложенные signs
не должны блокировать ввод после удаления. Подготовка проверяет версию/содержимое;
обычное открытие Git или файла исходники плагинов не меняет.
Команды вне редактора и отмена — [patches/README.md](patches/README.md).

Корень рабочей папки сохраняется при переключении между открытыми файлами.
Worktree/Open folder меняют его явно; `:ProjectRoot` определяет корень по
текущему файлу по запросу. Старые буферы остаются по прежним путям. После
создания worktree вернись в код и открой нужный файл относительно нового cwd.
Открытие обычного файла из другой папки само по себе больше не меняет cwd.

`w g` можно повторять, пока предыдущий status ещё загружается. История Neogit
использует штатный Unicode-граф из того же списка commit: быстрый visit не
смешивает старую историю с графом нового worktree. После обновления Head и
`l l` относятся к выбранной рабочей папке.

`Space g q`, `q`, `F4`/`Alt+w` и `:DiffviewClose` закрывают diff/history и во
время загрузки. Фокус возвращается сразу; загружающийся tab может ненадолго
оставаться в фоне до завершения безопасной очистки. Повторный close из кода
не закрывает файл. `Space e` из просмотра возвращает Explorer в исходном tab.
Два отказа push покрыты `git-errors.test.lua` (IDE-GIT-10); merge/rebase
continue/abort — четырьмя `git-conflicts.test.lua` (IDE-GIT-11) на Windows/Ubuntu.
Interactive sequence editor — `git-sequence.test.lua` (IDE-GIT-13); HTTP
cancel/rejection/retry и настоящий pre-push — `git-auth.test.lua` (IDE-GIT-14).
После обновления этих backports: `:Lazy build neogit`, затем перезапуск.
Быстрый worktree visit
IDE-028 проверяется отдельным `worktree-refresh.test.lua` (FIXLOG §91).

| Клавиша | Действие |
|---|---|
| `<leader>gd` | Diff view: дерево измененных файлов слева, diff справа |
| `<leader>gF` | Перейти в дерево файлов внутри diff view |
| `Ctrl+E` | Внутри diff/history view: показать или скрыть список слева/снизу |
| `Alt+j` / `Ctrl+PageDown` | Внутри diff view: следующий измененный файл, без перехода к обычным открытым вкладкам |
| `Alt+k` / `Ctrl+PageUp` | Внутри diff view: предыдущий измененный файл |
| `Alt+h` | Внутри diff view: левая сторона diff, старая/index-версия |
| `Alt+l` / `Alt+e` / `F7` | Внутри diff view: правая редактируемая версия файла |
| `<leader>gq` / `q` | Закрыть diff view |
| `<leader>e` | Закрыть diff view и открыть File Explorer |
| `<leader>gD` | История текущего файла |
| `<leader>gg` | Полная Git-панель Neogit в отдельной вкладке |
| `<leader>gG` | Полная Git-панель Neogit в split |
| `<leader>mg` | Git-раздел с измененными файлами |
| `<leader>gS` | Toggle Git-раздела |
| `]h` / `[h` | Следующий / предыдущий кусок изменений |
| `<leader>ghs` | Добавить текущий кусок изменений в будущий коммит |
| `<leader>ghr` | Отменить текущий кусок изменений |
| `<leader>ghp` | Посмотреть текущий кусок изменений |
| `<leader>ghu` | Убрать текущий кусок из будущего коммита |
| `<leader>ghb` | Показать историю текущей строки |
| `<leader>ghd` | Diff текущего файла против index |
| `<leader>ghD` | Diff текущего файла против HEAD~ |
| `<leader>ghB` | Toggle inline-истории строки |

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

Файловые вкладки:

| Клавиша | Действие |
|---|---|
| `Alt+h` | Предыдущая открытая вкладка файла |
| `Alt+l` | Следующая открытая вкладка файла |
| `Alt+w` | Закрыть текущий файл/контекст |
| `Ctrl+PageDown` | Следующая открытая вкладка файла |
| `Ctrl+PageUp` | Предыдущая открытая вкладка файла |

Панели и текущий контекст:

| Клавиша | Действие |
|---|---|
| `Alt+e` / `F7` | Перейти в редактируемый файл/код |
| `Alt+q` | Закрыть текущий контекст: Diffview, tool-window или текущий файл |
| `F4` / `Ctrl+F4` | То же закрытие, запасной вариант |

Те же действия доступны командами:

| Команда | Действие |
|---|---|
| `:ForgeFocusEditor` | Редактируемый файл/код |
| `:ForgeCloseContext` | Закрыть текущий контекст |
| `:ForgeBufferNext` / `:ForgeBufferPrev` | Следующий/предыдущий открытый файл |

Нативный Vim-префикс `<C-w>` не переопределяется, но в этой сборке он не основной способ навигации:

| Клавиша | Действие |
|---|---|
| `<leader>wv` / `<leader>ws` | Vsplit / hsplit |
| `<leader>wh/j/k/l` | Перейти в окно слева / снизу / сверху / справа |
| `<leader>wq` / `<leader>wo` | Закрыть текущее / оставить только текущее |

## 8. Терминал

| Клавиша | Действие |
|---|---|
| `<leader>tt` / `<C-t>` в normal | Скрыть/вернуть managed terminal снизу, сохранив job и вывод |
| `Space w T` в normal | Открыть/сфокусировать Terminal; повтор сохраняет видимое окно |
| `<C-\>` из normal вне terminal buffer | Тот же toggle терминала |
| `<C-\>`, затем `<C-n>` | Выйти из terminal input в normal; повтор безопасен |
| `<Esc><Esc>` | Из terminal input в normal mode |
| `<F7>` | Вернуть фокус в код |

Shell выбирается конфигом ToggleTerm: доступный pwsh либо `vim.o.shell`.
В terminal-normal одиночный Ctrl-\ остаётся стандартным префиксом Neovim;
для скрытия/возврата терминала здесь используйте Ctrl-t или Space tt.
Эти normal-команды работают после выхода из terminal input; печатный текст
в режиме ввода продолжает получать запущенная программа.

## 9. Сессии (persistence)

| Клавиша | Действие |
|---|---|
| `<leader>qs` | Восстановить сессию для cwd |
| `<leader>qS` | Выбрать из списка |
| `<leader>ql` | Восстановить последнюю |
| `<leader>qd` | Не сохранять текущую |

При обычном выходе и переключении проекта Files сохраняет свой вид отдельно
для каждой вкладки: открыто ли дерево, его корень, раскрытые каталоги, выбранный
узел, прокрутку и ширину. После восстановления фокус остаётся в коде; скрытое
дерево остаётся скрытым. При меньшем терминале ширина адаптируется с учётом
минимума Edgy. Если выбранный узел удалён, дерево возвращается к корню.
Возврат фокуса к тому же файлу сохраняет просмотр дерева; открытие другого
файла включает обычное следование. Ширина Files меняется штатными `Ctrl-w >`
и `Ctrl-w <` (по две колонки). Остальные панели и живые процессы ещё не входят
в этот снимок. Проверки и границы платформ — [рабочий план](../docs/IDE_ROADMAP.md).

## 10. Управление плагинами

| Клавиша | Действие |
|---|---|
| `<leader>L` | Lazy UI (плагины) |
| `<leader>M` | Mason UI (LSP/DAP/форматтеры) |

| Команда | Действие |
|---|---|
| `:Lazy update` | Обновить плагины |
| `:Lazy log` | Лог последних операций lazy |
| `:MasonToolsInstall` | Явно установить отсутствующие инструменты каталога |
| `:MasonToolsInstallSync` | То же синхронно для setup-скриптов |
| `:MasonToolsUpdate` | Обновить инструменты mason |
| `:ForgeTreesitterInstall` | Явно установить парсеры сборки |
| `:TSUpdate` | Обновить treesitter-парсеры |
| `:checkhealth` | Полный отчёт по подсистемам |
| `:LspInfo` | Активные LSP-клиенты в текущем буфере |
| `:LspLog` | Лог LSP |
| `:messages` | Все сообщения с момента старта |

Подготовленная сборка не скачивает инструменты/парсеры при обычном запуске.
После их явной установки перезапусти редактор для включения LSP.

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

## JavaScript / Node.js

Node.js с npm устанавливается явно. Project-local TypeScript Language Server,
TypeScript, Prettier и Jest имеют приоритет над общими tools; debug требует
явного `:MasonInstall js-debug-adapter`. После обновления сборки выполнить
`:Lazy install` для нового neotest-jest. Для существующей установки также
выполнить `:Lazy build neotest` и перезапустить редактор: применится проверяемый
по pin/SHA патч путей nearest/file. Обычный startup plugin source не меняет.

`Space j n` / `:NodeRun` выбирает package script; `Space j N` / `:NodeRunFile`
запускает текущий JS в Tasks. F5 работает и без launch.json; F9 — breakpoint,
Space d e — eval. Jest: Space T t / T f / T d — nearest / file / debug.
Панели: Space w b — Tasks, w t — Tests, w r — Test Output, w c — DAP Output,
w T — Terminal, w x — Problems/Trouble; [шпаргалка](../docs/PANEL_KEYS.md).
Установка, ограничения и все команды: [Node workflow](../docs/NODE_WORKFLOW.md).

## Python project venv

Project .venv используется и Pyright, и Python DAP без shell activation.
Для LSP нужны доступные Pyright/Ruff, для tests/debug — pytest/debugpy в среде.
Общий override interpreter: forge_python_path/FORGE_PYTHON_PATH; явный
settings.python.pythonPath сохраняется. После обновления выполнить
`:Lazy build nvim-dap` и restart: подготовится pin/SHA патч ложного WARN после
ожидаемого закрытия adapter. Реальные неожиданные adapter ошибки остаются видимыми.
Полная подготовка и команды: [Python workflow](../docs/PYTHON_WORKFLOW.md).

## Rust Cargo workspace

SDK с rust-analyzer/rustfmt/clippy/rust-src готовится явно; для Tests нужен
cargo-nextest, для debug — CodeLLDB. После обновления выполнить
`:Lazy build neotest-rust` и restart: применится pin/SHA backport выбора
тестов/executable и сохранения debug output. F5 сам собирает Cargo binary;
Space T t / T f / T d — nearest / file / debug. Подготовка, ограничения и
команды: [Rust workflow](../docs/RUST_WORKFLOW.md).

### Bash debug

`:MasonInstall bash-debug-adapter` → `:BashDebugPrepare` → `.sh` → F9 → F5.
После обновления adapter подготовку повторить (IDE-128, безопасный Stop). Windows использует
готовый default WSL2 Linux, Linux/Mac — Bash4+. Default Output — общий native
PTY; F5 продолжает, Shift-F5/Space d q останавливают. Space d w добавляет Watch
(`$answer`), Space d e — Evaluate, Space w c/d — Output/переменные и стек.
Поддержан type=bashdb launch.json с args/env/cwd. [Подготовка, ограничения и
проверенные сценарии](../docs/BASH_WORKFLOW.md): Windows/Ubuntu17 distinct PASS,
Interactive stdin/scrollback и изоляция Stop добавлены в §217: Space w c →
Ctrl-\ Ctrl-n читает/ищет вывод, i возвращает ввод; Shift-F5 останавливает
и из terminal-mode. Mac/physical/cold отдельно. Полный список Locals готовый
bundle не предоставляет; native console warning описан IDE-127.


### Рабочий вид IDE Logs после перезапуска

`Space q s` возвращает открытые Logs по вкладкам, высоту/scroll и выбранные
источник/фильтры проекта. A→B→A сохраняет разные виды; скрытые окна остаются
скрытыми. При меньшем терминале высота адаптируется, фокус остаётся в коде.
Проверено Windows/Ubuntu (§218), Mac/physical отдельно. [Подробности](../docs/IDE_LOGS.md).
