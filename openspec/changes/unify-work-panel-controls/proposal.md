# Proposal

## Why

IDE-009: Tests/Test Output, Search и Tasks уже зарегистрированы в ide, но
общий controls знает только Debug/Outline/Files/Git. У новых панелей нет
Space w маршрута, единой помощи/фокуса/zoom; close Search удаляет buffer
с введённым поиском. Нужен следующий перенос принятой клавиатурной модели.

## What Changes

- Space w t/r/f/b открывает и фокусирует Tests/Test Output/Search/Tasks;
  свободные сочетания сохраняют ws/wv/wo и прежние aliases.
- Общие q/Esc/?/Space w z/hjkl/0, индикатор фокуса и помощь с native действиями.
- Hide/смена bottom-слота сохраняет поисковый ввод, test results и running jobs.
- Действия задач из zoom применяются к выбранной строке, с восстановлением
  native окна, которым пользуется Overseer. Ввод insert/terminal сохраняется.
- Реальные Neotest/Go, GrugFar/rg и Overseer/Python E2E, история и шпаргалка.

## Capabilities

### New Capabilities

- `panel-controls`: IDE-PANEL-6/7/8, продолжение unarchived IDE-PANEL-1…5;
  основной spec пока отсутствует. Новые сценарии Tests/Tasks/Search.

### Modified Capabilities

Нет: main specs редактора ещё не сняты. Старые требования и handlers
Debug/Outline/Files/Git сохраняются.

## Impact

ide/controls.lua, search component close, normal keymaps, neotest help alias,
документация и зарегистрированные work-panel E2E. Пины/SDK/зависимости и
системные адаптеры не меняются. Не входят новые языковые адаптеры и неизвестные
IDE-047/048; Mac/физическая доставка клавиш проверяется отдельно.
