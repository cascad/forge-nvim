## Purpose

Редактирование, форматирование, запуск и обычное тестирование Bash scripts
через общие клавиши и панели терминальной IDE на целевых ОС.

## ADDED Requirements

### Requirement: IDE-SH-1 Языковые действия Bash

Редактор SHALL предоставлять definition/references/rename, completion и
диагностику Bash при наличии явно подготовленных language tools. Открытие
файла MUST NOT устанавливать SDK/tools или запускать иную ОС.

Платформы: все
Проверка: tests/e2e/bash-language.test.lua (IDE-SH-1)

#### Scenario: sourced library и языковые действия
- **GIVEN** script и локальная sourced library в workspace с пробелом/Unicode
- **WHEN** пользователь использует gd/gr/F2 и принимает LSP completion
- **THEN** получает definition/references/rename реальных symbols и вставленный completion
- **AND** diagnostic видна через gl и исчезает после исправления

#### Scenario: IDE-058 повторные URI одного файла
- **GIVEN** rename reply содержит одинаковые edits под URI с разным регистром percent encoding
- **WHEN** пользователь переименовывает symbol в workspace с Unicode
- **THEN** каждый edit применяется один раз, аргументы вызовов и соседний текст сохраняются

#### Scenario: tools отсутствуют
- **WHEN** пользователь открывает Bash файл без установленных language tools
- **THEN** редактирование остаётся доступным, установки и blocking prompt нет

### Requirement: IDE-SH-2 Форматирование Bash

Редактор SHALL форматировать Bash через подготовленный formatter по общим
командам и после сохранения, соблюдая проектные настройки. Результат после
save MUST сохраняться без второго write.

Платформы: все
Проверка: tests/e2e/bash-language.test.lua (IDE-SH-2)

#### Scenario: manual и save
- **WHEN** пользователь нажимает Space l f и затем сохраняет неформатированный script
- **THEN** получает языковое форматирование и корректный файл на диске

### Requirement: IDE-SH-3 Нативный запуск script

Редактор SHALL запускать сохранённый Bash script с аргументами в общих Tasks,
показывать stdout/stderr и настоящий exit status. Пути и аргументы с пробелами/
Unicode MUST передаваться целиком. Выбор executable MUST NOT неявно запускать
WSL или менять shell пользователя.

Платформы: все
Проверка: tests/e2e/bash-language.test.lua (IDE-SH-3)

#### Scenario: запуск и ошибка script
- **WHEN** пользователь вызывает BashRunFile или Space j b
- **THEN** запускается текущий script из workspace cwd, вывод и status доступны в Tasks
- **AND** script с exit 7 виден как failed, после завершения доступен код
- **AND** Bash profile/BASH_ENV/ENV hooks не исполняются процессами run/tests

#### Scenario: Bash отсутствует
- **WHEN** пользователь запускает script без пригодного interpreter
- **THEN** видит одно понятное сообщение о подготовке, остаётся в редакторе
- **AND** WSL/SDK/пакеты не запускаются и не устанавливаются автоматически

### Requirement: IDE-SH-4 Обычные Bash tests

Редактор SHALL запускать выбранный Bats test или файл через общие Tests
клавиши, показывать реальные pass/fail и output. Обычный test run MUST NOT
создавать DAP session или No active session overlay.

Платформы: все
Проверка: tests/e2e/bash-language.test.lua (IDE-SH-4)

#### Scenario: nearest, соседний fail и file
- **GIVEN** один успешный и соседний падающий Bash test
- **WHEN** пользователь запускает nearest через Space T t, затем файл через Space T f
- **THEN** nearest исполняет только выбранный test, file исполняет оба
- **AND** реальные результаты/вывод видны в Tests/Test Output, соседний marker подтверждает выбор
