# Tasks

## 1. Комплектность Core publisher

- [x] 1.1 Исправить native receipt metadata и добавить explicit source-bound tool document fetch/cache; tests/release-inventory.test.py проверяет implicit/requested version, nested cache/stale/SHA и opt-in fetch на Windows/Ubuntu. Native Mac пометить непроверенным.
- [x] 1.2 Сформировать actual Windows Core report с0 gaps и offline повтором, сохранить inputs; FIXLOG262 `Спека: IDE-BOOT-32 (ADDED)`, история/команды/план, strict OpenSpec/frozen25/append-only checks и exact local commit. Native/transitive/full release readiness отдельно.
