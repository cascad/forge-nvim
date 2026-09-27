# Tasks

Гейт шага (design, решение 1):
- `nvim -l tests/run.lua` выходит с кодом 0;
- `git status --porcelain tests/` пуст;
- `--update-golden` не применялся.

Каждая группа 2–6 — отдельный коммит с пометкой «поведение не меняется, эталоны без изменений». Если эталон изменился, шаг откатывается и делится мельче.

## 1. Предусловия

- [x] 1.1 Убедиться, что `add-wezterm-spec-checks` применён. Проверка (windows):
  - `nvim -l tests/run.lua` выходит с кодом 0;
  - в `tests/wezterm/golden/` есть `keys.{windows,macos,linux}.lua` и `config.{windows,macos,linux}.lua`;
  - в сводке trace FAIL = 0.
- [x] 1.2 Проверить другие changes по design, решение 8: `openspec list`, затем для каждого активного change с `wezterm.lua` в `tasks.md` — есть ли в нём одновременно `[x]` и `[ ]`. Начатый, но не законченный change → стоп, сначала довести его. Отдельно записать, применён ли `sync-docs-with-baseline`, от этого зависит группа 6. Проверка (windows): в заметках apply — список changes со статусом «применён / не начат / начат» и вывод «можно начинать» либо «стоп: <id>».

## 2. Факты о платформе

- [x] 2.1 Завести секцию фактов о платформе по design, решение 3: ОС, дом, разделители, шелл через `exe_in_path`. Перевести на неё все девять проверок `is_windows` и прямые чтения `target_triple`, `home_dir`, `os.getenv` и PATH. Условия переносятся дословно («не Windows» остаётся «не Windows»). Проверка (windows): гейт шага. `grep -n 'target_triple\|os.getenv\|home_dir' wezterm.lua` находит строки только внутри секции, её границы записаны в заметках apply. Эталоны `*.linux.lua` без изменений.

## 3. Колбэки — именованные функции

- [x] 3.1 Вынести встроенные колбэки в именованные функции секции действий по design, решение 6. Существующие имена не меняются, входы — аргументы, `platform` и явные пути. Проверка (windows):
  - гейт шага;
  - в секциях привязок и таблиц режимов нет `action_callback(function` — только ссылки на именованные функции;
  - разовая проверка запасной ветки: подделка с `gui.default_key_tables`, бросающим ошибку, грузит конфиг без ошибки, `config.keys` не пуст. Команда и вывод — в заметках apply.

## 4. Таблица привязок

- [x] 4.1 Перевести все сочетания вне режимов на записи `map(key, mods, action, opts)` в одной секции по design, решение 4. Семейства (вкладки, шрифт) строятся циклами через `map`, `opts.os` повторяет нынешние условия. `config.keys` присваивается одной строкой сборщика. Проверка (windows): гейт шага. `grep -n 'config.keys' wezterm.lua` находит одно присваивание, `grep -n 'table.insert(config.keys' wezterm.lua` пуст.
- [x] 4.2 Перевести таблицы `windows` и `resize_pane` на записи помощника таблиц режимов. `/`, `n`, `N` в `copy_mode` (и замены, которые уже принесли соседние changes) оформить записями «заменить пару» поверх `to_phys_binding` по design, решение 5. Проверка (windows): гейт шага. `grep -n 'table.insert(config.key_tables' wezterm.lua` пуст, проверки `--id WT-KEYS-8` и `--id WT-SCROLL` зелёные.

## 5. Теги `-- spec:`

- [x] 5.1 Поставить тег `-- spec: <ID>[, <ID>]` на каждую запись привязки, каждую запись-замену и каждую группу настроек по design, решение 7. ID берутся из `openspec/specs/`: требование, чей сценарий описывает эту клавишу или настройку. Проверка (windows): гейт шага, trace зелёный, у каждой записи привязки есть тег.
- [x] 5.2 Дополнить `tests/trace.test.lua` проверкой: строка `wezterm.lua` с вызовом `map(`, помощника таблиц режимов или записи-замены без `-- spec:` — FAIL с номером строки. Проверка (windows): на репо trace зелёный. Если временно убрать тег у одной записи, получается FAIL с её строкой; тег вернуть.
- [x] 5.3 Дописать в `CLAUDE.md`, правило 2 («Баг»), шаг «код требования: `grep -n 'spec: <ID>' wezterm.lua`», а в `tests/README.md` — формат тега и правило trace. Проверка (windows): команда из `CLAUDE.md` с `WT-CLIP-2`, выполненная дословно, находит строки привязок копирования.

