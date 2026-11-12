# Verification — 2026-11-12, незавершено

## Один Windows прогон

Проверялись native SDK Neovim и копия реального Forge; config source override
и ID/case filters очищены. Все временные данные F:. Docker/WSL не управлялись.

| Файл | PASS | FAIL | Результат |
|---|---:|---:|---|
| session-files-view | 0 | 1 | Blocking при раскрытии первого fixture-каталога, до save/restore |
| project-session | 0 | 1 | Explorer missing после restore |
| session-legacy | 4 | 0 | winfix/hidden, restart/direct |
| file-explorer | 7 | 0 | CRUD, источники, управление и zoom |
| outline-focus | 3 | 0 | Отложенный render/focus |
| Всего | 14 | 2 | 0 SKIP, повторов нет |

Raw logs/results/audit: `.tests/session-files-view-windows-first/`.
Новый case: `.tests/editor-e2e/15133290047000/`; старый project-session:
`.tests/editor-e2e/15185467124900/` и controller15185213773600.
Второй controller завершился успешно, но внешний проверяющий обнаружил
отсутствие Explorer; его report.ok сам по себе не PASS.

Audit10 profiles: root exit0/signal0, API errors[], own scopes active_after0;
у6 session TUI profiles есть native-host-exit, остальные используют direct
editor harness. Все10 config copies совпадают с проверенным runtime.
Всего13 native TUI PID в lifecycle артефактах. SDK SHA256:
`74aff15b3b6bc288753b721365b088ab44c9b2bfff152f8d27f5885b4b1c6ad9`.

## Что изменено после отказа

Source review подтвердил: Neo-tree get_state_for_window(win) выбирает
current tab, а снимок проходит все вкладки без переключения. При сохранении
из вкладки без дерева чужой Files мог стать files=false. Snapshot и test
reader исправлены на get_state('filesystem', tab).

В новом fixture удалено предположение gg/j/l о номерах каталогов: видимый
узел выбирается настоящими G/l по прочитанным строкам после _ready.
Добавлена запись host terminal до cleanup при FAIL, поскольку первоначальный
blocking screen не сохранился. Точная причина первого blocking не доказана;
locator — подготовленная правка теста, а не подтверждённый runtime fix.

После этих изменений тесты не запускались. Первичные14 PASS не являются
проверкой нынешней версии. Новый Files restore, follow, меньший UI, все
целевые ОС и полный WF-01/02 ещё не подтверждены. Коммита нет.

## Следующая ограниченная итерация

Один прогон тех же пяти файлов; сохранить оба исходных отказа. При PASS
проверить реальные saved views/metadata и shutdown, затем завершить историю
и commit. При FAIL сообщить конкретный остаток, без повторов до зелёного.
Постоянный журнал результата этой итерации: FIXLOG §202 / AGENT_COMMANDS §113.

## Продолжение — §203 / AGENT_COMMANDS §114

По команде владельца выполнен один новый Windows прогон пяти файлов, без
изменения runtime и без повторов. Raw logs/results/audit:
`.tests/session-files-view-windows-followup/`. Предыдущие артефакты сохранены.

| Файл | Checks PASS | Checks FAIL | Итог процесса |
|---|---:|---:|---|
| session-files-view | 0 | 1 | FAIL: равенство view после quit/relaunch |
| project-session | 1 | 0 | PASS: Explorer снова есть |
| session-legacy | 4 | 0 | PASS |
| file-explorer | 7 | 0 | FAIL: teardown exit1/signal15 |
| outline-focus | 2 | 1 | FAIL: первый case не прошёл startup UI attach |
| Всего | 14 | 2 | Дополнительно один teardown FAIL; 2/5 файлов PASS |

Новый case profile15758809460200 сохранил before-quit: две вкладки с разными
selected entry40/entry20, widths38/34, toplines6/1 и тремя раскрытыми каталогами.
Дошёл до другого native PID, LoadPre/LoadPost и equality timeout. Экран до quit
показывает раскрытый child/entry01..35; actual поля/sidecar до cleanup не были
сохранены, поэтому нельзя объявить точную причину и конкретное поле отказа.
Первая потеря Explorer исправлена: project-session15807114988600 PASS.

