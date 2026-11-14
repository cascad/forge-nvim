# Spec Delta

## Purpose

Позволить выбрать набор IDE-компонентов с клавиатуры и применить выбор к
установке, автоматически включая общие зависимости выбранных возможностей.

## ADDED Requirements

### Requirement: IDE-BOOT-10 Default и Custom профиль установки

Установщик SHALL иметь Default без интерактивных действий и Custom с
клавиатурными галочками. Core SHALL быть обязательным, зависимости SHALL
добавляться автоматически. Явный список компонентов SHALL обходить UI;
неизвестный компонент SHALL отказывать до package steps. Mask SHALL определять
вызываемые OS SDK handlers, Mason tools, parsers и Terminal preparation.

Платформы: все. История: FIXLOG §235.
Проверка: tests/install-profile.test.py и bootstrap transport/UI regression.

#### Scenario: Default

- **WHEN** выбран Default
- **THEN** выбраны все visible компоненты и их зависимости, меню не требуется

#### Scenario: Custom и отмена

- **WHEN** пользователь меняет галочки и подтверждает выбор
- **THEN** Core остаётся, выбранные компоненты передаются backend
- **AND** при отмене package installer не запускается

#### Scenario: Зависимость без JS-набора

- **WHEN** выбраны Python/Bash без JS
- **THEN** Node runtime включён как зависимость, JS tools/parsers не включены

#### Scenario: Legacy и обычный старт

- **WHEN** installation mask не задан
- **THEN** существующий direct setup catalog сохраняется, daily startup не
  устанавливает инструменты
