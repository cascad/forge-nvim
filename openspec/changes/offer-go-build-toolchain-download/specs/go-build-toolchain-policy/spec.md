## ADDED Requirements

### Requirement: IDE-BOOT-42 Явный build toolchain для Go tools

Установщик SHALL отдельно предлагать разрешение штатному Go получить необходимый
build toolchain для IDE tools, сохраняя выбранный SDK проекта. Разрешение SHALL
действовать только в tools stage согласованной операции до Mason initialization.
Без явного выбора загрузки SHALL быть запрещены. Установка SHALL использовать
native Go/Mason providers и сохранять checksum/proxy настройки пользователя.

Платформы: все
Проверка: tests/install-go-toolchain.test.py.

#### Scenario: Интерактивный выбор

- **GIVEN** выбраны Go tools и не задан CLI выбор
- **WHEN** пользователь проходит установщик в терминале
- **THEN** он видит отдельное объяснение native downloads и выбор по умолчанию Нет
- **AND** отказ сохраняет local policy, а отмена сохраняет предыдущий kit

#### Scenario: Автоматический запуск и preview

- **WHEN** установка запущена без терминала
- **THEN** только явный --go-toolchain-download allow разрешает переключение/загрузку
- **AND** deny, отсутствие выбора, preview и check не инициируют downloads
- **AND** план и лог показывают выбранную policy

#### Scenario: Native provider и граница процесса

- **GIVEN** доступен рабочий Go1.21+ и пользователь выбрал allow
- **WHEN** Mason устанавливает Go tool с требованием более нового compiler
- **THEN** GOTOOLCHAIN=auto доступен native provider до его initialization
- **AND** plugins/parsers/probes используют local, runtime и проектный SDK сохраняются
- **AND** готовые tools переиспользуются без обязательной загрузки compiler

#### Scenario: Ошибка установки

- **WHEN** новый compiler недоступен, offline или checksum policy запрещает загрузку
- **THEN** установка сообщает native причину и лог без автоматического retry
- **AND** предыдущий kit и глобальное окружение остаются прежними
