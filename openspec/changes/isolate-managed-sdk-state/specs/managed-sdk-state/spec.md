## Purpose

Отделять SDK state/config/cache установленного fride от прежних инструментов пользователя одной политикой для подготовки и запуска на поддерживаемых ОС.

## ADDED Requirements

### Requirement: IDE-BOOT-16 Private SDK environment

Managed setup/probes/launcher SHALL использовать общую policy для Cargo/Rustup, Go, npm и Python state/cache/config/global tool paths внутри kit. Наследованные SDK redirect variables MUST не возвращать запись в прежние SDK homes. State paths SHALL создаваться при явной установке; повтор SHALL сохранять собственные state/config files. Mutable executable dirs SHALL быть доступны в PATH после runtime и до caller PATH. PS launcher MUST восстановить caller process env после exit/error. Startup SHALL не выполнять SDK installs/config migrations/helper processes.
Платформы: windows, linux/ubuntu, macos (native gate отдельно).
Проверка: tests/install-sdk-state.test.py.

#### Scenario: Scope и caller context
- **WHEN** kit подготавливается или запускается при существующих SDK overrides
- **THEN** child видит private SDK paths, caller/foreign files остаются прежними
- **AND** HOME, project VIRTUAL_ENV/build-target context не переписываются

#### Scenario: Настоящая работа SDK
- **WHEN** из managed child выполняются offline native SDK state/global install commands
- **THEN** результаты/кэш/config оказываются в kit и доступны штатным инструментам
- **AND** ни прежние SDK dirs, ни shell profiles/PATH registry не изменяются

#### Scenario: Повтор и startup
- **WHEN** установка повторяется либо editor запускается снова
- **THEN** собственные настройки/state сохраняются, policy применяется без подготовки SDK на startup
- **AND** личные configs/credentials не импортируются автоматически
