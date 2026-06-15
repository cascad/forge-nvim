# Хоткеи nvim_forge — шпаргалка

`<leader>` = **Space**. Полный список: `<leader>sk` (Telescope keymaps), `:IdeStatus` — что сейчас в слотах.

---

## 1. Переключение по открытым файлам (буферам), вперёд/назад

| Клавиши | Действие |
|---|---|
| `Tab` / `Shift+Tab` | следующий / предыдущий файл |
| `Shift+l` / `Shift+h` | следующий / предыдущий |
| `]b` / `[b` | следующий / предыдущий |
| `Alt+l` / `Alt+h` | следующий / предыдущий |
| `Ctrl+PageDown` / `Ctrl+PageUp` | следующий / предыдущий |
| `<leader>bn` / `<leader>bp` | следующий / предыдущий |
| `<leader>bb` или `<leader>fb` | пикер по открытым буферам (MRU) |
| `<leader>bd` | закрыть текущий буфер (последний → alpha) |

---

## Закрытие (файлы / info-окна / панели)

**Закрыть открытый файл (буфер):**

| Клавиши | Действие |
|---|---|
| `<leader>bd` | закрыть текущий файл (переключит на предыдущий; последний → alpha) |
| `Alt+w` | то же (умное закрытие текущего файла) |

**Закрыть info / popup-окно (ConformInfo, help, Lazy, Mason, checkhealth, hover, Trouble):**

| Клавиши | Действие |
|---|---|
| `q` | закрыть окно |
| `F4` (или `Alt+q` / `Alt+w`) | универсально: float → diff → tool-окно → файл |

**Панели:** `<leader>Pp` — спрятать все разом · по-слотово `<C-b>` / `<C-j>` / `<leader>Pt` `Py` `Pu`.

> Правило: свой **файл** → `<leader>bd`; **info/popup/панель** → `q` или `F4` (закрываешь окно, а не буфер — layout не плывёт).

---

## 2. Переключение фокуса по панелям

| Клавиши | Действие |
|---|---|
| `F6` / `Shift+F6` | следующее / предыдущее окно (циклом по всем) |
| `F7` или `Alt+e` | прыгнуть в редактор (код) |
| `<leader>m]` / `<leader>m[` | следующая / предыдущая **панель** |
| `<leader>m0` или `<leader>P0` | фокус в main-редактор |
| `<leader>m1` … `<leader>m6` | фокус N-й видимой панели |
| `<leader>P/` `<leader>P.` `<leader>P,` | фокус left / right / bottom слота |
| `<leader>Dv` `<leader>Dw` `<leader>Ds` `<leader>Db` | debug: Variables / Watch / Stack / Breakpoints |
| `<leader>Dc` | debug: нижняя секция (REPL / Console / Terminal) |

---

## 3. Открытие/toggle панелей

**Дерево файлов (Explorer, слева):**

| Клавиши | Действие |
|---|---|
| `<leader>e` | toggle дерева |
| `Ctrl+b` | toggle левой панели (VS Code-style) |
| `<leader>mf` или `<leader>pf` | раскладка Files |
| `<leader>gS` | дерево Git-статуса |
| `<leader>bB` | дерево буферов |
| `<leader>Pt` | toggle левого слота |

**Дебажная левая панель (DAP sidebar):**

| Клавиши | Действие |
|---|---|
| `F5` | старт / continue (панели поднимаются авто) |
| `<leader>md` | раскладка Debug |
| `<leader>dD` / `<leader>du` / `Ctrl+Shift+d` | toggle debug-вида |
| `<leader>dR` | REPL |
| `F9` breakpoint · `F10` over · `F11` into · `Shift+F11` out |

**Нижняя консоль / bottom-панель:**

| Клавиши | Действие |
|---|---|
| `Ctrl+j` или `F8` или `<leader>Py` | toggle нижней панели |
| `<leader>mo` | debug Output (Console) |
| `<leader>tt` или `Ctrl+\` или `Ctrl+t` | терминал (горизонтальный) |
| `<leader>tT` / `<leader>tV` | терминал float / вертикальный |
| `<leader>jj` | панель задач (Overseer) |

**Troubles (Problems):**

| Клавиши | Действие |
|---|---|
| `<leader>xx` | диагностика по workspace |
| `<leader>xX` | диагностика по текущему буферу |
| `<leader>xs` | символы |
| `<leader>xr` | LSP refs/defs/impls (справа) |
| `<leader>xL` / `<leader>xQ` | location list / quickfix |
| `<leader>px` | раскладка Trouble |

**Всё разом:** `<leader>Pp` — спрятать все панели / вернуть последний набор.

---

## 4. Git (включая diff)

**Inline (gitsigns) в буфере:**

| Клавиши | Действие |
|---|---|
| `]h` / `[h` | следующий / предыдущий hunk |
| `<leader>ghs` / `<leader>ghr` | stage / reset hunk |
| `<leader>ghp` | preview hunk |
| `<leader>ghu` | undo stage |
| `<leader>ghb` | blame строки (полный) |
| `<leader>ghB` | toggle blame по строкам |
| `<leader>ghd` / `<leader>ghD` | diff буфера / vs HEAD~ |

**Статус (Neogit):** `<leader>gg` — во вкладке · `<leader>gG` — сплитом.

**Diff (Diffview):**

| Клавиши | Действие |
|---|---|
| `<leader>gd` | дифф изменённых файлов |
| `<leader>gD` | история текущего файла |
| `<leader>gF` | фокус на список файлов |
| `<leader>gq` | закрыть diff |
| `<leader>fc` | пикер изменённых файлов (git_status) |
| _внутри diff:_ `Alt+j`/`Alt+k` | следующий / предыдущий файл |
| _внутри diff:_ `Alt+h`/`Alt+l` | старая / новая сторона |
| _внутри diff:_ `Ctrl+e` | toggle списка файлов · `q` закрыть |

---

## 5. Запуск тестов (neotest)

| Клавиши | Действие |
|---|---|
| `<leader>Tt` | запустить ближайший (авто-открывает Output) |
| `<leader>Tf` | запустить файл |
| `<leader>TA` | запустить все |
| `<leader>Td` | дебажить ближайший |
| `<leader>Ts` / `<leader>Ta` | стоп / attach |
| `<leader>Tw` | watch файла |
| `<leader>To` | открыть Output (с фокусом) |
| `<leader>TO` | toggle Output-панели |
| `<leader>Tp` | toggle боковой панели тестов |

---

## 6. Поиск

**По проекту (grep):**

| Клавиши | Действие |
|---|---|
| `<leader>fg` или `<leader>ss` | live grep по проекту |
| `<leader>sw` | слово под курсором по проекту |
| `<leader>sr` | повторить последний поиск |

**Поиск файлов / по файлу:**

| Клавиши | Действие |
|---|---|
| `Ctrl+p` или `<leader>ff` | найти файл по имени |
| `<leader>fr` | недавние файлы |
| `<leader>sb` | fuzzy по текущему буферу |
| `/` (или `Ctrl+f`) | нативный поиск в буфере |
| `n` / `N` | след./пред. совпадение (со счётчиком `[3/12]`) |
| `Esc` | снять подсветку поиска |

**Replace:**

| Клавиши | Действие |
|---|---|
| `Ctrl+Shift+f` или `<leader>sF` / `<leader>sR` | панель поиска/замены (grug-far) |
| `<leader>sV` | замена в visual-выделении |

**Символы / диагностика:** `<leader>sS` (doc symbols) · `<leader>sW` (workspace symbols) · `<leader>sd` / `<leader>sD` (диагностика буфер / workspace).
