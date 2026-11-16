## Purpose

Необязательный Terminal доставляет воспроизводимый WezTerm и шрифт внутри fride,
сохраняя обычные терминалы, настройки и языковое окружение пользователя.

## ADDED Requirements

### Requirement: IDE-BOOT-28 Отдельный Terminal комплекта

Установщик SHALL доставлять выбранный Terminal как проверенный native IDE
component и MUST предоставлять явный запуск собственного WezTerm с fride,
не заменяя пользовательский терминал, конфиг или установленные шрифты.
Платформы: windows|macos|linux. Проверка: tests/install-terminal-runtime.test.py;
Windows GUI отдельно, Ubuntu без display — version/config/font, Mac владельцем.

#### Scenario: Выбран Terminal
- **WHEN** пользователь устанавливает Terminal вместе с Core
- **THEN** fride-terminal открывает fride в собственном WezTerm с переданными
  аргументами, прежним рабочим каталогом и явным config-file
- **AND** обычный fride запускается в текущем терминале
- **AND** шрифт загружается из kit без OS registration, настройки/SDK наследуются

#### Scenario: Отдельное состояние
- **WHEN** managed Terminal читает или сохраняет размер окна и шрифта
- **THEN** используется state внутри принадлежащего fride kit
- **AND** обычный WezTerm state/config/profile не меняется

#### Scenario: Проверка поставки
- **WHEN** publisher готовит Terminal либо installer получает component
- **THEN** pinned source/SHA/version и обязательные payloads проверяются
- **AND** license/source metadata включены в component
- **AND** неподходящий/повреждённый payload не заменяет прежний рабочий kit

#### Scenario: Terminal не выбран
- **WHEN** устанавливается Core без Terminal
- **THEN** fride не зависит от WezTerm и его шрифта
- **AND** launcher fride-terminal не устанавливается
