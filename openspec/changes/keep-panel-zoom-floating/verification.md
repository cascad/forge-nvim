# Verification: keep-panel-zoom-floating

2026-11-11, openspec-verify-change; contextFiles proposal/specs/design/tasks
прочитаны. Спецификация и выводы сверены с runtime/test diff, native source
RED и итоговыми artifacts. Это проверка доступных сред, не архивирование.

| Измерение | Результат |
|---|---|
| Completeness | 3/4 tasks; IDE-PANEL-18 реализован,1.4 остаётся открытым |
| Correctness | 1/1 ADDED requirement найден в controls.zoom/refresh; три сценария покрыты new IDE-PANEL-18 + existing IDE-PANEL-2; Windows/Ubuntu native PASS. Native Mac/physical GUI не проверены |
| Coherence | Дизайн соблюдён: window-local opt-out, source/buffer не выключены, explicit focus cleanup только при исчезновении source; без нового layout/lifecycle |

Mapping: nvim_forge/lua/ide/controls.lua после nvim_open_win и в M.refresh;
tests/e2e/debug-panels.test.lua проверяет native float при помощи300ms,
shared buffer/source ID/geometry, q/Esc, ту же pause/stdout. Соседний
IDE-PANEL-2 проверяет исчезновение source и повторный Output; tool/work/
outline/buffer/terminal suites проверяют общие controls.

Доказательства: .tests/frames-evidence.json, frames-source-*-final.txt,
frames-*-debug-panels.txt. Immutable2719e39 — по0PASS/1FAIL с native docking;
current — по44 positive editor checks/35 profiles, root0/APIerrors[]/scopes
empty. Quick360/trace11 +1manual-link SKIP на ОС, strict89. Exact63 runtime/
pin/patch sources и driver/test copies, SDK/prefix SHA сохранены. Один owned
Ubuntu child group завершён graceful SIGTERM, root hard-kill нет. Первые
отказы и marker-only focus regression описаны в FIXLOG173.

**CRITICAL для архива:** task1.4 не завершён. Пройти native Mac и physical
GUI на целевых машинах, записать фактические результаты; затем повторить
verify перед archive. Непроверенные platform/GUI checks не считаются PASS.
Новых расхождений кода/дизайна или непокрытых сценариев на Windows/Ubuntu
не найдено. Change остаётся открытым; commit проверенного фикса не означает
готовность к архивированию всего change.
