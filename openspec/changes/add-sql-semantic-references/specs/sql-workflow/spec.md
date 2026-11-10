## Purpose

Семантическая навигация SQL в терминальной IDE: ссылки на объект выбранной
схемы или локальный символ, общие клавиши и точные переходы между файлами.

## ADDED Requirements

### Requirement: IDE-SQL-9 Семантические references SQL

Редактор SHALL находить references выбранной таблицы, колонки или локального
SQL symbol в текущем workspace через `gr`, Space l r и общую quickfix-навигацию.
Результат MUST учитывать schema binding, области видимости и актуальный текст
буферов; текстовые совпадения не являются semantic references.

Платформы: все
Проверка: tests/e2e/sql-references.test.lua (IDE-SQL-9), native SQLS SDK tests.

#### Scenario: одноимённые колонки разных таблиц
- **GIVEN** схема с users.id и accounts.id, несколько SQL-файлов и JOIN aliases
- **WHEN** пользователь вызывает gr на колонке users.id
- **THEN** quickfix содержит её разрешённые usages, в том числе через другие aliases
- **AND** accounts.id, одноимённые literals/comments и неразрешённый id исключены
- **AND** Enter переводит курсор на точный identifier в выбранном SQL-файле

#### Scenario: физические таблицы и локальные aliases
- **WHEN** references запрашиваются на таблице либо на объявлении/использовании alias
- **THEN** таблица связывается с тем же объектом схемы между statements/файлами
- **AND** alias ограничен своей областью и вложенными correlated usages
- **AND** includeDeclaration определяет включение его объявления

#### Scenario: вложенные и correlated области
- **GIVEN** вложенный SELECT с shadowed alias и обращениями к внешней таблице
- **WHEN** пользователь вызывает references в каждой из этих областей
- **THEN** локальные и внешние symbols различаются по binding
- **AND** локальное неоднозначное имя не разрешается произвольно во внешнюю область

#### Scenario: CTE, derived tables и projection aliases
- **GIVEN** CTE/derived SELECT с переименованными выходными колонками
- **WHEN** пользователь вызывает references на CTE name или экспортированной колонке
- **THEN** находятся соответствующие объявления/usages в своей области
- **AND** одинаковые имена другого CTE, derived table или statement исключены
- **AND** output alias не смешивается с одноимённой физической колонкой

#### Scenario: несохранённые и закрытые файлы
- **GIVEN** закрытый SQL-файл на диске и открытый изменённый SQL-buffer
- **WHEN** пользователь вызывает references, меняет текст и повторяет запрос
- **THEN** участвуют закрытые файлы, а открытый buffer перекрывает текст на диске
- **AND** устаревшие usages исчезают без сохранения файла
- **AND** операция references не исполняет SQL-текст и не сохраняет buffer

#### Scenario: обычный DML
- **GIVEN** SELECT, INSERT columns, UPDATE SET/WHERE и DELETE в одной схеме
- **WHEN** пользователь запрашивает references физической таблицы/колонки
- **THEN** учитываются разрешённые usages этих DML statements
- **AND** одноимённые колонки других target tables остаются отдельными

#### Scenario: Unicode, quoting и workspace boundary
- **GIVEN** SQL с Unicode/astral literal перед identifier и workspace с пробелами
- **WHEN** пользователь вызывает references quoted/unquoted identifiers
- **THEN** точные диапазоны не повреждают соседний Unicode/quotes
- **AND** другой workspace и symlink на файл за границей workspace не индексируются
- **AND** одинаковые имена в другой schema/connection не смешиваются

#### Scenario: явно неразрешимый запрос
- **WHEN** symbol неоднозначен, схема не готова либо конструкция не поддерживается
- **THEN** пользователь получает понятную причину отсутствия надёжного результата
- **AND** references не подменяются grep, выдуманными locations или старым списком

#### Scenario: явная подготовка и обычный старт
- **WHEN** пользователь явно готовит закреплённый SQL SDK и открывает SQL
- **THEN** подготовленный backend предоставляет references через общие LSP mappings
- **AND** обычный старт/навигация не устанавливают SDK и не создают второй SQL backend
- **AND** отсутствие tools/provider остаётся видимым ограничением, не скрытой установкой
