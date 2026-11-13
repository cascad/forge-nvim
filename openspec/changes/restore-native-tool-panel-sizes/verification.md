# Verification — 2026-11-13

## Status

Реализация IDE-PANEL-27/28 и3 новых native cases PASS Windows/Ubuntu.
Ubuntu selected22 PASS/0 FAIL/0 SKIP. Windows selected21 PASS/1 FAIL/0 SKIP:
Logs native quit IDE-129 до restore. Строгий Windows gate задачи1.2 открыт,
change не объявлен полностью верифицированным/готовым к archive.

## Core

- Tests:50 настоящих public Bats positions до/после restart, native ширина и
  вкладка, скрытость после q, TEST_EXECUTED отсутствует. Полные folds/results
  не сериализованы; один штатный Neotest Summary, readiness по native событию.
- Terminal: высота сохраняется после q/quit, после restore live0/panels0/
  sessionfalse. Явное открытие возвращает размер, echo реально исполняется,
  следующий ручной resize переживает смену focus.
- Debug: официальный Bash SDK/Node, F9/F5/breakpoint3, Locals width/Output
  height, Stop и два native hide. После restart нет auto process/session/
  panels; следующий F5 создаёт настоящий сеанс с сохранённой геометрией.
- На OS:3 новых profiles/7 child PID, всего17 native profiles с parent exit0/
  signal0/APIerrors[]/hard_kill=false/scope empty. Source/metadata/version1/
  67 pins/6 plugin dependencies16 files/SDK SHA74aff15b сверены.

Полный selected22 = new3 + Files1/Logs1/Outline1/legacy4/debug6/work6.
Windows core27415205332800/27432300378300/27446543076200; Ubuntu — соответствующие
3 profiles в target-ubuntu. Runtime после начала target не менялся.

## Source / Diagnostic

First source0/3: Tests header уже показывал50, но fixture ждал раскрытые labels;
Debug посылал Ctrl-\ из normal-панели и открывал Terminal. Исправлены read-only
positions и mode guard, cleanup завершает свой DAP. V2 Tests26520839508500 и
Terminal26556788249700 — реальные RED восстановления. Debug v2 ждал скрытия
Output по q в Locals; это отдельные components. Исправленный узкий v3
26898254885800 подтвердил потерю sizes. Root runtime до source не менялся.

Windows Logs27485199147400/backend26348: SavePre27497086.878ms,
SavePost27511006.086ms, интервал13919.208ms при quit deadline10s. Позже
VimLeave и frontend job0, host0/scope0. Длительностей отдельных функций
в этом медленном цикле нет, причина неизвестна — IDE-129.

Один отдельный instrumented workflow28333531556800 на том же runtime/deadline:
6 saves, capture max5.467ms, cleanup67.682ms, native save27.587ms; workflow PASS.
Он не заменяет основной FAIL. Прежние функции только измерены в private TUI;
timeouts/SDK/сохранение не менялись. Идентичный проверенный script сохранён как
tests/diagnostics/session-save-phases.lua; повтор после копирования не запускался.
При новом slow cycle нужны именно его phases, сейчас причинного исправления нет.

## Artifacts / Limits

Raw .tests/session-tool-source-windows, source-v2-windows, debug-source-v3-windows,
target-windows/*.txt, target-ubuntu/run.txt, session-save-phase-probe-windows.
Audit .tests/session-tools-audit.json разделяет21/1,22/0 и отдельный diagnostic.
При source cleanup readonly private-path WSL probe нашёл0 остатков; global
process cleanup не выполнялся. Windows/Ubuntu serial, existing imagef63a05ca/
network none, без build/download/Desktop/WSL lifecycle.

Mac/physical, full provider view state, per-section DAP heights и исходные
IDE-117/121/124 остаются отдельными. IDE-129 не спрятан как skip/PASS. Новый
observer только читает реальные UI размеры, обновляет память и применяет их
появившемуся native окну. Restore не вызывает shell/adapter/test commands.

FIXLOG220/commands128/HISTORY/product docs/plan обновлены. Prefix guard
.tests/tool-session-prefix.json: journals append-only/frozen5/lock/SDK exact;
registry index только new row поверх HEAD20b1210, frozen2 строки working copy.
Полный runner/tests catalog не изменялись и не запускались.
