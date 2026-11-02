# Proposal

## Why

IDE-038: real editor регресс IDE-GIT-7 после dirty cancel → commit → повторного visit вернул Windows Git exit 255/Permission denied (artifact 551474721600). Подтверждён отдельный механизм: живой object read Gitsigns с cwd linked удерживает каталог; перенос cwd редактора этого не устраняет. Владелец handle именно первого случайного сбоя пока не установлен.

## What Changes

- Сохранить наблюдение фактических cwd/окон/процессов и управляемый real Git repro; различать уже завершённый Git с задержанным результатом и живой процесс, удерживающий каталог.
- Убрать ненужный переход в worktree при чтении Git-объектов, уже адресованных явным git-dir. Сохранить выбранный HEAD и cwd семантику команд, работающих с файлами. Без произвольной паузы, blind retry/force или завершения процессов.
- Проверить удаление при живом object read, dirty cancel и сохранность main/linked с разными HEAD. Внешнее удержание каталога и прочие причины Permission denied остаются отдельными ошибками Git, не объявлять их устранёнными.
- Выполнить E2E Windows/Ubuntu, дописать историю и команды; Mac/GUI оставить непроверенными без реального запуска.

## Capabilities

### New Capabilities

- `git-workflow`: IDE-GIT-9, удаление worktree во время фонового чтения Git-объектов. Основного Git spec ещё нет; capability продолжает существующие unarchived changes IDE-GIT-1…8.

### Modified Capabilities

Нет.

## Impact

Граница object reads Gitsigns, существующий backport с pin/SHA, диагностический наблюдатель и real Git fixtures. CLI A/B: с -C удаление даёт 255, с явным git-dir без -C — 0 при том же живом show. Pin, Neogit и Windows SDK сохраняются. IDE-039/040 и shell startup не входят в этот change.
