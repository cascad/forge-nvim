## Purpose

Обеспечить проверяемую установку всех плагинов выбранной конфигурации, чтобы готовность комплекта соответствовала закреплённым исходникам, а не одному коду возврата команды.

## ADDED Requirements

### Requirement: IDE-BOOT-30 Проверяемая подготовка plugins

Явный setup SHALL установить missing plugins и восстановить их по исходному lockfile, проверить ошибки задач Lazy, наличие plugins и совпадение Git HEAD с закреплёнными commits до backports/следующих stages/публикации. Отказ SHALL вернуть nonzero с именем и причиной. Setup MUST сохранять исходные байты lockfile при успехе и отказе. Обычный запуск подготовленного редактора SHALL не устанавливать missing plugins автоматически. Windows подготовка SHALL поддерживать длинные пути штатной настройкой Git только в дочернем окружении подготовки, сохраняя пользовательский Git config и унаследованные настройки. Linux/macOS SHALL использовать общий путь подготовки без Windows-настроек.

Проверка: tests/install-plugin-setup.test.py и actual Custom Core acceptance; native Mac отдельно.

#### Scenario: Cold setup и повторный запуск
- **WHEN** в чистом профиле выполняется явный setup
- **THEN** каждый plugin готов на закреплённом commit, backports проверены и lockfile сохранён
- **AND** обычный запуск не устанавливает удалённый plugin

#### Scenario: Clone, build или pin failure
- **WHEN** clone/build завершается ошибкой либо HEAD не соответствует lock
- **THEN** setup завершается nonzero с именем plugin, без ready/следующих stages
- **AND** исходный lockfile сохранён

#### Scenario: Длинный Windows путь
- **WHEN** Git checkout plugin содержит пути длиннее традиционного Windows ограничения
- **THEN** явная подготовка применяет process-local core.longpaths
- **AND** глобальный Git config, SDK environment и существующие Git параметры не меняются
