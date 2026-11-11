# Design

## Context

См. proposal. Registry уже содержит terminal/trouble, placement делает Edgy. В controls есть общий work_maps с сохранением native callbacks для Overseer/Grug-far и переносом cursor из overlay в source. Trouble callback читает выбор через view.win, поэтому перенести только отображение недостаточно. Native Trouble WinClosed останавливает sections; registry Terminal уже закрывает окна публичным nvim_win_close без уничтожения буферов.

## Goals / Non-Goals

**Goals:** завершить существующий маршрут без нового контроллера или состояния; применять native callbacks после восстановления source; hide именно текущего окна при нескольких views.

**Non-Goals:** новый shell/terminal manager, language server, SDK/plugin updates, вся матрица LSP References, постоянные рамки Termide и изменения Debug/SQL/workspace lifecycle. Mac/GUI проверяются отдельно.

## Decisions

- Добавить два backend в существующие titles/work, два focus aliases в keymaps; использовать show_work/registry. T выбран потому, что t занят Tests, x соответствует старому diagnostics prefix. Прежние aliases сохраняются.
- Registry terminal.open получает guard видимости: native :IdeShow terminal после Ctrl-t на b949919 скрывает окно, потому что open вызывает ToggleTerm. IDE-099 воспроизведён отдельным native source case до guard; существующий show должен быть идемпотентным и для старого маршрута.
- Normal q/Esc/? подключить существующим work_maps после native mappings; Trouble g? оставить native help. Печатные terminal-mode mappings не вводить.
- Для terminal/trouble current hide закрывать текущий native window и возвращать код. Registry close остаётся действием всего компонента при смене slot; UI q не должен закрывать соседнюю view. Native WinClosed hooks остаются ответственными за backend cleanup, buffer/job не удаляется. Не хранить отдельный реестр views/PID.
- Trouble normal callbacks оборачивать уже существующим механизмом work_maps: восстановить source/выбор, затем вызвать исходный callback. Не копировать внутреннюю реализацию jump/folds/filter и не добавлять private fork. Native q/?/Esc имеют общий смысл; native help переносится на g?.
- Реальный E2E с shell, несколькими окнами, native Quickfix и gopls diagnostics; no-op input barrier только в тесте. Исходный b949919 проверяется существующим config-source override, без rollback рабочего дерева.

## Risks / Trade-offs

- Native mappings устанавливаются после FileType → scheduled work_maps/существующий refresh и реальные native action tests.
- Native Trouble help тоже имеет filetype=trouble → подключать common maps только к буферам настоящих views с native window metadata; help сохраняет собственные q/Esc.
- IDE-100: тот же native help перехватывает существующий Edgy ft filter. Отдельный source case подтверждает docking; фильтр использует ту же native window metadata, без нового состояния или plugin patch.
- Trouble view читает исходный cursor → тест меняет выбор именно внутри zoom и проверяет другой результат/файл/строку.
- Несколько views одного backend → отдельные tests закрытия текущего окна; whole-slot registry close намеренно прежний.
- Terminal resize может менять padding → прежний semantic history helper, actual PID/channel/output; текст не подменять.
- RPC input не доказывает физическую доставку клавиш → Mac/WezTerm GUI gate остаётся открытым.
