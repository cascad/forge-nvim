# Ручные проверки WezTerm — macOS

Чек-лист владельца (change `review-baseline`, design, решения 3 и 4): только
платформенные пути macOS — IME, kitty, Cmd, окружение launchd, симлинк,
шрифты и то, что по исходнику ведёт себя иначе, чем на Windows. Общий код
WezTerm проверяется на Windows (`tests/manual/wezterm-windows.md`).

**Порядок.** Сверху вниз. WezTerm.app запускается из Dock (не из терминала),
раскладки ABC/US и «Русская». Перед прогоном: `git pull` в чекауте,
`./nvim_forge/scripts/install-macos.sh`, полностью выйти из WezTerm (Cmd+Q) и
запустить из Dock; `nvim -l tests/run.lua` из чекаута зелёный.

**Результат** дописывается строкой в конец пункта, прежние строки не
правятся, последняя — текущий статус:

    Проверено: <дата>, <ОС и версия>, WezTerm <версия>, раскладка <…> — совпало | расходится: <что видно>

**Ожидаемое** — текст требования в `openspec/specs/` на момент прогона. Где
требование поменял уже применённый, но ещё не заархивированный change, код
работает по его delta, и сверка идёт с delta (change назван в пункте).
«Расходится» — правится спека (правило фазы 1, `review-baseline`, решение 5).

## Паспорт

### M0 — паспорт прогона
Требования: —. Источник: divergence 47.
Шаги: `wezterm --version`, `sw_vers`, список раскладок (Системные настройки →
Клавиатура → Источники ввода).
Ожидаемое: версия WezTerm 20240203-110809-5046fc22 (как в
`tests/wezterm/VERSION`). Другая — см. Risks в design `review-baseline`:
сверка с исходником 20240203 может не подойти.
Воспроизведение для: `add-wezterm-spec-checks` (задача 8.2), `restructure-wezterm-config` (задача 7.2).

## wezterm-keyboard-protocol

### M1 — kitty в nvim_forge
Требования: WT-KBD-2. Источник: divergence 28.
Шаги: в nvim_forge `:lua print(vim.fn.keytrans(vim.fn.getcharstr()))` и
нажать Ctrl+., Ctrl+Shift+P, Ctrl+Enter. В nvim нажать Ctrl+Shift+Space (Esc)
и Ctrl+Shift+R. В шелле `printf '\e[>1u'`, затем Esc и Ctrl+C, затем `reset`.
Ожидаемое: сценарии «nvim получает «хитрые» сочетания отдельными клавишами»
(`<C-.>`, `<C-S-P>`, `<C-CR>`; Ctrl+Shift+Space и Ctrl+Shift+R перехватывает
WezTerm) и «Программа завершилась, не сняв флаги kitty» (Esc и Ctrl+C идут в
kitty-кодировке до `reset`).

### M2 — Shift через IME на русской раскладке
Требования: WT-KBD-3. Источник: divergence 29.
Шаги: русская раскладка; в Claude Code набрать `ab`, Shift+Ф, `,`, `cd`;
нажать Ctrl+Shift+Space (Esc); выделить текст мышью и нажать Cmd+C.
Ожидаемое: сценарии «Заглавная кириллица и запятая в kitty-программе»
(`abФ,cd`) и «Привязки WezTerm срабатывают раньше IME» (WINDOWS включается,
Cmd+C копирует).

