# Spec Delta

## Purpose

Позволить продолжать работу в коде, пока Cargo определяет исполняемую цель
для Rust debugging, и сохранять корректную отмену при смене проекта.

## ADDED Requirements

### Requirement: IDE-DAP-9 Отзывчивое разрешение Cargo debug target

F5 для Rust SHALL ожидать Cargo metadata асинхронно, сохраняя доступными фокус
и ввод в редакторе. Выбор bin/example и отмена SHALL сохранять IDE-DAP-7.
Ошибка metadata SHALL прервать запуск с сообщением; результат прежнего cwd
SHALL не запускать debugger после перехода в другой проект.

Платформы: все. История: FIXLOG §227.
Проверка: tests/e2e/rust-language.test.lua (IDE-DAP-9, IDE-DAP-7).

#### Scenario: Ввод до доставки Cargo metadata

- **GIVEN** Rust project имеет несколько исполняемых целей
- **WHEN** после F5 metadata ещё не доставлена
- **THEN** пользователь может переключить фокус и изменить код до получения результата
- **AND** reference E2E ввод завершается меньше чем за 300ms
- **AND** после результата открывается штатный target picker, Esc отменяет запуск

#### Scenario: Результат прежнего проекта

- **WHEN** пользователь меняет cwd, пока ожидается metadata
- **THEN** прежний результат прерывает запуск без target picker и DAP session

#### Scenario: Выбранный target работает как раньше

- **WHEN** пользователь выбирает второй bin в target picker
- **THEN** сохраняются реальный запуск, breakpoint/eval/output из IDE-DAP-7
