# Proposal

## Why

IDE-034 нарушает ожидаемое удаление чистого текущего worktree (IDE-GIT-3): Neogit планирует смену cwd, но запускает Git раньше неё. На Windows Git возвращает `Permission denied`, оставляет пустой каталог и показывает лишний force prompt. Воспроизведение: `tests/diagnostics/delete-current-worktree.lua`; место — `neogit/popups/worktree/actions.lua`, вызов `status.instance():chdir(main.path)` перед `git.worktree.remove`.

## What Changes

- Дожидаться смены cwd перед удалением текущего linked worktree, сохранив штатные окна, подтверждения и клавиши Neogit.
- Поддержать минимальный временный патч закреплённой версии Neogit через явную подготовку/Lazy build. Проверять исходный и итоговый SHA256; неизвестные исходники не менять. Подготовленный обычный запуск не переписывает исходники.
- Проверять реальный пользовательский маршрут на Windows/Ubuntu, отказ от удаления dirty worktree и повторное использование status. Добавить отдельное воспроизведение границы cwd обычными процессами Git.
- Записать результат, ограничения Mac/GUI и условие удаления временного патча в общую историю.

## Capabilities

### New Capabilities

- `git-workflow`: IDE-GIT-7, удаление активного linked worktree без лишнего force prompt; развивает capability из ещё не архивированных Git changes.

### Modified Capabilities

Нет: основная базовая линия пока содержит только WezTerm/macOS installer.

## Impact

Конфигурация Neogit, явная подготовка его исходников, editor/ConPTY test profiles и контейнерная подготовка. Базовая ревизия Neogit остаётся прежней; поведение Windows/macOS/Linux единое. Патч не относится к IDE-035 (незавершённый Gitsigns attach), SDK/ConPTY или shell startup.
