# Tasks

## 1. Рабочий opt-in пилот

- [x] 1.1 Добавить native E2E IDE-PANEL-20, fixture и registry; сохранить source RED без команды Windows.
- [x] 1.2 Реализовать явное включение/выключение, same-buffer Locals/Code,
  живые переменные/шаг/следующую остановку; frame-layout E2E Windows/Ubuntu.
- [x] 1.3 Поддержать общие клавиши, resize, hide/reopen, tab/session/native
  выход и cleanup; frame-layout и прежние panel E2E Windows/Ubuntu.
- [x] 1.4 Записать FIXLOG с IDE-PANEL-20 (ADDED), HISTORY/commands/руководство
  и измерения цены пилота, окна/строки/время; проверить prefixes и diff --check.

- [x] 1.5 Дополнить Windows native frontend probe: собственное окно в уже
  запущенном WezTerm, CLI/PTY/remote TUI, Locals/step/help/zoom/restore,
  проверка pane ID/cwd и завершения. tests/diagnostics/wezterm-frame.lua;
  CLI ввод не засчитывать за физические клавиши/pixel QA.

## 2. Оценка перед распространением

- [ ] 2.1 Проверить пилот физически в WezTerm Windows/macOS, включая ввод,
  шрифт/размер, resize и возврат session; записать реальные результаты.
- [ ] 2.2 По результату сравнить пользу/сложность с обычным layout и принять
  решение о распространении; default не менять до отдельного решения.
