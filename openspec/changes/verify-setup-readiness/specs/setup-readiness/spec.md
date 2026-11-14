## Purpose

Не объявлять явную подготовку IDE успешной, пока выбранные инструменты и парсеры не имеют проверяемого результата установки на целевой платформе.

## ADDED Requirements

### Requirement: IDE-BOOT-15 Postconditions явной подготовки

После install command setup SHALL проверить selected инструменты через native Mason package/receipt и существование объявленных source/exported bin/share/opt files и native executable bin exports; selected парсеры SHALL находиться в runtime и загружаться штатным Neovim loader. Missing/invalid результат MUST давать nonzero с именем и причиной до следующих stages/публикации kit. Проверки SHALL использовать тот же каталог, что конфигурация, и не выполнять дополнительные downloads/refresh/install. Обычный startup MUST не запускать проверки установки.
Платформы: windows, linux/ubuntu, macos (native gate отдельно).
Проверка: tests/install-readiness.test.py, tests/install-setup.test.py.

#### Scenario: Команда не установила обязательный инструмент
- **WHEN** install command вернулась успешно, но selected package/receipt/bin отсутствует или повреждён
- **THEN** tools stage завершается nonzero и называет пакет/причину
- **AND** каталог сам по себе и executable из системного PATH не считаются подтверждением

#### Scenario: Парсер отсутствует или не загружается
- **WHEN** parser task закончился, но selected parser отсутствует либо native loader не может его загрузить
- **THEN** parsers stage завершается nonzero с именем языка
- **AND** tools stage не запускается

#### Scenario: Готовый результат
- **WHEN** все selected package receipts/bin и parser libraries готовы
- **THEN** явный stage завершается0 и записывает результат проверки
- **AND** состав Default/Custom и обычное открытие редактора сохраняются
