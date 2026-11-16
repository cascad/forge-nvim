# Spec Delta

## Purpose

Доставлять существующие debugger/test возможности через штатную установку fride, сохраняя обычные SDK и исключая обязательные ручные prepare-команды после установки.

## ADDED Requirements

### Requirement: IDE-BOOT-23 Подготовка существующих debug/test tools

Managed setup SHALL устанавливать pinned codelldb1.12.2 для Rust на Windows/POSIX через Mason и применять существующий hash-checked Bash adapter patch только к принадлежащему fride Mason package. Ошибка/неизвестный payload MUST давать nonzero и сохранять исходник. SQL component SHALL доставлять готовые patched sqls и forge-sqltest через существующий runtime artifact mechanism, без требования Go/Rust/C compiler у пользователя SQL. Native binary versions SHALL проверяться перед ready; private SQL tools SHALL выбираться до stock Mason/PATH copy, явные пользовательские overrides SHALL сохраняться. SDK/чужие adapters MUST не изменяться, startup MUST не устанавливать и не патчить tools. Native Mac/publication SHALL оставаться явными непроверенными этапами до фактического прогона.

#### Scenario: Подготовка и повтор
- **WHEN** выбран Rust/Bash и выполнен tools setup
- **THEN** debugger доступен из Mason, Bash payload подготовлен без ручной команды, повтор сохраняет уже готовые файлы

#### Scenario: Неизвестный Bash payload
- **WHEN** установленный adapter не соответствует ни одному принятому hash
- **THEN** tools setup завершается nonzero, исходник и чужие adapters остаются неизменными

#### Scenario: SQL без SDK компилятора
- **WHEN** выбран SQL без Go/Rust, скачан подходящий native SQL part
- **THEN** query/test consumers работают через готовые tools, Go/Rust/CC не запускаются и не устанавливаются

#### Scenario: Неполная поставка
- **WHEN** отсутствует native SQL binary, версия не подходит или publisher manifest/source не совпадает
- **THEN** установка/упаковка завершается ошибкой, готовность не объявляется и прежний kit сохраняется
