# Tasks

## 1. Переходы панелей

- [x] 1.1 Добавить настоящий source regression Files/DAP UI/quickfix/PTY:
  panel-transitions.test.lua и dap-tab-scope.test.lua, Windows13 RED/1 control;
  промежуточный source после close fix также воспроизводит Show чужой вкладки. Ubuntu
  source 2026-11-11 был прерван; 2026-11-12 полный Ubuntu source12 RED/
  1 control + dap-tab-scope1 RED сохранён отдельно.
- [x] 1.2 Сосредоточить show/hide/toggle/layout в существующем state,
  убрать прямой повторный close из controls и дубли в activities;
  проверить panel-transitions Windows/Ubuntu, source/tree/tab boundaries.
  Windows14 target/53 integration PASS. Ubuntu первоначальный target12 PASS/
  1 FAIL нашёл IDE-116; после его исправления target13 + tab-scope1 PASS.
- [x] 1.3 Записать IDE-109/110/IDE-PANEL-21 в FIXLOG/HISTORY, команды,
  уточнить PANELS_PLAN/roadmap; git diff --check и append-only guard.

## 2. Интеграция

- [ ] 2.1 Пройти native debug/work/tool/Outline/frame/project/session E2E
  Windows/Ubuntu, проверить config sources, root exit/API errors/owned scopes;
  unit/trace и OpenSpec strict. Mac и физические клавиши не засчитывать.
- [ ] 2.2 Пройти тот же native сценарий на Mac; записать actual результат.
