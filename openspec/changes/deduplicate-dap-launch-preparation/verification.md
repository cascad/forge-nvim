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

## Ubuntu и observer IDE-115 — 2026-11-12

Первый source fd6b965 остановлен CodeLLDB, но snapshot PTY ещё пуст;
следующий содержит ROUTE_BEFORE42 (profile2954754232052). Сохранено в
.tests/ubuntu/integration-20261112/source-initial, результат FAIL. DAP pause
и stdout приходят независимо: тест теперь ждёт stdout прежним e:wait,
сохраняет stdout_at_stop. Backend/PTY, порядок запуска и timeout прежние.
Test SHA256 bc72e5cc71e2cf600fe50afce159fe153d22db3367957c464ab5bb414e1a200c.

С исправленным observer source fd6b965/target7aa0ba9: по1 PASS Ubuntu;
Windows source/target по1 PASS (16371339293100/16379551431900). Actual
CodeLLDB/3 fresh PTY/args/cancel сохранены. Ubuntu whole debug suites:
Python7+8, Node8, Rust8, Debug5, toggle2/startup1/tab1 PASS; root/API/scopes
review 265 paths не нашёл неожиданных native отказов. Source audit внутри
того же pod подтвердил config/test bytes и удаление runtime.

CRITICAL:2.2 — native Mac/physical delivery не проверены. Общий Ubuntu
остаётся FAIL на отдельном panel case IDE-116; это не PASS всего набора.
Границы target audit и источники — verification fix-panel-restore-focus, §192.
