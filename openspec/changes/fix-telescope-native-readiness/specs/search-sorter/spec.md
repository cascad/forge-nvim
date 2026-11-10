# Spec Delta

## Purpose

Обеспечивает быстрый поиск с необязательным native ускорением и наблюдаемым
рабочим fallback на устройствах без готовой библиотеки или инструментов сборки.

## ADDED Requirements

### Requirement: IDE-BOOT-5 — готовность optional native sorter

Редактор SHALL использовать готовый загружаемый native fzf sorter независимо
от наличия build tools в runtime PATH. При отсутствии/ошибке библиотеки поиск
SHALL продолжать работать через Lua fallback. Открытие редактора и поиск
MUST NOT инициировать сборку/скачивание. Явный health SHALL показывать выбранный
sorter и причину fallback; если Telescope ещё не загружен, SHALL сообщать,
что режим не определён. Подготовка optional native artifact SHALL выполняться отдельно.

#### Scenario: Готовая библиотека без build tools
- **WHEN** библиотека подготовлена, а CMake отсутствует в runtime PATH
- **THEN** picker использует настоящий native scoring для поиска файла с клавиатуры

#### Scenario: Отсутствующая библиотека
- **WHEN** готовой библиотеки нет, даже если CMake доступен
- **THEN** поиск имени/содержимого и переход в код работают через fallback, без ошибки UI
- **AND** health явно показывает Lua fallback и причину

#### Scenario: Повреждённая библиотека
- **WHEN** библиотека присутствует, но не загружается
- **THEN** поиск продолжает работать через Lua fallback, а health сохраняет причину

#### Scenario: Ещё не выбранный sorter
- **WHEN** пользователь вызывает health, пока Telescope не загружен
- **THEN** health сообщает о незагруженном Telescope, не объявляет native/fallback подтверждённым и не запускает сборку
