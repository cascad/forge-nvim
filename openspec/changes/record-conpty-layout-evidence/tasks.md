# Tasks

## 1. Диагностика без изменения проверки

- [x] 1.1 Добавить команду наблюдения и инструкцию; native ConPTY прогон сохраняет log/actual/expected/difference/sessions/manifest и исходный PASS, эталон/lock не меняются.
- [x] 1.2 Проверить native FAIL с намеренно неверной частной копией fixture: exit 1, точные поля diff, полные JSON и исходный fixture SHA сохранены; это проверка диагностики, не воспроизведение причины RU.
- [x] 1.3 Сохранить результаты и ограничения в FIXLOG/HISTORY/PROBLEMS/ROADMAP/командах; append-only prefix, ссылки и strict validate проходят. IDE-039 остаётся открытым.

## 2. Проверка интеграции

- [x] 2.1 Выполнить trace и Linux SKIP диагностической команды на уже работающем engine; подтвердить отсутствие runtime/fixture/SDK изменений, чистый commit завершённого диагностического шага.

Результаты: FIXLOG §101. Native EN 66 PASS; наблюдаемый drift 65/1;
намеренно неверный private fixture 65/1 с ожидаемым exit 1 и двумя полями.
Linux SKIP; trace 7/0/1. Metadata и исходные raw FAIL сохранены;
первоначальная причина IDE-039 и устойчивый RU контроль остаются открытыми.
