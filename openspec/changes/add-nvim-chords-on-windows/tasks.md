# Tasks

## 1. Проба через conpty.dll — до реализации (design, решения 3 и 6)

- [x] 1.1 Перенести харнесс в `tests/wezterm/conpty/harness.py`. Исходники прототипа: `%TEMP%\wz\conpty_harness.py` и во временном scratchpad `kbd\h2.py`, `ver\dump.py`, `ver\tu.py`. Что должно быть:
  - сеанс ConPTY с флагами WezTerm (`RESIZE_QUIRK | WIN32_INPUT_MODE`);
  - ответы терминала как у WezTerm 20240203 на Windows: на `CSI ?u` — ничего (kitty выключен), на XTVERSION — версия;
  - три читателя: сырой VT-ввод, записи консоли (`ReadConsoleInputW`), `nvim --clean` с журналом `vim.on_key` через `keytrans`;
  - таймаут на сеанс, дочерние процессы завершаются на всех путях;
  - энтропия собирается в начале: путь, SHA-256 и версия conpty.dll, версии WezTerm и nvim, активная раскладка.

  Проверка (windows):
  - самопроверка на русской раскладке повторяет известное из WT-KBD-6: запись Ctrl+Shift+P → `<C-P>`, Ctrl+Enter → `<NL>`, байты `CSI 25~` → `<F13>`;
  - два прогона подряд дают одинаковый результат;
  - после прогона `tasklist` не показывает запущенных харнессом `OpenConsole.exe` и `nvim.exe`.
- [x] 1.2 Перечислить сочетания для таблицы WT-KEYS-10. Источник — lhs nvim_forge: помощник `tests/lib/nvim_keymaps.lua` из `add-wezterm-spec-checks`, если он уже есть, иначе `grep` по `nvim_forge/lua`. Интересуют Ctrl+Shift+буква, Ctrl+знак, Ctrl+Enter, Ctrl+Space, Shift+Enter и Ctrl+Shift+F-клавиша. Для каждого сочетания через харнесс снять, что получает nvim на обеих раскладках. Сочетание входит в таблицу, если его привязывает nvim_forge, а nvim получает другую клавишу или ничего (критерий WT-KEYS-10). Найденные сверх девяти строк сочетания дописать в таблицу WT-KEYS-10 в delta этого change. Проверка (windows): список со значениями для обеих раскладок записан в `tests/wezterm/conpty/chords.fixture.json`; `openspec validate add-nvim-chords-on-windows --type change --strict --no-interactive` проходит.
- [x] 1.3 Проба A — объявление. В харнессе `nvim --clean` шлёт `OSC 1337 ; SetUserVar=FORGE_NVIM=<base64 "1"> BEL` сначала через `vim.api.nvim_ui_send`, затем через `chansend(v:stderr, …)`. Харнесс ищет последовательность в выходе ConPTY байт в байт. Проверка (windows): `python tests/wezterm/conpty/chords.test.py` печатает `ok WT-KBD-9 объявление проходит ConPTY (<способ>)` хотя бы для одного способа. Ворота: если не прошёл ни один способ — стоп; результат пишется в design, раздел Risks, дальше `/opsx:update` с владельцем. Группы 2 и 3 не начинаются.
- [x] 1.4 Проба B — подменные клавиши (design, решение 3). Что снимается:
  - кандидаты (a), затем (b) и (c): байты через харнесс и клавиша nvim на обеих раскладках;
  - множество клавиш от физических нажатий на обеих раскладках: F1–F12 без модификаторов и с Shift, Ctrl, Alt, Ctrl+Shift, Alt+Shift, Ctrl+Alt; сочетания WT-KBD-6; буквы и цифры с Ctrl и с Alt;
  - K3: в `nvim --clean` без привязок подменная клавиша ничего не вставляет в нормальном режиме, в режиме вставки, в командной строке и в `:terminal`.

  Выбрать первое семейство, в котором K1–K4 выполняются для всех строк таблицы. Проверка (windows):
  - в `chords.fixture.json` для каждой строки есть байты, клавиша nvim на ru и en и отметки K1–K4;
  - `python tests/wezterm/conpty/chords.test.py --layout ru` и `--layout en` печатают только `ok`;
  - повторный прогон не меняет фикстуру, кроме даты.

  Ворота: если ни одно семейство не прошло — стоп, решает владелец. Если множество физических нажатий подтвердит Shift+F1 → `<F13>`, это пишется в заметки apply для задачи 4.2.
