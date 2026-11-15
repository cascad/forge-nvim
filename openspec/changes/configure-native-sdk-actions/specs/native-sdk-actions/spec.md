# Spec Delta

## Purpose

Дать пользователю понятное управление недостающими SDK прямо в native установщике, сохраняя штатное окружение, выбранные компоненты и прежнюю установку IDE.

## ADDED Requirements

### Requirement: IDE-BOOT-19 Явные действия над SDK

Установщик SHALL предлагать клавиатурные действия existing path/install/skip/refresh/cancel для nonready SDK в TTY; SDK install MUST выполняться только после отдельного подтверждения конкретной штатной команды.
Платформы: все.
История: FIXLOG §247.
Проверка: tests/install-sdk-actions.test.py и installer controls; native Mac/real package installation отдельно владельцем.

#### Scenario: Existing SDK location
- **WHEN** пользователь указывает существующий SDK root/bin
- **THEN** location проверяется и добавляется после caller PATH
- **AND** при успешной установке сохраняется как launcher fallback без SDK homes или global PATH edits
- **AND** выбранная проектная venv сохраняет приоритет

#### Scenario: Explicit SDK installation
- **WHEN** пользователь выбирает Install
- **THEN** он видит manager/command/source/default version policy и подтверждает действие
- **AND** без подтверждения процесс установки не запускается
- **AND** результат/логи сохраняются, SDK проверяется повторно; exit0 без ready SDK не считается успехом

#### Scenario: Skip dependent features
- **WHEN** пользователь подтверждает Skip
- **THEN** удаляются перечисленные зависимые компоненты, SDK closure пересчитывается
- **AND** final plan отражает изменение до запуска IDE backend

#### Scenario: Cancellation and retry
- **WHEN** SDK action не удался или был отменён
- **THEN** пользователь может вернуться к выбору, повторить либо выйти с130
- **AND** прежний kit и caller environment сохраняются; standalone SDK не удаляются

#### Scenario: Noninteractive and read-only modes
- **WHEN** нет TTY или вызван preview/check-sdks
- **THEN** SDK не устанавливаются и action menu не открывается
- **AND** noninteractive missing SDK сохраняет actionable refusal по IDE-BOOT-18
