# Tasks

## 1. docs/WEZTERM.md — руководство, выведенное из спек

- [x] 1.1 Посмотреть, какие changes поведения WezTerm уже применены (`openspec list`, `git log --oneline -- wezterm.lua`). Снять `wezterm --config-file F:/repo/forge-nvim/wezterm.lua show-keys` в файл во временном каталоге: он служит эталоном для всей группы (design, решение 2). Проверка (windows): в снимке есть заголовки `Default key table` и `Key Table: windows`, а `wezterm --config-file F:/repo/forge-nvim/wezterm.lua ls-fonts` не пишет в stderr строк с `ERROR`.
- [x] 1.2 Переписать шапку и раздел «Принципы» (разделы 0–1 по design, решение 1). Содержание:
  - где лежит конфиг и как понять, что он загружен (WT-LOAD-1, -3, -4, -13, -15);
  - вход в режим WINDOWS Ctrl+Shift+Space вместо LEADER;
  - физические позиции клавиш (WT-KEYS-2) и исключения, где важен символ раскладки: метки QuickSelect, метки `q`, y/n в запросах WezTerm (WT-SCROLL-12, WT-WIN-7, WT-PANE-4);
  - встроенные привязки отключены (WT-KEYS-1);
  - строка про `openspec/specs` и `openspec/changes`.

  Проверка: `grep -n 'LEADER' docs/WEZTERM.md` ничего не находит.
- [x] 1.3 Написать раздел «Режим WINDOWS» по WT-WIN-1…21 и WT-UI-12…15. Содержание:
  - вход и выход: Esc, Enter, повторный Ctrl+Shift+Space;
  - таймаут 5 с от последней распознанной команды;
  - что происходит с клавишами без команды — так, как работает код на момент применения (WT-WIN-4);
  - таблица команд с колонками «режим остаётся / выключается» (WT-WIN-19) и «Спека»;
  - `o` и `x` — как в коде на момент применения (WT-WIN-6, WT-WIN-10);
  - RESIZE заменяет режим (WT-WIN-11);
  - `d` открывает debug overlay;
  - бейджи WINDOWS/RESIZE/COPY/SEARCH: у оверлеев бейджа нет, COPY/SEARCH принадлежат панели, при нехватке места бейдж обрезается.

  Проверка (windows): число строк таблицы и их действия совпадают с блоком `Key Table: windows` снимка из 1.1.
- [ ] 1.4 Написать разделы «Панели», «Вкладки и окна» и «Воркспейсы» (WT-PANE-1…13, WT-KEYS-5, WT-UI-13). Содержание:
  - прямые Ctrl+Shift+H/J/K/L и стрелки для фокуса;
  - подтверждение закрытия — только если в панели есть процесс не из списка по умолчанию; на русской раскладке ответить можно только мышью (WT-PANE-4);
  - каталог новой панели: OSC 7, без него — каталог процесса (WT-PANE-12);
  - размер новых окон — как в коде на момент применения (WT-STATE-2);
  - команды режима — ссылкой на раздел WINDOWS.

  Проверка (windows): в панели с одним pwsh Ctrl+Shift+W закрывает её без вопроса, а Ctrl+Shift+K переводит фокус в панель выше; каждое сочетание из разделов есть в `Default key table` снимка из 1.1; строки только для macOS сверены с таблицей WT-KEYS-3.
