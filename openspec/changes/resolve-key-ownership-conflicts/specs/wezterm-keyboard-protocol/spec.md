# Spec Delta

## MODIFIED Requirements

### Requirement: WT-KBD-4 Alt как Meta
Терминал SHALL передавать Alt+клавишу (Option+клавишу на macOS) программе как клавишу с модификатором Alt (Meta), а не как символ, который раскладка даёт через Alt/Option. Исключение — правый Alt на Windows на раскладке с AltGr: он SHALL оставаться AltGr и вводить символы третьего уровня раскладки (решение владельца 2026-09-27: на русской раскладке Windows нужен «₽», Meta там — левый Alt). На macOS Meta — и левый, и правый Option (`send_composed_key_when_left_alt_is_pressed = false`, `send_composed_key_when_right_alt_is_pressed = false`; умолчание WezTerm для правого — составной символ). На Windows эти две настройки ничего не решают: запись win32-input-mode несёт состояние клавиш как есть, и символ выбирает ConPTY. Левый Alt там всегда Meta, кроме Alt+Space и Alt+F4, которые забирает оконный слой (WT-KEYS-9). Правый Alt на раскладке с AltGr — это AltGr: в русской раскладке Windows правый Alt+8 вводит «₽», а правый Alt+буква до программы не доходит. На английской раскладке AltGr нет, и правый Alt работает как левый. Клавиша приходит с символом текущей раскладки: на русской Alt+x — это Alt+«ч».
Платформы: все
История: FIXLOG «WezTerm: правый Alt на Windows — AltGr, Alt+Space и Alt+F4 — окну (решения владельца)»
Проверка: вручную (windows; результат — в tests/manual/wezterm-windows.md и в записи FIXLOG «WezTerm: правый Alt на Windows — AltGr, Alt+Space и Alt+F4 — окну (решения владельца)»)

#### Scenario: Левый Option на macOS
- **GIVEN** macOS, английская раскладка, nvim в панели
- **WHEN** пользователь нажимает левый Option+x
- **THEN** nvim получает `<M-x>`, а не символ `≈`

#### Scenario: Правый Option на macOS
- **GIVEN** macOS
- **WHEN** пользователь нажимает правый Option+клавишу
- **THEN** программа получает Alt+клавишу, как от левого Option

#### Scenario: Символы, набираемые через Option, недоступны
- **GIVEN** macOS, раскладка, где символ набирается через Option (например, Option+- на английской даёт `–`)
- **WHEN** пользователь нажимает это сочетание в WezTerm
- **THEN** программа получает Alt+клавишу, а символ раскладки не вводится

#### Scenario: Alt+Enter на Windows
- **GIVEN** Windows, nvim_forge в панели
- **WHEN** пользователь нажимает левый Alt+Enter
- **THEN** программа получает Esc и Enter подряд, nvim видит `<A-CR>` и выполняет code action

#### Scenario: Alt+буква на русской раскладке
- **GIVEN** Windows, русская раскладка, в панели программа
- **WHEN** пользователь нажимает левый Alt + физическую X
- **THEN** программа получает Esc и «ч» подряд (в nvim — `<M-ч>`), а не `<M-x>`

#### Scenario: Правый Alt на Windows с русской раскладкой
- **GIVEN** Windows, русская раскладка (в ней есть AltGr)
- **WHEN** пользователь нажимает правый Alt+8, затем правый Alt + физическую X
- **THEN** в первом случае программа получает символ «₽»
- **AND** во втором программа не получает ничего

#### Scenario: Правый Alt на Windows с английской раскладкой
- **GIVEN** Windows, английская раскладка (AltGr нет)
- **WHEN** пользователь нажимает правый Alt+x
- **THEN** программа получает Esc и `x` подряд, как от левого Alt

#### Scenario: AltGr на Windows — намерение, а не недосмотр
- **GIVEN** Windows, русская раскладка, конфиг загружен с `send_composed_key_when_right_alt_is_pressed = false`
- **WHEN** пользователь нажимает правый Alt+8, затем левый Alt+Enter в nvim_forge
- **THEN** правый Alt+8 вводит «₽»: настройка правого Alt на Windows его в Meta не превращает, и так задумано
- **AND** левый Alt+Enter выполняет code action (`<A-CR>`): Meta на этой раскладке — левый Alt

