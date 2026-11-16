# Spec Delta

## Purpose

Проверка обычного Git до установки Core предотвращает неработающий plugin setup и сохраняет привычные настройки, credentials и SSH пользователя.

## ADDED Requirements

### Requirement: IDE-BOOT-27 Обычный Git для Core

Установщик SHALL переиспользовать рабочий Git пользователя и MUST проверять его до загрузки IDE artifacts/setup; при отсутствии SHALL предложить явный выбор существующего Git или штатной установки.

Платформы: все. Проверка: tests/install-git-prerequisite.test.py, native Windows/Ubuntu; Mac отдельно владельцем.

#### Scenario: Git готов
- **GIVEN** Git доступен в PATH или явно выбранном внешнем каталоге
- **WHEN** устанавливается Core
- **THEN** используется тот же Git без private copy и автоматического upgrade
- **AND** его обычные configuration/credentials/SSH environment сохраняются в launcher

#### Scenario: Git отсутствует или не запускается
- **WHEN** Git не проходит bounded native version probe
- **THEN** interactive installer предлагает существующий каталог, штатную установку, recheck или cancel
- **AND** Git нельзя пропустить как необязательный язык
- **AND** noninteractive запуск завершается до загрузки artifacts, сохраняя прежний kit

#### Scenario: Явная установка
- **WHEN** пользователь выбирает установку Git
- **THEN** показаны команда и источник системного менеджера и запрошено отдельное подтверждение
- **AND** отказ ничего не устанавливает
- **AND** exit0 менеджера без готового Git не считается успехом

#### Scenario: Preview и Apple shim
- **WHEN** выполняется обычный preview
- **THEN** Git/SDK/manager не запускаются
- **AND** обнаружение Apple Git не запускает установку Developer Tools через системный shim
