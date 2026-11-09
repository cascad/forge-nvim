## Purpose

SQLLogicTest/SQLite добавляет настоящие SQL tests в общие Tests/Test Output,
сохраняя управление клавиатурой и переносимость Windows/macOS/Ubuntu.

## ADDED Requirements

### Requirement: IDE-SQL-7 SQLLogicTest в Tests

Forge SHALL обнаруживать `.slt` scripts без исполнения и запускать nearest,
file и all через общие Tests hotkeys. Unit тестирования MUST быть полный
script с общей SQLite test DB для его statements/assertions; другой script
получает независимую БД. Results SHALL содержать реальный passed/failed,
ожидаемые/полученные данные и строку ошибки. Rerun, output и stop используют
общие панели, без DAP и повторного SQLRun. При отсутствии runner Forge MUST
сообщать требуемую явную подготовку, ничего не устанавливая.

Платформы: все
Проверка: tests/e2e/sql-tests.test.lua

#### Scenario: nearest и повтор после исправления
- **GIVEN** `.slt` с setup и зависимым query/assertion, runner подготовлен
- **WHEN** пользователь запускает nearest из середины файла
- **THEN** выполняется весь script, Tests показывает настоящий результат
- **AND** неверный expected виден в Test Output со строкой; исправление/save/rerun даёт passed

#### Scenario: file и all
- **WHEN** пользователь запускает file или all для нескольких `.slt`
- **THEN** file исполняет только выбранный script, all — все scripts workspace
- **AND** Unicode/space пути передаются без shell; scripts не разделяют test DB

#### Scenario: управление и остановка
- **WHEN** пользователь переключает Tests/Test Output/code, скрывает output либо останавливает долгий script
- **THEN** общие focus/help/zoom/hide сохраняются, stop завершает свой runner
- **AND** output/статус не превращается в ложный passed, DAP session не создаётся

#### Scenario: отсутствующая среда и неверный script
- **GIVEN** runner отсутствует либо script синтаксически неверен/не содержит assertions
- **WHEN** пользователь запускает test
- **THEN** получает понятную ошибку вместо passed или «No active session»
- **AND** discovery/open не исполняют SQL и не устанавливают SDK

### Requirement: IDE-SQL-8 Явный переносимый test runner

Native runner SHALL использовать официальный sqllogictest parser/validator
и native SQLite, не требуя Bash или Python при обычном выполнении. Подготовка
MUST быть явной, с фиксированными dependencies/lock и source/binary hashes;
readiness без download MUST не выполнять build/скачивание и не требовать
compiler/scratch. Windows temp/build/cache остаются на диске checkout.

Платформы: все
Проверка: tests/e2e/sql-tests.test.lua, tests/e2e/sql-test-sdk.test.lua

#### Scenario: build и immutable readiness
- **WHEN** пользователь явно готовит SDK, затем проверяет уже готовый SDK без compiler/build scratch
- **THEN** native binary выполняет реальный SQLite assertion, source/lock/hash проверены
- **AND** повторная readiness сохраняет manifest/payload, ничего не скачивает и не собирает

#### Scenario: ошибка native runner
- **WHEN** SQLite assertion или parser возвращает ошибку
- **THEN** machine report и exit code содержат реальный failed и его причину
- **AND** повреждённый/отсутствующий report не считается passed

### Requirement: IDE-TEST-5 Run all при нескольких adapters

Общий Space T A SHALL исполнять обнаруженные tests всех активных adapters
в текущем cwd, пропуская пустые trees и чужие workspace. Порядок регистрации
MUST NOT заставлять выбирать пустой adapter вместо настоящих tests.

Платформы: все
Проверка: tests/e2e/sql-tests.test.lua, tests/e2e/work-panels.test.lua

#### Scenario: пустой adapter того же корня
- **GIVEN** SQL workspace имеет `.slt` tests и активный Bats adapter без tests
- **WHEN** пользователь запускает Space T A
- **THEN** все SQL scripts выполняются ровно один раз с настоящими результатами
- **AND** соседний adapter не перехватывает run и не создаёт ложный passed

#### Scenario: несколько языков и другой workspace
- **GIVEN** текущий cwd имеет tests нескольких adapters, другой workspace тоже открыт
- **WHEN** пользователь запускает Run all
- **THEN** исполняются tests каждого adapter внутри cwd
- **AND** чужой workspace не запускается

### Requirement: IDE-TEST-6 Единая identity путей discovery

Neotest discovery SHALL использовать согласованные native пути для directory
и file trees, включая пути из событий editor. Смена файла после query failure
или stop MUST сохранять отзывчивость редактора и возможность запуска другого
script; объединение деревьев не зацикливается из-за separators/aliases.

Платформы: все
Проверка: tests/e2e/sql-tests.test.lua, tests/e2e/python-language.test.lua,
tests/e2e/plugin-backports.test.lua

#### Scenario: смена script после stop или ошибки
- **GIVEN** SQL test завершён ошибкой либо остановлен пользователем
- **WHEN** пользователь открывает другой `.slt` и запускает его
- **THEN** editor остаётся отзывчивым, другой script получает настоящий результат
- **AND** native source RED и patched GREEN используют одинаковый UI scenario без watchdog

#### Scenario: один namespace физического workspace
- **GIVEN** pytest workspace обнаружен вместе с другими adapters
- **WHEN** Root и directory/file events используют разные формы пути одной папки
- **THEN** workspace получает один canonical adapter namespace
- **AND** nearest/file/debug запускают ожидаемые настоящие tests без дублирования
