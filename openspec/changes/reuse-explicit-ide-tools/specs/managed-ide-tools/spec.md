## MODIFIED Requirements

### Requirement: IDE-BOOT-22 Подготовка существующих IDE tools

Explicit managed setup SHALL подготавливать gopls/gofumpt/golines для Go,
stylua для Core и prettier для Node через существующий Mason. Готовый tool из
user tools.json согласно IDE-BOOT-45 SHALL удовлетворять setup вместо своего
Mason package, включая baseline; проверяются его path/JS prerequisites. Остальные отсутствующие
packages SHALL получать закреплённую версию; установленные версии SHALL
сохраняться по умолчанию согласно IDE-BOOT-43. Явный baseline SHALL возвращать
закреплённые версии. Postconditions SHALL проверять валидный receipt и требуемый
executable export, а в baseline также expected version; для prettier обязательны
JS entrypoint и обычный Node. Установка MUST не выполняться на startup и MUST
не менять SDK homes/global package prefixes. Go source build SHALL использовать
обычный SDK: default local требует1.26+, отдельно согласованный IDE-BOOT-42 auto
допускает1.21+ и native Go selection. Несовместимый build SDK SHALL давать nonzero
до установки с причиной. Готовые packages с валидным receipt SHALL переиспользоваться
без обновления build SDK; expected baseline version обязательна только при его
явном выборе. Core без Node SHALL оставаться допустимым, UI SHALL объяснять
принадлежность JSON/YAML/Markdown formatting к Node компоненту. Project Prettier
SHALL сохранять приоритет над shared Mason copy.

Платформы: все
Проверка: tests/install-ide-tools.test.py, tests/install-go-toolchain.test.py, tests/install-tool-versions.test.py, tests/install-external-tools.test.py.

#### Scenario: Полный набор
- **WHEN** выбран Core/Go/Node и явно выполнен setup
- **THEN** пять tools включены в setup; явно выбранные external удовлетворяют его, остальные отсутствующие packages получают закреплённые версии
- **AND** установленные версии сохраняются при preserve и проверяются до завершения

#### Scenario: Core без Node
- **WHEN** выбран только Core
- **THEN** устанавливается stylua, не устанавливаются prettier/Go tools и не появляется обязательный Node SDK

#### Scenario: Неверный или неполный пакет
- **WHEN** отсутствует нужный bin export, валидный receipt либо prettier JS entrypoint
- **THEN** setup завершается nonzero с именем пакета и причиной, даже если install callback сообщил успех
- **WHEN** при baseline receipt имеет другую версию
- **THEN** setup завершается nonzero, если native установка не вернула закреплённую версию

#### Scenario: Обычное редактирование
- **WHEN** открывается Go/Lua/JSON файл после подготовки
- **THEN** LSP/formatter consumers используют готовые tools без установки
- **AND** project Prettier имеет приоритет, SDK environment не переназначается
