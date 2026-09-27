# Tasks

## 1. Подготовка

- [x] 1.1 Сверить соседей по design, решение 12. Выполнить `openspec list` и `ls tests tests/wezterm tests/wezterm/golden` и найти в `docs/WEZTERM.md` описание режима WINDOWS. Записать, что уже есть: `tests/wezterm-keys.scenarios.sh` (от `change-search-enter-accept`), `tests/wezterm/windows-mode.test.lua` и эталоны `show-keys` (от `add-wezterm-spec-checks`), раздел «Режим WINDOWS» (от `sync-docs-with-baseline`) или ещё LEADER-таблицы разделов 1–4. Проверка (windows): в заметках apply для каждого файла стоит «есть / нет» и решение «дополнить / создать / не применимо».
- [x] 1.2 Снять копию `wezterm.lua` до правок в scratchpad. Это «мутант» для проверки сценариев. Проверка (windows): `wezterm --config-file <копия> ls-fonts` не пишет `ERROR` в stderr, путь к копии записан в заметках apply.

## 2. Режимы WINDOWS и RESIZE модальные (WT-WIN-2, WT-WIN-3, WT-WIN-4, WT-WIN-6, WT-WIN-7, WT-WIN-10, WT-WIN-11, WT-WIN-19, WT-WIN-20, WT-WIN-21, WT-PANE-4, WT-UI-12)

- [x] 2.1 Написать сценарии `windows-mode:` в `tests/wezterm-keys.scenarios.sh` (design, решение 12). Если файла нет, создать его по образцу `tests/install-macos.scenarios.sh`:
  - `ok` / `bad` / `check`, итоговый код возврата, в шапке — покрытые ID;
  - путь к конфигу первым аргументом, по умолчанию `wezterm.lua`;
  - совместимость с `/bin/bash` 3.2: без ассоциативных массивов, `mapfile` и `${x,,}`.

  Общая часть файла:
  - загрузка конфига: `ls-fonts`, в stderr нет `ERROR`;
  - снимок `show-keys --lua` с приведением регистра `phys:` к одному виду;
  - вид macOS — через обёртку во временном каталоге, которая выставляет `wezterm.target_triple = "aarch64-apple-darwin"` и загружает конфиг по абсолютному пути.

  Шесть сценариев из решения 12 гоняются для видов windows и macos.

  Проверка (windows, git-bash) на копии из 1.2:
  - загрузка и «windows-mode: выходы из режима» проходят;
  - остальные пять сценариев падают.

  Результат записан в заметках apply.
- [x] 2.2 Включить проглатывание (design, решение 6): `prevent_fallback = true` у `ActivateKeyTable` для `windows` (Ctrl+Shift+Space в `config.keys`) и для `resize_pane` (`r` в таблице `windows`, `replace_current` остаётся). Проверка (windows): сценарий «windows-mode: вход в режимы проглатывает чужие клавиши» проходит для видов windows и macos.
- [x] 2.3 Расширить `map()` до `map(key, mods, action, opts)` (design, решение 8). Необязательный `opts.leaves_mode` записывается в локальную таблицу по ссылке на запись привязки, в саму запись лишних полей не пишется. Пометить Ctrl+Shift+W, Ctrl+Shift+U, Ctrl+Shift+X и Cmd+Q. Проверка (windows):
  - `wezterm --config-file wezterm.lua ls-fonts` не пишет `ERROR`;
  - нормализованный `show-keys --lua` раздела `keys` отличается от того же снимка копии из 1.2 только записью Ctrl+Shift+Space (`prevent_fallback` из 2.2), и для вида windows, и для вида macos: пометка не меняет сами привязки.
- [x] 2.4 Добавить копирование сочетаний терминала в таблицы `windows` и `resize_pane` (design, решения 7 и 8). Проход один и стоит после последней записи в `config.keys`, то есть после Cmd-сочетаний macOS. Пара, уже занятая таблицей режима, пропускается. Копия помеченного сочетания — `act.Multiple({ act.ClearKeyTableStack, <действие> })`. Проверка (windows):
  - сценарии «windows-mode: сочетания терминала есть в таблицах режимов» и «windows-mode: сочетания, открывающие экран, выходят из режима» проходят для видов windows и macos;
  - запись Ctrl+Shift+Space в `windows` по-прежнему `PopKeyTable`: копия входа её не перебила (WezTerm при повторе пары молча оставляет последнюю запись, WT-KEYS-8).
