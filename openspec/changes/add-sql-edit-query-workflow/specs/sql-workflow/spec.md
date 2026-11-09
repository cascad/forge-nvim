## Purpose

Редактирование SQL с настоящей схемой БД, языковым форматированием и
диагностикой, выполнением запросов и результатами через клавиатурную модель IDE.

## ADDED Requirements

### Requirement: IDE-SQL-1 Языковые действия SQL

Редактор SHALL предоставлять schema-aware completion, definition/hover и
rename alias при подготовленных tools и подключении. Открытие SQL MUST NOT
устанавливать пакеты/SDK или исполнять SQL-текст пользователя.

Платформы: все
Проверка: tests/e2e/sql-language.test.lua (IDE-SQL-1)

#### Scenario: схема и aliases
- **GIVEN** SQLite с настоящими таблицами/колонками и SQL workspace с пробелом/Unicode
- **WHEN** пользователь принимает completion, вызывает gd/K/F2 на alias
- **THEN** использует схему выбранной БД, видит definition/hover и корректные edits alias
- **AND** соседние statements и остальной SQL-текст сохраняются

#### Scenario: IDE-061 первый символ и Unicode
- **GIVEN** курсор стоит на первом символе alias, перед ним есть astral Unicode literal
- **WHEN** пользователь переименовывает alias
- **THEN** изменяются все соответствующие usages текущего statement
- **AND** literal, соседний текст и SQL другой statement не повреждены

### Requirement: IDE-SQL-2 Диагностика и форматирование SQL

Редактор SHALL показывать SQL diagnostics по общему действию gl и форматировать
по общим клавишам и save, соблюдая выбранный проектом dialect/style.

Платформы: все
Проверка: tests/e2e/sql-language.test.lua (IDE-SQL-2)

#### Scenario: исправление и save
- **WHEN** пользователь вводит ошибочный SQL и нажимает gl
- **THEN** видит реальную диагностику, которая исчезает после исправления
- **AND** Space l f и save форматируют SQL, результат на диске не требует второго write

#### Scenario: IDE-063 autosave сохраняет набранный текст
- **WHEN** пользователь изменяет SQL и ждёт фонового автосохранения
- **THEN** текст записан без запуска форматирования и всплывающей ошибки форматтера
- **AND** последующий явный write форматирует и сохраняет результат

### Requirement: IDE-SQL-3 Подключения, запросы и результаты

Редактор SHALL выполнять явный SQLRun текущего buffer или точного visual
selection в выбранном подключении, показывать настоящий result/error в SQL
Results и сохранять отзывчивость ввода. Снимок текста MUST соответствовать
моменту запуска. Отмена/переключение MUST NOT подменять результат поздним reply.

Платформы: все
Проверка: tests/e2e/sql-language.test.lua (IDE-SQL-3)

#### Scenario: unsaved buffer и batch
- **WHEN** пользователь запускает изменённый buffer с несколькими statements
- **THEN** исполняется снимок buffer, видны rows/status, фактическая БД меняется ожидаемо
- **AND** сохранённый файл и невыбранная БД не изменяются

#### Scenario: точный visual selection
- **GIVEN** на одной строке перед/после SELECT есть statements с marker updates
- **WHEN** пользователь выделяет только SELECT с Unicode и semicolon внутри literal
- **THEN** выполняется только выделенный SQL, marker updates не происходят

#### Scenario: IDE-066 комментарии перед query
- **GIVEN** SELECT с ведущими line/block comments, в том числе внутри batch
- **WHEN** пользователь выполняет SQLRun
- **THEN** получает настоящие rows, а не ложный Exec status без результата
- **AND** comments, literals и SQL-текст, переданный БД, сохраняют исходный смысл

#### Scenario: выбор подключения
- **WHEN** пользователь выбирает другой connection через SQLConnect и запускает query
- **THEN** получает rows и schema нового подключения
- **AND** picker/команды не показывают credentials, результат подписан своим подключением

#### Scenario: ошибка и остановка session
- **WHEN** query падает либо блокируется реальным DB lock
- **THEN** ошибка видна в SQL Results, код доступен с клавиатуры
- **AND** SQLStop останавливает SQL session/backend этого workspace, редактор остаётся доступным
- **AND** ожидаемая остановка не выдаётся за падение LSP, реальный неожиданный exit остаётся видимым

#### Scenario: панель и повторное открытие
- **WHEN** пользователь переводит фокус в SQL Results, разворачивает/возвращает, скрывает/открывает её
- **THEN** действуют общие управление/помощь, прежний output сохранён
- **AND** эти действия не исполняют SQL повторно

### Requirement: IDE-SQL-4 Работа без tools и подключения

Редактор MUST сохранять редактирование SQL без tools/config/доступной БД.
Явная команда SHALL давать одно понятное сообщение вместо установки или
зависшего prompt. Отсутствующий SQLite файл MUST NOT создаваться открытием SQL.

Платформы: все
Проверка: tests/e2e/sql-language.test.lua (IDE-SQL-4)

#### Scenario: недоступная среда
- **WHEN** пользователь открывает/сохраняет SQL и вызывает SQLRun без tools/config/SQLite файла
- **THEN** редактор остаётся доступным, состояние объяснено, установки и лишней БД нет
- **AND** обычные SQL действия не создают DAP session или No active session overlay

### Requirement: IDE-SQL-5 Явная подготовка и проверка SQL SDK

Подготовка SHALL проверять pinned source/patch/payload и собирать выбранный
native SQLS только по явному --download с предоставленным Go SDK. Readiness
MUST работать без compiler/build scratch, не менять подготовленные payload/
manifest и не менять вариант без явной подготовки. Временный профиль проверки
SHALL быть отдельным от установленного SDK; Windows temp остаётся на диске checkout.

Платформы: все
Проверка: tests/e2e/sql-sdk.test.lua; tests/e2e/sql-language.test.lua (IDE-066)

#### Scenario: native SDK с проверенным исправлением
- **GIVEN** pinned upstream source/patch и предоставленные Go >=1.25/native CC
- **WHEN** владелец явно готовит patched SQLS
- **THEN** actual -version обозначает вариант, Go locks сохраняются, metadata содержит before/after SHA
- **AND** тот же real SQLite UI regression проходит, official upstream воспроизводит IDE-066

#### Scenario: IDE-067 readiness без build scratch
- **GIVEN** SDK содержит manifest, binaries/parser и проверяемые archives, но build scratch/компиляторы отсутствуют
- **WHEN** владелец вызывает readiness без --download
- **THEN** проверяет настоящий native ABI/versions без установки, payload/manifest не меняются
- **AND** временный профиль удаляется после проверки, SDK scratch не создаётся

#### Scenario: смена варианта требует подготовки
- **WHEN** readiness запрошена с другим sqls-variant
- **THEN** завершает работу с понятным сообщением о --download и сохраняет SDK
