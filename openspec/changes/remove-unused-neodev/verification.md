# Verification

2026-11-19, source c7522d6. Cleanup IDE-080, прежний IDE-BOOT-31 сохранён.

## Native controls

Upstream LuaLS3.19.2, настоящий full editor config, private profiles и native
server. Подмены LSP methods/on_init/settings нет; fixture задаёт executable/
logpath. Новый registered tests/e2e/lua-language.test.lua:

| Case | Windows baseline с neodev | Windows target | Ubuntu target |
|---|---|---|---|
| Diagnostics → edit/save; Neovim API completion/hover | PASS | PASS | PASS |
| Explicit .luarc.json external library/hover | PASS | PASS | PASS |
| Explicit .luarc.jsonc external library/hover | PASS | PASS | PASS |

Baseline: package.loaded.neodev и Lazy spec=true; target оба=false.
Default Lua workspace library ровно VIMRUNTIME. Explicit project library
не подменяется; настоящий LuaLS находит внешний fixture module.
Source control зелёный: это сохранение поведения, не устранение user-visible бага.

Windows baseline .tests/neodev-review/windows-baseline.txt; target
batch1795112719682524100,25.29s. Ubuntu target1795112782178531400,26.5s.
По одному affected packet после реализации; failures/retries нет.
State JSON/config snapshots — editor-e2e directories из соответствующих00.log.
Broad E2E, Mac/Omarchy/physical GUI не проверялись.

## Dependency / environment boundary

Удалены только neodev spec, pin, plugin-source row; остальные66 revisions,
LuaLS production settings,6 backports и SDK/старый UI прежние. Private66-pin
manifests подготовлены отдельно от общего67-pin source cache.
Windows binary из own Core stand, Linux из cached official3.19.2 archive,
без downloads. User Neovim/LuaLS/SDK/config не менялись. Нативные LuaLS logs
пишутся в private profile, host scratch на F.

Ubuntu own container6ef07abcb0a9, label refactor-e2e, CPU2/RAM3GiB/network none;
Docker Desktop/WSL и image не менялись. Cleanup/metadata — commands206.
Снижение latency численно не измерялось и не заявляется.

Финал: syntax/strict PASS, trace9 PASS/1 SQL pending SKIP. Journal prefixes,
точное удаление одного pin/source row,66 unchanged pins/inventory entries,
3 frozen .tools SHA, SDK/backport/старый UI lock и diff whitespace PASS.
Exact-ID/owner own container удалён, records на host F сохранены, cleanup.json.