Edgy source review: get_win ищет в Config.layout, layout.update собирает окна
текущей вкладки; scheduled restore для чужого окна может не получить Edge
object. Это кандидат для дальнейшего разбора, не подтверждённая причина.
Runtime по предположению не менялся.

File-explorer15970978381800:7 действий PASS, QuitPre/VimLeavePre есть,
VimLeave отсутствует; через2034ms controller отправил SIGTERM. Native exit1/
signal15. Outline startup16020020065900: nvim_ui_attach RPC timeout10000ms,
также exit1/signal15; остальные два Outline cases PASS. Причины обоих отказов
не установлены. Timeout не увеличивался, повторов не было.

Audit отбирает9 profiles по artifact paths из наших пяти logs и один failed
startup по Outline fixture/RPC failure. Выбор по всему числовому диапазону
ошибочен: рядом есть SQL-профили другого запуска, они исключены из audit и
не изменялись; причинная связь с отказами не заявляется.
Все10 config copies совпали с tested runtime; все own scopes active_after0,
6 native-session host scopes тоже0,14 дочерних TUI PID. У8 root exit0/signal0,
у2 exit1/signal15; API errors[] не делают такой exit успешным. SDK прежний.

После прогона изменён только E2E: сохраняет expected/actual последнего
сравнения, failure state, raw metadata сразу после первого quit и до cleanup
при отказе. Тестовая диагностика ещё не запускалась; runtime соответствует
версии из этого прогона, фича не принята, коммита нет. Следующая ограниченная
итерация — один новый case для точного расхождения. Перед приёмкой остаются
все пять файлов и два дополнительных отказа. Ubuntu/macOS/physical не проверены.

## Диагностическая итерация — §204 / AGENT_COMMANDS §115

Один Windows запуск только session-files-view:0 PASS/1 FAIL,31.16s. Profile
16551819802500, TUI PID24720→31244, host5968. Raw artifacts:
`.tests/session-files-view-windows-diagnostic/`, profile report/metadata/terminal
в `.tests/editor-e2e/16551819802500/`. Прежние результаты не перезаписаны.

| Вкладка | Поле | Ожидалось | Фактически |
|---|---|---:|---:|
| 1 | width | 38 | 32 |
| 1 | topline | 6 | 14 |

Это все расхождения expected/actual. Вкладка2 целиком совпала; selected,
expanded/path/visibility/col/leftcol в обеих совпали. Metadata first-quit и
failure побайтно равны; session_hash соответствует SHA native .vim из
sessions-view-first-quit. Messages/notices пусты. Снимок записывается верно.
Host/root exit0/signal0, APIerrors[], scope active_after0, native host тоже0;
lifecycle двух TUI содержит штатные выходы. Captured config и тест совпали
с исходниками, выполненными до правки. Audit фиксирует точные hashes.

Source review объясняет пропуск width: restore проходил все tabs до
scheduled render callbacks; get_win смотрит только layout текущей вкладки,
чужой Edge не находился и resize молча пропускался. Для scroll промежуточная
position сохранялась в focus_node до нашего winrestview; дальнейший redraw
мог возвращать старый viewport. Точный порядок поздних redraw не трассирован.

После прогона изменены session_files/lifecycle/editor и OpenOptions:
последовательный render→resize→selection/view→следующая вкладка; сохранение
новой native position, завершение focus/follow только после цепочки либо
ошибки. Ошибки open/render передаются completion вместо молчаливого пропуска.
Прямых private Edgy vars, новых timers, layout owner и dependency patches нет.

Тест и metadata diagnostics больше не менялись. Исправление runtime ещё не
проверено, PASS/commit не заявляются. Следующая ограниченная итерация — один
прогон всех пяти выбранных файлов; teardown/UI attach §203 открыты. Меньший UI,
Ubuntu/macOS/physical и остальные панели WF-01/02 остаются непроверенными.