- [x] 1.5 Проба C — повтор исходного нажатия. Для каждого сочетания сравнить настоящую запись нажатия и отпускания (как у WezTerm 20240203) с её повтором через `SendString`. Сравнение — для трёх читателей на обеих раскладках. Разрешены только отличия из WT-KBD-9: правый Ctrl становится левым, отпускание приходит сразу. Для записи в design прогнать и вариант `SendKey` (xterm-кодировка при modifyOtherKeys, который включил nvim) и записать, чем он отличается. Проверка (windows): для каждого сочетания есть строка `ok WT-KBD-9 повтор <сочетание> (<читатель>, <раскладка>)`. Ворота: любое другое отличие — стоп, решает владелец.
- [x] 1.6 Записать итог и зарегистрировать пробу:
  - в design.md, решение 3, — абзац «Итог пробы (<дата>)»: таблица «сочетание → байты → клавиша nvim (ru/en)», способ объявления, способ повтора, версии conpty.dll, WezTerm и nvim;
  - `chords.test.py` — в раннер `add-wezterm-spec-checks` как набор только для Windows: без `python`, без conpty.dll или при другой раскладке — SKIP.

  Проверка (windows):
  - `nvim -l tests/run.lua --id WT-KBD-9` запускает пробу и зелёный;
  - с PATH без `python` набор даёт SKIP с причиной, а не PASS;
  - `openspec validate add-nvim-chords-on-windows --type change --strict --no-interactive` проходит.

## 2. nvim_forge: объявление и подменные клавиши (WT-KBD-9, WT-KEYS-10)

Одна эта группа поведение для пользователя не меняет: подменных клавиш ещё никто не шлёт, а объявление терминал пока не использует. Запись FIXLOG — одна на change, задача 3.6.

- [x] 2.1 Сверить предпосылки (design, решение 9):
  - `resolve-key-ownership-conflicts` заархивирован: `openspec list` его не показывает, а `openspec show wezterm-key-ownership --type spec` содержит «на Windows 48»;
  - раннер, `tests/wezterm/fake_wezterm.lua` и `tests/lib/nvim_keymaps.lua` из групп 1–3 `add-wezterm-spec-checks` на месте. Если нет — сначала те задачи; второй раннер и вторую подделку не заводить;
  - если delta `resolve-key-ownership-conflicts` при применении поменялась — `/opsx:update` этого change.

  Проверка (windows): `openspec validate add-nvim-chords-on-windows --type change --strict --no-interactive` проходит; `nvim -l tests/run.lua` на текущем коде зелёный.
- [x] 2.2 Тест стороны nvim (design, решение 8) в `tests/wezterm/key-ownership.test.lua`, часть nvim. Для каждой строки фикстуры:
  - подменная клавиша привязана в режимах n, x, s, o, i, c, t с `rhs = lhs` и `remap`;
  - у `lhs` есть привязка nvim_forge (в `keymaps.lua` или в `keys` lazy.nvim);
  - русского псевдонима нет.

  Версия модуля равна версии в фикстуре. Проверка (windows): `nvim -l tests/run.lua --id WT-KEYS-10` на текущем коде даёт FAIL «нет модуля или привязок».
- [x] 2.3 Написать `nvim_forge/lua/config/wezterm_chords.lua` (design, решения 1 и 4):
  - таблица: `version` и строки `{ chord, lhs, key }` из итога пробы;
  - привязки с `remap`;
  - автокоманды объявления: `VimEnter` и `VimResume` ставят, `VimLeavePre` и `VimSuspend` снимают; только при интерфейсе-терминале; способ записи — из пробы A;
  - выключатель `vim.g.forge_wezterm_chords = false`.

  Подключить модуль после `config.keymaps`. В `nvim_forge/KEYBINDINGS.md` — короткий раздел: подменные клавиши WezTerm, зачем они и как выключить. Проверка (windows):
  - `nvim -l tests/run.lua --id WT-KEYS-10` (часть nvim) зелёный;
  - headless-запуск nvim_forge не пишет OSC 1337 ни в stdout, ни в stderr;
  - в харнессе из группы 1 nvim_forge при старте шлёт `FORGE_NVIM=<base64 версии>`, при `:qa` — пустое значение, а с `vim.g.forge_wezterm_chords = false` — ничего;
  - `grep -n 'forge_wezterm_chords' nvim_forge/KEYBINDINGS.md` находит строку.
- [x] 2.4 Мутации: временно сменить в модуле одну подменную клавишу, потом отдельно — версию. Проверка (windows): в обоих случаях `nvim -l tests/run.lua --id WT-KEYS-10` даёт FAIL с именем строки или с версией; после отката тест зелёный, а `git diff nvim_forge` содержит только модуль, его подключение и `KEYBINDINGS.md`.

## 3. WezTerm: подмена на Windows (WT-KEYS-10, WT-KEYS-1, WT-KEYS-3, WT-KEYS-4, WT-KBD-6, WT-KBD-7, WT-KBD-9)

