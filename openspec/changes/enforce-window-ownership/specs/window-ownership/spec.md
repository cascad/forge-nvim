## ADDED Requirements

### Requirement: IDE-PANEL-32 Владение окнами и время жизни views
IDE SHALL различать editor/tool/transient по единому контракту, защищать owned
панель от случайной подмены и сохранять только документы/разрешённые views.
Платформы: все.
Проверка: tests/e2e/window-ownership.test.lua, tests/e2e/work-panels.test.lua, tests/e2e/outline.test.lua.

#### Scenario: Защищённая панель
- **GIVEN** открыты editor splits и служебная панель
- **WHEN** команда пытается заменить её буфер посторонним
- **THEN** подмена блокируется native guard либо исправляется контроллером
- **AND** owned buffer, modified документы и editor splits сохраняются.

#### Scenario: Разрешённые переходы
- **GIVEN** Files, Git, Tests, Debug или Terminal view
- **WHEN** пользователь переключает штатный source/секцию/terminal или повторно открывает view
- **THEN** native backend выполняет переход без E1513 и без потери job/session/вывода.

#### Scenario: Предпросмотр выбранной задачи
- **GIVEN** в Tasks видны две задачи с разным выводом
- **WHEN** курсор переходит между задачами
- **THEN** Overseer обновляет буфер своего предпросмотра
- **AND** список Tasks сохраняет защиту, а скрытие панели сохраняет активную задачу.

#### Scenario: Outline следует за открытым файлом
- **GIVEN** открыт Outline с символами первого файла
- **WHEN** пользователь открывает второй файл в коде
- **THEN** Aerial обновляет буфер Outline и показывает символы второго файла
- **AND** фокус остаётся в коде.

#### Scenario: Навигация и временные окна
- **GIVEN** picker, gf/gd, quickfix или команда панели ведёт в файл
- **WHEN** выполняется открытие
- **THEN** файл находится в editor, панель остаётся owned view
- **AND** Help/picker/input закрываются доступными средствами с клавиатуры.

#### Scenario: Save и legacy restore
- **GIVEN** документы, editor splits, разрешённые views и случайный Help
- **WHEN** сессия сохраняется и загружается, включая старый session script
- **THEN** Help/menu/input не возвращаются как постоянные панели
- **AND** документы и view data сохраняются без запуска прежнего Terminal/Debug job.
