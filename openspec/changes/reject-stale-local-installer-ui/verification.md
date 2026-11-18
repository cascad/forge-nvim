# Verification — 2026-11-18

## Evidence and fix

Actual repo entrypoint с выбранными user Go1.26/Node paths запустил старый
checkout frontend: preflight показал PATH Go1.23/F:nodejs, settings reader не
вызывался. .tools checksum совпадал с его binary, но source catalog указывал
другой готовый frontend. Это не checksum corruption, а неверный приоритет.

PS/Bash теперь сначала читают source platform URL/SHA. Совпадающий local digest
можно reuse; другой не запускается. Без catalog нужен explicit developer path.
Нового manifest/dependency/parser нет, Rust/UI payloads не пересобирались.

## Native tests

Один пакет на ОС: Windows1795015497831217300 100.65s,
Ubuntu1795015510428857166 52.99s. SourceUI6 +SDK settings12 +UI13 +bootstrap6 =
37 native Python PASS; trace8 PASS/2 informational SKIP. Aggregate45 PASS2 SKIP
на каждой ОС. Повторов не понадобилось. Trace SKIP: нет manual links и старый
pending IDE-SQL-9. Новый SDK case запускает repo install file без override,
с настоящими SDK и source settings reader, не scriptblock entry fixture.

Native SourceUI cases проверяют stale local с корректной собственной checksum,
matching local/cache без HTTP download, unpublished failure, explicit override,
bad source SHA и запуск полученной binary с актуальным --tools-versions.
Local copies/SHA не изменяются. Старый .tools frontend сохранился byte-identical.

## Actual Default checkpoint

Windows/Ubuntu production tools stage подготовил20 настоящих Mason packages
(154.56s/142.99s,1017/989 exports), с существующими SDK и concurrency1. Source
tools/settings не подменялись. Для actual stand отдельно получены67 настоящих
pinned Git repos на каждой ОС, clones concurrency2. Archive-only E2E cache
не имеет полных Git objects/refs и не подходит для Native Lazy install; первый
plugin отказ в Windows был ошибкой stand preparation, не product bug.

Windows после исправления source frontend: Default из настоящих source/Core/
Terminal archives установлен (21.25s), managed launcher0 и реальный Core workflow
tree/search/LuaLS/diagnostics/edit/save/restart0 (4.18s). SDK source теперь user,
как ожидалось. Первая проверка owner marker ошибочно ожидала8 language IDs:
он хранит2 runtime parts core/terminal, а tools readiness проверяет20 packages.
Assertion исправлен, установка повторно ради него не выполнялась.

Repeat нашёл следующий отдельный product defect: ownership walk получает EACCES
на оставшемся Windows IPC reparse file в kit/tmp. Native Runtime/Default принятие
в целом не закрыто. Нужен отдельный regression/fix transient ownership boundary;
исходный отказ и первый setup failure сохранены в owned stand. Custom/Ubuntu
archive workflows ещё не объявлены PASS. Native Mac/Windows WSL/publication открыты.

## Bounds

Host temp/cache F, Docker existing image, одна owned bridge preparation session
с явными upstream downloads, без Desktop/WSL changes; E2E контейнер offline2CPU/
3GiB. Default profile Linux живёт в контейнере261d5816a414 для последующего
workflow; это собственный disposable stand, не пользовательский сервис.
SDK/locks/backports/old UI frozen, raw/staged journals/exact index и syntax/
strict/trace проверяются перед local commit. Full regression не повторялся.
