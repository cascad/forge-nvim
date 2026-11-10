# Tasks

## 1. Постоянное исходное воспроизведение

- [x] 1.1 Добавить SQL references fixtures и настоящий editor E2E `gr` → quickfix → Enter для двух таблиц с id, разных aliases и закрытого SQL-файла. На Windows текущий forge.1 обязан дать целевой RED; сохранить exact SDK manifest/config/test, native provider/error и screen/shutdown. Обновить E2E README/реестр, FIXLOG/HISTORY/команды и текущую точку плана как воспроизведение, не готовую фичу.

## 2. Семантический backend

- [ ] 2.1 Добавить изолированный native resolver поверх существующего SQLS AST/cache: schema/table/column identity, FROM/JOIN, alias declaration/usage, nested/correlated scopes, shadowing/ambiguity и Unicode ranges. Проверить native tests с независимыми expected locations и реальный editor case из 1.1; постоянные проверки и описание границ в том же шаге.
- [ ] 2.2 Расширить resolver CTE/derived output identities, projection aliases и обычным INSERT/UPDATE/DELETE; добавить native и editor положительные/отрицательные E2E, включая одноимённые символы, includeDeclaration и неоднозначный target. Не закрывать IDE-062 по одному простому SELECT. Дописать историю/описание текущих поддержанных сценариев.
- [ ] 2.3 Подключить настоящий references handler/provider и workspace index: closed files, unsaved overlays, didClose/повторные requests, Git ignored/generated paths, canonical boundary/symlink, смена connection, cancellation и понятные ошибки. Native tests и editor E2E на актуальный текст, отсутствие SQL execution/изменения диска, другой workspace и quoting; docs/FIXLOG со Спека: IDE-SQL-9 (ADDED).

## 3. Явный SDK и платформенная интеграция

- [ ] 3.1 Зафиксировать overlay/patch, новую SDK version и source/before/after SHA; готовить candidate отдельно от исходного SDK. Native upstream query/resolver tests, неизменные Go locks, SDK readiness/immutable variant checks и отсутствие startup install. Обновить prepare/container recipe и SQL docs/команды; Windows native build/readiness и process tests PASS.
- [ ] 3.2 Последовательно Windows и уже доступный Ubuntu: полный references E2E через общие gr/Space l r/quickfix, query 20, SQL Tests 12, common panels, применимые SDK, unit/trace и strict. Проверить shutdown/process scope/source artifacts и отсутствие лишнего SQLS process. Дописать FIXLOG/HISTORY/PROBLEMS/матрицу/план и самостоятельно закоммитить проверенный шаг; недоступный engine не запускать.
- [ ] 3.3 На macOS владельца выполнить native SDK и editor references/query/Tests сценарии через документированные команды, внести реальные результаты. До запуска Mac/ARM64/GUI/внешние DB остаются явно непроверенными и task открытой.