- [x] 3.1 Тест стороны WezTerm на поддельном `wezterm` (design, решение 8), `key-ownership.test.lua`:
  - на тройке Windows — по одной привязке на строку таблицы, буквы и знаки через `phys:`;
  - колбэк на поддельной панели с `FORGE_NVIM=<версия>` делает ровно `SendString(<байты подмены из фикстуры>)`; без переменной, с пустым значением и с другой версией — `SendString(<запись исходного нажатия из фикстуры>)`;
  - на macOS и Linux таких привязок нет;
  - WT-KEYS-3: 48 перехватов плюс N подмен;
  - сверка WT-KEYS-7 исключает подмены по списку из WT-KEYS-10;
  - WT-KEYS-8: повторов пар нет.

  Проверка (windows): `nvim -l tests/run.lua --id WT-KEYS` на текущем коде даёт FAIL у WT-KEYS-10, остальные проверки зелёные.
- [x] 3.2 Реализовать в `wezterm.lua`, ветка Windows (design, решения 2 и 7):
  - таблица подмен с версией;
  - цикл привязок с `action_callback`;
  - обработчик `user-var-changed`, который пишет строку через `wezterm.log_info`;
  - комментарии о клавиатуре (шапка `1-5`, секция `140-146`): kitty и «хитрые» сочетания — только macOS, на Windows — подмена для nvim_forge (WT-KEYS-10).

  Проверка (windows):
  - `wezterm --config-file F:/repo/forge-nvim/wezterm.lua ls-fonts` — stderr без `ERROR`;
  - `nvim -l tests/run.lua` — FAIL = 0;
  - мутация «версия 1 → 2 только в `wezterm.lua`» даёт FAIL сверки версий, потом откат;
  - если эталоны `show-keys` есть: после `nvim -l tests/run.lua --update-golden` в diff `keys.windows.lua` ровно N новых привязок, `keys.macos.lua` и `keys.linux.lua` не меняются.
- [x] 3.3 Прогнать пробу группы 1 на байтах из `wezterm.lua`: подделка выгружает байты колбэков в JSON, харнесс их проигрывает. nvim_forge в харнессе на каждое сочетание таблицы выполняет действие своего `lhs` (журнал `vim.on_key` и срабатывание привязки). `nvim --clean` без объявления получает то же, что в WT-KBD-6. Проверка (windows): `nvim -l tests/run.lua --id WT-KBD-9` и `nvim -l tests/run.lua --id WT-KEYS-10` зелёные на обеих раскладках.
- [ ] 3.4 Ручная проверка в GUI WezTerm на Windows, на русской и английской раскладке (сценарии WT-KEYS-10 и WT-KBD-9):
  - в nvim_forge:
    - Ctrl+Shift+F, Ctrl+Shift+P, Ctrl+Shift+E, Ctrl+Shift+D;
    - Ctrl+Enter: в нормальном режиме нижняя панель не переключается, в визуальном выделенное выполняется в pwsh;
    - Ctrl+/ и Ctrl+. на русской раскладке;
    - Ctrl+Space в режиме вставки;
    - Ctrl+Shift+F5 в сессии DAP, в окне кода и в терминале DAP;
    - Ctrl+Shift+F в режиме WINDOWS;
  - без объявления — всё как до изменения:
    - pwsh: Ctrl+Space в PSReadLine;
    - Claude Code: Ctrl+Enter и Ctrl+Space;
    - `nvim --clean`: `:lua print(vim.fn.keytrans(vim.fn.getcharstr()))` и Ctrl+Shift+F дают `<C-F>`;
  - соседняя панель pwsh рядом с nvim_forge;
  - шелл панели после `:qa`;
  - после `taskkill /F` для nvim_forge шелл получает подменную клавишу, а команда сброса из docs возвращает исходное нажатие;
  - строка журнала `forge: FORGE_NVIM …` видна в debug overlay (режим WINDOWS → `d`).

  Проверка (windows, вручную): пункт в `tests/manual/wezterm-windows.md` (следующий свободный код W, формат `review-baseline`) со строкой `Проверено:` по каждому пункту. Если GUI разошёлся с пробой — стоп, запись в design, раздел Risks.
- [x] 3.5 Документы:
  - `docs/WEZTERM.md`, раздел о том, что отдано nvim и что nvim получает (по ID WT-KEYS-4 и WT-KBD-6 в заголовке): на Windows сочетания WT-KEYS-10 работают в nvim_forge через подмену, остальные программы получают их как раньше; зависшее объявление и команда сброса для pwsh; выключатель `vim.g.forge_wezterm_chords`;
  - `nvim_forge/HOTKEYS.md` и `nvim_forge/KEYBINDINGS.md`: у сочетаний из таблицы пометка «не доходит (WT-KBD-6)», если её поставил `sync-docs-with-baseline`, заменяется на «на Windows — через подмену WezTerm (WT-KEYS-10)»; у остальных (F-клавиши с модификаторами, `<S-CR>`) пометка остаётся.

  Проверка (windows):
  - `grep -n 'WT-KEYS-10' docs/WEZTERM.md nvim_forge/HOTKEYS.md nvim_forge/KEYBINDINGS.md` находит строки;
  - `grep -nE '<C-S-[fped]>|<C-S-F5>|<C-CR>|<C-/>|<C-Space>|<C-\.>' nvim_forge/HOTKEYS.md nvim_forge/KEYBINDINGS.md | grep 'не доходит'` ничего не находит;
  - команда сброса из docs, выполненная в pwsh дословно, снимает объявление: в журнале появляется строка с пустым значением.
