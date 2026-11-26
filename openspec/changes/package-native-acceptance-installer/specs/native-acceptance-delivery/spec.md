## Purpose

Дать владельцу локальный установщик текущего native комплекта для приёмки до
публикации release URLs, сохраняя штатные frontend/backend и среду пользователя.

## ADDED Requirements

### Requirement: IDE-BOOT-54 Локальный установочный комплект для приёмки
Publisher SHALL собирать комплект из проверенных native Core/optional Terminal,
текущего frontend и tracked исходников IDE. Установка SHALL запускаться одной
командой из комплекта без Python/Cargo/компилятора, использовать существующий
Default/Custom UI и сохранять обычные nvim/config/SDK пользователя.
Платформы: все
История: FIXLOG §301
Проверка: tests/install-acceptance-package.test.py; tests/install-isolation.test.py; tests/e2e/search-sorter.test.lua; вручную (docs/ACCEPTANCE_INSTALLER.md)

#### Scenario: Установка из готового комплекта
- **GIVEN** совместимый native комплект и доступ к штатным источникам plugins/tools
- **WHEN** пользователь запускает его entrypoint с выбранным install directory
- **THEN** штатный frontend получает source/runtime и параметры пользователя
- **AND** обычные SDK переиспользуются, отсутствующие языки остаются отложенными

#### Scenario: Неполный или изменённый комплект
- **WHEN** publisher input или доставленный payload изменён, отсутствует либо чужой платформы
- **THEN** упаковка или entrypoint завершается с понятной ошибкой до запуска установки
- **AND** existing output и пользовательский kit не заменяются

#### Scenario: Повтор после установки или ошибки
- **WHEN** установщик завершил попытку установки
- **THEN** рабочие файлы и журналы находятся рядом с payload в logs
- **AND** проверка исходного payload проходит при следующем запуске того же комплекта

#### Scenario: Пользовательские файлы не входят в поставку
- **WHEN** рядом с checkout существуют .tests/.tools/private notes
- **THEN** они не копируются в пакет; используются только объявленные tracked sources

#### Scenario: Terminal снят в Custom
- **GIVEN** local runtime содержит Core и Terminal
- **WHEN** пользователь выбирает только Core
- **THEN** Terminal files/probes/PATH и launcher не устанавливаются
- **AND** Core запускается, прежние пользовательские файлы сохраняются

#### Scenario: Native search без compiler при установке
- **GIVEN** Core содержит publisher-built библиотеку закреплённого upstream fzf-native
- **WHEN** выполняется setup без CMake/C compiler на машине пользователя
- **THEN** библиотека копируется в IDE plugin data и реально используется для native scoring
- **AND** при отсутствии подходящей библиотеки остаётся штатный Lua fallback без попытки сборки

### Requirement: IDE-BOOT-55 Официальный POSIX Neovim для publisher
Явная publisher-команда SHALL получать только официальный закреплённый Neovim
для native Linux/macOS, проверять SHA и version probe и сохранять готовую поставку
в выбранном каталоге. Она MUST NOT менять системный nvim, config или SDK пользователя.
Платформы: linux, macos
История: FIXLOG §301
Проверка: tests/install-native-neovim.test.py; вручную (docs/ACCEPTANCE_INSTALLER.md)

#### Scenario: Подготовка и повтор
- **WHEN** publisher передаёт официальный archive или явно разрешает download
- **THEN** проверяются pinned SHA, native platform и версия0.12.2
- **AND** повтор проверяет готовые files без загрузки или замены существующей установки

#### Scenario: Повреждённый archive или чужая платформа
- **WHEN** archive не совпадает с закреплённым source или native probe не проходит
- **THEN** команда завершается до публикации output; прежние каталоги сохраняются
