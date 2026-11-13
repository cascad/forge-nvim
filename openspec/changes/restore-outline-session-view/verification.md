# Verification — 2026-11-13

## Result

Windows6 PASS/0 FAIL/0 SKIP, Ubuntu6 PASS/0 FAIL/0 SKIP, один selected script
на OS: session-outline1 + session-files1 + session-logs1 + outline-focus3.
По6 native profiles: exit0/signal0/APIerrors[]/hard_kill=false/scope empty.
Source Windows24005408657800 RED сохранён: две прежние Outline панели после
relaunch закрыты. Неизменённого green retry нет, один source/target срез.

## Evidence

Final Windows24205071681000 и Ubuntu main из target-ubuntu: встроенный Lua
parser, по50 настоящих function symbols для A first/second и B first, разные
width40/36,6 разных backend PID, quit/relaunch→A→B→A. Code cursor35/focus
сохранились. Скрытый tab остаётся скрытым. Меньший UI140→106 даёт native
minimum width32, symbols доступны. Arbitrary browsing scroll/folds не заявлены;
native centering/follow Aerial остаётся прежним.

Actual version1 sidecar содержит optional outline width/columns или false,
старые fields Files/Logs сохранены. Сами symbols не сериализованы. Общая
геометрия двух tools теперь использует один local helper session_views и
существующий activities.find_window/public Edgy resize; новое состояние
provider/таймеры/controller/private patches не добавлены.

Файлы runtime/67 pins/6 plugin dependencies16 files/Windows SDK SHA74aff15b
сверены. Native host exit0/signal0, scoped cleanup без hard kill; logs/source/
session Vimscript/JSON sidecars/native lifecycle сохранены до удаления runtime.

## Commands / Limits

`<nvim> -l tests/e2e/session-outline-view.test.lua`; прежние session-files-view,
session-logs-view, outline-focus — отдельными `nvim -l` командами. Нужны только
ready Editor deps; Lua parser встроен в официальный SDK, LSP/download не нужен
новому case. Outline focus controls используют прежние готовые Go deps/gopls.

Raw .tests/session-outline-source-windows/run.txt, target-windows/*.txt,
target-ubuntu/run.txt; audit .tests/session-outline-audit.json. Docker existing
imagef63a05ca/private Neogit overlay/network none, без build/download/lifecycle.
Windows/Ubuntu serial. Mac/physical/full WF-01/Tests открыты; старые IDE-117/
121/124 этим selected PASS не закрыты.

Решение владельца для следующего пункта: Terminal/Debug после полного restart
скрывать до явного открытия/запуска, затем применять saved size; новых процессов
session restore не создаёт. Здесь это решение записано, реализации ещё нет.
В Tests public summary нет getter полного expanded state; private renderer
не подменяем, сначала native visibility/geometry.

FIXLOG219/commands127/HISTORY/guides/roadmap обновлены. Guard baseline
.tests/outline-session-prefix.json: append-only journals/frozen5/lock/SDK exact;
registry index только new Outline row, frozen2 строки остаются working copy.
