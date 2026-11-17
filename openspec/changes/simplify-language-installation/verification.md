# Проверка

2026-11-17. Native Windows/Ubuntu; frontend собран офлайн с тем же Cargo.lock.
Windows использовал existing developer cache; Linux — его read-only копию в
container /tmp. SDK, Docker Desktop/WSL и production catalogs не менялись.

| Проверка | Windows | Ubuntu |
|---|---|---|
| install-profile, включая basic setup actor | 22 PASS | 21 PASS,1 platform SKIP |
| install-runtime HTTP/private delivery | 17 PASS | 17 PASS |
| optional SQL bundle/basic SQL delivery | 5 PASS, последний native case повторён отдельно | 5 PASS |
| release-inventory CLI/report | 8 PASS,1 explicit-network SKIP | 8 PASS,1 explicit-network SKIP |
| ручная Bash patch preparation/отказ unknown payload | 3 PASS | 3 PASS |
| native Bash formatter/editorconfig E2E | 1 PASS | 1 PASS |

Runtime transport содержит контролируемый Terminal CLI fixture; это не проверка
WezTerm GUI/шрифтов. Native Neovim/install/HTTP/hash/rollback настоящие; plugin
stages контролируемые. Optional SQL delivery проверяет настоящие sqls/SQLite
query и SQLLogicTest binary, basic control использует настоящий Mason receipt
Sqruff без DB bundle. Basic setup actor проверяет команду/состав без downloads,
готовность всех Mason tools этим actor не доказывается.

Initial runtime выявил оставшийся language guard в private installer; исправлен
до финального17 PASS. SQL fixture обновлена под текущий plugin_setup contract;
native DB setup теперь не требует Lazy при уже доступной LSP config. Linux
inventory сначала нашёл устаревший Neogit backport image; повтор только inventory
с офлайн обновлённой private deps copy прошёл. Production проверки не отключались.

Логи host: .tests/toolchain-research/basic-{profile,runtime,sql-delivery,inventory,
debug,bash-smoke}-windows*.txt; Linux driver/result: basic-install-ubuntu*.txt,
подробности в .tests/ubuntu/basic-*.txt. Native Mac не запускался.

Перед commit: strict OpenSpec, exact index, frozen25, journal raw/staged prefixes,
Markdown local links и diff check. Full Default install/publication не заявлены.
