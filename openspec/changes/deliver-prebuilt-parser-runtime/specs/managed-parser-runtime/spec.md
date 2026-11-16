# Spec Delta

## Purpose

Поставка готовых native parser libraries позволяет установить и запустить managed IDE без компилятора на машине пользователя, сохраняя проверку фактической работы подсветки.

## ADDED Requirements

### Requirement: IDE-BOOT-24 Готовые парсеры managed IDE

Managed IDE SHALL получать проверенные native парсеры и связанные queries из своего runtime, без загрузки исходников и запуска компилятора при установке или открытии файла.

Платформы: все. Проверка: tests/install-parser-runtime.test.py; native macOS проверяется владельцем отдельно.

#### Scenario: Установка без build SDK
- **GIVEN** native Core artifact с парсерами существующего каталога, соответствующими закреплённому Treesitter
- **WHEN** пользователь устанавливает Core без tree-sitter CLI и C-компилятора
- **THEN** установка проверяет загрузку native libraries и queries без сборки
- **AND** установленный launcher позволяет реально разобрать и подсветить файл этими libraries

#### Scenario: Неполный или несовместимый набор
- **GIVEN** ранее установленный kit и новый набор с отсутствующей, несовместимой или неверной библиотекой
- **WHEN** выполняется установка нового набора
- **THEN** операция завершается с ошибкой до замены прежнего kit
- **AND** ошибка указывает проблемный parser

#### Scenario: Проверяемый publisher
- **WHEN** publisher упаковывает Core
- **THEN** он проверяет native Neovim, закреплённые Treesitter/grammar revisions и фактическую загрузку libraries
- **AND** сохраняет manifest с platform, source revisions и SHA256 доставленных файлов
- **AND** не изменяет исходный Neovim, пользовательский site или SDK

#### Scenario: Обычная конфигурация
- **GIVEN** конфигурация запущена без managed runtime
- **THEN** существующая явная команда подготовки парсеров остаётся доступной
- **AND** обычное открытие файла не запускает установку или сборку
