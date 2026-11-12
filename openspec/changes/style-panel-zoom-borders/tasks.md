# Tasks

## 1. Единый стиль развёрнутых панелей

- [x] 1.1 Добавить native RGB E2E IDE-PANEL-24 в debug-panels и оформить общий zoom через existing controls; проверить active/help/refocus/restore на Locals/Output/Files/Logs.
- [x] 1.2 Один раз прогнать Windows debug-panels/work-panels/outline/git-workflow/tool-panels/frame-layout; сохранить результаты и native UI, Ubuntu/macOS/physical GUI явно непроверены.
- [x] 1.3 Обновить PANEL_KEYS/roadmap, FIXLOG198/HISTORY/AGENT_COMMANDS109 и verification; проверить strict/diff/append-only, commit только завершённой итерации.

Первый единственный прогон: новый IDE-PANEL-24 PASS, следующий старый Debug
сценарий FAIL из-за оставленных Logs вместо Output. Postamble теста исправлен
после прогона и в первой итерации не запускался. Тогда задачи 1.2/1.3 остались
открыты; исходный FAIL сохранён.

Следующая отдельная итерация по поручению владельца: один debug-panels прогон
после postamble fix дал6 PASS/0 FAIL/0 SKIP,12 RGB checkpoints. Runtime прежний,
остальные28 checks пяти файлов из первого прогона PASS. Итоговое выбранное
покрытие Windows34 различных checks; это не новый общий прогон. Финальная
история — FIXLOG199/AGENT_COMMANDS110. Ubuntu/macOS/physical GUI непроверены.
