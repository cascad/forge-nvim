# Spec Delta

## Purpose

Rust workspace начинает подготовку при выборе проекта с готовыми инструментами,
пока редактор остаётся доступным для обычного ввода и открытия файлов.

## ADDED Requirements

### Requirement: IDE-RUST-2 Ранняя асинхронная подготовка Cargo workspace

При открытии или выборе каталога с Cargo.toml и готовыми Cargo/rust-analyzer
редактор SHALL начать native workspace preparation до первого Rust-файла.
Метаданные и compiler work MUST NOT ожидаться синхронно в UI. Первый .rs SHALL
использовать уже запущенный клиент соответствующего workspace без второго RA.
Без Cargo.toml фоновые Rust-команды MUST NOT запускаться; startup MUST NOT
устанавливать SDK. Устаревший metadata callback после смены проекта SHALL
игнорироваться, собственный pending metadata job SHALL отменяться при quit.
Платформы: все
Проверка: tests/e2e/rust-language.test.lua (IDE-RUST-2)

#### Scenario: Workspace готовится до первого файла
- **GIVEN** выбран Cargo проект с настоящим build script, Rust-файлы ещё не открыты
- **WHEN** backend выполняет compile-time preparation
- **THEN** редактор принимает ввод и открывает обычные файлы, не дожидаясь build script
- **AND** первый Rust-файл подключается к тому же initialized client

#### Scenario: Каталог другого языка
- **GIVEN** в выбранном каталоге нет Cargo.toml
- **WHEN** редактор запускается или сменяется cwd
- **THEN** metadata/rust-analyzer не запускаются этим механизмом

#### Scenario: Проект сменился до ответа metadata
- **GIVEN** metadata прежнего проекта ещё выполняется
- **WHEN** выбран другой каталог или редактор завершает работу
- **THEN** собственный pending job отменяется, ответ прежнего проекта не запускает RA
