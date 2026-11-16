# Verification

2026-11-16, IDE-BOOT-27. Реализованы общий bounded probe, Git Core gate до
artifacts/setup, native package recipes с явными подтверждениями, existing/
install/recheck/cancel без skip и --check-tools/--tool-path.

## Native Windows

tests/install-git-prerequisite.test.py: 8 PASS,28.369s.
Evidence: .tests/git-prerequisite/e2e-windows-v1.txt; test case outputs/UI frames
и native Git proof в указанном первой строкой install-isolation stand.
SDK actions06/11:2 PASS18.934s; missing SDK03:1 PASS11.283s.
После этого изменены help и форматирование; macOS guard уточнён canonical path.

## Native Ubuntu

Тот же Git suite:8 PASS11.639s; SDK actions06/11:2 PASS5.222s;
missing SDK03:1 PASS3.644s. Evidence: .tests/git-prerequisite/e2e-ubuntu-v1.txt,
exported install-isolation/* metadata/UI frames/Git proof.
Existing image Docker28.5.1, run --rm --no-deps --pull never, network none,
2CPU/2GiB. Native build из имеющихся vendored crates; heavy work в /tmp.
Desktop/WSL lifecycle не менялся, image build/pull отсутствовали.

## Coverage / Limits

- Missing, invalid output, nonzero,2s timeout; preview без probe/manager.
- Noninteractive failure до HTTP artifacts/setup и сохранение старого kit.
- Native PTY: choose root/cmd, reuse fallback при повторной установке,
  отсутствие skip, cancel/decline, confirmed native manager recipe и recheck,
  exit0 без Git не считается успехом.
- Реальный Git через настоящий fride/Neovim launcher: executable прежний,
  отдельный обычный Git config неизменен, SSH environment сохранён,
  local init/add/commit. Никаких запросов credentials/remote/push.
- Controlled package managers не устанавливают ничего на host.
- Конфигурация setup/plugins — прежняя install fixture; full Default readiness
  этим suite не доказывается. Native Mac/Apple shim и реальные manager installs
  остаются отдельными acceptance gates. Production catalog пуст.
- Для владельца Mac добавлен case09 apple_shim_read_only (выбранные Developer
  Tools до/после, готовый Git либо отказ до shim). На Windows/Ubuntu не запускался.

История: FIXLOG §257, commands §165. Frozen25 и raw append-only prefixes сохранены;
итоговые native build receipts соответствуют исходникам. Own Windows payloads
589548166 bytes удалены, metadata/raw logs сохранены (.tests/git-prerequisite/cleanup.json).
Точечный staging проверяет те же HEAD journal prefixes и allowlist25;
чужой E2E/catalog WIP сохраняется. Local commit без push; sync/archive не выполняются.
