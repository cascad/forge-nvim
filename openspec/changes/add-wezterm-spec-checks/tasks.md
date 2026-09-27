# Tasks

## 1. Каркас: протокол, раннер, отчёт

- [x] 1.1 Сверить, что уже есть. Выполнить `git ls-files tests` и `ls tests tests/wezterm tests/manual` и посмотреть статусы соседних changes (`openspec list`: `fix-copy-clobbers-clipboard`, `change-search-enter-accept`, `fix-windows-mode-modality`, `review-baseline`). Если `tests/wezterm/fake_wezterm.lua`, `tests/wezterm/clipboard.test.lua`, `tests/wezterm-keys.scenarios.sh` или `tests/manual/*.md` уже есть, дальше они дополняются, а не создаются заново (design, решения 3 и 9). Проверка (windows): в заметках apply записан список найденных файлов и для каждого решение «дополнить» или «создать».
- [x] 1.2 Добавить в `.gitignore` строку `.tests/`. Проверка (windows): `git check-ignore -v .tests/report.json` печатает правило из `.gitignore`.
- [x] 1.3 Написать `tests/lib/check.lua`:
  - `check(имя, fn)` выполняет случай в `pcall`;
  - `skip(имя, причина)`;
  - `finish()` выставляет код возврата;
  - фильтр `FORGE_TEST_ID` — точное совпадение или префикс до `-`;
  - формат строк как у `tests/install-macos.scenarios.sh`.

  Самопроверки `SELF: …` положить в `tests/lib/check.test.lua`. Проверка (windows): `nvim -l tests/lib/check.test.lua` зелёный. В нём есть случаи:
  - случай, бросающий ошибку, даёт `FAIL` с текстом ошибки, а следующий случай выполняется;
  - файл с упавшим случаем выходит с кодом 1;
  - при `FORGE_TEST_ID=WT-CLIP-1` случай `WT-CLIP-10 …` не выполняется.
- [x] 1.4 Написать `tests/run.lua` по design, решения 1, 2 и 12:
  - реестр файлов по наборам `unit`, `wezterm`, `install`, `trace`;
  - процесс на файл через `vim.system` с таймаутом;
  - разбор строк и правила вердикта: код не 0 → FAIL, таймаут → FAIL, пустой вывод без фильтра → FAIL;
  - аргументы `--id`, `--update-golden`, `--strict`;
  - логи в `.tests/logs/`;
  - энтропия (ОС, пути к инструментам, время) собрана в начале файла.

  Проверка (windows) — три временных файла, зарегистрированных в реестре, после проверки удалить:
  - файл с `os.exit(1)` после строк `ok` → FAIL;
  - файл без вывода с кодом 0 → FAIL «проверки не выполнялись»;
  - файл с бесконечным циклом → FAIL по таймауту;

  после удаления `nvim -l tests/run.lua unit` выходит с кодом 0.
- [x] 1.5 Написать `tests/lib/spec_index.lua`. Он читает ID из `openspec/specs/*/spec.md`, ADDED-требования открытых changes, требования из `openspec/changes/archive/`, строки `Проверка:` (пути `tests/…` и пункты `вручную (…)`) и чек-листы `tests/manual/*.md` по формату `review-baseline`: код пункта, ID, последняя строка `Проверено:`. Раннер по этому индексу печатает сводку по ID (PASS / FAIL / SKIP / MANUAL / UNCOVERED), список «есть проверка, нет строки `Проверка:`» и пишет `.tests/report.json` с происхождением. Проверка (windows): число ID в отчёте равно `grep -h '^### Requirement:' openspec/specs/*/spec.md | wc -l` (на 2026-09-27 — 128), в `report.json` есть HEAD, признак грязного дерева, версии nvim и WezTerm.
- [x] 1.6 Написать `tests/README.md`:
  - протокол строк и правила вердикта;
  - наборы и реестр;
  - как добавить проверку: имя начинается с ID, файл вносится в реестр;
  - `--id`, `--update-golden` и когда его можно применять;
  - SKIP и MANUAL;
  - ограничения LuaJIT против Lua 5.4.

  Раздел «Проверки» в `CLAUDE.md` начинается с `nvim -l tests/run.lua` как единственной команды, туда же добавляется `--id` к правилу 2 («Баг»). Проверка (windows): каждая команда из обоих файлов, выполненная дословно из корня репо, отрабатывает без ошибки использования.

## 2. Поддельный wezterm, обёртка и фикстура

