## Why

IDE-152: при открытии Logs пользователь видит начало истории вместо последних
сообщений. logs.refresh безусловно возвращает прежний winsaveview, а open
создаёт окно после render и не перемещает курсор. Требование IDE-LOG-6 уточняет
открытие/следование хвосту; IDE-LOG-5 (сохранённый вид проекта) сохраняется.

## What Changes

- Открытая заново панель показывает последние записи в хронологическом порядке.
- Обновление следует за хвостом только если cursor был в конце; чтение истории
  сохраняет native view. Новый source/filter тоже начинает с конца результата.
- Session sidecar restore имеет приоритет над default tail при открытии.
- Native E2E на initial/reopen/follow/history/source/filter и прежний session case.

## Capabilities

### New Capabilities
- `log-tail-follow`: начальная позиция и следование за последними логами.

### Modified Capabilities
Нет.

## Impact

forge/logs.lua, registered ide-logs E2E и документация/FIXLOG307. Установка
языков, формат хранения/лимиты, SDK/plugins, Docker Desktop/WSL не меняются.
