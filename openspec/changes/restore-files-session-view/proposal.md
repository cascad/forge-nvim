# Proposal

## Why

WF-01/02 требуют возвращать дерево Files в прежнем виде. Сейчас перед
mksession tool windows удаляются, после load создаётся новый Explorer.
Раскрытие, выбранный узел, прокрутка и ширина теряются.

## What Changes

- Снимок native Files до cleanup для каждой вкладки: видимость, root,
  раскрытые каталоги, выбранный узел, viewport и ширина.
- Компактные данные рядом с native state, привязанные к фактическому session
  file/hash; файлы и tabpages продолжает сохранять Persistence/mksession.
- Restore через Neo-tree navigate/render и Edgy resize; закрытый Files остаётся закрытым.
- Автоследование реагирует на смену файла, а не на возврат фокуса в тот же
  файл: иначе оно тут же сбрасывает восстановленную прокрутку дерева.
- Общий SavePre/save/SavePost при переключении проекта, без второго autosave
  поверх уже очищенных окон. Failed restart возвращает прежний autosave.
- Permanent native TUI E2E: quit/relaunch, две вкладки, A→B→A, исчезнувший узел.

## Capabilities

### New Capabilities

- `files-session-view`: IDE-PANEL-25, состояние Files в проектной сессии.

### Modified Capabilities

Нет изменений прежних требований; legacy sessions без нового снимка сохраняют прежний путь.

## Impact

Небольшой adapter session_files, hooks editor/start, existing neo_tree_lifecycle,
native E2E и docs. SDK/pins/зависимости прежние. Это первый законченный срез
WF-01, не восстановление всех панелей/живых процессов и не новый layout owner.