- [x] 2.1 Написать обёртку `tests/wezterm/guard.lua` по design, решение 7: `FORGE_CONFIG`, `FORGE_TARGET`, `pcall(dofile)`, `os.exit(3)` и маркер `FORGE_CONFIG_OK`, всё тело в `pcall`. В `tests/wezterm/VERSION` записать `20240203-110809-5046fc22`. Проверка (windows):
  - копия `wezterm.lua` с синтаксической ошибкой в `.tests/` даёт код 3 и `FORGE_CONFIG_ERROR` с файлом и строкой;
  - `wezterm.lua` репо с тройками `x86_64-pc-windows-msvc`, `aarch64-apple-darwin` и `x86_64-unknown-linux-gnu` даёт код 0 и маркер с нужной тройкой.
- [x] 2.2 Добавить в обёртку режим выгрузки `wezterm.gui.default_key_tables()` в `tests/wezterm/fixtures/default_key_tables.lua`: Lua-литерал, в шапке версия WezTerm, тройка хоста и команда. Выгрузку делает `run.lua --update-golden`. Проверка (windows): две выгрузки подряд дают побайтно одинаковый файл, в нём есть таблицы `copy_mode` и `search_mode`.
- [x] 2.3 Написать или дополнить `tests/wezterm/fake_wezterm.lua` по design, решение 3:
  - `load_config{ triple, env, files }` с `setfenv`;
  - `require`, `os.getenv` и `io.open` подставляются, файлы лежат в памяти, записи перехватываются;
  - `act.*` отдаются как данные, `action_callback`, `on`;
  - `gui.default_key_tables` из фикстуры, заглушки `gui.screens` и `mux`;
  - поддельные окно и панель.

  У каждого поддельного поведения в комментарии записано, что оно имитирует и где проверено. Проверка (windows): самопроверки `SELF: …` в `tests/wezterm/fake_wezterm.test.lua` зелёные:
  - `config.keys` не пуст для трёх троек;
  - настоящий `io.open` при загрузке не вызывается (шпион);
  - копия `wezterm.lua` с оператором `//` не загружается и даёт FAIL с синтаксической ошибкой.

## 3. Проверки по требованиям через подделку

Каждая проверка — сценарий требования, имя начинается с ID. Проверки описывают базовую линию, то есть код как есть (design, решение 4). Если проверка, написанная по сценарию, падает на текущем коде, её не подгоняют: расхождение решается по правилу фазы из `config.yaml`. В заметках apply записывается ID и что разошлось. После каждой задачи временная мутация откатывается, `git diff wezterm.lua` пуст.