- [ ] 1.5 Написать разделы «История», «QuickSelect» и «Выгрузка в nvim» (WT-SCROLL-1…15). Содержание:
  - вход через Ctrl+Shift+X / Ctrl+Shift+U и через `[` / `f` / Space / `b` в режиме WINDOWS (режим при этом выключается сам);
  - очистка — Ctrl+Shift+Delete (на Mac — Forward Delete, fn+⌫);
  - Ctrl+R перебирает три типа поиска по кругу: без учёта регистра → regex → с учётом регистра;
  - `/` и `f` восстанавливают шаблон вкладки, Ctrl+U очищает его;
  - Esc в поиске закрывает и copy mode;
  - Enter и PageUp/PageDown в поиске — как в коде на момент применения (WT-SCROLL-10, WT-SCROLL-15);
  - H/M/L держат отступ в 5 строк, `g`/`G` сохраняют столбец;
  - метки QuickSelect латинские: на русской раскладке переключиться на английскую и стереть набранную кириллицу; Shift+метка копирует и сразу вставляет; поиск идёт по экрану и до 1000 строк выше;
  - выгрузка: пустые строки выпадают, на альтернативном экране выгружается только видимый экран, запускается `nvim` из PATH без nvim_forge.

  Убрать ссылку на несуществующий комментарий о переключении на nvim_forge и заголовок «Весь вывод».

  Проверка (windows):
  - в pwsh выполнить `'a'; ''; 'b'`, затем Ctrl+Shift+Space и `b` — в nvim строки `a` и `b` идут подряд;
  - Ctrl+Shift+X, `/` и трижды Ctrl+R — тип поиска возвращается к исходному;
  - `grep -n 'в комментарии рядом\|Весь вывод' docs/WEZTERM.md` ничего не находит.
- [x] 1.6 Написать разделы «Буфер обмена», «Окно и шрифт» и «Различия Windows и macOS» (WT-CLIP-*, WT-STATE-*, WT-KBD-1…5, WT-PANE-8, WT-UI-1, WT-UI-2). Таблица перехватов строится по WT-KEYS-3 с колонками Windows/macOS/Спека. В разделах отразить:
  - Super-сочетания шрифта есть и на Windows (клавиша Win), часть из них забирает ОС;
  - `Ctrl+Shift+K/L` в этих разделах не встречаются (они — навигация);
  - debug overlay — `d` в режиме WINDOWS.

  Проверка:
  - (windows) каждое сочетание с пометкой «Windows» есть в `Default key table` снимка из 1.1;
  - строки только для macOS совпадают с таблицей WT-KEYS-3 из `openspec show wezterm-key-ownership --type spec`.
