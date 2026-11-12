# Verification: remove-obsolete-debugpy-exit-filter

2026-11-12. Windows проверен; Ubuntu/Mac остаются открытыми. Archive readiness
не заявляется.

| Dimension | Status |
|---|---|
| Completeness | 3/5 tasks, задачи2.1 Ubuntu и2.2 Mac открыты |
| Correctness | IDE-DAP-6 Windows source RED → target PASS; обе scenario покрыты; Ubuntu/Mac Not verified |
| Coherence | Удалён только obsolete debugpy filter; native classification и Go/TCP policy сохранены |

Source83cf655, профиль6646393541500: настоящий debugpy.adapter с invalid CLI
option, native Process exit2, argparse stderr сохранён, notification отсутствует.
Target6665886202100: тот же exit2 виден через native WARN и общую IDE Logs,
source файл редактируется/сохраняется. Adapter задан публичной конфигурацией;
debugpy package/process/stdio/stderr не подменены.

18 прежних checks PASS: Python8 (включая default/project, pytest/debug nearest
и custom failure23), Go output/panic4, late focus2, Logs3, launch routes1.
С новым case19 Windows target PASS. Все Python notifications проверены:
из exit WARN остался только expected negative forge_failure23. В pytest debug
native log содержит настоящий Process exit1, ложного WARN/hit-enter нет.
Это сохраняет IDE-DAP-5, а тип debugpy покрыт отдельным новым regression.

Audit .tests/debugpy-evidence.py / debugpy-evidence.json:17 profiles
(source1/target1/regression15), saved config/test SHA, backend Process exit2,
stderr, notices, root0/signal0/APIerrors[]/no root hard kill, own scopes empty,
runtime удалены. Source/target отличаются только plugins/dap.lua,4 add/21 delete.
Backend patch/6 dependencies/67 pins/SDK прежние; нового logger/manager нет.
Unit360+trace11 PASS, trace1 SKIP; strict98 PASS. Финальные temp/build F:.

При подготовке обнаружен отдельный IDE-112: F7 планирует focus даже в normal
mode и отменяет следующий Space w i. Отдельный source RED без DAP сохранён
в6809191856600; draft вынесен из tests до собственного change/регистрации,
чтобы не добавлять неизвестный IDE-PANEL-22 в trace этого исправления.
Финальный debugpy case использует обычные Space w i / Space w 0.

Mapping: IDE-DAP-6 unexpected exit — debugpy-exit.test.lua, delegation из
utils.notify в original_notify без benign_patterns; normal-close — existing
client-close guard nvim-dap/session.lua + python-language pytest debug.
Go server callback не имеет этого guard; его policy намеренно не удалена.

2026-11-12: actual Ubuntu source83cf6551 RED → target1 PASS: настоящий
debugpy CLI exit2/stderr/WARN/IDE Logs/edit recovery. Source config/test,
native root0/APIerrors[]/scopes empty/runtime removed подтверждены в том же
pod. Whole target Python case7/language8, Go language6 и Go output cases PASS,
native metadata audit 265 paths без неожиданных отказов. Desktop/WSL не
управлялись. Общий Ubuntu FAIL на независимом Files focus IDE-116 сохранён.
Подробности и границы target audit — verification fix-panel-restore-focus.
CRITICAL:2.2 — actual Mac/physical delivery не проверены; archive открыт.