### Requirement: WT-KBD-6 Что получает nvim на Windows
На Windows nvim SHALL получать клавиши в том виде, в каком их переводит ConPTY, без kitty; это ограничение, а не цель. nvim спрашивает о kitty (`CSI ?u`), ответа не получает (WT-KBD-1) и включает modifyOtherKeys (`CSI >4;2m`). Запрос проходит через ConPTY в WezTerm, но набираемые клавиши это не меняет: они идут записями win32-input-mode, и в последовательности для nvim их переводит ConPTY (modifyOtherKeys влияет только на клавиши, которые WezTerm шлёт сам, WT-KBD-7). Сочетания, которых нет в классической кодировке, до nvim отдельными клавишами не доходят. WezTerm их не перехватывает (WT-KEYS-4), но nvim видит их как другие клавиши и выполняет привязки nvim_forge на этих клавишах, а часть сочетаний не получает вовсе.
Платформы: windows
История: FIXLOG §41, «nvim_forge: мёртвые привязки Ctrl+V удалены, вставку делает WezTerm»

#### Scenario: Ctrl+Shift+буква неотличима от Ctrl+буквы
- **GIVEN** Windows, nvim_forge в панели, любая раскладка
- **WHEN** пользователь нажимает Ctrl+Shift+F, Ctrl+Shift+P, Ctrl+Shift+E или Ctrl+Shift+D
- **THEN** nvim получает `<C-f>`, `<C-p>`, `<C-e>` и `<C-d>` — ровно то же, что от Ctrl+буквы
- **AND** срабатывают привязки nvim_forge на Ctrl+букву (поиск по буферу, поиск файла, фокус проводника, прокрутка на полэкрана), а привязки `<C-S-f>`, `<C-S-p>`, `<C-S-e>`, `<C-S-d>` — нет

#### Scenario: Enter и точка с модификаторами
- **GIVEN** Windows, nvim_forge в панели
- **WHEN** пользователь нажимает Shift+Enter, Ctrl+Enter и Ctrl+.
- **THEN** nvim получает `<CR>`, `<NL>` и `<C-n>`
- **AND** `<NL>` для nvim — та же клавиша, что `<C-j>`: в нормальном режиме Ctrl+Enter переключает нижнюю панель nvim_forge
- **AND** привязки `<S-CR>`, `<C-CR>` и `<C-.>` не срабатывают

#### Scenario: Ctrl+Space не доходит
- **GIVEN** Windows, nvim_forge в режиме вставки
- **WHEN** пользователь нажимает Ctrl+Space
- **THEN** nvim не получает ничего, ручной вызов автодополнения (`<C-Space>`) не срабатывает

#### Scenario: Ctrl+знак препинания на русской раскладке
- **GIVEN** Windows, активна русская раскладка, nvim_forge в нормальном режиме
- **WHEN** пользователь нажимает Ctrl + физическую `;`, затем Ctrl + физическую `/`
- **THEN** nvim получает `<C-v>` и `<C-n>`
- **AND** первое нажатие включает блочное визуальное выделение — встроенное значение `<C-v>` в nvim: своих привязок `<C-v>` у nvim_forge нет (WT-KEYS-7)
- **AND** переключение комментария (`<C-/>`, `<C-_>`) не срабатывает

#### Scenario: F-клавиши с модификаторами приходят под другими номерами
- **GIVEN** Windows, nvim в панели, `TERM=xterm-256color` (умолчание WezTerm)
- **WHEN** пользователь нажимает Shift+F5, Ctrl+F5 и Ctrl+Shift+F5
- **THEN** nvim получает `<F17>`, `<F29>` и `<F41>`, а не `<S-F5>`, `<C-F5>` и `<C-S-F5>`

#### Scenario: Что доходит различимо
- **GIVEN** Windows, nvim в панели
- **WHEN** пользователь нажимает Tab, Shift+Tab, Ctrl+PageUp, Ctrl+PageDown, Alt+букву, Ctrl+букву или Shift+кириллическую букву
- **THEN** nvim получает `<Tab>`, `<S-Tab>`, `<C-PageUp>`, `<C-PageDown>`, `<M-буква>` (буква текущей раскладки, WT-KBD-4), `<C-буква>` (латинская буква этой клавиши и на русской раскладке) и заглавную кириллическую букву текстом
- **AND** F13, который WezTerm шлёт вместо Ctrl+[ (WT-KEYS-6), приходит как `<F13>`
