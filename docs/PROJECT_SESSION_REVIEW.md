# Project/session: native baseline

## Последний срез — Tests и отложенные размеры (§220)

Tests sidebar возвращается с native привязкой к вкладке и шириной; positions
обнаруживает прежний Neotest/Bats adapter. Раскрытия/results не сериализуются,
штатное одно окно не клонируется. Readiness — public NeotestSummaryOpen.

По явному выбору владельца Terminal/Debug после полного restart скрыты.
Высота нижней консоли и debug Output, общая ширина debug sidebar запоминаются
по native WinLeave/WinResized даже после q. При явном открытии/F5 размеры
получает появившееся штатное окно; focus не сбрасывает последующий user resize.
Sidecar version1 дополнен optional fields. Native load boundary отменяет старые
queued applies; WinClosed/TabClosed чистят метки. Нового storage/backend/процессов
или timers/polling нет. Регистрация UI callbacks — один setup существующего module.

Core Tests/Terminal/Debug3 PASS на каждой ОС; Ubuntu selected22 PASS. Windows
selected21 PASS/1 FAIL — первый quit Logs, SavePre→SavePost13.9s (IDE-129).
Один отдельный instrumented Logs workflow дал6 быстрых saves; исходный FAIL
не заменён этим PASS. Строгий Windows gate открыт. Mac/physical/full arbitrary
view state остаются отдельными. Прежние срезы ниже сохраняют свои границы.

## Текущая граница — 2026-11-13

Files реализован в §205, Logs — §218. Общий прежний sidecar module теперь
называется forge.session_views: те же version1/session hash/SavePre→SavePost/
LoadPost и один JSON. Для Logs добавлены optional fields, старые Files-only
данные читаются без миграции. Capture до cleanup, Files render→Logs native
Edgy resize/view→следующая вкладка, затем прежний code focus. Нового session
backend/window manager/таймеров нет.

Logs сохраняет видимость/высоту/scroll по tabs и общие source/minimum/query
проекта, даже если все окна скрыты. Windows/Ubuntu по10 selected PASS:
новый PTY Logs workflow, Files, project-session,4 legacy и3 Logs controls.
По10 native profiles со штатным shutdown/scope; native A→B→A/quit использует
новые PID. Меньший UI42→29 адаптирует высоту18→12. Только данные представления,
процессы не возобновляются. Mac/physical и остальные панели WF-01 открыты.

Outline visibility/width реализован §219: native AerialOpen показывает символы
восстановленного файла и сохраняет прежний follow, arbitrary browsing scroll/
folds не переопределяются. Общий scheduled Edgy dimension helper теперь в
session_views для Outline/Logs; новых module/controller нет. Windows/Ubuntu6
selected PASS, включая прежние Files/Logs и3 Outline focus controls.

Следующий срез — Tests visibility/geometry; public summary API не даёт snapshot
раскрытых узлов. Private structures не сериализуем. Решение владельца: после
полного restart Terminal/Debug скрыты до явного открытия/запуска, затем вернуть
сохранённый размер; не создавать shell/debug из session restore. Реализовано §220 с описанным выше Windows gate. Прежний обзор ниже — исходная точка до выполненных изменений.

## WF-01/02: текущая граница восстановления — 2026-11-12

Новые пользовательские кейсы требуют точного вида Files и положения/размеров/
прокрутки панелей. Старый baseline ниже подтверждает files/tabs/cursors и A→B→A,
но не это состояние. В plugins/editor.lua PersistenceSavePre вызывает очистку
tool views; config.start.save_current_session отдельно очищает их перед save.
LoadPost затем заново открывает Explorer. Данные дерева и Edgy resize overrides
не входят в mksession после закрытия этих окон.

У Edgy есть документированные get_win и Window:resize; Neo-tree предоставляет
native navigate/reveal и renderer state. Тонкий адаптер этих данных должен
снимать snapshot **до** очистки, восстанавливать его по готовности native render
и учитывать оба пути сохранения/все tabpages. Добавление произвольного таймера
или второго layout owner не решает порядок событий.

