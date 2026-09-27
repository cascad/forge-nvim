# wezterm-keyboard-protocol Specification

## Purpose
Как WezTerm (`wezterm.lua`) кодирует нажатия для программы в панели: какой клавиатурный протокол действует на Windows и на macOS, как ведут себя Shift, Alt, Super и системный метод ввода (IME), в каком виде уходят клавиши, которые WezTerm отправляет сам, и что из-за этого получает nvim. Не покрывает, какие сочетания WezTerm перехватывает (wezterm-key-ownership), смысл копирования и вставки (wezterm-clipboard), таблицы режимов (wezterm-windows-mode, wezterm-scrollback). Linux получает ветку конфига «не Windows» (kitty включён, IME-маски нет) и отдельно не описывается. Наблюдения для Windows сняты пробой через тот же conpty.dll, что поставляется с WezTerm, с nvim 0.12; поведение macOS выведено из исходника WezTerm 20240203 и на Mac не проверялось.

## Requirements

### Requirement: WT-KBD-1 Windows — протокол win32-input-mode, kitty выключен
На Windows терминал SHALL передавать набираемые клавиши программе записями win32-input-mode (`allow_win32_input_mode = true`) и SHALL игнорировать попытки программы включить kitty keyboard protocol (`enable_kitty_keyboard = false`). Между WezTerm и программой на Windows всегда стоит ConPTY. Он сам включает у терминала win32-input-mode, и каждое нажатие уходит целиком: код клавиши, скан-код, символ текущей раскладки с учётом Shift и Ctrl, модификаторы. Во что это превратится для программы, решает ConPTY (что получает nvim — WT-KBD-6). Push, set и запрос флагов kitty WezTerm молча игнорирует. Kitty выключен потому, что кодировщик kitty в WezTerm считает раскладку US и теряет Shift+кириллицу и знаки русской раскладки. Клавиши, которые WezTerm отправляет от себя (F13 вместо Ctrl+[, Ctrl+C без выделения), идут не записями win32-input-mode, а xterm-кодировкой (WT-KBD-7).
Платформы: windows
История: FIXLOG §41

#### Scenario: Заглавная кириллица и русская запятая в Claude Code
- **GIVEN** Windows, русская раскладка, в панели Claude Code (при старте он шлёт kitty push `CSI >5u`)
- **WHEN** пользователь набирает `a`, `b`, Shift+Ф, Shift+/ (русская запятая), `c`, `d`
- **THEN** в поле ввода Claude Code появляется `abФ,cd`

#### Scenario: Английская раскладка
- **GIVEN** Windows, английская раскладка, любая программа в панели
- **WHEN** пользователь набирает Shift+A и Shift+/
- **THEN** программа получает `A` и `?`

#### Scenario: Программа пытается включить kitty
- **GIVEN** Windows, программа в панели прислала push или set флагов kitty (`CSI >Nu`, `CSI =Nu`)
- **WHEN** пользователь нажимает клавишу, которую WezTerm не перехватывает
- **THEN** WezTerm по-прежнему кодирует её в win32-input-mode
- **AND** при `debug_key_events = true` в debug overlay видна строка `win32: Encoded input …` и ни одной `kitty: Encoded input …`

#### Scenario: Запрос поддержки kitty остаётся без ответа
- **GIVEN** Windows
- **WHEN** программа спрашивает о поддержке kitty (`CSI ?u`)
- **THEN** WezTerm на запрос не отвечает, и программа видит терминал без kitty

### Requirement: WT-KBD-2 macOS — kitty keyboard protocol включён
На macOS терминал SHALL поддерживать kitty keyboard protocol (`enable_kitty_keyboard = true`): отвечать на запрос поддержки, принимать от программы push, set и pop флагов и, пока флаги включены, кодировать по kitty клавиши, которые WezTerm не перехватил. Программа, которая kitty не включала, получает классическую кодировку (WT-KBD-5). Флаги у каждой панели свои, отдельно для основного и альтернативного экрана. Они держатся, пока программа их не снимет, или до полного сброса терминала (RIS, например командой `reset`). Ради kitty на macOS nvim различает сочетания, которых нет в классической кодировке. Перехваты WezTerm от протокола не зависят (WT-KEYS-3).
Платформы: macos
История: FIXLOG §41

#### Scenario: nvim получает «хитрые» сочетания отдельными клавишами
- **GIVEN** macOS, в панели nvim_forge (nvim сам включает kitty при старте)
- **WHEN** пользователь нажимает Ctrl+., Ctrl+Shift+P или Ctrl+Enter
- **THEN** nvim получает `<C-.>`, `<C-S-p>` и `<C-CR>` — не `.`, не `<C-p>` и не `<CR>`

#### Scenario: Программа без kitty
- **GIVEN** macOS, в панели шелл, который kitty не включал
- **WHEN** пользователь нажимает клавиши с модификаторами
- **THEN** шелл получает их в классической xterm-кодировке без kitty-последовательностей

#### Scenario: Программа завершилась, не сняв флаги kitty
- **GIVEN** macOS, программа на основном экране панели (например, Claude Code) включила kitty и завершилась аварийно, не прислав `CSI <u`
- **WHEN** пользователь набирает в шелле той же панели Ctrl+C или Esc
- **THEN** WezTerm продолжает кодировать клавиши по kitty: Ctrl+C и Esc уходят kitty-последовательностями, а не байтами 0x03 и 0x1b
- **AND** после полного сброса терминала (`reset`) шелл снова получает классическую кодировку

### Requirement: WT-KBD-3 macOS — нажатия с Shift идут через IME, текст приходит без модификаторов
На macOS терминал SHALL отдавать в системный метод ввода (IME) нажатия без модификаторов и нажатия, где среди модификаторов есть Shift (в том числе Ctrl+Shift и Cmd+Shift), кроме сочетаний с Alt/Option. Текст, который выдал IME, программа SHALL получать без модификаторов. Так работает маска `macos_forward_to_ime_modifier_mask = "SHIFT"`. Это инвариант: значение совпадает с умолчанием WezTerm и записано явно. Поэтому Shift+буква любой раскладки приходит в kitty-кодировщик готовым текстом, и ошибка кодировщика с не-US раскладками (WT-KBD-1) на macOS не проявляется. Сочетания с Ctrl или Cmd без Shift и любые сочетания с Alt в IME не уходят (Alt — WT-KBD-4). Если IME текста не дал (например, на Ctrl+Shift+буква), клавиша обрабатывается обычным путём, с модификаторами. Привязки WezTerm по физической позиции клавиши сопоставляются раньше IME, поэтому IME их не забирает.
Платформы: macos
История: FIXLOG §41

#### Scenario: Заглавная кириллица и запятая в kitty-программе
- **GIVEN** macOS, русская раскладка, в панели Claude Code с включённым kitty
- **WHEN** пользователь набирает `a`, `b`, Shift+Ф, русскую запятую, `c`, `d`
- **THEN** в поле ввода появляется `abФ,cd`

#### Scenario: Заглавная кириллица в nvim
- **GIVEN** macOS, русская раскладка, nvim в режиме вставки с включённым kitty
- **WHEN** пользователь нажимает Shift+Ф
- **THEN** в буфер вставляется `Ф`

#### Scenario: Привязки WezTerm срабатывают раньше IME
- **GIVEN** macOS, русская раскладка
- **WHEN** пользователь нажимает Ctrl+Shift+Space (Shift в маске IME) или Cmd+C
- **THEN** срабатывает привязка WezTerm (режим WINDOWS, копирование), IME нажатие не получает

#### Scenario: Ctrl+Shift+буква без привязки
- **GIVEN** macOS, в панели nvim с включённым kitty
- **WHEN** пользователь нажимает Ctrl+Shift+P
- **THEN** IME текста не выдаёт, и nvim получает клавишу с Ctrl и Shift (`<C-S-p>`, WT-KBD-2)

#### Scenario: Инвариант маски
- **GIVEN** конфиг загружен на macOS
- **THEN** `macos_forward_to_ime_modifier_mask` равна `"SHIFT"` — без CTRL, ALT и SUPER

### Requirement: WT-KBD-4 Alt как Meta
Терминал SHALL передавать Alt+клавишу (Option+клавишу на macOS) программе как клавишу с модификатором Alt (Meta), а не как символ, который раскладка даёт через Alt/Option. На macOS так работают левый и правый Option (`send_composed_key_when_left_alt_is_pressed = false`, `send_composed_key_when_right_alt_is_pressed = false`; умолчание WezTerm для правого — составной символ). На Windows эти две настройки ничего не решают: запись win32-input-mode несёт состояние клавиш как есть, и символ выбирает ConPTY. Левый Alt там всегда Meta, кроме Alt+Space и Alt+F4, которые забирает оконный слой (WT-KEYS-9). Правый Alt на раскладке с AltGr — это AltGr: в русской раскладке Windows правый Alt+8 вводит «₽», а правый Alt+буква до программы не доходит. На английской раскладке AltGr нет, и правый Alt работает как левый. Клавиша приходит с символом текущей раскладки: на русской Alt+x — это Alt+«ч».
Платформы: все

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

### Requirement: WT-KBD-5 Устаревшая кодировка CSI-u выключена
Терминал SHALL NOT использовать устаревшую кодировку клавиш CSI-u (`enable_csi_u_key_encoding = false`). Программа, которая сама не включила kitty, получает клавиши в классической xterm-кодировке; расширенные коды получают только программы, включившие kitty на macOS (WT-KBD-2). На Windows путь до программы задают win32-input-mode и ConPTY (WT-KBD-1).
Платформы: все

#### Scenario: Шелл без kitty на macOS
- **GIVEN** macOS, в панели шелл без kitty и без modifyOtherKeys
- **WHEN** пользователь нажимает Ctrl+Enter, затем Ctrl+.
- **THEN** шелл получает для Ctrl+Enter тот же `\r`, что для Enter, а для Ctrl+. — просто `.`
- **AND** последовательностей вида `CSI <код>;<модификаторы>u` WezTerm не шлёт

### Requirement: WT-KBD-6 Что получает nvim на Windows
На Windows nvim SHALL получать клавиши в том виде, в каком их переводит ConPTY, без kitty; это ограничение, а не цель. nvim спрашивает о kitty (`CSI ?u`), ответа не получает (WT-KBD-1) и включает modifyOtherKeys (`CSI >4;2m`). Запрос проходит через ConPTY в WezTerm, но набираемые клавиши это не меняет: они идут записями win32-input-mode, и в последовательности для nvim их переводит ConPTY (modifyOtherKeys влияет только на клавиши, которые WezTerm шлёт сам, WT-KBD-7). Сочетания, которых нет в классической кодировке, до nvim отдельными клавишами не доходят. WezTerm их не перехватывает (WT-KEYS-4), но nvim видит их как другие клавиши и выполняет привязки nvim_forge на этих клавишах, а часть сочетаний не получает вовсе.
Платформы: windows
История: FIXLOG §41

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
- **AND** первое нажатие вставляет системный буфер обмена (привязка nvim_forge на `<C-v>`), а переключение комментария (`<C-/>`, `<C-_>`) не срабатывает

#### Scenario: F-клавиши с модификаторами приходят под другими номерами
- **GIVEN** Windows, nvim в панели, `TERM=xterm-256color` (умолчание WezTerm)
- **WHEN** пользователь нажимает Shift+F5, Ctrl+F5 и Ctrl+Shift+F5
- **THEN** nvim получает `<F17>`, `<F29>` и `<F41>`, а не `<S-F5>`, `<C-F5>` и `<C-S-F5>`

#### Scenario: Что доходит различимо
- **GIVEN** Windows, nvim в панели
- **WHEN** пользователь нажимает Tab, Shift+Tab, Ctrl+PageUp, Ctrl+PageDown, Alt+букву, Ctrl+букву или Shift+кириллическую букву
- **THEN** nvim получает `<Tab>`, `<S-Tab>`, `<C-PageUp>`, `<C-PageDown>`, `<M-буква>` (буква текущей раскладки, WT-KBD-4), `<C-буква>` (латинская буква этой клавиши и на русской раскладке) и заглавную кириллическую букву текстом
- **AND** F13, который WezTerm шлёт вместо Ctrl+[ (WT-KEYS-6), приходит как `<F13>`

### Requirement: WT-KBD-7 Клавиши, которые WezTerm отправляет сам
Клавиши, которые WezTerm отправляет программе от себя, терминал SHALL кодировать xterm-кодировкой независимо от kitty и win32-input-mode. Таких клавиш две: F13 вместо Ctrl+[ (WT-KEYS-6) и Ctrl+C без выделения на Windows (WT-CLIP-2). F13 всегда уходит как `CSI 25~`. Ctrl+C уходит байтом 0x03, а если программа включила modifyOtherKeys в режиме 2 (`CSI >4;2m`; на Windows так делают nvim и Claude Code, запрос проходит через ConPTY), — как `CSI 27;5;99~`. modifyOtherKeys WezTerm принимает всегда, от конфига это не зависит. На Windows ConPTY переводит обе формы для программы: nvim получает `<C-c>` и `<F13>`.
Платформы: все
История: FIXLOG §17, §31

#### Scenario: Ctrl+C без выделения в nvim на Windows
- **GIVEN** Windows, nvim в панели (включил modifyOtherKeys), выделения WezTerm нет
- **WHEN** пользователь нажимает Ctrl+C
- **THEN** WezTerm шлёт `CSI 27;5;99~`, и nvim получает `<C-c>`

#### Scenario: Ctrl+C без выделения в шелле на Windows
- **GIVEN** Windows, в панели шелл без modifyOtherKeys, выделения нет
- **WHEN** пользователь нажимает Ctrl+C
- **THEN** WezTerm шлёт 0x03, и шелл получает прерывание

#### Scenario: F13 на Windows
- **GIVEN** Windows, nvim в панели
- **WHEN** пользователь нажимает Ctrl+[
- **THEN** WezTerm шлёт `CSI 25~`, и nvim получает `<F13>`

#### Scenario: F13 в kitty-программе на macOS
- **GIVEN** macOS, nvim с включённым kitty
- **WHEN** пользователь нажимает Ctrl+[
- **THEN** WezTerm шлёт `CSI 25~`, а не kitty-последовательность, и nvim получает `<F13>`

### Requirement: WT-KBD-8 Super без привязки
Нажатие с Super (Cmd на macOS, Win на Windows), для которого нет привязки WezTerm, терминал SHALL передавать программе без модификатора Super. Исключение — программы с включённым kitty на macOS: они получают клавишу вместе с Super. Встроенных Cmd-сочетаний у конфига нет (WT-KEYS-1), поэтому на macOS, например, Cmd+K и Cmd+W в шелле печатают `k` и `w`. На Windows большинство сочетаний с Win забирает ОС. Те, что доходят до WezTerm, уходят записью win32-input-mode без признака Win.
Платформы: все

#### Scenario: Cmd+буква в шелле на macOS
- **GIVEN** macOS, в панели шелл без kitty
- **WHEN** пользователь нажимает Cmd+K
- **THEN** в строку шелла вводится `k`, WezTerm ничего не очищает

#### Scenario: Cmd-сочетание в nvim на macOS
- **GIVEN** macOS, nvim_forge с включённым kitty
- **WHEN** пользователь нажимает Cmd+Alt+L
- **THEN** nvim получает `<D-A-l>` и форматирует буфер

#### Scenario: Win+буква на Windows
- **GIVEN** Windows, сочетание Win+буква, которое ОС пропустила в WezTerm
- **WHEN** пользователь его нажимает
- **THEN** программа получает саму букву, без Win
