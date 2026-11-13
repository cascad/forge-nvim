## Purpose

Native interactive rebase доступен с клавиатуры, а отмена редактора не
выдаётся за конфликт истории.

## ADDED Requirements

### Requirement: IDE-GIT-13 Результат native sequence editor
Редактор SHALL позволять переставлять commits, выполнять fixup и применять
native Git todo. Отмена изменённого todo SHALL сохранять исходные HEAD/refs/tree
и сообщаться как отмена, включая Git output с раздельными hint/error строками.
Настоящий rebase conflict MUST оставаться видимой ошибкой с доступным abort.
Платформы: все.
Проверка: tests/e2e/git-sequence.test.lua, tests/e2e/git-conflicts.test.lua.

#### Scenario: Перестановка и fixup
- **GIVEN** три независимых commits A/B/C
- **WHEN** пользователь переставляет C перед B, выбирает fixup C в A и Submit
- **THEN** остаются A+C и B, итоговый tree и рабочие файлы сохранены

#### Scenario: Отмена изменённого todo
- **GIVEN** настоящий native sequence editor и изменённый todo
- **WHEN** пользователь выполняет native Abort
- **THEN** исходные HEAD/refs/tree сохранены и rebase не остаётся в progress
- **AND** сообщение об отмене не подменяется требованием разрешить конфликты

#### Scenario: Настоящий конфликт после перестановки
- **GIVEN** два зависимых изменения одной строки
- **WHEN** они переставлены в обратный порядок и Submit вызывает Git conflict
- **THEN** conflict остаётся ERROR и native abort возвращает исходную историю
