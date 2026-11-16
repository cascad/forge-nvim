# Проверка IDE-BOOT-26

2026-11-16. Official ripgrep15.2.0 assets закреплены по release SHA; Windows x64 MSVC и Ubuntu x64 musl native version probes прошли. COPYING/LICENSE-MIT/UNLICENSE доставляются побайтно из того же архива; publisher повторно сверяет binary/licenses с pinned source archive. Остальные platform rows — recipe, не native acceptance.

- Windows: provenance/native-version/corrupt-archive и old-kit native-probe failure cases02/03 PASS в `.tests/search-runtime/e2e-windows-v1.txt`. Native Telescope consumer01 после исправления драйвера PASS37.075s в v3.
- Ubuntu: cases02/03 PASS в `.tests/ubuntu/search-runtime/e2e-ubuntu-v1.txt`; consumer01 PASS17.455s в v2. Старые green cases не повторялись.
- Consumer проходит настоящий localhost source/UI/Core catalog/archive/private install/installed fride launcher. Native embedded editor с тем же installed environment/config принимает настоящий input Telescope find_files/live_grep, находит Unicode path, исключает ignored файл и открывает точный файл/строку2. System rg/fd не требуются; подставной user rg остаётся неизменным и перекрывается только PATH дочернего fride.
- Изменённый binary/license, invalid source archive и чужой real native executable вместо ожидаемой version отклонены. Corrupt native rg в новом Core даёт probe failure до замены marker/binary прежнего kit.

## Значимые failures и ограничения

Win v1/v2 и Ubuntu v1 показали правильный результат поиска, затем новый driver зависал на RPC и child завершался по60s timeout (124/15). Причина — RPC predicate внутри callback vim.wait: вложенный loop повторно входил в predicate. Использован существующий editor:wait pattern с внешним repeat/wait; добавлено ожидание выбранного entry. Driver теперь сохраняет screen/stderr и требует нормальный native exit. Это исправление нового стенда, product picker не менялся.

Other plugins/Mason provisioning контролируются parser fixture; Telescope/rg/picker selection не подменяются. Это не полный Default acceptance. Release Core CLI теперь требует --search; historical Python API без search оставлен для parser-only fixtures и не считается release. SDK/pins/backports/обычный nvim не менялись. Docker — предоставленный engine, готовый image, network none,2CPU/2GiB, --pull never; Desktop/WSL lifecycle не менялся. Native Mac и publication открыты; production catalog пуст. Git policy не реализована этим срезом.
