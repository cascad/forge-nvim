## MODIFIED Requirements

### Requirement: IDE-DAP-10 Отзывчивый поиск Delve

Поиск Go environment и версии Delve для F5 или DapGoDlvInfo SHALL выполняться
асинхронно. Metadata запрос SHALL использовать локальный Go без изменения
глобального GOTOOLCHAIN; настоящая сборка/debug SHALL сохранять прежние правила
выбора SDK. Overrides и versioned candidate policy SHALL сохраняться.

Платформы: все. История: FIXLOG §229, §277.
Проверка: tests/e2e/go-passive.test.lua (IDE-DAP-10), tests/e2e/dap-output.test.lua, tests/e2e/test-runner.test.lua (IDE-TEST-2).

#### Scenario: Ввод при ожидающем metadata ответе

- **GIVEN** проект требует отсутствующий Go toolchain, локальные Go и Delve доступны
- **WHEN** пользователь вызывает DapGoDlvInfo и ответ Go ещё ожидается
- **THEN** можно сфокусировать Files и вернуться в код, изменить текст до доставки ответа
- **AND** reference E2E ввод занимает меньше 300ms
- **AND** после ответа показаны действительные версия и выбранный путь Delve
- **AND** глобальный GOTOOLCHAIN остаётся прежним

#### Scenario: Один поиск для одной команды информации

- **WHEN** DapGoDlvInfo показывает кандидатов и Selected
- **THEN** GOBIN/GOPATH читаются одним запросом, список не сканируется повторно

#### Scenario: Прежние startup и debug

- **WHEN** пользователь редактирует Go без запуска metadata/debug
- **THEN** сохраняется IDE-BOOT-4: фоновые Go/Delve probes не появляются
- **WHEN** пользователь запускает настоящий первый и повторный debug
- **THEN** сохраняются запуск и вывод по IDE-DAP-1

#### Scenario: Отладка Go теста из neotest

- **GIVEN** Go тест и Delve доступны, neotest запускает DAP strategy из собственной coroutine
- **WHEN** пользователь запускает debug ближайшего теста
- **THEN** metadata discovery остаётся асинхронным и Delve останавливается на breakpoint без hit-enter
- **AND** eval, продолжение, stdout и результат теста доступны