- [x] 3.1 `tests/wezterm/keyboard-protocol.test.lua`: WT-KBD-1…5 и WT-KBD-7 в части, видимой в конфиге. Это настройки протокола по тройкам, Alt как Meta, CSI-u выключен, `SendKey F13` на Ctrl+[. Проверка (windows): `nvim -l tests/run.lua --id WT-KBD` зелёный. Мутация `enable_kitty_keyboard = true` для Windows даёт FAIL у WT-KBD-1.
- [x] 3.2 `tests/wezterm/key-ownership.test.lua`, часть WezTerm:
  - WT-KEYS-1 (встроенные привязки отключены);
  - WT-KEYS-2 (только `phys:` и именованные клавиши, голых символьных нет);
  - WT-KEYS-3 (набор перехватов по тройкам сверяется с таблицей требования);
  - WT-KEYS-5;
  - WT-KEYS-8 (повторы по design, решение 5).

  Проверка (windows): `nvim -l tests/run.lua --id WT-KEYS` зелёный. Мутация: вторая запись `phys:S` с другим действием в таблице windows даёт FAIL у WT-KEYS-8 с парой `phys:S NONE` в тексте.
- [x] 3.3 Написать `tests/lib/keynames.lua` (перевод в запись nvim) и `tests/lib/nvim_keymaps.lua` (headless nvim без плагинов плюс статические `keys` lazy, design, решение 6). Добавить в `key-ownership.test.lua` WT-KEYS-4, WT-KEYS-6 и WT-KEYS-7:
  - пересечение равно исключениям WT-KEYS-7;
  - набор `<C-S-…>` и `<D-…>` nvim_forge;
  - `<F13>` в режимах n, i и x.

  Ограничение по динамическим привязкам записано в тесте. Проверка (windows):
  - `--id WT-KEYS` зелёный;
  - мутация — привязка Ctrl+Shift+F в `config.keys` — даёт FAIL у WT-KEYS-4 и WT-KEYS-7;
  - после прогона вне `.tests/` нет новых файлов (`git status --porcelain` пуст, кроме файлов этого change);
  - самопроверки `keynames` зелёные.
- [x] 3.4 `tests/wezterm/clipboard.test.lua`: WT-CLIP-1…6 и WT-CLIP-10. Колбэки копирования проверяются на поддельном окне с выделением и без, вставка — по привязкам, независимость от раскладки — по `phys:`. Если файл принёс `fix-copy-clobbers-clipboard`, его проверки переименовываются под формат «ID в начале», а не дублируются. Проверка (windows): `--id WT-CLIP` зелёный. Мутация: Cmd+C → голый `act.CopyTo` даёт FAIL у WT-CLIP-5 (а не падение файла).
- [x] 3.5 `tests/wezterm/windows-mode.test.lua`: WT-WIN-1…21 в части, видимой в таблицах и колбэках:
  - вход и тумблер;
  - выходы Esc и Enter;
  - таймаут;
  - состав команд;
  - какие команды выходят из режима, а какие нет (WT-WIN-19, как есть);
  - раскладка и платформа (WT-WIN-20).

  Проверка (windows): `--id WT-WIN` зелёный. Мутация: удаление Escape из таблицы windows даёт FAIL у WT-WIN-2.
- [x] 3.6 `tests/wezterm/panes-tabs.test.lua`: WT-PANE-1…13 в части привязок и колбэков. Готовый лэйаут проверяется на поддельной панели, переименование вкладки и воркспейсы — по вызовам запросов. Проверка (windows): `--id WT-PANE` зелёный. Мутация: направление в Ctrl+Shift+Enter → `Down` даёт FAIL у WT-PANE-1.
- [x] 3.7 `tests/wezterm/scrollback.test.lua`:
  - WT-SCROLL-1, -2 и -4;
  - WT-SCROLL-5…12: перевод copy_mode на `phys:` по фикстуре, `/`, `n`, `N`, search_mode, QuickSelect;
  - WT-SCROLL-13: колбэк пишет файл в поддельный `io` и запускает вкладку с nvim;
  - WT-SCROLL-15.

  Проверка (windows): `--id WT-SCROLL` зелёный. Мутация: отключение перевода для `mapped:G` даёт FAIL у WT-SCROLL-6.
- [x] 3.8 `tests/wezterm/window-state.test.lua`: WT-STATE-1…8.
  - Файл состояния: чтение, битый JSON, отсутствие.
  - Сохранение по Ctrl+Shift+S: JSON в поддельный файл.
  - Шрифт: крупнее, мельче, сброс через overrides.
  - `gui-startup` на поддельных `screens` и `mux`: размер и центрирование.

  Проверка (windows): `--id WT-STATE` зелёный. Мутация: шрифт по умолчанию 12 → 13 даёт FAIL у WT-STATE-5.
- [x] 3.9 `tests/wezterm/ui.test.lua`: WT-UI-1…15 в части конфига:
  - выбор `default_prog` по поддельному PATH и поддельным файлам;
  - схема, шрифты и запасные шрифты, поля, звонок, курсор, панель вкладок, притушение;
  - бейдж по `active_key_table` через `update-right-status`;
  - имя воркспейса, частота обновления.

  Проверка (windows): `--id WT-UI` зелёный. Мутация: удаление `pwsh.exe` из поддельного PATH меняет ожидаемый `default_prog`, и проверка это видит (FAIL, если ожидание не поменять).

## 4. Проверки на настоящем WezTerm

- [x] 4.1 `tests/wezterm/config-loading.test.lua`: WT-LOAD-11 по design, решение 7. Сначала дословная проверка `ls-fonts` на файле репо для ОС хоста, затем обёртка для трёх троек. HOME, USERPROFILE и XDG указывают в `.tests/sandbox/wezterm`. Проверка (windows):
  - `nvim -l tests/run.lua wezterm` зелёный;
  - временно испорченный `wezterm.lua` даёт FAIL у WT-LOAD-11, откатить;
  - с PATH без `wezterm` набор даёт SKIP с причиной, а в сводке WT-LOAD-11 не PASS.
- [x] 4.2 `tests/wezterm/snapshot.test.lua` и эталоны по design, решение 8:
  - снимок `show-keys --lua` через обёртку для трёх троек, нормализация `phys:` и `Callback`;
  - снимок конфигурации из подделки;
  - эталоны `tests/wezterm/golden/{keys,config}.{windows,macos,linux}.lua` с шапкой происхождения;
  - сверка `tests/wezterm/VERSION` с `wezterm --version`.

  Проверка (windows):
  - два прогона подряд зелёные;
  - `--update-golden` на чистом дереве не даёт `git diff tests/wezterm/golden`;
  - мутация m3 (`phys:S` → `CloseCurrentPane` в таблице windows) даёт FAIL с diff'ом строки;
  - временная подмена `VERSION` даёт SKIP снимка `show-keys` с обеими версиями.

## 5. Shell-наборы в общем прогоне

- [x] 5.1 Зарегистрировать `tests/install-macos.scenarios.sh` по design, решение 9. Как запускается:
  - Windows — `wsl bash` с путём через `wslpath` и веткой `FORGE_BASH32`;
  - macOS — `/bin/bash` и `bash` из Homebrew;
  - Linux — `bash`;
  - без среды — SKIP.

  Проверка (windows):
  - `nvim -l tests/run.lua install` выполняет скрипт в WSL, итог `N passed, 0 failed` виден в логе;
  - в сводке ID из строк `Проверка: tests/install-macos.scenarios.sh (…)` (например, MAC-INST-1, WT-LOAD-4) получают вердикт набора;
  - с временно скрытым `wsl` набор получает SKIP, а не PASS.
- [x] 5.2 Если к моменту применения есть `tests/wezterm-keys.scenarios.sh`, зарегистрировать его с окружением «bash + wezterm». Проверка (windows): он выполняется в `nvim -l tests/run.lua`, его строки попадают в сводку. Если файла нет, в заметках apply записано «не зарегистрирован, файла нет».

## 6. Трассировка

- [x] 6.1 Написать `tests/trace.test.lua` по design, решение 10, на индексе из 1.5. Корень репо передаётся параметром, чтобы проверять копию дерева. Проверки:
  - неизвестные ID в файлах проверок, в `tests/manual/*.md`, в тегах `-- spec:` в `wezterm.lua` и в строках `Спека:` FIXLOG;
  - несуществующие или незарегистрированные пути `tests/…` в строках `Проверка:`;
  - ненайденные пункты `вручную (…)`;
  - файлы `*.test.lua` и `*.sh` в `tests/` вне реестра.

  Проверка (windows): на репо `nvim -l tests/run.lua trace` зелёный. На копии дерева в `.tests/trace-fixture/` каждое нарушение даёт свой FAIL с именем файла и ID:
  - тест с `WT-CLIP-99`;
  - тег `-- spec: WT-XXX-1`;
  - `Проверка: tests/nope.sh`;
  - незарегистрированный `tests/x.test.lua`.
- [x] 6.2 Сверить сводку раннера с ручными чек-листами. Если `tests/manual/wezterm-{windows,macos}.md` уже есть (`review-baseline`), ID их пунктов получают MANUAL с последней строкой `Проверено:` или «не проверялось». Проверка (windows): у пункта W2 (WT-KEYS-9) статус MANUAL, ни один ID со статусом MANUAL не показан как PASS. Если файлов ещё нет, сводка явно пишет «ручных чек-листов нет», и это записано в заметках apply.

## 7. Хук pre-commit (необязательный)

- [x] 7.1 Написать `.githooks/pre-commit`: POSIX sh, запускает `nvim -l tests/run.lua`. Без `nvim` хук падает с подсказкой, а не пропускает молча. Способ включения (`git config core.hooksPath .githooks`) и выключения описать в `tests/README.md` и в разделе «Проверки» `CLAUDE.md`. Проверка (windows): на чистом дереве `sh .githooks/pre-commit` выходит с кодом 0, с временным падающим файлом в реестре — с кодом 1. Файл удалить, `core.hooksPath` в этом репо без решения владельца не выставлять.

## 8. Итог

- [x] 8.1 Полный прогон на Windows. Проверка (windows):
  - `nvim -l tests/run.lua` выходит с кодом 0, FAIL = 0;
  - общее время записано в заметках apply (ожидание — порядка 10 с);
  - `.tests/report.json` содержит все 128 ID;
  - `wezterm --config-file F:/repo/forge-nvim/wezterm.lua ls-fonts` — stderr без `ERROR`;
  - `openspec validate add-wezterm-spec-checks --type change --strict --no-interactive` проходит.
- [ ] 8.2 Передать владельцу шаги для Mac: `wezterm --version`, `nvim -l tests/run.lua` из чекаута, сравнить сводку с Windows. Проверка (macos, вручную): результат записан строкой `Проверено:` в пункт-паспорт M0 `tests/manual/wezterm-macos.md` (`review-baseline`). Если снимок macOS разошёлся с эталоном, снятым на Windows, это записано там же и открыт вопрос из design, Open Questions.