Просмотрен альтернативный [resession.nvim](https://github.com/stevearc/resession.nvim):
его документированный API расширений поддерживает пользовательские данные и
восстановление специальных окон. Это само по себе не доказывает поддержку
нашего Neo-tree/Edgy/DAP workspace. Замена текущего backend потребовала бы
миграции сессий и регресса всех маршрутов; в этом обзоре она не выполнялась.
Новых dependencies/pins/runtime edits и тестовых прогонов здесь нет.

Следующий шаг WF-01 — отдельно спроектировать сохранение plugin view state
через штатные события существующих компонентов. До реализации кейс открыт;
полное восстановление всех панелей не объявлено выполненным.

## Прежний native baseline

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

## WF-01/02: Files view — незавершённый срез 2026-11-12

`restore-files-session-view` сохраняет native state до cleanup и привязывает
JSON к SHA session file. Предназначение — вернуть видимость, раскрытия,
выбранный узел, прокрутку и ширину Files отдельно по вкладкам через штатные
Neo-tree/Edgy API. Native persistence по-прежнему сохраняет файлы и code layout;
остальные панели и живые процессы этим шагом не восстанавливаются.

Один Windows прогон:14 PASS/2 FAIL. Новый native TUI case остановился при
раскрытии fixture, до quit/relaunch; точная причина blocking не сохранена.
Прежний project-session потерял Explorer. Найдена ошибка нового снимка:
`get_state_for_window(win)` использует current tab, даже если win из другой
вкладки. После прогона snapshot и read-only test reader переведены на
`get_state('filesystem', tab)`. Locator теперь читает видимые строки перед
нажатием G/l; при отказе сохраняет host terminal до quit.

Правки после прогона непроверены, повторов не было, фича не принята и commit
не сделан. Legacy4/Files7/Outline3 прошли на проверенной до правки версии.
Не переносить эти PASS на новую версию. Доказательства и следующий шаг —
FIXLOG §202 и `openspec/changes/restore-files-session-view/verification.md`.

Продолжение, §203: один новый Windows прогон той версии подтвердил возврат
Explorer в старом project-session. Legacy4 тоже PASS. Новый case прошёл
подготовку/разные per-tab views/quit/relaunch и упал при равенстве после restore.
Экран показывает раскрытое дерево, но точных actual полей тест не сохранил.
Edgy хранит layout текущей вкладки, тогда как наш scheduled restore проходит
все вкладки; это подозреваемый участок, не доказанная причина расхождения.

Итог14 checks PASS/2 FAIL, дополнительно file-explorer teardown FAIL после
7 успешных действий: SIGTERM спустя2 секунды ожидания quit. Второй case FAIL —
Outline startup nvim_ui_attach timeout10s, до сценария. Причины этих отказов
не установлены, timeout не менялся. Все10 owned scopes освобождены, но2 native
exit1/signal15 нельзя называть чистым завершением. Повторов не было.
Runtime не менялся. После прогона только новый E2E получил expected/actual,
failure state и копирование metadata до cleanup. Диагностика ещё не запускалась;
следующий ограниченный запуск — новый case. Финальная приёмка пяти файлов
и закрытие остальных отказов не отменены. Коммита по-прежнему нет.

Продолжение §204: один запуск только нового case,0 PASS/1 FAIL. Диагностика
сработала: вкладка1 width32 вместо38 и topline14 вместо6; вкладка2 целиком
совпала, selection/expanded/path в обеих тоже. Metadata до quit и при отказе
одинаковы, session SHA совпал с native .vim. Ошибка находится в применении
view после load, а не в снятии/сохранении snapshot.

Прежний restore переключал все вкладки до выполнения scheduled callbacks.
Edgy get_win ищет в layout текущей вкладки, поэтому чужой resize пропускался.
Neo-tree focus_node сохраняет промежуточный viewport; прежний winrestview
не обновлял эту native position. Подготовлен последовательный restore:
следующая вкладка после after_render/resize/view предыдущей, затем общий
возврат фокуса/разрешение follow; после winrestview — renderer.position.save.
Это callback в существующем lifecycle, без timers/polling/private Edgy vars.

Правки сделаны после единственного прогона и ещё не проверены. Тест/metadata
из этой итерации сохранены без изменений; host и два TUI PID завершились0,
owned scopes пусты. Шаг не принят, commit не сделан; следующий прогон —
пять выбранных файлов, включая незакрытые отказы §203. Остальные платформы,
меньший UI и полное рабочее место остаются отдельной проверкой.

Завершение среза, §205: конечный runtime совпадает побайтно с16 PASS Windows
selected прогоном sequential; финальный расширенный E2E без UI cache тоже PASS.
Проверены точные per-tab views/hidden tree/quit/relaunch/A→B→A/missing node,
уменьшенный UI с минимумом Edgy32, native Ctrl-w >, same-file focus/new-file
follow. Прежние отказы не удалены. Дополнительный cache UI-геометрии оказался
ненужной гипотезой и удалён после контрольного запуска: ожидание smaller UI
должно использовать последний A snapshot и фактический минимум Edgy.

Ubuntu на конечном source прошёл все workflow assertions, report.ok=true,
но полный E2E FAIL на known process_scope_posix probe при cleanup. Общий
Ubuntu selected дал15 PASS/1 FAIL (legacy cleanup той же причины); это не16 PASS.
Gate IDE-117 остаётся за отложенной test-infra работой. Windows metadata/core
и оба source artifacts сохранены; Mac/physical и другие панели ещё открыты.
