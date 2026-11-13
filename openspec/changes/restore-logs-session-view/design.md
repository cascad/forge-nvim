# Design

## Context

См. proposal. session_files хранит данные с SHA native session и tab order,
снимает их до SavePre cleanup и возвращает по готовности Files renderer.
Logs — один native buffer/общие filters, окна по tabpages. Edgy имеет get_win/
Window:resize; анимация отключена, BufWinEnter планирует native layout update.

## Goals / Non-Goals

**Goals:** дополнить существующий sidecar без второго storage/layout owner.
**Non-Goals:** другие панели/перемещение между сторонами, копии buffers,
перезапуск процессов, замена Persistence/Edgy, новые зависимости или таймеры.

## Decisions

- Переименовать session_files в session_views и обновить прежние три hooks.
  В существующем version1 добавить необязательный logs у каждой вкладки:
  false означает явно скрытый, nil — старые Files-only данные. Никакой миграции
  или второго JSON; session hash/фильтрация закрытых tabs остаются прежними.
  Общие source/minimum/query хранятся один раз в data.logs, в том числе когда
  все окна скрыты; tab.logs хранит только native view/height/lines.
- Существующие публичные поля Logs передаются в снимок, native windows дают
  winsaveview/height/lines. Данные validate до открытия. Позиция winrestview ограничивается
  текущим содержимым, resize масштабируется при меньшем UI. Текст логов не
  сериализуется заново: log_store уже хранит ограниченную настоящую историю.
- Сначала Files, затем Logs той же вкладки, затем следующая вкладка. Обычный
  ide.show управляет bottom slot. Один vim.schedule после native open позволяет
  Edgy зарегистрировать окно; public resize и callback допускают следующий tab.
  Общий completion сохраняет прежний code focus. Альтернатива polling/отдельный
  manager не нужна. Сохранение окон через mksession вернуло бы stale tool state.
- Refresh Logs сохраняет native views его существующих окон, чтобы обновление
  общего buffer не сбрасывало другую вкладку/чтение старого сообщения.
- Тест использует прежний session_tui: реальный PTY, новые PID, keyboard input
  и read-only наблюдение; новые runner/инфраструктура не требуются.

## Risks / Trade-offs

- Edgy/layout и async Files → последовательное завершение по существующим
  render callback, native тест на нескольких tabs и resize.
- История может быть обрезана/изменена → native clamping, никакого выдуманного
  восстановления старого содержимого. Filters общие, как уже устроен Logs.
- Старые Files-only JSON → optional поле и прежние session/legacy regressions.
- Windows/Ubuntu проверяются локально; Mac/physical остаются явно открытыми.
- Первый target22642014015600 прошёл quit/relaunch, A→B→A, hidden filters и
  refresh. Ошибка тестового UI fixture: фиксированные host45 строк оставили
  native child42, как до resize. Target не объявлен PASS. Тест теперь уменьшает
  высоту относительно реального saved.lines, сохраняет raw sidecar; runtime прежний.
