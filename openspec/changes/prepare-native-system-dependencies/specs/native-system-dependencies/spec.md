# Spec Delta

## Purpose

Обеспечить системные зависимости выбранных компонентов fride штатными
средствами ОС, сохраняя отложенную подготовку языков и работающую установку.

## ADDED Requirements

### Requirement: IDE-BOOT-52 Системные требования выбранных компонентов

Установщик и явная подготовка языка SHALL проверять нужные OS utilities/
runtime libraries и повторно использовать готовые. Debian/Ubuntu SHALL иметь
явный native APT шаг установки недостающего с показом команды/лога и повторной
проверкой. Core MUST NOT устанавливать SDK/средства сборки отложенных языков.
Preview MUST NOT запускать probes/actions. Windows/macOS MUST NOT запускать
APT/Linux probes. Другой Linux MUST NOT ошибочно использовать APT.
Платформы: Windows/macOS (изоляция шага), linux/ubuntu (APT); Omarchy/pacman
отдельно в IDE-143, до реализации — existing reuse/actionable refusal.
Проверка: tests/install-system-dependencies.test.py, native frontend unit checks,
tests/diagnostics/check-cold-install.py; GUI на native машине отдельно.

#### Scenario: Чистая база
- **GIVEN** Core или Terminal требует отсутствующую OS dependency
- **WHEN** пользователь подтверждает native шаг или явно задаёт install policy
- **THEN** видит package command/source и получает установку штатным manager
- **AND** после повторной проверки установка IDE продолжается без ранних SDK

#### Scenario: Состав и повтор
- **WHEN** ставится Custom Core или повторно готовится выбранный язык
- **THEN** неподключённые Terminal/language prerequisites не устанавливаются
- **AND** готовые utilities/libraries пропускаются, SDK/версии/config сохраняются
- **AND** Rust build prerequisites предлагаются только при explicit Rust prepare

#### Scenario: Отказ и ошибка
- **WHEN** действие отменено либо native manager завершается ошибкой/no-op
- **THEN** нет ложного ready и замены прежнего kit, причина/лог доступны
- **AND** отсутствие интерактивного ввода даёт явную automation инструкцию

#### Scenario: Диагностика и платформы
- **WHEN** запрошен preview/print-plan либо read-only check-system
- **THEN** нет установки, SDK downloads и изменения parent environment
- **AND** preview не выполняет OS probes; check-system даёт JSON/exit0 либо2
- **AND** Windows/macOS не вызывают Linux manager; Arch/Omarchy не получает APT
