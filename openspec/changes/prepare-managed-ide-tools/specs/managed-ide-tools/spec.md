# Spec Delta

## Purpose

Подготавливать существующие инструменты языка и форматирования одним штатным Mason mechanism внутри каталога fride, сохраняя обычные SDK пользователя и явные границы установки.

## ADDED Requirements

### Requirement: IDE-BOOT-22 Подготовка существующих IDE tools

Explicit managed setup SHALL устанавливать закреплённые gopls/gofumpt/golines для Go, stylua для Core и prettier для Node через существующий Mason. Postconditions SHALL проверять receipt version и требуемый executable export; для prettier также JS entrypoint и доступный обычный Node. Установка MUST не выполняться на startup и MUST не менять SDK homes/global package prefixes. Go source build SHALL использовать обычный Go SDK1.26.0+ и GOTOOLCHAIN=local; при необходимости сборки несовместимый SDK SHALL давать nonzero до установки с причиной. Готовые packages с правильными receipt versions SHALL переиспользоваться без требования обновить build SDK. Core без Node SHALL оставаться допустимым, UI SHALL объяснять принадлежность JSON/YAML/Markdown formatting к Node компоненту. Project Prettier SHALL сохранять приоритет над shared Mason copy.

Платформы: все
Проверка: tests/install-ide-tools.test.py.

#### Scenario: Полный набор
- **WHEN** выбран Core/Go/Node и явно выполнен setup
- **THEN** пять tools включены в установку с закреплёнными версиями и проверяются перед успешным завершением

#### Scenario: Core без Node
- **WHEN** выбран только Core
- **THEN** устанавливается stylua, не устанавливаются prettier/Go tools и не появляется обязательный Node SDK

#### Scenario: Неверный или неполный пакет
- **WHEN** receipt имеет другую версию, отсутствует нужный bin export либо prettier JS entrypoint
- **THEN** setup завершается nonzero с именем пакета и причиной, даже если install callback сообщил успех

#### Scenario: Обычное редактирование
- **WHEN** открывается Go/Lua/JSON файл после подготовки
- **THEN** существующие LSP/formatter consumers используют готовые tools без установки; project Prettier имеет приоритет, SDK environment не переназначается
