# Design

## Context

См. proposal.md. Neogit уже содержит все базовые операции, менеджер IDE регистрирует его split справа; Diffview открывает отдельный tab. Общий контроллер пока не знает NeogitStatus. Используем API и исходники закреплённых плагинов из подготовленного lock.

## Goals / Non-Goals

**Goals:** общие панели без изменения семантики Git; e2e реальных popup/input/commit editor и локального remote на двух ОС.

**Non-Goals:** новый Git backend, обновление зависимостей, merge/rebase-конфликты, сетевые credentials, автоматическое закрытие чужих файлов при смене worktree.

## Decisions

- `Space w g` и старый `Space g G` используют registry; старый `Space g g` сохраняет отдельный tab. Esc/? и g? задаются через opts. Запись q=Close в конфигурации сохраняется: её используют log/diff. Общий q и адаптер zoom устанавливаются только в готовом status на NeogitStatusRefreshed; FileType ещё слишком рано для его карт.
- Zoom использует общий overlay. Перед Git-действием выбранная строка переносится в исходное окно backend, как для дерева. q/Esc не заменяют подтверждения операций Git.
- Действия с ветками/worktree выполняет Neogit. Его cwd относится к выбранному worktree; уже открытые файлы не переносятся молча в другой каталог.
- Сквозной e2e показал сброс cwd через project.nvim BufEnter старого файла. Включаем manual_mode: cwd принадлежит выбранной рабочей папке. Open folder уже вызывает set_pwd и сохраняет историю; ProjectRoot остаётся явным автоопределением. Не закрываем старые файлы, не патчим project.nvim и не добавляем OS-ветки.
- Начальный cwd и DirChanged записываются в историю через штатный set_pwd с уже текущим cwd. Проверяем Recent Projects настоящим picker: в нём есть исходный и новый worktree, при этом фокус старого файла не меняет root.
- Windows e2e выявил ошибку Neogit Path:make_relative: смешанные разделители оставляли абсолютный путь в patch. Обновляем только pin Neogit до upstream d7bb91b4 (#1977), не патчим private API и не вводим альтернативную реализацию stage. Повторно готовим зависимости и образ, проверяем общий регресс.
- E2E готовит private identity/hooks/config, main и bare origin средствами Git, затем подаёт только реальные клавиши. Read-only Git-команды проверяют index/HEAD/remote/worktree. Ошибки не заглушаются и диалоги не подменяются.

## Risks / Trade-offs

- Native input/confirm блокирует обычный RPC → наблюдать grid/mode и отвечать вводом, без вызова Lua во время confirm.
- У backend собственные окна/курсоры → проверить stage из zoom и возврат из Diffview, не ограничиваться наличием хоткеев.
- Автосохранение может вмешиваться в commit editor → пройти реальный commit до bare remote.
- macOS и физический терминал здесь недоступны → оставить команды владельцу, не выдавать Ubuntu за macOS.

## Migration Plan

После изменения lock явно повторить prepare_editor.py --download и сборку
Ubuntu-образа; обычный запуск редактора не готовит тестовые зависимости.
Для установленной IDE Neogit приводится к lazy-lock через обычный Lazy restore.
Откат: вернуть pin 395ac481, адаптеры Git-панели и прежний manual_mode, затем
повторить подготовку тестовых зависимостей. Это вернёт и известный Windows hunk bug.
