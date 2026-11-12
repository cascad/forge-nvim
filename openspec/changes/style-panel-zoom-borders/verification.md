# Первый прогон — 2026-11-12

Статус после первого прогона: реализация есть, change не завершён и не закоммичен.
Runtime: controls.lua, net+19 строк; native border/title/winbar для прежнего
zoom, остальные winhl mappings сохраняются. Нового layout owner нет.

Единственный последовательный Windows прогон:

| Existing permanent E2E | PASS | FAIL | SKIP |
|---|---:|---:|---:|
| debug-panels | 5 | 1 | 0 |
| work-panels | 6 | 0 | 0 |
| outline | 6 | 0 | 0 |
| git-workflow | 6 | 0 | 0 |
| tool-panels | 9 | 0 | 0 |
| frame-layout | 1 | 0 | 0 |

Новый IDE-PANEL-24 прошёл:12 actual native RGB checkpoints, по active/help/
refocus для Locals/Output/Files/Logs, source window/buffer/geometry/options/
cursor и настоящая DAP pause. Остальные прежние проверки прошли, кроме
последнего IDE-PANEL-2 в том же Debug fixture: ожидал видимый dap-repl,
но новый тест оставил Files/Logs. Это подтверждено snapshot IDE-PANEL-24
профиля9757080411800 и последовательностью вызовов. Код оформления не менялся
после прогона; postamble нового теста теперь возвращает Output и проверяет
паузу. Эта правка ещё не запускалась. Результат33 PASS/1 FAIL не заменяется.

У24 native profiles: root exit0/signal0/APIerrors[]/own scopes empty;
captured controls.lua совпадают с текущим runtime. Строгая проверка change PASS.
Raw logs .tests/zoom-style-*.txt/result/audit; исходные test bytes сохранены
в .tests/zoom-style-first-debug-panels.test.lua и первом native profile.
SHA256 проверенного теста aa4e783c5f9e40f957c3c899f9004d4d4626e555d216f2a5f78b571b4f65e3b5,
runtime2118d8e70e8c8578f06613e015091b5c558a0e713a6be1b22466488c27da97dd.
SVG active/help скопированы без изменений из этого UI в docs/assets/panel-frames.

Следующая отдельная итерация: один debug-panels прогон после postamble fix,
затем документация/commit при PASS. Остальные пять файлов и runtime прежние.
Ubuntu/macOS, физический WezTerm/font QA, общий full suite не запускались.
Постоянные рамки split и распространение Code/Locals pilot не включались.

## Завершение Windows-проверки в следующей итерации

По новому поручению владельца выполнен один debug-panels прогон после
исправления postamble:6 PASS/0 FAIL/0 SKIP, включая IDE-PANEL-24 и следующий
старый IDE-PANEL-2. Native profile10274073955800: root0/signal0/APIerrors[],
own scopes empty. Captured controls и test bytes совпадают с текущими.
Проверены12 RGB checkpoints, native title/focus и возврат source window.

Runtime SHA2118d8e7...27da97dd не менялся с первого прогона. Исправленный тест
SHA2563ee74119346b007704ce8384d5938fc067e10dc8b75d196bbc2ca27084310a18.
Пять соседних файлов также неизменны и ранее дали28 PASS. Совокупное
выбранное покрытие Windows —34 различных checks; общий набор не повторялся.
Первый33 PASS/1 FAIL остаётся исходным результатом первой итерации.

Логи: .tests/zoom-style-final-debug-panels.txt, final-result.json,
final-audit.json; старые логи и frozen test сохранены. Строгая проверка change
PASS; append-only guards проверяются перед commit. Windows-итерация завершена;
Ubuntu/macOS и physical/font QA остаются непроверенными. Change не архивируется.
