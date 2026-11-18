# Verification — 2026-11-18

IDE-TEST-11. Законченный batch unit файл: Windows4 PASS, Ubuntu4 PASS.
Тяжёлые editor/installer E2E и полный regression не запускались; Mac отдельно.

- CLI --plan без inputs: Core suite остаётся в списке, ready=false,
  missing_inputs не пуст, results пуст.
- Actual CLI без inputs:exit2, no tests started; report содержит results=[],
  complete=false/ok=false. Не выполнялись ни Core, ни соседние suites.
- Source/installed plan: правильные mutually exclusive CLI modes, native runtime
  и deps либо kit/profile args. Kit/profile pair имеет приоритет; неполная пара
  не подменяется source режимом. Файлы fixtures проверяют лишь plan availability,
  не являются реальными Core binaries и не дают installed acceptance PASS.
- Прежние selection/duplicate/unknown/OS inventory/filter/unit tests сохранены.

Commands: scripts/test.ps1 quick -Files tests/lib/test_batch.test.lua;
Ubuntu existing driver --batch quick --file tests/lib/test_batch.test.lua.
Raw logs `.tests/toolchain-research/core-inputs-unit-{windows,ubuntu}.txt`;
reports `.tests/batches/1794987942684299400` и
`.tests/ubuntu/batches/1794987952947085014`. Windows registry group1.0s,
Ubuntu9.25s включая registry/index IO; сами cases — быстрые subprocess plans.
Docker Desktop/WSL/build/pull/SDK installs не запускались. Host temp на F.

Strict/diff/frozen25/raw+staged journal prefixes/exact owned index проверяются
перед local commit. User's frontend Core/SDK order decision остаётся pending;
Rust/frontend/transport и product SDK code не изменялись.
