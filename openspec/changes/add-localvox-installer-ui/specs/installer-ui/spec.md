## Purpose

Единый понятный мастер подготовки Fride на Windows, Linux и macOS, с оформлением LocalVox, прозрачным прогрессом и возможностью безопасно посмотреть интерфейс до установки.

## ADDED Requirements

### Requirement: IDE-BOOT-13 Общий frontend установки

Установщик SHALL использовать единый frontend с визуальным языком LocalVox: бирюзовый акцент, линия шагов, Core отдельно, галочки, контекстные клавиши и итог. Пользователь MUST не устанавливать Rust/Cargo/Python/Neovim ради запуска этого frontend. Подготовка комплекта MUST оставаться в существующем private backend с прежними границами владения.
Платформы: все.
Проверка: tests/install-ui.test.py и прежние install regressions.

#### Scenario: Custom и возврат
- **WHEN** пользователь выбирает Custom
- **THEN** доступны выбор компонентов, пути, регистрация fride и итоговый план
- **AND** стрелки/Space/Enter управляют выбором, Esc предлагает назад/продолжить/отменить
- **AND** подтверждённые ответы сохраняются при возврате, незавершённый ввод не применяется

#### Scenario: Отмена и preview
- **WHEN** пользователь отменяет мастер или запускает preview
- **THEN** backend не запускается и выбранные config/command directories не меняются
- **AND** preview ясно обозначен и использует тот же presentation frontend

#### Scenario: Автоматический режим
- **WHEN** указан Default или явный список компонентов
- **THEN** установка не требует меню и сохраняет component closure из общей таблицы
- **AND** без TTY/при no-color доступен понятный plain вывод без управляющих цветов
- **AND** Custom без explicit списка и без TTY отклоняется до backend

#### Scenario: Подготовка и ошибка
- **WHEN** frontend запускает существующий backend
- **THEN** видны этапы и путь к подробному логу
- **AND** ошибки и ненулевой exit сохраняются, успешный backend не заменяется симуляцией
- **AND** финал показывает действительный путь запуска из backend

#### Scenario: Доставка frontend
- **GIVEN** source содержит UI manifest и готовый native artifact
- **WHEN** root entry запускается без заранее установленного frontend/compiler
- **THEN** он автоматически получает и проверяет artifact перед запуском
- **AND** отсутствующий/неверный artifact не запускается и не изменяет target
- **AND** legacy source без UI marker сохраняет advanced совместимость