## 6. Комментарии

- [x] 6.1 Выполняется, только если `sync-docs-with-baseline` применён (см. 1.2). Иначе задача отмечается как отложенная с причиной, а change архивируется без неё.
  - Сократить до тега и строки `История: FIXLOG §N` те комментарии-обоснования и истории, чьё содержание уже есть в требовании или записи FIXLOG. Знание, которого нет нигде, остаётся.
  - В шапку добавить оглавление секций (design, решение 2).

  Проверка (windows): гейт шага. В сообщении коммита перечислен каждый сокращённый блок с ID или § FIXLOG, где лежит его содержание. Число строк комментариев (`grep -c '^\s*--' wezterm.lua`) до и после записано.

## 7. Итог

- [ ] 7.1 Финальный прогон на Windows. Проверка (windows):
  - гейт шага;
  - `wezterm --config-file F:/repo/forge-nvim/wezterm.lua ls-fonts` — stderr без `ERROR`;
  - в работающем WezTerm после Ctrl+Shift+R: Ctrl+Shift+Space включает режим WINDOWS с бейджем, Ctrl+C без выделения прерывает `ping -t localhost`, а с выделением копирует;
  - `openspec validate restructure-wezterm-config --type change --strict --no-interactive` проходит.
- [ ] 7.2 Передать владельцу шаги для Mac: `git pull`, перечитать конфиг в WezTerm, `nvim -l tests/run.lua` из чекаута. Там же проверить, что Cmd+C с выделением копирует, а Ctrl+Shift+Space включает WINDOWS. Проверка (macos, вручную): результат записан строкой `Проверено:` в пункт-паспорт M0 `tests/manual/wezterm-macos.md`. Если чек-листа ещё нет — в заметках apply с датой и версией WezTerm.

## Заметки apply (2026-09-27)

- **Коммитов нет** — указание владельца («ничего коммитить не надо»). Поэтому группы 2–6 сделаны одним проходом, а гейт прогнан после него и после правки trace. `tests/` в git ещё не добавлен, и `git status --porcelain tests/` ничего не доказывает. Вместо него — `sha1sum -c` эталонов `tests/wezterm/golden/*`, снятых до перестройки: все шесть OK. Снимки сравнивались, не SKIP: в логе `ok SNAPSHOT: keys.windows|macos|linux` и `config.*`. `--update-golden` не применялся. Перечень сокращённых блоков, который шёл бы в сообщения коммитов, — ниже.
- **1.1:** `add-wezterm-spec-checks` применён. Открыт только пункт 8.2 (Mac). Эталоны `keys.*`/`config.*` для трёх троек есть, trace FAIL = 0.
- **1.2:** у всех changes с `wezterm.lua` открыты только ручные проверки в GUI и на Mac, код доделан:
  - `fix-windows-mode-modality`, `change-search-enter-accept`, `fix-copy-clobbers-clipboard`, `resolve-key-ownership-conflicts`, `fix-window-state-new-windows`, `fix-ui-robustness`, `add-nvim-chords-on-windows` — применены;
  - `sync-docs-with-baseline` — применён, без GUI-пунктов 1.4, 1.5, 3.1, 3.7, 3.8.

  Вывод: можно начинать, группа 6 выполняется.
