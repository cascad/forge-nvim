# Spec Delta

## REMOVED Requirements

### Requirement: IDE-SQL-1 Языковые действия SQL
**Reason:** DB-aware слой удалён по решению владельца.
**Migration:** Базовый Sqruff сохраняется по IDE-BOOT-34 и IDE-SQL-10.

### Requirement: IDE-SQL-2 Диагностика и форматирование SQL
**Reason:** Legacy SQL contract заменён действующим Sqruff baseline без DB слоя.
**Migration:** Диагностика/форматирование сохраняются по IDE-BOOT-34 и IDE-SQL-10.

### Requirement: IDE-SQL-3 Подключения, запросы и результаты
**Reason:** Собственные connections/query/Results удалены по решению владельца.
**Migration:** Для системных CLI можно использовать обычную встроенную консоль.

### Requirement: IDE-SQL-4 Работа без tools и подключения
**Reason:** Удалены специальные SQL-команды; базовое редактирование сохраняется.
**Migration:** Общие сообщения/paths и Sqruff baseline IDE-BOOT-34/IDE-SQL-10.

### Requirement: IDE-SQL-5 Явная подготовка и проверка SQL SDK
**Reason:** SQLS SDK/build/patch больше не входит в продукт.
**Migration:** Готовый upstream Sqruff через общие tools, без SDK компилятора.

### Requirement: IDE-SQL-6 Результаты выбранного workspace
**Reason:** SQL Results component удалён вместе с query workflow.
**Migration:** Общая встроенная консоль сохраняет собственную сессию/output.

### Requirement: IDE-SQL-7 SQLLogicTest в Tests
**Reason:** SQL test adapter и собственный runner удалены по решению владельца.
**Migration:** Neotest продолжает поддерживать остальные выбранные языки.

### Requirement: IDE-SQL-8 Явный переносимый test runner
**Reason:** Собственный Rust SQL runner и package pipeline удалены.
**Migration:** Пользовательские инструменты остаются доступны в системной консоли.

### Requirement: IDE-SQL-9 Семантические references SQL
**Reason:** Отложенный DB-aware контракт снят вместе с дополнительным SQL scope.
**Migration:** Неподдерживаемые semantic references не выдаются за Sqruff feature.
