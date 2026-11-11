# Панели: шпаргалка

`Space` — leader. Команды ниже работают в normal mode. Из terminal input:
`Ctrl-\`, затем `Ctrl-n` либо `Esc Esc`; `F7` сразу возвращает фокус в код.
В insert/terminal печатные символы получает редактор или запущенная программа.

| Открыть / сфокусировать | Клавиши |
|---|---|
| Код | `Space w 0` / `F7` |
| Files / Outline | `Space w e` / `Space w a` |
| Git | `Space w g` |
| Locals / Debug Output | `Space w d` / `Space w c` |
| Tests / Test Output | `Space w t` / `Space w r` |
| Search / Tasks | `Space w f` / `Space w b` |
| Terminal | `Space w T` (заглавная T) |
| Problems / Trouble | `Space w x` |

| Действие в рабочей панели | Клавиши |
|---|---|
| Соседнее видимое окно | `Space w h/j/k/l` |
| Следующее / предыдущее окно | `F6` / `Shift-F6` |
| Скрыть панель и вернуться в код | `q` / `Space w q` |
| Развернуть / вернуть | `Space w z` |
| Выйти из zoom, иначе фокус в код | `Esc` |
| Общая помощь | `?` / `Space w ?` |
| Закрыть помощь | `q` / `Esc` |
| Выбор / основное действие списка | `j/k` / `Enter` |

`[focus]` в заголовке показывает активную область. Открытие/фокус сохраняет
видимую панель; toggle отдельно скрывает/возвращает её. В коде `q` сохраняет
штатный смысл Vim, `Space w q` закрывает окно. Debug sidebar скрывается группой;
в Terminal/Trouble скрывается текущее окно. Скрытие сохраняет jobs и вывод,
не продолжает и не завершает отладку.

Помощь поверх zoom сохраняет развёрнутую панель плавающей; `q` возвращает
в неё, `Esc` из zoom — в исходный slot. Если backend закрыл исходное окно,
zoom убирается с возвратом в код. Явный выбор другой панели сохраняет её фокус.

Terminal: `i` — ввод; normal `Ctrl-t` / `Space tt` — toggle, `Ctrl-\` из кода —
тот же toggle. В terminal-normal `Ctrl-\` остаётся native prefix; повтор
`Ctrl-\ Ctrl-n` безопасен. `Space w T` открывает/фокусирует без toggle.

Trouble: `Space xx` — diagnostics, `Space xQ` — Quickfix; `zo/zc` — раскрыть/
свернуть, `Enter` — перейти, `g?` — штатная справка. В zoom новое выделение
используется подтверждённым действием backend. Files/Outline/Tests/Tasks/Git
имеют свою штатную справку `g?`; конкретные действия — в общей `?` и
[полном руководстве](../nvim_forge/QUICKSTART.md).

Windows/Ubuntu: native E2E. Mac и физическая доставка клавиш WezTerm проверяются
отдельно; наличие одинаковой привязки не является результатом GUI-проверки.