- [x] 2.5 Поправить таблицу `windows` (design, решения 9 и 10):
  - `o` → `act.ActivatePaneDirection("Next")`;
  - `q` и `x` → `act.Multiple({ act.ClearKeyTableStack, … })`;
  - в остальной группе «выходят» (a, `,`, w, Shift+S, `[`, f, Space, b, e, `;`, m, d) `PopKeyTable` заменить на `ClearKeyTableStack`;
  - Esc, Enter и Ctrl+Shift+Space остаются `PopKeyTable`.

  Проверка (windows): все шесть сценариев `windows-mode:` проходят на `wezterm.lua` для обоих видов, а на копии из 1.2 падают все, кроме «выходы из режима».
- [x] 2.6 Поправить комментарии `wezterm.lua:405-413`, `562-569`, `646-647` (design, решение 14). Проверка (windows):
  - `grep -n "один Esc" wezterm.lua` ничего не находит;
  - комментарий у `r` ссылается на WT-WIN-11;
  - блок модели режима говорит, что клавиши без команды проглатываются, а сочетания терминала работают и продлевают режим.
- [x] 2.7 Если в 1.1 найдены проверки `add-wezterm-spec-checks`, обновить их в этом же коммите:
  - проверки WT-WIN в `tests/wezterm/windows-mode.test.lua` переписать под delta: `prevent_fallback`, группы WT-WIN-19, `o`, покрытие копиями, одна запись на пару;
  - эталоны `show-keys` обновить через `--update-golden`, просмотрев diff;
  - зарегистрировать `tests/wezterm-keys.scenarios.sh` в раннере, если его там ещё нет.

  Проверка (windows): `nvim -l tests/run.lua --id WT-WIN` и `nvim -l tests/run.lua --id WT-KEYS-8` зелёные, а diff эталонов задевает только таблицы `windows`, `resize_pane` и запись входа в режим. Если таких проверок нет, в заметках apply записано «не применимо: add-wezterm-spec-checks не применён».
- [ ] 2.8 Проверить вручную на Windows, в GUI после Ctrl+Shift+R, на английской и русской раскладке, сценарии delta:
  - WT-WIN-2: «Enter с модификатором — не выход»;
  - WT-WIN-3: «Клавиши, не распознанные режимом, не продлевают его», «Сочетание терминала продлевает режим»;
  - WT-WIN-4: все сценарии;
  - WT-WIN-6: все сценарии;
  - WT-WIN-7: «Метки перехватывает сам режим», «Esc на экране выбора — Windows», «Русская раскладка»;
  - WT-WIN-10: «Запрос при включённом режиме»;
  - WT-WIN-11: «Команд WINDOWS в RESIZE нет», «Ctrl+Shift+Space из RESIZE», «Сочетания терминала в RESIZE», «Экран из RESIZE»;
  - WT-WIN-19: «Выход поверх RESIZE»;
  - WT-WIN-21: все сценарии, кроме macOS-части последнего;
  - WT-PANE-4: «Ctrl+Shift+W в режиме»;
  - WT-UI-12: «Copy mode поверх режима WINDOWS», «Режим WINDOWS, включённый из copy mode».

  Проверка (windows): по каждому сценарию в заметках apply стоит «совпало» или «расходится: …», это вход для записи 2.11. При любом расхождении дальше не идти, а вернуть change на уточнение спеки.
