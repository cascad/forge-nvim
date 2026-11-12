## Purpose

Позволяет запускать тесты нескольких модулей Go workspace из общего корня и
исправлять ошибки через привычную Tests panel без зависания редактора.

## ADDED Requirements

### Requirement: IDE-TEST-7 Запуск Go workspace suite
Редактор SHALL выполнять все обнаруженные тесты Go workspace из общего корня,
включая корень с go.work без go.mod и проекты вне HOME, сохраняя отзывчивость UI,
настоящие результаты и Output. Команды suite MUST выполняться последовательно,
чтобы разбиение workspace не создавало неограниченную параллельную нагрузку.
Платформы: все.
Проверка: tests/e2e/go-workspace-tests.test.lua, tests/e2e/test-runner.test.lua,
tests/e2e/work-panels.test.lua.

#### Scenario: Контейнер нескольких модулей вне HOME
- **GIVEN** Go.work root вне HOME без go.mod и два модуля с тремя tests
- **WHEN** Tests panel открыта из первого модуля и запускается Run all из root
- **THEN** оба модуля выполняются ровно один раз, даже до открытия второго файла
- **AND** pass/fail и полный вывод доступны, редактор продолжает принимать ввод

#### Scenario: Обычные цели и повтор после исправления
- **GIVEN** workspace имеет ближайший test и файл с двумя tests, один failing
- **WHEN** пользователь запускает nearest/file, исправляет assertion и suite
- **THEN** nearest запускает один test, file только его файл, suite все tests
- **AND** новые результаты отражают исправление, обычный run не создаёт DAP float

#### Scenario: Одинаковая цель из общего и native управления
- **GIVEN** общий корень Go workspace
- **WHEN** suite запускается через общий Run all либо native Neotest run API
- **THEN** выполняется тот же полный набор tests без зависания поиска go.mod
