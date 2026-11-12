# Verification: deduplicate-dap-launch-preparation

2026-11-12. Windows проверен. Ubuntu/Mac открыты, archive readiness не заявляется.

| Dimension | Status |
|---|---|
| Completeness | 3/5 tasks; 2.1 Ubuntu и 2.2 Mac остаются открыты |
| Correctness | Spec/requirement/scenario mapping Not applicable: skip_specs=true; Windows behavior baseline PASS→PASS, Ubuntu/Mac Not verified |
| Coherence | Один прежний module; общий порядок сохранён; PTY/backend/flags/scheduling не перенесены |

Source fd6b965: новый dap-launch-routes1 PASS, профиль3796782590900.
Final target1 PASS, профиль4235476794900. Настоящие3 CodeLLDB sessions:
F5/current-file, Space dP single и multiple; args ${file} указывают source,
buf/channel различаются; stdout до/после breakpoint, cancel сохраняет историю.
Первоначальная Lua-опечатка нового теста исправлена до native baseline;
source RED по product runtime не заявляется.

Выбранный Windows regression27 checks PASS: Rust default/project/nearest debug,
Python default/project/pytest debug, Node default/project/missing adapter,
Jest debug и отсутствие Node; Go output/panic, общая output policy, panels,
startup hide/reopen, toggle, late focus и PTY двух вкладок. Итого28 различных
target checks. Ранний неверный Node filter дал0 selected: не засчитан,
исправленные project/missing случаи отдельно прошли; итоговый raw log содержит
реальный выбранный case. Runner/verifier требуют хотя бы один выполненный case.

Unit360+trace11 PASS, trace1 SKIP; OpenSpec strict97 PASS. Audit
.tests/launch-evidence.py / launch-evidence.json:22 profiles (source1/target1/
regression20), exact test bytes, saved config SHA, root exit0/signal0/
APIerrors[]/no root hard kill, owned scopes empty и runtime удалены.
Config source/target отличаются только plugins/dap.lua; registry/state/guard/
frame/pins прежние. SDK74AFF15B...C6AD9 не пересобирался. Финальные temp/build F:.

Code review: run_config содержит прежний open → codelldb reset → Node readiness
→ with_launch_buffer → dap.run. prepare_debug_action объединяет прежние
leave_terminal_mode/remember_launch_buffer/current-session view. F5 continue,
no-choice native fallback, scheduling и Space dP selection/cancel сохраняются
в своих маршрутах. 24 add/52 delete, net−28 в одном runtime file; это сокращение
дублирования, не измеренное ускорение или завершение всего DAP lifecycle review.

CRITICAL: выполнить задачи2.1/2.2. Linux engine недоступен; Desktop/WSL агент
не запускает. Mac/physical key delivery не проверены; selected suite не full.