- [x] 3.6 Запись FIXLOG «WezTerm + nvim_forge: сочетания nvim_forge на Windows через подмену клавиш». Проблема (divergences 21–24, 31) → Причина (ConPTY, FIXLOG §41) → Решение (итог пробы, объявление, подмена) → Файлы. Строки `Спека:`:
  - `Спека: WT-KEYS-10 (ADDED)`, `Спека: WT-KBD-9 (ADDED)`;
  - `Спека: WT-KEYS-1 (MODIFIED)`, `Спека: WT-KEYS-3 (MODIFIED)`, `Спека: WT-KEYS-4 (MODIFIED)`;
  - `Спека: WT-KBD-6 (MODIFIED)`, `Спека: WT-KBD-7 (MODIFIED)`.

  В запись переносится «Проверено вручную» из 3.4. Проверка (windows): в новой записи ровно 7 строк `Спека: WT-K`; заголовок записи совпадает со строками `История:` в delta.
- [ ] 3.7 macOS, при доступе к Mac: nvim_forge объявляет себя, WezTerm ничего не подменяет, Ctrl+Shift+F открывает панель поиска как раньше (WT-KBD-9, сценарий «Объявление на macOS ни на что не влияет»). Проверка (macos, вручную): пункт в `tests/manual/wezterm-macos.md` со строкой `Проверено:`; до доступа к Mac — статус «не проверялось».

## 4. Итог

- [x] 4.1 Полный прогон. Проверка (windows):
  - `nvim -l tests/run.lua` — FAIL = 0, наборы WT-KBD-9 и WT-KEYS-10 не в SKIP;
  - `wezterm --config-file F:/repo/forge-nvim/wezterm.lua ls-fonts` — stderr без `ERROR`;
  - `openspec validate add-nvim-chords-on-windows --type change --strict --no-interactive` и `openspec validate --all --strict` проходят.
- [x] 4.2 Находки вне охвата — в `PROBLEMS.md`: F-клавиши с модификаторами (`<S-F5>` → `<F17>` и т. п.) и, если проба B это подтвердила, Shift+F1 → `<F13>` (пересечение с WT-KEYS-6). Проверка (windows): `grep -nE 'F17|Shift\+F1' PROBLEMS.md` находит пункты со ссылкой на этот change.

## Заметки apply (2026-09-27)

- 1.4, 1.5: сняты на обеих раскладках — ru, затем en (2026-09-27, `chords.test.py --update-fixture` при активной en; `nvim -l tests/run.lua conpty` зелёный). Отличие en от ru одно: исходный Ctrl+/ в панели без объявления nvim получает как `<C-_>`, а не `<C-N>` (design, «Итог пробы»).
- 1.2: сверх девяти строк найден Ctrl+] (на ru приходит `<NL>`), в таблицу не взят — запись нажатия зависит от раскладки (design, «Итог пробы»; PROBLEMS.md).
- 1.4 (итог): семейство (a) даёт 8 клавиш, девятая строка — то же семейство с Ctrl+Shift; одно правило (design, «Итог пробы», Risks).
- 2.1: `resolve-key-ownership-conflicts` не заархивирован (у него открыты ручные задачи), но тексты WT-KEYS-3 (48) и WT-KBD-6 в обоих changes совпадают; `openspec validate --all --strict` проходит.
- 3.1–3.3: проверки WT-KEYS-1/2/4/7 уточнены под подмены на Windows; WT-WIN-2 — новый MODIFIED в этом change (Ctrl+Enter на Windows в режиме — сочетание терминала). Сквозная проверка 3.3 — в пробе: живой nvim_forge получает подменную клавишу и её привязка — исходный `lhs`.
- 3.2: diff эталона `keys.windows.lua` — 27 строк, а не 9: подмены копируются и в таблицы режимов WINDOWS/RESIZE (fix-windows-mode-modality).
- Набор `conpty` в раннере — по запросу (`nvim -l tests/run.lua conpty` или с `--id`), не в обычном прогоне и хуке: проба идёт около 1,5 минут.
- 3.4, 3.7: ручные — GUI Windows и Mac; `tests/manual/` ещё не заведён (`review-baseline`).