## Итог реализации — §205 / AGENT_COMMANDS §116

Владелец уточнил: FAIL — вход следующей обоснованной итерации того же захода,
а не причина ждать нового «дальше». Каждый ниже перечисленный вариант запущен
один раз, неизменённая версия ради зелёного не повторялась.

| Итерация | Результат | Что подтвердилось / почему следующая |
|---|---|---|
| Windows sequential,5 файлов | 16 PASS | serial render исправил обе вкладки и весь исходный case |
| Windows acceptance, расширенный case | FAIL на prepare resize и cleanup | Не дошёл до новых условий; причина native ввода не доказана |
| Windows native-keys | FAIL smaller UI | Реальные Ctrl-w > работают; ожидание размера неверно |
| Windows stable-terminal | FAIL smaller UI | Использовались columns первого quit вместо последнего A snapshot и не учитывался minimum32 |
| Windows ui-geometry,5 файлов | 15 PASS/1 FAIL | Временный UI cache не исправлял неверное ожидание |
| Windows final-acceptance | 1 PASS | latest metadata + Edgy minimum, smaller UI и follow работают |
| Ubuntu selected,5 файлов | 15 PASS/1 FAIL | Новый case PASS; legacy winfix workflow ok, FAIL POSIX probe при cleanup |
| Windows no-ui-cache | 1 PASS | Конечный код проще; UI cache не нужен |
| Ubuntu final source | E2E FAIL, workflow ok | Все assertions пройдены, cleanup блокирует тот же POSIX probe |

Hypothesis UI cache отвергнута: raw old first-quit UI133/saved133 и final UI133/
saved133 совпадают; последующие A/B snapshots законно имеют другой columns140.
Ошибкой было использовать первый размер для последнего снимка. Дополнительные
UIEnter/UILeave/VimResized hooks/состояние удалены. Не объявлять их фиксами.

Конечный runtime побайтно совпадает с Windows sequential audit по5 изменённым
runtime modules. Поэтому Windows16 distinct PASS подтверждаются тем прогоном
и новым расширенным case на конечном коде; это не утверждение нового полного
прогона final-acceptance всех5 файлов. Остальные15 checks после тестовой правки
не повторялись, потому что runtime/их тесты не менялись. Старые FAIL сохранены.

Windows final profile18529870995600: real TUI6 PIDs, before/reopened и B-return
views совпали, smaller UI width32 при minimum32, same-file focus/new-file follow
PASS. Связанные cached-source profile18293757520800 и sequential17330432804000
сохранены отдельно. Подготовка ширины идёт через native Ctrl-w >, ожидаемый
размер/фактический width записывается в report.resize.

Ubuntu image f63a05ca328a… уже существовал, engine был запущен владельцем.
Не было build/download/start/stop/restart Desktop/WSL. Selected source был
временным UI-cache вариантом:15 PASS/1 FAIL, legacy profile10514097623336
report.ok=true/host0, но scope probe false. Конечный source без cache:
profile10746697986549 report.ok=true, восемь captured workflow states, весь
smaller/follow цикл завершён, root/host/TUI exit0. Полный E2E FAIL: POSIX
process_scope_posix.lua:76 не проверил own groups; clean scope не утверждается.
Container завершён и удалён обычным --rm. Это прежний IDE-117, отдельный gate
отложенной test-infra работы; ради feature его не подменяли и не перезапускали.

Raw .tests/session-files-view-{sequential,acceptance,native-keys,stable-terminal,
ui-geometry,final-acceptance,no-ui-cache,ubuntu,ubuntu-final}/ и соответствующие
editor-e2e profiles. Windows artifacts на F:, Ubuntu в .tests/ubuntu/. Первичные
source checks/metadata копии остаются. SDK/pins/patches не менялись.

Реализация bounded Files slice завершена и проверена на Windows. Ubuntu
functional evidence есть, полный gate FAIL; Mac/physical не проверены. Весь
WF-01/02 остальных панелей открыт. Общая e2e framework/каталог не развивались.
