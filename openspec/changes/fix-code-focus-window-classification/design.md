# Design

## Context

CODE_WINDOW_REVIEW и FIXLOG §155 разделили обязанности. В state уже есть is_main_window; он не создаёт окна, в отличие от find_main_window. Activities tool_filetypes содержит дополнительные SQL/legacy исключения и используется session cleanup.

## Goals / Non-Goals

**Goals:** исключить terminal/float из focus-only кандидатов и убрать расходящееся правило buftype, сохранив отсутствие side effects.

**Non-Goals:** общий finder/manager, session cleanup, guard markers/winfix/relocation, новый tool registry, focus retry timers и preferred split policy. Процесс PTY и SDK не меняются.

## Decisions

- Локальный is_code_window в activities делегирует обычную классификацию state.is_main_window и дополнительно сохраняет прежнее not tool_filetypes[ft]. Таблица не переписывается; прямой вызов find_main_window здесь запрещён, поскольку он может создать split.
- State require выполняется внутри predicate, без новой связи модулей при загрузке. Нового слоя классификации нет.
- F7 использует ide.buffers.is_editor_window и отдельный Diffview-aware выбор, без создания. В E2E создание main проверяется Space w 0; F7 проверяется при уже существующем main. Первоначальное предположение теста о создании через F7 было ошибочным, runtime F7 не меняется.
- Три постоянных native E2E: реальный nvim PTY process, настоящие окна/float, F7/md/wc и сохранение process/window identity. До изменения runtime получить native RED. SQL/legacy исключения сохраняются по прежнему списку; полноценная SQL матрица не объявляется повторно проверенной.

## Risks / Trade-offs

- State имеет legacy edgy_disable override → прежний activities tool filter сохраняется поверх него.
- Отложенный focus может перебивать очень быстрый следующий ввод → новая политика не меняет retry timers; E2E разделяют действия ожиданием результата, быстрые гонки требуют отдельного среза.
- API native fixture не доказывает GUI/физические клавиши → Mac/GUI gate открыт.