- [x] 2.9 Проверить на ConPTY-стенде (design, решение 13), что отпускание проглоченной клавиши ничего не вводит. pwsh и nvim запускаются под `C:\Program Files\WezTerm\conpty.dll` с флагами RESIZE_QUIRK | WIN32_INPUT_MODE. Им подаётся одинокое отпускание `ESC[vk;sc;uc;0;cs;1_` для `i` и `g`, экран сравнивается до и после. Enter в Claude Code не слать. Проверка (windows): на экранах pwsh и nvim символа нет, команда запуска стенда и итог записаны для 2.11. Если символ появился, это расхождение с WT-WIN-20: дальше не идти, вернуть change на уточнение.
- [x] 2.10 Обновить описание режима WINDOWS в `docs/WEZTERM.md`. Правится раздел «Режим WINDOWS», если `sync-docs-with-baseline` уже применён; иначе — строки LEADER-таблиц разделов 1–4 про `o`, `q`, `x`, `r`. Что должно быть описано:
  - клавиши без команды проглатываются;
  - сочетания терминала работают и продлевают режим;
  - какие команды оставляют режим, а какие выключают, в том числе Ctrl+Shift+W, Ctrl+Shift+U, Ctrl+Shift+X и Cmd+Q;
  - `o` — следующая панель;
  - RESIZE подчиняется тем же правилам;
  - Esc снимает один слой;
  - ограничение экранов выбора панели, выбора символа и палитры.

  Проверка (windows): `grep -n "RotatePanes\|поворот\|уходят в программу" docs/WEZTERM.md` в этом разделе ничего не находит, а строки про `o`, `q`, `x` и RESIZE сверены с WT-WIN-6, WT-WIN-7, WT-WIN-10, WT-WIN-11 и WT-WIN-19 (список сверки — в заметках apply).
- [x] 2.11 Дописать в конец `nvim_forge/FIXLOG.md` нумерованную запись `### <N>. WezTerm: режимы WINDOWS и RESIZE модальные` (Проблема → Причина → Решение → Файлы). В ней:
  - строки `Спека: WT-WIN-2 (MODIFIED)`, `Спека: WT-WIN-3 (MODIFIED)`, `Спека: WT-WIN-4 (MODIFIED)`, `Спека: WT-WIN-6 (MODIFIED)`, `Спека: WT-WIN-7 (MODIFIED)`, `Спека: WT-WIN-10 (MODIFIED)`, `Спека: WT-WIN-11 (MODIFIED)`, `Спека: WT-WIN-19 (MODIFIED)`, `Спека: WT-WIN-20 (MODIFIED)`, `Спека: WT-WIN-21 (MODIFIED)`, `Спека: WT-PANE-4 (MODIFIED)`, `Спека: WT-UI-12 (MODIFIED)`;
  - ссылка на `tests/wezterm-keys.scenarios.sh`;
  - «Проверено вручную: windows, <дата>» с итогами 2.8 и 2.9.

  Название записи совпадает с тем, на которое ссылаются строки `История:` и `Проверка:` в delta. Проверка (windows): `git diff nvim_forge/FIXLOG.md` содержит только добавленные строки в конце, а `grep -c "^Спека: WT-" nvim_forge/FIXLOG.md` вырос ровно на 12.

## 3. Проверка на macOS

- [ ] 3.1 При доступе к Mac: `git pull`, перечитать конфиг в WezTerm и запустить `/bin/bash tests/wezterm-keys.scenarios.sh`. Потом пройти вручную сценарии delta, которые на macOS выведены из исходника:
  - WT-WIN-7: «Esc на экране выбора — macOS»;
  - WT-WIN-4: «Глобальные сочетания работают и в режиме» (Ctrl+Tab, Ctrl+Shift+Enter, Shift+PageUp) и «Сочетание терминала, открывающее экран» с Cmd+Q;
  - WT-WIN-20: «macOS и Shift+S» и «Программа включила клавиатурный протокол» в Claude Code (в режиме `i` и `g` не печатаются, и после отпускания тоже);
  - WT-WIN-21: «Режим поверх выбора панели, выбора символа или палитры» (Esc на macOS).

  Проверка (macos): все сценарии `windows-mode:` проходят под `/bin/bash` 3.2, а итог ручной проверки дописан в запись FIXLOG из 2.11 строкой «Проверено вручную: macos, <дата>, WezTerm <версия>». Расхождение записывается в `PROBLEMS.md`, а change возвращается на уточнение спеки.
