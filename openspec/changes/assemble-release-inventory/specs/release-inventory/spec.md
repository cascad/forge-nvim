## Purpose

Publisher получает единый состав выбранного профиля с исходниками, версиями,
контрольными суммами и доступными license documents перед сборкой полного fride.

## ADDED Requirements

### Requirement: IDE-BOOT-29 Проверяемый inventory поставки

Publisher SHALL формировать inventory действующего выбранного состава и MUST
явно перечислять недостающие metadata/licenses/artifacts без объявления полного
release готовым по одному наличию отчёта.
Платформы: все. Проверка: tests/release-inventory.test.py, native Windows/Ubuntu.

#### Scenario: Явные inputs
- **WHEN** publisher получает prepared plugins/parser site, Mason roots и archives
- **THEN** источником состава служат текущие components/tool_catalog и pins
- **AND** создаются JSON, читаемый отчёт, exact copies доступных лицензий и notices
- **AND** языковые SDK перечислены как внешние prerequisites и не копируются

#### Scenario: Неполные или повреждённые inputs
- **WHEN** отсутствует metadata/license/artifact либо обнаружен version/hash drift
- **THEN** отчёт называет конкретный item и причину
- **AND** strict mode завершается ненулевым кодом при gaps
- **AND** inputs и прежние output directories остаются неизменными

#### Scenario: Ограниченные побочные действия
- **WHEN** выполняется обычный inventory
- **THEN** установки, SDK probes, сеть и изменения pins не выполняются
- **AND** явно выбранная загрузка parser license обращается только к его pinned source
- **AND** файлы создаются только в новом output каталоге

#### Scenario: Граница проверки
- **WHEN** inventory завершён
- **THEN** его metadata completeness отдельно обозначена от native workflow acceptance
- **AND** transitive coverage не объявляется доказанной по top-level license document
