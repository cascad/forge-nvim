# Proposal

## Why

IDE-137 / IDE-PANEL-29: config.start.normalize_dir удаляет POSIX root '/';
path_inside_dir строит двойной slash для roots с конечным separator. Выбор '/'
отвергается. Windows source workflow прошёл: native exit save компенсирует
пропуск explicit save; пользовательская потеря сессии там не доказана. Это общий
path boundary в выбранном workspace, не новая политика определения root.

## What Changes

- Сохранить filesystem roots при нормализации и проверке принадлежности файла.
- Permanent native TUI E2E: выбрать root, открыть private файл, уйти в другой
  проект и вернуться с восстановлением файла/сессии.
- Проверить прежний A→B→A session workflow как control.

## Capabilities

### New Capabilities

- `project-paths`: нормализация и принадлежность файлов выбранной папке.

### Modified Capabilities

Нет; baseline IDE ещё не снята.

## Impact

config.start, existing project-session E2E/session_tui, OpenSpec/docs/history.
Без изменения project.nvim/persistence/native restart/session backend,
SDK/pins/backports или нового resolver. Тест пишет только private fixture.