- [x] 1.7 Переписать раздел «Что отдано nvim и что nvim получает» (WT-KEYS-4, WT-KEYS-6, WT-KEYS-7, WT-KBD-6, WT-KBD-7). Что сделать:
  - убрать Ctrl+Shift+B/J как «панели nvim»: Ctrl+Shift+J — фокус вниз, Ctrl+Shift+B свободен, панели nvim_forge на Ctrl+B/Ctrl+J;
  - убрать «долетают благодаря kitty» вместе с Ctrl+; и Shift+Enter;
  - добавить таблицу «что nvim получает на Windows» по сценариям WT-KBD-6 с альтернативами nvim_forge (design, решение 5);
  - указать, что Ctrl+V перехвачен на всех платформах, а Ctrl+[ шлёт F13.

  Проверка:
  - `grep -n 'Ctrl+Shift+B\|kitty' docs/WEZTERM.md` находит только строки о том, что Ctrl+Shift+B не перехвачен, и строки о kitty как протоколе только macOS (WT-KBD-1, WT-KBD-2);
  - каждая названная альтернатива находится `grep -rn` в `nvim_forge/lua`; для найденных по `:map` (windows) записать команду в раздел.
- [x] 1.8 Переписать раздел «Альтернативный экран и OSC 52» (WT-SCROLL-14, WT-CLIP-11). Copy mode, поиск, QuickSelect и выгрузка в нём работают с видимым экраном программы, а не «дампить нечего». Claude Code в перечне программ оставить, только если это подтверждено. Проверка (windows): в панели с Claude Code команда `wezterm cli get-text --pane-id <id> --start-line -5000 | wc -l` из соседней панели выдаёт примерно высоту окна; иначе Claude Code из перечня убрать.
- [x] 1.9 Сверить ссылки на требования. Проверка: `grep -oE '(WT-[A-Z]+|MAC-INST)-[0-9]+' docs/WEZTERM.md | sort -u | while read id; do grep -q "^### Requirement: $id " openspec/specs/*/spec.md || echo "нет $id"; done` ничего не печатает, и `grep '^## ' docs/WEZTERM.md | grep -vE 'WT-|MAC-INST'` пусто.

## 2. Документация nvim_forge

- [x] 2.1 Переписать в `nvim_forge/README.md` абзац об установке (design, решение 9):
  - curl | bash на macOS клонирует в `~/forge-nvim` и ставит в локальном режиме, `~/.config/nvim` не трогает;
  - установка в каталог конфига идёт только с `FORGE_NVIM_DEPS_ONLY=0` и сегодня удаётся только с `FORGE_NVIM_USE_LOCAL_SOURCE=1`;
  - в NOTE о плоской раскладке добавить macOS к Linux/Windows и убрать «(macOS script: fixed, see above)».

  Проверка: `grep -n 'macOS script: fixed' nvim_forge/README.md` ничего не находит; текст совпадает со сценариями MAC-INST-2 «из чекаута без флагов» и «явный FORGE_NVIM_DEPS_ONLY=0», MAC-INST-3 «чистый мак» и MAC-INST-10 «источник по умолчанию — клон монорепо» (`openspec show macos-install --type spec`).
- [x] 2.2 Исправить список переменных в `nvim_forge/README.md`:
  - `FORGE_NVIM_DEPS_ONLY` и `FORGE_NVIM_SKIP_WEZTERM` — общие для Linux и macOS; на Linux `DEPS_ONLY` по умолчанию `0`, автоопределения нет;
  - добавить `FORGE_NVIM_FORCE_WEZTERM=1` (только Linux);
  - в «macOS only» оставить `FORGE_NVIM_SRC` и автоопределение `DEPS_ONLY`.

  Проверка: `for v in $(grep -oh 'FORGE_NVIM_[A-Z_]*' nvim_forge/scripts/install-linux.sh nvim_forge/scripts/install-macos.sh | sort -u); do grep -q "$v" nvim_forge/README.md || echo "нет $v"; done` ничего не печатает.
- [x] 2.3 Пометить строки в `nvim_forge/HOTKEYS.md` и `nvim_forge/KEYBINDINGS.md`, где есть сочетание из WT-KBD-6: `<C-S-…>` / `Ctrl+Shift+буква`, `<C-CR>`, `<S-CR>`, `<C-Space>`, `<C-/>` и F-клавиши с модификаторами. Пометка: «Windows+WezTerm: не доходит (WT-KBD-6)» с альтернативой или «альтернативы нет»; то же — в заметке KEYBINDINGS.md о `<C-S-b>`/`<C-S-j>`. Для F-клавиш, кроме F5 из сценария WT-KBD-6, пометку ставить только после проверки на Windows: `:echo keytrans(getcharstr())` в nvim_forge и нажать сочетание. Проверка: `grep -nE '<C-S-[A-Za-z0-9]+>|Ctrl\+Shift\+[A-Za-z]|<C-CR>|<S-CR>|<C-Space>|<C-/>' nvim_forge/HOTKEYS.md nvim_forge/KEYBINDINGS.md | grep -v 'WT-KBD-6'` ничего не находит.
- [x] 2.4 Добавить в начало `nvim_forge/QUICKSTART.md`, `nvim_forge/PANELS.md` и `nvim_forge/COOKBOOK.md` по одной оговорке (design, решение 5): под WezTerm на Windows часть сочетаний не доходит (WT-KBD-6), список и альтернативы — в `docs/WEZTERM.md`, раздел про WT-KBD-6. Проверка: `grep -c 'WT-KBD-6'` по каждому из трёх файлов даёт 1, и номер строки оговорки меньше номера первой таблицы или списка клавиш.

## 3. Комментарии wezterm.lua и запись в FIXLOG

- [ ] 3.1 До правок сохранить во временный каталог:
  - копию `wezterm.lua`;
  - нормализованный снимок `wezterm --config-file F:/repo/forge-nvim/wezterm.lua show-keys --lua | sed -E 's/phys:([A-Za-z])\b/phys:\U\1/g'`;
  - хеш выгрузки: в pwsh выполнить `'a'; ''; 'b'`, затем Ctrl+Shift+Space и `b`, потом `sha256sum ~/.wezterm_scrollback.txt`; панель не закрывать.

  Проверка (windows): три файла не пусты, в снимке есть строки `key_tables = {` и `windows = {`, а повторный снимок той же командой совпадает с первым (`diff` пуст).
- [x] 3.2 Переписать шапку (строки 1–5) и секцию клавиатуры (140–146):
  - kitty и «хитрые» сочетания — только macOS (WT-KBD-2);
  - на Windows — win32-input-mode и ограничение WT-KBD-6;
  - убрать фразу «Оставляем стандартные wezterm-хоткеи…» и сослаться на WT-KEYS-1;
  - блок «ИСПОЛЬЗОВАНИЕ» с командой `SetEnvironmentVariable` сохранить, на него ссылается WT-LOAD-3.

  Проверка: `grep -n 'Оставляем стандартные' wezterm.lua` пусто, `grep -n 'SetEnvironmentVariable' wezterm.lua` находит команду.
- [x] 3.3 Уточнить комментарии про `phys:C` и `SendKey` (строки 277–283 и 316–321). Ctrl+C уходит байтом 0x03, а если программа включила modifyOtherKeys — как `CSI 27;5;99~`; ConPTY переводит обе формы (WT-KBD-7). Проверка: `grep -n 'чистый' wezterm.lua` не находит утверждения, что в панель всегда уходит 0x03, и в этих комментариях есть `WT-KBD-7`.
- [x] 3.4 Исправить комментарии шрифта:
  - строки 372–386: Super-варианты висят на всех платформах, на Windows это клавиша Win, часть сочетаний забирает ОС (WT-KEYS-3);
  - строки 193–199: оба имени находят один и тот же Nerd Fonts 3.x, вторая запись — страховка на случай другой сборки (WT-UI-4).

  Проверка (windows): в `wezterm --config-file F:/repo/forge-nvim/wezterm.lua ls-fonts` первые две записи указывают на один файл; `grep -n 'старое имя' wezterm.lua` пусто.
- [x] 3.5 Исправить комментарии мультиплексора (строки 417–425):
  - список «Ctrl+Shift+{B,D,E,F,J,P}… заняты Neovim» заменить ссылкой на WT-KEYS-4 и оговоркой, что Ctrl+Shift+H/J/K/L — навигация WezTerm (WT-PANE-2);
  - комментарий о каталоге: берётся из OSC 7, без него — рабочий каталог процесса на переднем плане; pwsh без OSC 7 даёт каталог своего запуска (WT-PANE-12).

  Проверка: `grep -n 'B,D,E,F,J,P\|домашнем каталоге' wezterm.lua` пусто.
- [x] 3.6 Исправить комментарии внешнего вида:
  - полоса прокрутки (строки 221–225): ползунок активной панели виден всегда; без истории и на альтернативном экране он во всю высоту; ширина полосы равна `window_padding.right`; `min_content_width` убрать (WT-SCROLL-3, WT-UI-7);
  - курсор (строки 227–236): по умолчанию Linear на 800 мс; дискретность даёт пара Constant/Constant; `animation_fps = 1` влияет только на прочие анимации, например на мигающий текст (WT-UI-9).

  Проверка: `grep -n 'min_content_width\|Ease-анимацию' wezterm.lua` пусто.
- [ ] 3.7 Переписать комментарий к `scrollback_to_nvim` (строки 599–612) по WT-SCROLL-13: строки экранные, пустые строки выпадают, перевода строки в конце нет, на альтернативном экране — только видимый экран. Удалить строку `text = text:gsub("%s+$", "\n")` (design, решение 7). Проверка (windows): после перечитывания конфига в той же панели из 3.1 снова нажать Ctrl+Shift+Space и `b`. `sha256sum ~/.wezterm_scrollback.txt` совпадает с хешем из 3.1, а `tail -c1 ~/.wezterm_scrollback.txt | od -c` показывает не `\n`.
- [ ] 3.8 Переписать комментарий бейджа (строки 751–756) по WT-UI-12:
  - бейдж только у WINDOWS, RESIZE, COPY и SEARCH;
  - QuickSelect, лаунчер, палитра, CharSelect, запросы, подтверждение закрытия и debug overlay перехватывают ввод без бейджа;
  - COPY/SEARCH принадлежат панели.

  Проверка (windows): после Ctrl+Shift+U бейджа нет, хотя клавиши перехвачены; `grep -n 'Нет бейджа = NORMAL' wezterm.lua` пусто.
- [x] 3.9 Убедиться, что код не изменился, кроме удалённой строки. Проверка (windows):
  - `diff <(sed 's/[[:space:]]*--.*$//' <копия из 3.1> | grep -v '^[[:space:]]*$') <(sed 's/[[:space:]]*--.*$//' wezterm.lua | grep -v '^[[:space:]]*$')` показывает только строку с `gsub`;
  - нормализованный снимок `show-keys --lua` совпадает со снимком из 3.1;
  - `wezterm --config-file F:/repo/forge-nvim/wezterm.lua ls-fonts 2>&1 >/dev/null | grep ERROR` пусто.
- [x] 3.10 Дописать в `nvim_forge/FIXLOG.md` новую запись со следующим свободным номером (design, решение 8). Проблема: docs и комментарии разошлись с кодом. Причина: запись 2026-08-01 не обновила docs, проверки нет. Решение:
  - docs/WEZTERM.md выведен из спек;
  - комментарии исправлены;
  - перечислены неточности §16 (WT-SCROLL-3, WT-UI-7), §17 (WT-KBD-7), 2026-05-31 п. 3 (WT-UI-4) и 2026-08-01 (WT-UI-12, неполный список файлов) без правки самих записей.

  «Файлы» — все файлы групп 1–3. Строки `Спека:` нет. Проверка: `git diff --numstat -- nvim_forge/FIXLOG.md` показывает 0 удалённых строк, а `grep -n 'WT-KBD-7\|WT-UI-4\|WT-UI-12\|WT-SCROLL-3' nvim_forge/FIXLOG.md` находит их в новой записи.

## Заметки apply (2026-09-27)

- Change применялся последним из changes поведения (кроме `restructure-wezterm-config`), поэтому docs описывают итоговый код, а не базовую линию: модальный WINDOWS (`fix-windows-mode-modality`), Enter в поиске, `y`, новые окна, Super только вне Windows, pwsh 7 / шрифты / бейдж (`fix-ui-robustness`), подмена WT-KEYS-10. Пункты задач, писавшиеся под базовую линию («Super-сочетания есть и на Windows», «установка в каталог конфига удаётся только с USE_LOCAL_SOURCE», «`<C-S-…>` не доходит»), заменены итоговым поведением — решение 2 design («если change поведения уже применён, описывается новое поведение»).
- 1.9: ID WT-KEYS-10 и WT-KBD-9 пока только в ADDED `add-nvim-chords-on-windows`; проверка ID засчитывает и ADDED активных changes.
- 2.3: девять сочетаний WT-KEYS-10 помечены «через подмену (… — WT-KBD-6)», а не «не доходит»; номера F-клавиш с модификаторами сняты пробой через conpty.dll (tests/wezterm/conpty), а не нажатием в GUI.
- 3.7: удаление `gsub` проверено по исходнику 20240203 (`get_lines_as_text` делает `trim_end()`); сверка хеша файла выгрузки в GUI — владельцу.
- 1.4, 1.5, 3.1 (хеш выгрузки), 3.7, 3.8: ручные проверки в GUI не выполнялись — открыты.