- **2.1:** секция «1. ФАКТЫ О ПЛАТФОРМЕ» — строки 37–76; `target_triple`, `home_dir` и `os.getenv` только в ней (строки 63, 69, 73; строка 39 — комментарий). `platform = { os, is_windows, home, pwsh }`. Условие «не Windows» осталось «не Windows» (`opts.os = "not_windows"`), эталоны linux без изменений. Разделители путей отдельным полем не заведены: их единственный потребитель, `find_in_path`, работает только на Windows, и `;` и `\` названы в его комментарии.
- **3.1:** `action_callback(function` — только в секции 4: копирование, шрифт, сохранение окна, лэйаут, выгрузка, подмена. Запросы получили именованные `rename_active_tab` и `switch_to_workspace`, события — `on_window_config_reloaded`, `on_user_var_changed`, `update_right_status`, `format_tab_title`. Колбэки подмены теперь создаются на всех ОС, а привязываются только на Windows. Лишние 9 колбэков на macOS и Linux ни в `show-keys`, ни в снимке не видны.
- **3.1, запасная ветка.** Подделка без `wezterm.gui` (`F.load_config{ triple, env = {}, files = {}, gui = false }`, скрипт в scratchpad сессии). Итог: windows — `keys=57`, macos и linux — `keys=61`, `key_tables = resize_pane, windows`. В журнале два `warn`: «copy_mode: встроенной таблицы нет — остаётся таблица WezTerm» и то же для search_mode. Конфиг грузится.
- **4.1:** `config.keys` присваивается одной строкой — `config.keys = build_keys(bindings, platform)`. `table.insert(config.keys` нет.
- **4.2:**
  - таблицы `windows` и `resize_pane` строятся через `mode_map`, сборку делает `with_terminal_bindings`;
  - `/`, `n`, `N`, `y` и Enter заданы записями `mode_replace` («заменить пару, нет — добавить; больше одной — `log_error`»);
  - `table.insert(config.key_tables` нет;
  - `--id WT-KEYS-8` и `--id WT-SCROLL` зелёные.

  Отличия от прежнего кода — только на версиях WezTerm без нужных записей (на 20240203 эталоны те же):
  - нет встроенного `y` — теперь добавляется наш, раньше был только `log_error`;
  - нет встроенных таблиц — предупреждение на каждую таблицу, раньше одно на copy_mode.

  В таблицах режимов `mods = "NONE"` вместо отсутствующего поля, в resize `act.PopKeyTable` вместо строки `"PopKeyTable"`. По обоим снимкам это одно и то же.
- **5.1:** тег стоит на каждой записи `map`/`mode_map`/`mode_replace`, на группах настроек и на `wezterm.on`. ID — из `openspec/specs/` и ADDED активных changes (WT-KEYS-10, WT-KBD-9); trace зелёный.
- **5.2:** в `tests/lib/trace.lua` — категория `untagged` (`M.is_binding_call`), в самопроверке `tests/lib/trace.test.lua` — мутация `map("F24", …)` без тега. Проба на репо: снят тег у `map("phys:Z", …)` → `FAIL TRACE: запись привязки без тега -- spec: — wezterm.lua:580`, файл восстановлен (cmp).
- **5.3:** правило 2 в `CLAUDE.md` и абзац о тегах в `tests/README.md`. `grep -n 'spec: WT-CLIP-2' wezterm.lua` находит строку 540 — привязку умного Ctrl+C.
- **6.1:** строк комментариев (`grep -c '^\s*--'`) было 462, стало 233; файл — 1082 строки, стало 879. Шапка получила оглавление секций. Сокращены до ID/§ блоки:
  - kitty и win32-input-mode — WT-KBD-1, §41;
  - маска IME — WT-KBD-3, §41 (пометка ИНВАРИАНТ оставлена);
  - выключенные встроенные привязки — WT-KEYS-1/2;
  - «почему не tmux» и модель режима — docs/WEZTERM.md, разделы 0–2, §47;
  - список шрифтов — WT-UI-4, §52;
  - копирование — WT-CLIP-1, §42, §45;
  - шрифт через overrides и сброс — WT-STATE-6/7, §48;
  - «принять окно» — WT-STATE-1/2, §48;
  - Super-шрифт — §50; правый Alt — §51;
  - подмена — WT-KEYS-10, §53;
  - бейдж и ширина вкладок — WT-UI-12/15, §52;
  - Enter в поиске — WT-SCROLL-10, §46;
  - каталог новой панели (OSC 7) — WT-PANE-12;
  - Ctrl+Tab — WT-KEYS-5.

  Остались комментарии с тем, чего нет нигде:
  - перевод `to_phys_binding`: заглавные и Shift;
  - Store-псевдоним и `wezterm.glob`;
  - Null-overrides как признак непринятого окна;
  - ClearKeyTableStack вместо PopKeyTable;
  - формат записи win32-input-mode.
- **7.1:**
  - гейт: `nvim -l tests/run.lua` — 19/19 PASS, ID 108 PASS / 0 FAIL;
  - `nvim -l tests/run.lua conpty` — PASS после снятия EN-пробы, см. `add-nvim-chords-on-windows`;
  - `ls-fonts` — `ERROR` нет;
  - `openspec validate --all --strict` — 23/23.

  Ручная часть в GUI (Ctrl+Shift+R, WINDOWS с бейджем, Ctrl+C и `ping -t`) не выполнялась — пункт открыт.
