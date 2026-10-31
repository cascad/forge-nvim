# Proposal

## Why

Следующий пункт IDE_ROADMAP после Outline — создание, переименование и
перемещение файлов из дерева и общий маршрут панели. Neo-tree уже содержит
эти операции, но пользовательские сценарии не покрыты E2E. Его q/Esc/? и
заголовок ещё не включены в Space w; источник Files/Buffers/Git разделяет
один filetype и требует корректного выбора компонента. Требования этого
изменения: IDE-PANEL-4 и IDE-FILE-1/2.

## What Changes

- Space w e открывает/фокусирует Files. Старые Space e/E и source aliases
  сохраняются, управление источниками согласуется с менеджером слотов.
- Общие q/Esc/help/zoom и видимый фокус сохраняют строку Files/Buffers/Git.
- Проверка настоящих диалогов создания, rename и move, cut/paste; отмена и
  конфликт имён сохраняют файлы. Открытые буферы продолжают указывать на файл
  после переименования/перемещения. Исправления вносятся по воспроизведениям.
- Постоянные E2E на Windows и Ubuntu, команды владельцу для macOS.

## Capabilities

### New Capabilities

- `file-explorer`: управление файлами и деревом с клавиатуры в общей модели.

### Modified Capabilities

Нет. Контракты Debug и Outline из активных changes сохраняются.

## Impact

Neo-tree integration, ide.controls и keymaps; новые editor E2E/fixtures,
реестр, roadmap/инструкции/FIXLOG/хронология. Общий код Windows/macOS/Ubuntu;
новые зависимости, обновление lock и платформенные обходы не планируются.
