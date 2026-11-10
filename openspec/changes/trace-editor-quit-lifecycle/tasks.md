# Tasks

## 1. Наблюдаемость quit

- [x] 1.1 Проверить первичный artifact и bounded baseline исходного search case Windows; сохранить повторный RED и не увеличивать timeout.
- [x] 1.2 Добавить минимальный controller/native trace до init, bounded RPC detail flag и реальные normal/delayed-QuitPre E2E; проверить native события/сигналы/empty scope Windows.
- [x] 1.3 Выполнить до 3 traced samples исходного поиска, сохранить exact sources/quit timeline и вывод; обновить docs/PROBLEMS/roadmap/FIXLOG (test-only, skip_specs), HISTORY и команды без заявления неподтверждённого фикса.

## 2. Интеграция

- [x] 2.1 Последовательно проверить quit trace/process/descendants/runtime и search Windows/Ubuntu; подтвердить штатные exit и ожидаемый signal только у controlled fixture, source/empty scopes, unit/trace и strict OpenSpec.
- [x] 2.2 Проверить append-only prefixes/diff, сохранить verification и закоммитить test-only этап.
- [ ] 2.3 Выполнить native Mac capture/проверки и записать результат; до фактического запуска gate открыт.
