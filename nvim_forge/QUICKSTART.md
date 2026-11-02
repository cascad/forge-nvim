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

### Общий маршрут Debug, Outline, дерева и Git — Space w

В **normal mode**:

| Клавиши | Действие |
|---|---|
| `Space w h/j/k/l` | Фокус в соседнее окно |
| `Space w d` | Открыть/сфокусировать Locals |
| `Space w c` | Сфокусировать/вернуть текущий debug Output |
| `Space w a` | Открыть/сфокусировать Outline слева |
| `Space w e` | Открыть/сфокусировать Files слева |
| `Space w g` | Открыть/сфокусировать Neogit status справа |
| `Space w 0` | Вернуться в код |
| `Space w q` | В Debug/Outline/Neo-tree/Git — скрыть панель; в коде — прежнее закрытие окна |
| `Space w z` | Развернуть текущую Debug/Outline/Neo-tree/Git панель / вернуть её на место |
| `Space w ?` | Помощь по управлению |

В Debug/Outline/Neo-tree/Git normal `q` скрывает панель, `?` открывает помощь, `Esc` возвращает
из развёрнутого вида, иначе переводит фокус в код. Левая группа Debug
(Locals/Watch/Stack/Breakpoints) скрывается целиком. Enter и j/k сохраняют
штатные действия списка/дерева. `[focus]` в заголовке показывает активную область.
Навигация и скрытие не продолжают/не завершают сессию и не очищают Output.

В insert/terminal печатные q/? остаются вводом. Из terminal сначала
`Esc`, `Esc` для normal или `F7` для фокуса в коде. Прежние `Space D v`, `Space D c`,
`Space D 0`, `F6/F7` и команды раскладок сохранены. Tests/поиск/задачи
подключаются к общим локальным действиям следующими этапами.

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
| `Enter` / `o` | Открыть файл в коде |
| `h/l` | Свернуть / открыть узел |

В диалоге `Enter` подтверждает, `Esc` отменяет только ввод; q/? остаются
обычным текстом. В дереве `Esc` возвращает фокус в код, сохраняя панель.
Подтверждение или файловая команда из zoom сначала возвращает выбранную
строку в исходное окно, затем выполняет действие. Переименование/перемещение
сохранённого открытого файла обновляет путь буфера; каталог — пути дочерних
буферов. При занятом имени rename отменяется; move предлагает другой путь,
`Esc` сохраняет оба файла. Несохранённые буферы имеют штатный отдельный диалог
Neo-tree; этот сценарий пока не входит в проверенную матрицу.

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
сессии. Merge/rebase-конфликты и credentials проверяются отдельно.

Worktree: `w W` → путь → исходный ref → имя ветки; `w g` — список/посещение;
`w D` — выбор и подтверждение удаления. На dirty worktree второй вопрос
предлагает force: ответ No сохраняет данные. При удалении текущего worktree
Neogit сначала возвращается в основной, даже если затем отказать force.

После обновления существующей установки один раз выполнить `:Lazy build neogit`
и `:Lazy build gitsigns.nvim`, затем перезапустить редактор. Первая команда
готовит исправление удаления текущей папки (IDE-034), вторая — фоновых Git
запросов, если worktree исчез до завершения initial signs (IDE-035),
и ненужного cwd живого object read (IDE-038). После обновления этого
исправления повторить Gitsigns build; прежний известный payload обновляется явно.
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
Merge/rebase-конфликты и credentials ещё требуют e2e. Два отказа push
покрыты `git-errors.test.lua` (IDE-GIT-10); UI merge не входит в этот тест.
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
