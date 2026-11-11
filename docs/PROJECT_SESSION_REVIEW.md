# Project/session: native baseline

2026-11-10. Продолжение IDE-080. Baseline §166 снят на runtime HEAD fad809c и
закреплён c1beaaa без production edits. После него IDE-095 исправляет restore
focus (§167); все67 pins и выбранный Windows SDK 0.12.2 прежние.

Старый code-window probe проверял Persistence save/load в одном процессе.
Новый scenario использует настоящий TUI внутри private editor terminal:
Neovim сам обрабатывает restart UI event и подключается к новому backend.
Дочерняя сборка получает те же private config/data/state; host persistence
остановлен, чтобы fixture не перезаписывал сохранение. Observer пишет lifecycle
и readiness; не вызывает restore/restart вместо редактора. Ввод — PTY,
наблюдение — public RPC по native socket/pipe.

| Переход | Что проверено на Windows |
|---|---|
| quit → новый запуск → Space qs | Новый PID; три файла в двух tabpages, cursor 23:7 / 37:5 / 47:3 |
| Служебные окна перед quit | Explorer на первом tabpage, Quickfix на втором; после restore Quickfix нет, Explorer открыт, code windows без panel marker/winfix |
| A→B через config.start | Новый PID и cwd B, буферов A нет, modified строка third.txt записана до входа в B |
| B→A через config.start | Ещё один PID; исходные files/tabpages/cursors и изменённый текст восстановлены, буфера B нет |
| Завершение | Native TUI exit0; host exit/signal0, API errors пусты; scope пуст без helper signals/TerminateJobObject |

Проекты имеют пробелы и Unicode в путях. Lifecycle каждого из четырёх backend
содержит VimEnter/ready/VimLeavePre/PersistenceSavePost/VimLeave; у restore
есть PersistenceLoadPost. Session Vimscript, raw states, terminal screen,
source helpers/config/pins и shutdown сохранены до удаления owned runtime.
Windows Job accounting может обновиться после native exit callback: fixture
наблюдает drain до close, как прежний process-lifecycle E2E. Это не новая
production lifecycle политика и не объяснение Docker IDE-087.

Команды из корня репозитория после обычной явной подготовки plugins:

```powershell
& .tools/neovim/windows-x64/bin/nvim.exe -l tests/e2e/project-session.test.lua
& .tools/neovim/windows-x64/bin/nvim.exe -l tests/diagnostics/project-session.lua
```

На Ubuntu/Mac: `nvim -l tests/e2e/project-session.test.lua`. Сценарий входит
в общий `nvim -l tests/run.lua e2e`, scripts/test.ps1 и scripts/test.sh e2e/full.
После IDE-095 его requirement ID — IDE-PANEL-15; общая команда
`nvim -l tests/run.lua e2e --id IDE-PANEL-15` включает основной и четыре legacy
случая. Для одного файла остаётся прямая команда выше.
Дополнительные language tools, сеть, Docker/WSL самому тесту не нужны.

Native TUI на Windows проверен. Ubuntu/Mac не запускались; физические клавиши
WezTerm/GUI, branch-specific sessions, Space qd/ql/qS, ошибка записи файла,
удалённый project root и активный DAP при смене проекта остаются отдельными
сценариями. Этот baseline не доказывает их исправность.

В исходном baseline IDE-095: Space qs возвращает код, config.start restore —
Explorer focus. Это наблюдение проверено отдельным source RED ниже; нынешний
Explorer focus не закреплён как контракт.

Пилоты не считаются product RED: missing Lua field сначала сравнивался с
vim.NIL; Escape и следующий текст в одном PTY burst распознались как Alt;
naive поиск Quickfix marker в session source нашёл сохранённый statusline,
хотя actual Quickfix window не восстановилось. Raw artifacts не переписаны.
Постоянный тест проверяет actual windows, marker/winfix, buffer text и lifecycle.

## IDE-095: один restore route и fallback к файлу

Source c1beaaa: усиленный E2E сохраняет прежние assertions, но падает именно на
current window neo-tree после A→B→A. Второй scheduled callback в config.start
закрывал панели после общего PersistenceLoadPost и повторно открывал дерево.
Устаревший post-restore cleanup/open удалён. Common LoadPost по-прежнему
открывает дерево, panel_guard лечит legacy winfix, SavePre очищает сохранение.

Полностью выкинуть старый file fallback нельзя: native Help-only session с
именованным listed file хранит файл только в списке буферов. До исправления
reveal текущего Help из SDK вне project cwd открывал root prompt; второй
cleanup мог удалить scheduled NUI window и оставить invalid-window/hit-enter.
Trial без второго callback исправил обычный/winfix focus, но Help-only fallback
не восстановил. Поэтому оставшаяся необходимая функция выбирает обычный main
и listed file перед reveal; общий callback сохраняет его window ID и возвращает
фокус туда после открытия дерева. Destructive cleanup не переносился в manual
restore. Новых controller/flags/timers нет, production net -8 строк.

Постоянные дополнительные проверки:

```powershell
& .tools/neovim/windows-x64/bin/nvim.exe -l tests/e2e/session-legacy.test.lua
& .tools/neovim/windows-x64/bin/nvim.exe -l tests/diagnostics/session-legacy.lua hidden
& .tools/neovim/windows-x64/bin/nvim.exe -l tests/diagnostics/session-legacy.lua winfix-direct
```

Четыре legacy variants: winfix/hidden через A→B→A и winfix-direct/hidden-direct
через Space qs. Native mksession создаёт fixture; noautocmd only используется
только атомарно при создании старой Help-only раскладки, чтобы нынешний Edgy
не перестроил её до сохранения. Сам restore идёт со всеми настоящими callbacks.
Raw session сохраняется, затем устанавливается только в private state, после
того как обычный switch закончил autosave. File list/actual windows/cwd/tree
root/notices/Job cleanup проверяются, а не подменяются. У direct тот же PID,
у project restart — новые; выбранный SDK, источник config и raw state сохранены.

Windows пять native cases PASS. Последний source replay теми же тестами дал
main RED, legacy winfix RED, hidden restart invalid-window/hit-enter, hidden
direct без Explorer; winfix-direct уже проходил до fix. Ubuntu выполнен
2026-11-11 (§170): те же5 cases PASS,5 private profiles/12 backend instances,
native host0/APIerrors[]/own groups empty. Mac/GUI gates открыты.
Это небольшой общий restore fix; унификация всех root/interpreter
политик, active DAP при restore и остальные session клавиши сюда не входят.
