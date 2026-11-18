## ADDED Requirements

### Requirement: IDE-BOOT-45 Явный IDE tool вместо установки пакета

Explicit setup SHALL использовать готовый инструмент из пользовательского
tools.json для уже поддерживаемого runtime key и пропускать соответствующий
Mason package. Это MUST действовать при preserve и baseline. Неверный путь
MUST приводить к ошибке с источником настройки без fallback.
Платформы: все.
Проверка: tests/install-external-tools.test.py.

#### Scenario: Внешний инструмент

- **GIVEN** user tools.json выбирает существующий executable/JS entrypoint
- **WHEN** выполняется setup или повтор
- **THEN** Mason не устанавливает/обновляет его package, receipt не обязателен
- **AND** Go build SDK не требуется для пропущенной установки
- **AND** выбранный path/source виден в log и payload/settings не меняются
- **AND** JS entrypoint требует готовый Node, CodeLLDB использует целый bundle

#### Scenario: Смешанный набор

- **WHEN** только часть tools явно выбрана, остальные отсутствуют
- **THEN** оставшиеся packages устанавливаются штатным provider/policy
- **AND** их receipt/exports остаются обязательными
- **AND** неизвестный неподдерживаемый key не пропускает package

#### Scenario: Неверный выбор

- **WHEN** выбранный path неверен, исчез до postcondition, отсутствует Node
  либо path лежит в заменяемом kit runtime/config/bin
- **THEN** setup завершается ошибкой до publication и сохраняет прежний kit
- **AND** выбранный tool не заменяется установленной копией в Mason/PATH

#### Scenario: Область и обычный старт

- **WHEN** проект содержит другой/неверный tools.json
- **THEN** setup приложения использует user settings, runtime project priority прежний
- **WHEN** редактор просто запускается
- **THEN** подготовка каталога для MTI не читает settings и не запускает install
