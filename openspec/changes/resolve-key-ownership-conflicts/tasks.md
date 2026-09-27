# Tasks

## 1. Ctrl+V: мёртвые привязки `<C-v>` в nvim_forge (Q7; WT-KEYS-7, WT-KBD-6)

- [x] 1.1 Сверить предпосылки (design, решение 2). Выполнить `ls tests/wezterm/key-ownership.test.lua tests/lib/nvim_keymaps.lua tests/lib/keynames.lua` и `openspec list`. Если файлов нет, сначала выполнить задачи 3.2 и 3.3 `add-wezterm-spec-checks`; второй тест здесь не заводить. Проверка (windows): `nvim -l tests/run.lua --id WT-KEYS-7` на текущем коде зелёный с исключениями базовой линии (`<C-v>` везде, `<C-c>` на Windows); в заметках apply записано, чьи задачи выполнены для этого.
- [x] 1.2 Сузить ожидания в `tests/wezterm/key-ownership.test.lua` по MODIFIED WT-KEYS-7:
  - исключение одно — `<C-c>` на Windows, на macOS пересечение пустое;
  - Ctrl+[ сравнивается как `<F13>`, а не как `<Esc>` (design, решение 2);
  - отдельная проверка: у nvim_forge нет `<C-v>` ни в одном из режимов n, v, x, s, i, c.

  Проверка (windows): `nvim -l tests/run.lua --id WT-KEYS-7` на текущем коде даёт FAIL, в тексте — `<C-v>` и режимы n, v, i, c; других FAIL нет.
- [x] 1.3 Удалить из `nvim_forge/lua/config/keymaps.lua` подблок Ctrl+V (строки 450-455: `nm`, `vm`, `im` и `map("c", …)` на `<C-v>` с комментариями); заголовок блока (`:445`) — «Ctrl+C / Ctrl+X». Проверка (windows): `grep -n '<C-v>' nvim_forge/lua/config/keymaps.lua` ничего не находит; `nvim -l tests/run.lua --id WT-KEYS` зелёный; `nvim -l tests/run.lua` без новых FAIL.
- [ ] 1.4 Ручная проверка в WezTerm с nvim_forge (плагины загружены), английская и русская раскладка:
  - Ctrl+V в нормальном режиме, в режиме вставки и в командной строке вставляет буфер обмена (WT-KEYS-7, сценарии «Ctrl+V в nvim» и «Ctrl+V в режиме вставки и в командной строке»);
  - `:verbose map <C-v>` и `:verbose map! <C-v>` не показывают привязок nvim_forge;
  - Ctrl+Q в нормальном режиме включает `-- VISUAL BLOCK --`; в режиме вставки Ctrl+Q, затем Tab вставляет буквальный Tab;
  - на русской раскладке Ctrl + физическая `;` в нормальном режиме включает `-- VISUAL BLOCK --` (WT-KBD-6, сценарий «Ctrl+знак препинания на русской раскладке»).

  Проверка (windows, вручную): результат по каждому пункту записан строкой «Проверено вручную: …» в запись FIXLOG из 1.6. Проверка (macos, вручную): первый пункт — в `tests/manual/wezterm-macos.md` со статусом «не проверялось» до доступа к Mac; если файла ещё нет, это записано в заметках apply.
- [x] 1.5 Обновить документы, где Ctrl+V описан как привязка nvim_forge:
  - `nvim_forge/KEYBINDINGS.md` — строки `<C-v>` «Paste» (сейчас около 558 и 611) убрать или заменить на «вставка — Ctrl+V терминала (WezTerm), блочное выделение — Ctrl+Q»;
  - строки `<C-q>` «Smart close» в `nvim_forge/KEYBINDINGS.md` (сейчас около 145, 540, 665) сверить с `:verbose map <C-q>`: глобальной привязки `<C-q>` в коде нет, строки исправить так, чтобы Ctrl+Q значился блочным выделением;
  - `nvim_forge/HOTKEYS.md` и раздел `docs/WEZTERM.md` о том, что отдано nvim (раздел с WT-KEYS-7 в заголовке после `sync-docs-with-baseline`, иначе §10): Ctrl+V вставляет WezTerm, привязки у nvim_forge нет.

  Проверка (windows): `grep -nE '<C-v>' nvim_forge/KEYBINDINGS.md nvim_forge/HOTKEYS.md` не находит строк, где `<C-v>` описан как привязка nvim_forge; `grep -n '<C-q>' nvim_forge/KEYBINDINGS.md | grep -i 'smart close'` ничего не находит.
- [x] 1.6 Запись FIXLOG «nvim_forge: мёртвые привязки Ctrl+V удалены, вставку делает WezTerm»: Проблема (divergence 16) → Причина → Решение → Файлы. В записи — **BREAKING** для nvim_forge в других терминалах, строки `Спека: WT-KEYS-7 (MODIFIED)` и `Спека: WT-KBD-6 (MODIFIED)`, «Проверено вручную» из 1.4. Проверка (windows): `grep -n 'Спека: WT-KEYS-7 (MODIFIED)' nvim_forge/FIXLOG.md` находит строку в новой записи; заголовок записи совпадает с `История:` в delta WT-KEYS-7.

## 2. Super-сочетания шрифта только вне Windows (Q9; WT-KEYS-3, WT-STATE-6, WT-STATE-7)

- [x] 2.1 Сверить предпосылки: `tests/wezterm/key-ownership.test.lua` с набором WT-KEYS-3 по тройкам и `tests/wezterm/window-state.test.lua` (задачи 3.2 и 3.8 `add-wezterm-spec-checks`), эталоны `tests/wezterm/golden/keys.{windows,macos,linux}.lua` (задача 4.2), если они уже есть. Чего нет — сначала выполнить там. Проверка (windows): `nvim -l tests/run.lua --id WT-KEYS-3` и `nvim -l tests/run.lua --id WT-STATE` зелёные на текущем коде.
- [x] 2.2 Обновить ожидания тестов по MODIFIED WT-KEYS-3, WT-STATE-6 и WT-STATE-7:
  - тройка Windows — 48 перехватов, ни одной пары с `SUPER`;
  - macOS и Linux — шесть Super-пар шрифта, на macOS всего 61;
  - в `window-state.test.lua` — проверка «WT-STATE-6/7: Super-варианты только вне Windows».

  Проверка (windows): `nvim -l tests/run.lua --id WT-KEYS-3` и `--id WT-STATE-6` на текущем коде дают FAIL, в тексте — шесть лишних пар `SUPER`/`SHIFT|SUPER` на Windows; macOS и Linux — PASS.
- [x] 2.3 В `wezterm.lua:372-386` строить список модификаторов цикла по платформе: `CTRL` и `SHIFT|CTRL` везде, `SUPER` и `SHIFT|SUPER` только при `not is_windows` (design, решение 3). Комментарий над циклом: Cmd на macOS, Super на Linux, на Windows только Ctrl (WT-KEYS-3, WT-STATE-6). Проверка (windows):
  - `wezterm --config-file F:/repo/forge-nvim/wezterm.lua ls-fonts` — stderr без `ERROR`;
  - `wezterm --config-file F:/repo/forge-nvim/wezterm.lua show-keys | grep -E 'SUPER +(Equal|Minus|0) \(Physical\)'` ничего не находит;
  - `nvim -l tests/run.lua --id WT-KEYS` и `--id WT-STATE` зелёные;
  - если эталоны есть: после `nvim -l tests/run.lua --update-golden` в `git diff tests/wezterm/golden` ровно 6 удалённых строк с `SUPER` в `keys.windows.lua`, а `keys.macos.lua` и `keys.linux.lua` не меняются.
- [ ] 2.4 Ручная проверка на Windows: Ctrl+=, Ctrl+-, Ctrl+0 меняют и сбрасывают шрифт; Win+=, Win+Shift+-, Win+0 шрифт не меняют (Win+= открывает экранную лупу или не делает ничего). В пункте W18 `tests/manual/wezterm-windows.md` (часть «доходят ли Win+=, Win+-, Win+0 до WezTerm») дописать, что после этого change вопрос снят, со ссылкой на запись FIXLOG из 2.6. Проверка (windows, вручную): результат записан в запись FIXLOG из 2.6. Проверка (macos, вручную): Cmd+=, Cmd+-, Cmd+0 работают как раньше — пункт в `tests/manual/wezterm-macos.md` со статусом «не проверялось» до доступа к Mac.
- [x] 2.5 Документы: в `docs/WEZTERM.md` таблица шрифта и список «Только macOS» (или разделы с WT-KEYS-3 и WT-STATE-6 в заголовке после `sync-docs-with-baseline`): Cmd+=/-/0 — macOS (Super — Linux), на Windows только Ctrl; утверждений «Super-варианты есть и на Windows» нет. Проверка (windows): `grep -niE 'Win\+=|Super.*Windows|Windows.*Super' docs/WEZTERM.md` находит только строки о том, что на Windows Super-вариантов нет.
- [x] 2.6 Запись FIXLOG «WezTerm: Super-сочетания шрифта только вне Windows»: divergences 25 и 26, **BREAKING** на Windows, строки `Спека: WT-KEYS-3 (MODIFIED)`, `Спека: WT-STATE-6 (MODIFIED)`, `Спека: WT-STATE-7 (MODIFIED)`, «Проверено вручную» из 2.4. Проверка (windows): `grep -n 'Спека: WT-STATE-7 (MODIFIED)' nvim_forge/FIXLOG.md` находит строку в новой записи.

## 3. Правый Alt и Alt+Space/Alt+F4 на Windows (Q10, Q11; WT-KBD-4, WT-KEYS-9)

- [x] 3.1 Уточнить комментарий `wezterm.lua:167-168`: настройки `send_composed_key_when_{left,right}_alt_is_pressed` работают только на macOS; на Windows правый Alt на раскладке с AltGr — AltGr, так задумано (WT-KBD-4). Значения настроек не менять. Проверка (windows): `git diff wezterm.lua` в этой задаче меняет только строки комментария; `wezterm --config-file F:/repo/forge-nvim/wezterm.lua ls-fonts` — stderr без `ERROR`.
- [ ] 3.2 Ручная проверка WT-KBD-4 на Windows в nvim_forge (`:lua print(vim.fn.keytrans(vim.fn.getcharstr()))` там, где нужна запись клавиши):
  - русская раскладка: правый Alt+8 вводит «₽»; правый Alt + физическая X ничего не вводит; левый Alt+Enter выполняет code action; левый Alt + физическая X даёт `<M-ч>`;
  - английская раскладка: правый Alt+x даёт `<M-x>`.

  Проверка (windows, вручную): пункт в `tests/manual/wezterm-windows.md` (следующий свободный код W, формат `review-baseline`, решение 3) со строкой `Проверено: <дата>, windows, …`; если файла ещё нет — результат в записи FIXLOG из 3.4.
- [ ] 3.3 Ручная проверка WT-KEYS-9 — пункт W2 в `tests/manual/wezterm-windows.md` (`review-baseline`): левый Alt+Space в nvim_forge открывает системное меню окна WezTerm, Alt+F4 закрывает окно так же, как кнопка закрытия. Если у W2 уже есть строка `Проверено:`, задача только ссылается на неё; второй пункт не заводится. Проверка (windows, вручную): у W2 есть строка `Проверено:`. Если результат расходится с WT-KEYS-9, записано новое расхождение базовой линии; этот change его не чинит.
- [x] 3.4 Запись FIXLOG «WezTerm: правый Alt на Windows — AltGr, Alt+Space и Alt+F4 — окну (решения владельца)»: решения Q10 и Q11 с отклонёнными вариантами (design, решения 4 и 5), строка `Спека: WT-KBD-4 (MODIFIED)`, для WT-KEYS-9 — «без изменений, проверено вручную: W2». В `docs/WEZTERM.md` (раздел про Alt/Meta или «Различия Windows и macOS») одна строка: на Windows Meta — левый Alt, правый Alt на русской раскладке — AltGr («₽»), Alt+Space и Alt+F4 забирает окно. Проверка (windows): `grep -n 'Спека: WT-KBD-4 (MODIFIED)' nvim_forge/FIXLOG.md` находит строку; `grep -n 'AltGr' docs/WEZTERM.md` находит строку.

## 4. Итог

- [x] 4.1 Полный прогон на Windows. Проверка (windows): `nvim -l tests/run.lua` — FAIL = 0; `wezterm --config-file F:/repo/forge-nvim/wezterm.lua ls-fonts` — stderr без `ERROR`; `openspec validate resolve-key-ownership-conflicts --type change --strict --no-interactive` проходит.
- [x] 4.2 Сверка с соседними changes перед архивацией (design, решение 7):
  - MODIFIED WT-KEYS-3 и WT-KBD-6 в `add-nvim-chords-on-windows` содержат тексты этого change (48 перехватов, Ctrl+; включает блочное выделение); если нет — `/opsx:update add-nvim-chords-on-windows`;
  - WT-STATE-7 правят оба change. Если `fix-window-state-new-windows` заархивирован раньше, его правка перенесена в MODIFIED WT-STATE-7 этого change: сброс при каждом нажатии, его тексты сценариев «Повторный сброс не видит новое сохранение» и «Сброшенное окно следует за файлом». Если он ещё не заархивирован, в его заметках apply записано, что при архивации нужно перенести сюда оговорку про Super и сценарий «Win+0 на Windows шрифт не сбрасывает».

  Проверка (windows): `openspec validate --all --strict` проходит; в заметках apply записано, что сверено.

## Заметки apply (2026-09-27)

- 1.1: проверки `add-wezterm-spec-checks` уже есть (`tests/wezterm/key-ownership.test.lua`, `tests/lib/keynames.lua`, `tests/lib/nvim_keymaps.lua`); второго теста не заводили.
- 1.2: `KN.canon` уже держит `<C-[>` отдельно от `<Esc>`. Сравнение «как `<F13>`» дало бы ложное пересечение с намеренной привязкой `<F13>` (WT-KEYS-6), поэтому сценарий «Сверка наборов» в delta уточнён: Ctrl+[ сравнивается как `<C-[>`.
- 2.3: diff эталонов на Windows — 18 строк с `SUPER`, а не 6: с `fix-windows-mode-modality` сочетания терминала копируются в таблицы `windows` и `resize_pane` (6 × 3). macOS и Linux не изменились.
- 1.4, 2.4, 3.2, 3.3: `tests/manual/` ещё не заведён (`review-baseline`); ручные шаги записаны в FIXLOG §49–§51 как «не проверено».
- 4.2: MODIFIED WT-STATE-7 сведён в один текст в обоих changes (`fix-window-state-new-windows` и этом): сброс при каждом нажатии, Super только вне Windows, все сценарии обоих. Порядок архивации теперь не важен. `add-nvim-chords-on-windows` уже содержит 48 перехватов и Ctrl+; → блочное выделение. `openspec validate --all --strict` — 23/23.
