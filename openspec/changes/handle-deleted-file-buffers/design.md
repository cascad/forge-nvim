# Design

## Context

В IDE-032 NeogitStatusRefreshed → set autoread | checktime обрабатывает оставшийся загруженным файл удалённого worktree. Native FileChangedShell deleted выводит E211; общий checktime фактически проверяет только видимые окна. Контроль финального сценария на старой полной config-source даёт E211 без Gitsigns traceback (36164862736900). ide.buffers уже содержит common missing warning при show и may_autosave/ForgeBufferClose для отмены deferred save.

## Goals / Non-Goals

**Goals:** штатная обработка deleted, сохранность текста и обычного autoread/conflict, детерминированный Git/editor red и постоянный регресс Windows/Ubuntu.

**Non-Goals:** удалять/переименовывать пользовательские буферы автоматически, подтверждать потерю unsaved данных за пользователя, менять worktree Git backend/пины/SDK, отключать checktime/все warnings, повышать timeout, заявлять Mac/GUI проверенными.

## Decisions

- Common ide.buffers использует FileChangedShell и v:fcs_reason/v:fcs_choice для deleted. Остальные причины сохраняют native default ask, если другой handler ещё не выбрал действие. Не оборачиваем приватные методы Neogit и не фильтруем все ошибки глобально.
- Missing episode хранится по буферу/имени, единое предупреждение для события и show. Буфер/modified/undo не меняются. BufWritePost/BufFilePost/BufWipeout управляют сбросом состояния.
- Конкретное warning идёт через уже установленный Fidget public notify: многострочный default vim.notify сам создал hit-enter при первом исправлении. Глобальный vim.notify не переопределяется. История Fidget проверяется public get_history.
- Нативное обнаружение удаления снимает Gitsigns через public detach. Один раз за episode проверяются другие загруженные файлы, ранее прочитанные с диска; missing watchers снимаются сразу, для hidden ставится public checktime N. Новые ещё не существовавшие файлы не превращаются в quarantined. После успешной записи штатный BufWritePost возвращает attach/autosave; простое переименование не снимает удержание.
- FileChangedShell запрещает переключать буферы, а native early return при ignore пропускает FileChangedShellPost. Поэтому deferred save отменяет сам AutoSave через добавленное public cancel trigger FileChangedShell для его opts.buf, включая hidden. Наш handler установлен раньше lazy AutoSave, отмечает deleted и временно разрешает cancel condition; flag снимается schedule после native события. Самого переключения буфера/приватного API нет.
- E2E синхронизирует настоящий checktime после настоящего Git remove, без подмены результата Git; несколько loaded буферов проверяют hidden lifecycle, текст/modified, отсутствие E211, ввод/запись/закрытие панели и source/main сохранность. Готовность GitSigns diff наблюдается, пока каждый файл видим: плагин намеренно откладывает diff скрытого буфера.
- Отдельные реальные buffer E2E проверяют deferred save, repeated checktime, явную запись/Save As, autoread и conflict. Общие timeout остаются прежними.

## Risks / Trade-offs

- Handler FileChangedShell отключает native default всех причин → для не-deleted явно сохранять ask и проверить конфликт/обычный autoread.
- Cancel event может попасть в текущий tool buffer → AutoSave native callback получает opts.buf целевого файла, проверяется hidden pending save.
- Файл может исчезнуть повторно/поменять имя → состояние episode сбрасывается только после явной успешной записи/смены имени и удаления буфера; не терять предупреждение следующего удаления.
- Предыдущая сборка и SDK уже изменены в рабочем дереве → baseline снимок FIXLOG/buffers и append-only §95, не сбрасывать старые изменения.
- Найдены отдельные от успешно завершённого удаления проблемы: IDE-034 — native Git/Neogit отказ удаления самого cwd на Windows; IDE-035 — удаление во время initial Gitsigns attach. Сохранены диагностические CLI с исходными действиями, они остаются следующими пунктами плана. Основной regression IDE-032 соответствует прежнему долгому commit/push сценарию с уже готовыми signs, при успешном Git remove.
