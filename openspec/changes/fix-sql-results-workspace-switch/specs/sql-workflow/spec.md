## Purpose

SQL workflow показывает результаты выбранного workspace с клавиатуры,
сохраняя их подпись, контекст и независимость от других запросов.

## ADDED Requirements

### Requirement: IDE-SQL-6 Результаты выбранного workspace

SQL Results SHALL показывать cached output/error и подпись явно выбранного
workspace при повторном фокусе как видимой, так и скрытой панели. Workspace
без query SHALL показывать отсутствие результатов. Навигация MUST NOT
повторно выполнять SQL; поздний reply другого root не подменяет выбранный вывод.

Платформы: все
Проверка: tests/e2e/sql-language.test.lua (IDE-068)

#### Scenario: возврат к прежнему workspace
- **GIVEN** два SQL workspace получили разные rows из настоящих БД, Results видима
- **WHEN** пользователь возвращается в первый workspace и вызывает Space j o
- **THEN** видит его сохранённые rows/header вместо результата второго workspace
- **AND** повторное скрытие/открытие сохраняет тот же output, SQL не выполняется

#### Scenario: workspace без результата
- **GIVEN** Results содержит вывод другого workspace
- **WHEN** пользователь открывает Results из SQL workspace без запусков query
- **THEN** видит отсутствие результатов, прежние rows не выдаются за его output
- **AND** возврат в прежний workspace восстанавливает сохранённый вывод

#### Scenario: ответ после переключения
- **GIVEN** query первого workspace ожидает настоящий DB lock
- **WHEN** пользователь явно выбирает Results второго workspace до завершения query
- **THEN** завершившийся query обновляет собственный cache и не меняет выбранный вывод
- **AND** явный возврат в первый workspace показывает его завершённый результат
