# Proposal

## Why

IDE-138 требует установки с чистой машины, но `sdk_install::recipe` сейчас прекращает действие при отсутствии WinGet/Homebrew. Пользователь вынужден самостоятельно искать установщик менеджера, хотя уже выбрал установку SDK.

## What Changes

- Предлагать официальный bootstrap отсутствующего WinGet на Windows или Homebrew на macOS с отдельным подтверждением по умолчанию «Нет».
- После bootstrap повторно искать менеджер, затем отдельно подтверждать команду SDK. Отказ, ошибка и exit0 без менеджера возвращают SDK menu.
- Переиспользовать менеджер в стандартном каталоге вне PATH; сохранять только фактически найденные SDK bin paths.
- В Ubuntu использовать штатный APT; отсутствие APT означает неподдерживаемое/повреждённое окружение, которое установщик не перестраивает.

## Capabilities

### New Capabilities

- `native-sdk-manager-bootstrap`: явная установка отсутствующего штатного менеджера SDK.

### Modified Capabilities

Нет.

## Impact

Native installer Rust, SDK menu, контролируемые native PTY E2E, документация установки. Без новых Rust dependencies, изменений SDK homes, глобального PATH/profile и автоматической установки SDK. Полный release inventory и native Mac acceptance остаются следующими пунктами.
