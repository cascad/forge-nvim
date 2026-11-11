# Proposal

## Why

После IDE-023 общий маршрут этапа3 остаётся незавершённым для Terminal/Trouble: компоненты зарегистрированы в ide/init.lua, но отсутствуют в titles/work и Space w в controls.lua/keymaps.lua. Нужны те же normal focus/help/hide/zoom, сохранение terminal input/jobs и правильное native действие выбранной строки Trouble из overlay; это продолжение принятой владельцем модели IDE-009, новое IDE-PANEL-17. При проверке найден IDE-099: Ctrl-t → F7 → :IdeShow terminal скрывает видимое окно на b949919; причина — toggle внутри registry open, проверяется тем же E2E.

## What Changes

- Space w T — открыть/сфокусировать managed Terminal, Space w x — Problems/Trouble; t уже занят Tests, x соответствует прежнему Space xx. Прежние terminal/Trouble aliases сохраняются.
- Общие normal q/Esc/? и Space w q/z/? для этих панелей, заголовок/фокус. В terminal-input печатные клавиши остаются вводом программы.
- Hide текущего окна сохраняет другие видимые Terminal/Trouble views и terminal jobs; zoom возвращает тот же buffer и выбор.
- Из Trouble overlay подтверждённое native действие применяется к выбранной строке после возврата исходного окна. Штатные действия backend сохраняются, native help доступна по g?.
- Реальные E2E Windows/Ubuntu: empty/cold routes, terminal input/job/multiple views, gopls diagnostics и native Quickfix/Trouble navigation. Mac/GUI — отдельный gate.

## Capabilities

### New Capabilities

- `terminal-trouble-controls`: IDE-PANEL-17, недостающая часть общей модели панелей.

### Modified Capabilities

Нет. Main specs описывают WezTerm/установщик; прежние IDE-PANEL-1…16 и aliases сохраняются.

## Impact

Существующий ide.controls, config/keymaps.lua, terminal.open в ide/init.lua и Edgy filter Trouble (IDE-100: native help не должна dock-иться как view); один новый E2E suite/registry, история и руководства. Без новых plugins/controllers/state machine, SDK/pins/backports, shell/установщиков, собственного LSP или Docker/WSL lifecycle. Полный Terminal workflow (создание/именование/reorder всех терминалов) и визуальный Termide prototype — отдельные пункты.