### M3 — Ctrl+[ и Esc
Требования: WT-KBD-7, WT-KEYS-6. Источник: divergence 30.
Шаги: в nvim_forge строка с отступом, Ctrl+[ в нормальном режиме; Esc в
режиме вставки.
Ожидаемое: WT-KEYS-6 «Сдвиг строки влево в nvim» и «Esc не затронут»;
WT-KBD-7 «F13 в kitty-программе на macOS».

### M4 — CSI-u выключен
Требования: WT-KBD-5. Источник: divergence 32.
Шаги: в шелле `cat -v`, нажать Ctrl+Enter и Ctrl+., выйти Ctrl+D.
Ожидаемое: сценарий «Шелл без kitty на macOS» — `^M` и `.`.

### M5 — Cmd без привязки
Требования: WT-KBD-8, WT-KEYS-1. Источник: divergence 33.
Шаги: в шелле Cmd+K, Cmd+W, Cmd+1; в nvim_forge Cmd+Alt+L.
Ожидаемое: WT-KBD-8 «Cmd+буква в шелле на macOS» (`k`, `w`, `1`) и
«Cmd-сочетание в nvim на macOS» (буфер отформатирован); WT-KEYS-1
«Встроенных Cmd-сочетаний на macOS нет».

## wezterm-clipboard

### M6 — Ctrl+C, Cmd+C, Cmd+V
Требования: WT-CLIP-3, WT-CLIP-5, WT-CLIP-10. Источник: divergence 47.
Шаги: `sleep 100` → Ctrl+C. Выделить мышью вывод → Cmd+C → `pbpaste`.
`printf A | pbcopy`, дождаться, пока выделение погаснет (новый вывод), Cmd+C →
`pbpaste`. Cmd+V в шелле. То же на русской раскладке.
Ожидаемое: WT-CLIP-3 «Ctrl+C при выделении — прерывание, а не копирование»;
WT-CLIP-5 «Выделение мышью в шелле» и «Выделение уже погасло (случай §42)» —
буфер остался `A`; WT-CLIP-10 «Cmd+C и Cmd+V на русской раскладке (macOS)».
Воспроизведение для: `fix-copy-clobbers-clipboard` (задача 2.5) — один прогон.

## wezterm-scrollback

### M7 — выгрузка `b` из WezTerm.app
Требования: WT-SCROLL-13. Источник: divergence 46.
Шаги: WezTerm.app из Dock, в шелле немного вывода, Ctrl+Shift+Space → `b`.
Если вкладка не открылась — WINDOWS → `d` (debug overlay) и `ls -l
~/.wezterm_scrollback.txt`.
Ожидаемое: сценарий «Выгрузка вывода шелла» — новая вкладка с nvim, курсор
на последней строке. Если nvim не найден: записать, есть ли в overlay «No
viable candidates found in PATH» и записан ли файл.

## wezterm-panes-tabs

### M8 — Cmd+Q
Требования: WT-PANE-8. Источник: вопрос «Cmd+Q».
Шаги: во всех панелях только шеллы; Cmd+Q → `n`; Cmd+Q → Esc; на русской
раскладке Cmd+Q → клавиша Y, потом клик по [Y]es.
Ожидаемое: сценарий «Cmd+Q всегда спрашивает».

### M10 — каталог новой панели без OSC 7
Требования: WT-PANE-12. Источник: вопрос «каталог без OSC 7».
Шаги: zsh без shell-integration WezTerm; `cd /tmp`; Ctrl+Shift+Enter; в
новой панели `pwd`.
Ожидаемое: сценарий «macOS, zsh или bash без OSC 7» — `/tmp`.

## wezterm-windows-mode

### M9 — Esc на экране выбора панели
Требования: WT-WIN-7. Источник: вопрос «Esc на экране выбора».
Шаги: две панели; Ctrl+Shift+Space → `q` → Esc; нажать `l`.
Ожидаемое (delta `fix-windows-mode-modality`): «Esc на экране выбора —
macOS» — экран закрыт, режим выключен ещё на `q`, `l` уходит в шелл.
Воспроизведение для: `fix-windows-mode-modality` (задача 3.1).

## wezterm-config-loading

### M11 — перечитывание через симлинк
Требования: WT-LOAD-14. Источник: вопрос WT-LOAD-14.
Шаги: в чекауте поменять `wezterm.lua` (например, `config.line_height`) и
сохранить, Ctrl+Shift+R не нажимать; вернуть.
Ожидаемое: сценарий «macOS — правка через симлинк» — конфиг перечитался сам.

## wezterm-ui

### M12 — шрифты
Требования: WT-UI-4. Источник: вопрос «шрифты на Mac».
Шаги: запуск WezTerm.app из Dock; `wezterm ls-fonts | head`.
Ожидаемое (delta `fix-ui-robustness`): «Шрифт установлен» — окна
«wezterm Configuration Error» нет; `ls-fonts` находит основной шрифт по
имени «CaskaydiaCove NF».
Воспроизведение для: `fix-ui-robustness` (задача 3.3).

## wezterm-window-state

### M13 — уведомление о сохранении
Требования: WT-STATE-3. Источник: вопрос «уведомления».
Шаги: Ctrl+Shift+S, засечь, сколько держится уведомление; Cmd+Shift+S.
Ожидаемое: сценарии «Сохранение» (текст уведомления, пропадает примерно
через 3 с) и «Cmd+Shift+S на macOS».
