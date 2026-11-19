# Verification

2026-11-19, source766b775. Internal cleanup IDE-080, skip_specs=true.

## Source fidelity

Main1629→1146 строк; Go165/Rust148/Python193/context29. Все function bodies
перенесены без изменений. Context — normalize_path, with_launch_buffer,
current_launch_path, без новых state/probes. Прямые imports/aliases.
Reverse reconstruction main = exact source766b775; native Lua syntax PASS.
Публичные keys/configs/launch.json, async options и SDK policy прежние.

## Native packet

Existing registered E2E, explicit native CASE filters после цельной реализации.
Не запускался общий batch runner, поскольку он очищает эти filters.

| Сценарий | Windows | Ubuntu |
|---|---|---|
| Delve async discovery, UI input при pending metadata | PASS после observer fix | PASS после observer fix |
| Late Delve override, настоящий breakpoint/output/launch.json | PASS | PASS |
| Cargo pending input/picker cancel | PASS после observer fix | PASS после observer fix |
| Cargo stale project abort | PASS после observer fix | PASS после observer fix |
| Cancel выбора цели → второй bin запускается | PASS | PASS |
| Python default/project/interpreter/output | PASS | PASS |
| Python pytest debug/breakpoint/eval/continue | PASS | PASS |
| Missing codelldb: Go/F9/plain/F5 controls (3) | PASS | PASS |

Initial7 PASS/3 FAIL на каждой ОС: origin filters в native observers искали
старый plugins/dap.lua. Обновлены legacy+new paths; production bodies не менялись.
Только failed3 повторены →3 PASS/ОС. Итог10 PASS/ОС aggregate; не новый цельный
green packet. Pass broad full E2E/Mac/Omarchy/physical GUI не заявляется.

Host artifacts: .tests/dap-refactor/windows-packet и windows-retry/report.json;
Linux .tests/ubuntu/dap-refactor/ubuntu-packet и ubuntu-retry/report.json.
Own containerecbc9270cfaf, label dap-refactor-e2e,2CPU/3GiB/network none,
source RO/.tests records RW на F. No downloads, Desktop/WSL/image changes.
Source-fidelity/metadata/cleanup результаты — commands207.

Финал: syntax/strict/diff PASS, trace9 PASS/1 SQL pending SKIP. Exact moved
bodies и reverse reconstruction, unchanged66 pins/SDK/backports/old UI lock,
3 frozen .tools SHA и journal prefixes PASS. Exact-owner container удалён,
cleanup.json и records сохранены на host F.
