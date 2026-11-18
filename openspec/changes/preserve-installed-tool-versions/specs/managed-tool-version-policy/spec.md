## ADDED Requirements

### Requirement: IDE-BOOT-43 Сохранение установленных версий IDE tools

Повторный setup fride SHALL сохранять установленные версии Mason tools по
умолчанию и устанавливать отсутствующие штатным provider. Возврат к версиям,
закреплённым fride, SHALL требовать отдельного явного действия. Preserve SHALL
сохранять проверки receipt/exports и не объявлять повреждённый tool готовым.
Настройки SDK и ручных executable paths MUST оставаться прежними.

Платформы: все
Проверка: tests/install-tool-versions.test.py.

#### Scenario: Ручная версия и повтор

- **GIVEN** пользователь выбрал другую установленную версию через Mason
- **WHEN** запускается обычный повторный setup
- **THEN** эта версия и payload сохраняются без install/update
- **AND** receipt/exports остаются обязательными, готовый Go tool не требует build SDK

#### Scenario: Отсутствующий инструмент

- **WHEN** требуемый tool отсутствует
- **THEN** native Mason ставит закреплённую версию либо обычный provider default
- **AND** пользователь видит результат/источник в прежних логах

#### Scenario: Явный baseline

- **WHEN** выбран --tools-versions baseline
- **THEN** pinned tools возвращаются к закреплённым версиям через Mason
- **AND** план/лог показывают выбор, загрузка Go требует отдельного согласия
- **AND** unpinned packages, SDK и plugins не становятся произвольным rollback

#### Scenario: Ошибка и preview

- **WHEN** receipt/export повреждён либо установка неуспешна
- **THEN** readiness завершается ошибкой, повреждение не становится PASS
- **WHEN** запрошен preview/check
- **THEN** версии packages не меняются
