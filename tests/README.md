# Проверки

Слой проверок связывает ID требований из `openspec/specs/` с кодом
(change `add-wezterm-spec-checks`). Поведение WezTerm, установщиков и
nvim_forge он не меняет.

## Одна команда

```sh
nvim -l tests/run.lua                      # всё, что проверяется без GUI
nvim -l tests/run.lua unit                 # только набор unit (наборы: unit, e2e, wezterm, install, trace, conpty)
nvim -l tests/run.lua e2e                  # реализованные end-to-end сценарии
nvim -l tests/run.lua conpty               # проба через conpty.dll (Windows, ~1,5 мин; в обычный прогон не входит)
nvim -l tests/run.lua --id WT-CLIP         # вся capability
nvim -l tests/run.lua --id WT-CLIP-2       # одно требование (WT-CLIP-20 не захватывается)
nvim -l tests/run.lua --strict             # UNCOVERED тоже валит прогон
nvim -l tests/run.lua --update-golden      # принять осознанное изменение эталонов и фикстуры
nvim -l tests/run.lua --help
```

Команды — из корня репо. Нужен только Neovim 0.12 (LuaJIT, `vim.system`).
Наборы с Python требуют Python 3. Единые quick/e2e/full-команды для VM,
правило e2e для каждой фичи/бага и фактическое покрытие:
[e2e/README.md](e2e/README.md). Обёртки — `scripts/test.ps1` и `scripts/test.sh`.
WezTerm 20240203, WSL и bash 3.2 нужны своим наборам; без них набор получает
SKIP, а не PASS.

Editor e2e требует Git, ripgrep и подготовленные исходники плагинов по
`nvim_forge/lazy-lock.json`: `python3 tests/e2e/prepare_editor.py --download`
(Windows: `python`). Подготовка выполняется отдельно; отсутствие или
расхождение зависимостей даёт FAIL с подсказкой. Docker готовит их при build.
В подготовку входят временные Neogit/Gitsigns backports, проверяемые по pin/SHA256;
используется Neovim (`--nvim <path>`). Повторять подготовку также после
изменения backport при том же lock. См. [patches](../nvim_forge/patches/README.md).
Сам тест запускает настоящую сборку с подключённым RPC UI и приватным
профилем; подробнее — [e2e/README.md](e2e/README.md).

DAP E2E также требует совместимые Go/Delve. Явная подготовка частных версий:
`python3 -B tests/e2e/prepare_dap.py --download` (Windows: `python`).
Docker готовит их при build; в тесте нет загрузки SDK/адаптера.
Только DAP: `nvim -l tests/e2e/dap-output.test.lua`; фильтр —
`nvim -l tests/run.lua e2e --id IDE-DAP`.

Go/neotest E2E дополнительно требует C compiler (clang/gcc) и явной подготовки
парсера/runner: после prepare_editor.py и prepare_dap.py выполнить
`python3 -B tests/e2e/prepare_tests.py --download` (Windows: `python`).
Она собирает Go parser из каталога pinned Treesitter, проверяет ABI в Neovim
и ставит gotestsum v1.13.0 в `.tests/test-deps`. Docker делает это при build.
Прямой прогон: `nvim -l tests/e2e/test-runner.test.lua`; фильтры общего runner:
`--id IDE-TEST` или `--id IDE-DAP-3`. Нужные бинарники добавляются только
в PATH дочернего редактора. Системный Go и профиль пользователя не меняются.

Completion/snippet E2E без новых инструментов:
`nvim -l tests/e2e/snippet-input.test.lua` либо
`nvim -l tests/run.lua e2e --id IDE-SNIP-1`. Нужны только общие подготовленные
плагины; fixture загружается штатным VSCode loader и принимается из настоящего
cmp меню. LSP не подменяется, языковой сервер этому сценарию не нужен.

Отсутствующий codelldb: `nvim -l tests/e2e/dap-discovery.test.lua` либо
`nvim -l tests/run.lua e2e --id IDE-DAP-4`. Тест исключает каталоги codelldb
только из PATH дочернего редактора, проверяет отсутствие binary и наличие
Git; private LOCALAPPDATA/Mason не содержат tools. Если обязательные tools
на машине находятся в том же единственном каталоге, подготовить отдельное
окружение без codelldb. Реальные установленный debugger и пользовательские
файлы не меняются; это negative E2E, не проверка Rust/C/C++ debugging.

Run & Debug panels: `nvim -l tests/e2e/debug-panels.test.lua` либо
`nvim -l tests/run.lua e2e --id IDE-PANEL`. Нужны подготовленные Go/Delve.
Go E2E используют общий compiler cache одного прогона в native temp:
`FORGE_E2E_GO_CACHE` передаётся только тестовым процессам. Для прямого файла
создаётся собственный temp cache; можно явно задать подготовленный каталог.
Это не test-result cache. Runtime cache не расположен на Windows/Docker bind mount.
Для повторения старого конфига можно явно задать `FORGE_E2E_CONFIG_SOURCE`:
его lock обязан совпасть с подготовленным, источник пишется в config-origin.txt.

Код возврата: 0 — FAIL нет; 1 — есть FAIL (или UNCOVERED под `--strict`,
или под `--id` не выполнилось ни одной проверки); 2 — ошибка аргументов.

Каждый файл проверок запускается и напрямую, без раннера:

```sh
nvim -l tests/lib/check.test.lua
nvim -l tests/wezterm/fake_wezterm.test.lua
nvim -l tests/shell-diagnostics.test.lua   # пассивная диагностика IDE-001, нужен Python 3
```

Сам сборщик: `python3 nvim_forge/scripts/diagnose-shell.py` (на Windows —
`python`). Выполнять из проблемного каталога, используя абсолютный путь к
скрипту. Он ничего не исполняет и не изменяет; инструкция —
`docs/MACOS_STARTUP_DIAGNOSTICS.md`.

## Протокол строк

Один на все файлы — Lua и shell (как у `tests/install-macos.scenarios.sh`):

```
  ok   <имя>
  FAIL <имя>  -- <подробность>
      | <продолжение подробности>
  SKIP <имя>  -- <причина>
```

Имя проверки начинается с ID требования: `WT-CLIP-2 Ctrl+C без выделения
уходит в программу`. Несколько ID — через пробел или запятую в начале имени
(`WT-KEYS-4 WT-KEYS-7 пересечение …`); `WT-CLIP-1-b …` — вариант случая
WT-CLIP-1. Служебные самопроверки начинаются с `SELF:` и в сводку по ID не
попадают. Строки, не похожие на протокол, раннер пропускает (они остаются в
логе).

**Вердикт файла** (раннер, `tests/run.lua`):

| Что случилось | Вердикт |
|---|---|
| файл в реестре, но его нет на диске | FAIL «зарегистрирован, но файла нет» |
| код возврата не 0 | FAIL, даже если все строки `ok` |
| таймаут (60 с, у установщика 180 с) | FAIL, процесс убит |
| код 0, ни одной строки, без `--id` | FAIL «проверки не выполнялись» |
| код 0, ни одной строки, под `--id` | нет случаев — не PASS и не FAIL |
| есть строки `FAIL` | FAIL |
| все случаи `SKIP` | SKIP |
| иначе | PASS |

SKIP никогда не засчитывается как PASS.

**Статус ID** в сводке:

- **PASS** — все его проверки `ok`;
- **FAIL** — есть `FAIL`, или файл с его проверками упал целиком (таймаут,
  код без строк `FAIL`): его `ok`-строкам тогда не верим;
- **SKIP** — проверки есть, но не все `ok` и нет `FAIL`;
- **MANUAL** — у требования есть пункт ручного чек-листа
  (`tests/manual/*.md`) или строка `Проверка: вручную (tests/manual/<файл>, <пункт>)`.
  Показывается последняя строка `Проверено:` пункта или «не проверялось».
  Автоматическая часть видна рядом («авто: PASS …»). MANUAL никогда не PASS,
  а FAIL автоматической части важнее MANUAL;
- **UNCOVERED** — проверок нет. В фазе 1 не валит прогон, `--strict` — валит.

ID shell-набора берутся не из имён его проверок, а из строк
`Проверка: tests/<набор> (…)` в спеках; их статус — вердикт набора целиком.

Кроме сводки раннер печатает:
- «есть автоматическая проверка, нет строки `Проверка:` с этим файлом в спеке» —
  список для прохода по спекам (design, Open Questions);
- неизвестные ID в именах проверок (нет в `openspec/specs/` и в ADDED открытых
  changes);
- «ручных чек-листов нет», если `tests/manual/*.md` ещё нет.

## Наборы и реестр

`tests/registry.lua` — список всех файлов проверок:

```lua
{ file = 'tests/wezterm/clipboard.test.lua', suite = 'unit' },
{ file = 'tests/install-macos.scenarios.sh', suite = 'install', kind = 'sh', shell = 'posix', timeout = 180 },
```

- `suite` — `unit` (подделка, без GUI и сети), `wezterm` (настоящий бинарник),
  `install` (shell-наборы установщиков), `trace` (связь ID ↔ проверка);
- `kind` — `lua` (по умолчанию, `nvim -l <file>`) или `sh` (способ запуска
  зависит от ОС хоста, `LAUNCHERS.sh` в `run.lua`, см. «Shell-наборы»);
- `shell` — у `kind = 'sh'` обязательно, среда набора; сейчас одна — `posix`;
- `timeout` — секунды, по умолчанию 60 (на каждый прогон).

Файл вне реестра trace считает ошибкой; запись без файла — FAIL.
`--registry <файл>` подменяет реестр — только для самопроверки раннера.

Каждый файл идёт отдельным процессом. Раннер передаёт ему окружение:

| Переменная | Что |
|---|---|
| `FORGE_REPO` | корень репо |
| `FORGE_TEST_ID` | фильтр `--id` (пусто — все случаи) |
| `FORGE_UPDATE_GOLDEN` | `1` под `--update-golden` |
| `FORGE_SANDBOX` | `.tests/sandbox` — всё, что проверке нужно записать |
| `FORGE_WEZTERM` | путь к `wezterm` (пусто — бинарника нет, проверки дают SKIP) |
| `FORGE_HOST_OS` | `windows` / `macos` / `linux` |

Вся энтропия раннера (ОС, пути к инструментам, версии, git, время) собрана
в начале `run.lua`; ниже по коду — только данные.

### Shell-наборы (`kind = 'sh'`, `shell = 'posix'`)

Среда `posix` — bash, git и python3; скрипт вызывается как
`<скрипт> <репо> [bash под проверкой]` (контракт
`tests/install-macos.scenarios.sh`, сам скрипт не меняется). Каждая ветка —
отдельный прогон со своей строкой `== install: <файл> [<ветка>]`, своим
вердиктом и логом `.tests/logs/<файл>@<ветка>.log`:

| ОС хоста | Ветки |
|---|---|
| Windows | `wsl -e bash` (bash из WSL), путь репо — через `wslpath`; ветка bash 3.2 — `FORGE_BASH32=<путь в WSL>` |
| macOS | `/bin/bash` (3.2); bash из Homebrew — если `bash` в PATH не `/bin/bash` |
| Linux | `bash`; ветка bash 3.2 — `FORGE_BASH32=<путь>` |

```sh
FORGE_BASH32=/home/<user>/b32/bash-3.2.57/bash nvim -l tests/run.lua install   # Windows: путь внутри WSL
```

В Git Bash на Windows значение, начинающееся с `/`, при запуске `nvim.exe`
переписывается в путь Windows (`C:/Program Files/Git/home/…`), и ветка
получает FAIL «не исполняемый файл». Там переменную исключают из перевода:

```sh
MSYS2_ENV_CONV_EXCL=FORGE_BASH32 FORGE_BASH32=/home/<user>/b32/bash-3.2.57/bash nvim -l tests/run.lua install
```

Из PowerShell перевода нет: `$env:FORGE_BASH32 = '/home/<user>/b32/bash-3.2.57/bash'`.
Путь Windows в `FORGE_BASH32` раннер распознаёт и пишет эту подсказку в
причине FAIL.

- нет среды (нет `wsl`, в WSL нет дистрибутива, нет git/python3) — SKIP
  всего набора с причиной;
- bash 3.2 — целевой для установщика macOS, поэтому незаданный
  `FORGE_BASH32` (Windows, Linux) — SKIP этой ветки, и ID набора в сводке —
  SKIP, а не PASS; заданный, но неисполняемый — FAIL (ошибка настройки);
- bash из Homebrew на macOS необязателен: нет его — ветки нет;
- ID набора — из строк `Проверка: tests/<набор> (…)`; статус ID — по всем
  веткам: PASS, только если все PASS;
- набор печатает свой каталог вывода `(outputs in /tmp/…)`: после PASS
  раннер его удаляет (иначе каждый прогон и каждый коммит с хуком оставляет
  его в `/tmp`), после FAIL оставляет для разбора — путь в логе и в выводе;
- под `--id` набор запускается, только если его строки `Проверка:` покрывают
  такой ID.

`tests/wezterm-keys.scenarios.sh` (`change-search-enter-accept`,
`fix-windows-mode-modality`) на момент применения этого change не было — он
не зарегистрирован. Когда появится, его регистрируют со своей средой
(«bash + wezterm», на Windows — Git Bash): новое значение `shell` и ветка в
`LAUNCHERS.sh`.

### Python-наборы (`kind = 'py'`): проба через conpty.dll

`tests/wezterm/conpty/chords.test.py` — проба клавиатуры на Windows
(add-nvim-chords-on-windows, WT-KBD-9, WT-KEYS-10). Стенд
`tests/wezterm/conpty/harness.py` поднимает псевдоконсоль из conpty.dll
поставки WezTerm с флагами WezTerm и играет роль терминала; читатели в
`readers/` — nvim, сырой VT-ввод, записи консоли и nvim_forge. Итог —
`chords.fixture.json` (сверка без даты и происхождения; обновить осознанно:
`python tests/wezterm/conpty/chords.test.py --update-fixture`, раскладку —
`--layout ru|en` после ручного переключения). Раннер запускает `python <файл>`
только на Windows; нет python или conpty.dll, другая раскладка — SKIP. Набор
`conpty` идёт по имени или с `--id`, в обычный прогон и хук не входит.

## Как добавить проверку

1. Файл `tests/<…>/<capability>.test.lua` начинается так:

   ```lua
   local r = os.getenv('FORGE_REPO'); r = (r and r ~= '') and r or vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p'):match('^(.*)[/\\]tests[/\\]')
   dofile(r .. '/tests/lib/bootstrap.lua')
   local T = require('check')
   local F = require('fake_wezterm')   -- если нужна подделка

   T.check('WT-CLIP-2 Ctrl+C без выделения уходит в программу как Ctrl+C', function()
     local res = F.load_config({ triple = F.TRIPLES.windows })
     local b = F.find_binding(res.config.keys, 'phys:C', 'CTRL')
     local win = F.window({ selection = '' })
     F.run_callback(b.action, win, F.pane())
     T.eq(win.performed, { { name = 'SendKey', args = { { key = 'c', mods = 'CTRL' } } } })
   end)

   T.finish()
   ```

   `bootstrap.lua` находит корень (`FORGE_REPO`, иначе вверх от файла до
   каталога с `openspec/`) и добавляет в `package.path` `tests/lib/?.lua` и
   `tests/wezterm/?.lua`. `require('bootstrap')` отдаёт `root`, `sandbox`,
   `update_golden`, `wezterm` (путь или nil).
2. Имя каждой проверки начинается с ID требования; одна проверка — один
   сценарий требования.
3. Файл вносится в `tests/registry.lua`.
4. Если проверка описывает известный баг (фаза 1 — код как есть), так и
   пишется. Если проверка по сценарию падает на текущем коде, её не подгоняют:
   `T.skip('<ID> <имя>', 'BASELINE-DIVERGENCE: <что расходится>')`, а
   расхождение уходит в спеку по правилу фазы из `openspec/config.yaml`.

**`tests/lib/check.lua`:**

- `T.check(имя, fn)` — случай в `xpcall`: ошибка — `FAIL` с текстом (трасса —
  в stderr, то есть в лог), следующий случай выполняется;
- `T.skip(имя, причина)`;
- `T.eq(a, b, msg)` — глубокое сравнение (метатаблицы не сравниваются,
  функции — по идентичности) с diff по путям: `.keys[3].mods: получено "CTRL", ожидалось "SHIFT"`;
- `T.ok(cond, msg)`;
- `T.finish()` — итог и код возврата: 1, если был `FAIL`;
- `T.matches(имя, id)` — правило фильтра; `T.new{ out, err, exit, filter }` —
  экземпляр с подставными стоками (самопроверки протокола).

## `--id`

`--id X` берёт ID, равный X или начинающийся с `X-`: `--id WT-CLIP` — вся
capability, `--id WT-CLIP-1` — только WT-CLIP-1. Раннер передаёт фильтр в
`FORGE_TEST_ID`, `check.lua` пропускает остальные случаи. Shell-набор под
`--id` запускается, только если его строки `Проверка:` покрывают такой ID.

Ремонт одного места:

```sh
nvim -l tests/run.lua --id WT-CLIP-2             # одно требование
nvim -l tests/wezterm/fake_wezterm.test.lua      # один файл напрямую
```

## `--update-golden`

Перезаписывает эталоны (`tests/wezterm/golden/`) и фикстуру встроенных
таблиц (`tests/wezterm/fixtures/default_key_tables.lua`). Применять, только
когда изменение поведения осознанное: diff эталона входит в тот же коммит,
что и изменение, и виден на ревью. Чтобы «позеленить» прогон — нельзя;
в `restructure-wezterm-config` — нельзя вовсе.

Фикстуру выгружает обёртка `tests/wezterm/guard.lua` в процессе
`wezterm … show-keys`, и только если `wezterm --version` совпадает с
`tests/wezterm/VERSION`; иначе — SKIP с обеими версиями. Две выгрузки подряд
дают побайтно одинаковый файл: WezTerm отдаёт записи в случайном порядке,
обёртка их сортирует.

## Обёртка `tests/wezterm/guard.lua`

WezTerm 20240203 не показывает ошибку конфига кодом возврата (`show-keys` и
`ls-fonts` выходят с 0). Обёртка работает внутри настоящего WezTerm (Lua 5.4):

```sh
FORGE_CONFIG=<абс. путь к wezterm.lua> FORGE_TARGET=aarch64-apple-darwin \
  wezterm --config-file tests/wezterm/guard.lua show-keys --lua
```

- `FORGE_TARGET` подменяет `wezterm.target_triple` — вид macOS/Linux на Windows;
- ошибка → stderr `FORGE_CONFIG_ERROR: <файл>:<строка>: …`, код 3;
- успех → stderr `FORGE_CONFIG_OK <тройка>`, подкоманда работает дальше;
- `FORGE_DUMP_KEY_TABLES=<путь>` — режим выгрузки фикстуры, затем код 0.

Проверять копию конфига (мутации): копию кладут в `.tests/`, путь — в
`FORGE_CONFIG`. `wezterm.lua` репо не правится.

## Набор `wezterm`: загрузка конфига и снимки

Оба файла работают с настоящим бинарником через `tests/wezterm/real_wezterm.lua`:
HOME, USERPROFILE и XDG — в `.tests/sandbox/wezterm`, у каждого вызова таймаут.
Нет `wezterm` — случаи на бинарнике дают SKIP с причиной, WT-LOAD-11 в сводке
не PASS.

- `config-loading.test.lua` — WT-LOAD-11 (design, решение 7):
  - дословно `wezterm --config-file <репо>/wezterm.lua ls-fonts`: stdout не
    пуст, в stderr нет `ERROR` (на Windows ещё сценарий «stderr пуст»);
  - обёртка для трёх троек: код 0 и маркер `FORGE_CONFIG_OK <тройка>`;
  - сценарии о самом WezTerm, на которых держится способ проверки, — на
    копиях в `.tests/sandbox/wezterm/config-loading/`: сломанный конфиг даёт
    код 0 и молчащий `show-keys`; ошибка синтаксиса, выполнения или нет файла
    дают пустой stdout `ls-fonts` и `ERROR`; нет основного шрифта —
    предупреждение без `ERROR`;
  - `SELF:` обёртка на сломанной копии даёт код 3.
- `snapshot.test.lua` (решение 8) — детектор изменений, а не спека: случаи
  `SNAPSHOT: …` ID не несут и в сводку по ID не входят.
  - `golden/keys.<ОС>.lua` — `show-keys --lua` через обёртку. Буква после
    `phys:` — заглавная (регистр в выводе случаен), `EmitEvent 'user-defined-N'`
    → `Callback`. Сверяется, только если `wezterm --version` =
    `tests/wezterm/VERSION`, иначе SKIP с обеими версиями.
  - `golden/config.<ОС>.lua` — весь `config` из подделки (`env = {}`,
    `files = {}`) и отсортированный список событий `wezterm.on`. Ключи
    отсортированы, привязки `keys` и `key_tables.*` — каноническая пара
    (`F.norm_binding`) и сортировка, колбэк — `{ name = "Callback" }`, функция —
    `"<function>"`. Идёт и без бинарника, и при другой версии.
  - Шапка эталона — происхождение (версия WezTerm, тройка, команда) без путей
    машины; у `config` — версия из шапки фикстуры. Сверяется файл целиком.
    Расхождение — FAIL: первая пара строк — в строке FAIL, unified diff — в
    продолжении и в логе. `--update-golden` пишет эталоны только из
    `wezterm.lua` репо.
- Мутации: обёртка в `.tests/` ставит `require('fake_wezterm').CONFIG_PATH` на
  копию (или `.VERSION` на другую строку) и делает `dofile` файла проверок; в
  раннере — через `--registry` с временным реестром.
- Ограничение песочницы на Windows: `wezterm.home_dir` берётся из профиля
  пользователя, а не из `USERPROFILE`, поэтому `~/.wezterm_forge_window.json`
  владельца читается. Он только читается (разбор под `pcall`), а размер шрифта
  в вывод `show-keys` и `ls-fonts` не попадает, так что на вердикт это не
  влияет.

## Подделка `tests/wezterm/fake_wezterm.lua`

```lua
local F = require('fake_wezterm')
local res = F.load_config({
  triple = F.TRIPLES.windows,            -- windows | macos | linux, обязательно
  env = { PATH = 'C:\\pwsh' },           -- os.getenv; чего нет — nil
  files = { ['C:\\pwsh\\pwsh.exe'] = '' }, -- io.open читает отсюда
  -- необязательно: path = <копия конфига> | source = <текст> (+ chunkname),
  -- home, unwritable = { [путь] = true }, gui = false (без GUI),
  -- screens = <таблица | функция>, default_key_tables = <форма WezTerm>
})
res.config           -- то, что вернул wezterm.lua
res.events[name]     -- обработчики wezterm.on
res.writes[path]     -- что записано через io.open(…, 'w')
res.callbacks        -- action_callback по порядку создания (event = 'user-defined-N', с 0)
res.spawned          -- вызовы mux.spawn_window (окно — F.window)
res.opened, res.getenv, res.calls, res.wezterm
```

- Действия — данные: `act.CopyTo('X')` → `{ name = 'CopyTo', args = { 'X' } }`,
  `act.PopKeyTable` → `{ name = 'PopKeyTable' }`,
  `action_callback(fn)` → `{ name = 'Callback', fn = fn, event = … }`.
  Строку `'PopKeyTable'` в конфиге приводит `F.normalize_action`.
- Встроенные таблицы режимов — из фикстуры, действия приведены к той же форме
  (`F.from_real_action`).
- `F.window{ selection, active_key_table, dimensions, config_overrides,
  effective_config, workspace }` записывает `performed`, `toasts`, `overrides`
  и `override_calls`, `right_status`, `inner_size`, `position`;
  `effective_config()` учитывает overrides. `F.pane{ text, dimensions }`
  записывает `splits`, `activated` и общий журнал `log` семейства панелей.
- `F.find_binding(list, key, mods)` → последняя совпавшая запись (как у
  WezTerm), её индекс и число совпадений. `F.norm_binding(key, mods)` —
  каноническая пара, как её видит WezTerm 20240203: `phys:c` ≡ `phys:C`;
  `Enter` ≡ `Return` ≡ `mapped:\r` (так же Tab, Escape, Backspace, Delete);
  `Space` без префикса — физическая клавиша, `mapped: ` — символ;
  модификаторы — множество (`nil`, `''`, `NONE` равны; `CMD`/`WIN` = `SUPER`,
  `OPT`/`META` = `ALT`); символ-буква с SHIFT — заглавная без SHIFT.
  Наборы пар из подделки совпадают с `show-keys --lua` настоящего бинарника
  для всех таблиц и трёх троек (проверено 2026-09-27).
- `F.run_callback(action, win, pane, …)` — выполнить колбэк.

**Ограничения подделки** (что она НЕ имитирует; это ловит только загрузка
настоящим бинарником через `guard.lua`):

- `config_builder()` — обычная таблица; настоящий падает на неизвестном поле;
- `act.X` — всегда и значение, и конструктор; настоящий `act.PopKeyTable` —
  строка, вызвать её нельзя;
- `wezterm.format` отдаёт элементы, а не строку с escape-последовательностями;
- `json_encode` пишет целые float как `12`, настоящий — `12.0`;
- `os` кроме `getenv` — настоящий; `io` кроме `open`/`lines` — настоящий;
- порядок записей встроенных таблиц — отсортированный, у настоящего — случайный;
- колбэки выполняются под LuaJIT, а не под Lua 5.4.

## LuaJIT (подделка) против Lua 5.4 (WezTerm)

Верхний уровень конфига исполняют оба (подделка и `guard.lua`), колбэки —
только подделка. Конфиг держится в общем подмножестве языка. Проверено на
Neovim 0.12.2 (LuaJIT 2.1) и WezTerm 20240203 (Lua 5.4):

| Конструкция | LuaJIT | Lua 5.4 |
|---|---|---|
| `7 // 2`, `1 & 2`, `local x <const>` | синтаксическая ошибка | работает |
| `string.format('%d', 1.5)` | `1` | ошибка «no integer representation» |
| `tostring(12.0)` | `12` | `12.0` |
| `math.type`, `utf8`, `table.unpack` | нет | есть |
| `unpack`, `setfenv`, `loadstring` | есть | нет |
| `goto` | есть | есть |

Поэтому: `//` и битовые операторы подделка ловит сразу (загрузка падает);
форматирование чисел и `math.type` — только настоящий бинарник.

## Межслойная проверка: ограничение

Сторона nvim_forge (`tests/lib/nvim_keymaps.lua`, WT-KEYS-4/6/7) собирается
в headless nvim без плагинов: буферные привязки, привязки из `LspAttach` и из
`config`-функций плагинов там не видны. Эта часть WT-KEYS-7 — ручная.

Как собирается: отдельный процесс `nvim --clean --headless -i NONE -l
tests/lib/nvim_keymaps.lua --child <корень>` грузит `config.ru_keys.setup()`,
`config.options`, `config.keymaps` (лидер — как в `init.lua`), снимает
`nvim_get_keymap` до и после и читает `keys` из `lua/plugins/*.lua` через
`dofile`. XDG-каталоги, `NVIM_LOG_FILE` и TEMP процесса — в
`.tests/sandbox/nvim`; живой `nvim_forge-data` не трогается (проверка сверяет
`stdpath()` процесса с песочницей). Ошибка загрузки nvim_forge — FAIL, а не
проверка на неполных данных.

Обе стороны приводятся к записи nvim `tests/lib/keynames.lua`: `phys:` — по
раскладке US-ANSI, CTRL/SHIFT/ALT/SUPER → C/S/A/D, каноническая форма — `lhs`
из таблицы привязок nvim (см. «Отклонения от design»).

## SKIP и MANUAL

- SKIP — проверка не выполнялась: нет среды (WezTerm, WSL, bash 3.2), другая
  версия WezTerm, расхождение базовой линии (`BASELINE-DIVERGENCE: …`).
  Причина — в строке. Не PASS.
- MANUAL — исход зависит от кодировщика клавиш WezTerm, ConPTY, IME, буфера
  обмена ОС, оконной системы или отрисовки. Чек-листы `tests/manual/*.md`
  ведёт change `review-baseline` (пункты `### W<n>`/`### M<n>` в разделах
  `## <capability>`, результат — строка `Проверено: <дата>, <ОС>, WezTerm
  <версия>, раскладка <…> — совпало | расходится: …`, последняя — текущий
  статус). Раннер их только читает. Пока файлов нет, MANUAL в сводке нет, и
  раннер пишет это отдельной строкой («Ручных чек-листов нет …»).

## Трассировка (`tests/trace.test.lua`)

```sh
nvim -l tests/run.lua trace                          # на дереве репо
nvim -l tests/trace.test.lua .tests/trace-fixture    # на копии дерева: корень — параметр
```

Логика — `tests/lib/trace.lua` (`collect(root)`), индекс ID —
`tests/lib/spec_index.lua`. Каждое нарушение — отдельный `FAIL` с файлом,
строкой и ID; имена начинаются с `TRACE:`, в сводку по ID не попадают.
Категория без нарушений — одна строка `ok`; категория, где проверять нечего
(нет чек-листов, нет тегов), — SKIP с причиной.

| Что проверяется | Известные ID |
|---|---|
| ID в файлах проверок (`*.test.lua`, `*.sh` в `tests/` и всё из реестра) | спеки + ADDED открытых changes |
| ID в `tests/manual/*.md` | то же |
| ID в тегах `-- spec: …` в `wezterm.lua` (любая область; тег без ID — тоже нарушение) | то же |
| у каждой записи привязки в `wezterm.lua` (строка начинается с `map(`, `mode_map(`, `mode_replace(`) есть тег `-- spec:` | — |
| ID в строках `Спека: …` FIXLOG (в начале строки) | плюс архив changes |
| пути `tests/…` в строках `Проверка:` спек: файл есть и он в реестре | — |
| `вручную (tests/manual/<файл>, <пункт>)`: файл есть, пункт найден | — |
| `*.test.lua` и `*.sh` в `tests/` — в реестре | — |

Самопроверки каркаса `tests/lib/*.test.lua` держат выдуманные ID как данные
разбора (`WT-AA-1`, `WT-CLIPX-1`, мутанты trace) и не сверяются; проверки
требований в `tests/lib/` не кладутся.

`tests/lib/trace.test.lua` — самопроверка trace: копирует то, что trace
читает (`openspec/`, `tests/`, `wezterm.lua`, FIXLOG), в `.tests/trace-fixture/`,
вносит по нарушению каждого вида (тест с `WT-CLIP-99`, тег
`-- spec: WT-XXX-1`, `Проверка: tests/nope.sh`, незарегистрированный
`tests/x.test.lua`, `Спека: WT-CLIP-98`, неизвестный ID и ненайденный пункт
чек-листа) и сверяет: новых нарушений ровно столько, у каждого свой `FAIL` с
файлом и ID, код возврата 1. Копия пересоздаётся при каждом прогоне.

**Теги `-- spec:` в `wezterm.lua`** (restructure-wezterm-config): в конце
строки записи или над группой настроек — `-- spec: WT-CLIP-2` или
`-- spec: WT-CLIP-2, WT-CLIP-5`. ID — требование, чей сценарий описывает эту
клавишу или настройку. Запись привязки (вызов `map(`, `mode_map(`,
`mode_replace(` в начале строки; у записи на несколько строк — тег на первой)
без тега — `FAIL` с номером строки. Код требования:
`grep -n 'spec: <ID>' wezterm.lua`.

## Хук pre-commit (необязательный)

`.githooks/pre-commit` — POSIX sh (Git Bash, macOS): запускает
`nvim -l tests/run.lua`; есть FAIL — коммит останавливается. Нет `nvim` в
PATH — хук падает с подсказкой, а не пропускает молча.

```sh
git config core.hooksPath .githooks      # включить (один раз на машине, в этом клоне)
git config --unset core.hooksPath        # выключить
git commit --no-verify                   # разовый обход
```

- Проверяется рабочее дерево, а не индекс: правки, не добавленные в индекс,
  тоже участвуют.
- На Windows `core.fileMode = false`, и git не запишет бит исполнения сам:
  файл добавляют как `git add --chmod=+x .githooks/pre-commit`, иначе на macOS
  git пропустит хук с подсказкой «not set as executable».
- Хук включает владелец; в репо `core.hooksPath` не выставлен.

## Отчёт и логи

Всё в `.tests/` — производное, в git не попадает (`.gitignore`), удаляется и
пересобирается одной командой:

- `.tests/report.json` — происхождение (HEAD, признак грязного дерева, ОС,
  версии nvim и WezTerm, время, аргументы), вердикты файлов с их строками,
  статус каждого ID, списки из сводки;
- `.tests/logs/<файл>.log` (у веток shell-набора — `<файл>@<ветка>.log`) —
  команда, окружение `FORGE_*`, код возврата, полный stdout и stderr файла;
  перед прогоном старые логи удаляются;
- `.tests/sandbox/` — песочницы (HOME/XDG для настоящего wezterm и т.п.);
- `.tests/trace-fixture/` — копия дерева с нарушениями для самопроверки trace.

## Отклонения от design

- Реестр содержит ещё `tests/lib/spec_index.test.lua` — самопроверки разбора
  спек и чек-листов (чек-листов пока нет, разбор проверяется на образце).
- У раннера есть `--registry <файл>` — для самопроверки правил вердикта.
- Раннер передаёт ещё `FORGE_WEZTERM` и `FORGE_HOST_OS` (энтропия — из
  композиционного корня).
- `load_config` принимает ещё `source`/`chunkname`, `home`, `unwritable`,
  `gui`, `screens`, `default_key_tables`; результат содержит ещё
  `event_handlers`, `opened`, `getenv`, `callbacks`, `calls`, `spawned`, `files`.
- Нормализация клавиш шире design (решение 5): кроме регистра `phys:` и
  множества модификаторов — синонимы клавиш и normalize_shift WezTerm
  (`F.norm_binding`), как у настоящего бинарника.
- Каноническая запись nvim в межслойной проверке (решение 6) — не
  `keytrans(keycode(lhs))`, а `lhs`, под которым nvim хранит привязку
  (keytrans неупрощённых кодов, `KN.canon`). `vim.keycode` упрощает сочетание
  до другой клавиши: `<C-[>` → `<Esc>`, `<C-S-j>` → `<S-NL>`, `<C-j>` → `<NL>`
  (Neovim 0.12.2), и Ctrl+[ из WezTerm совпал бы с привязкой nvim_forge на
  клавишу Esc. Таблица привязок их различает (`<C-[>`, `<C-S-J>`, `<C-J>`).
- Самопроверки `keynames` (`SELF: keynames …`) лежат в
  `tests/wezterm/key-ownership.test.lua`, единственном его пользователе, а не в
  отдельном файле реестра.
- Shell-набор (решение 9): у записи реестра обязательное поле `shell`
  (`posix`); каждая ветка bash — отдельный прогон со своим вердиктом и логом;
  незаданный `FORGE_BASH32` — SKIP ветки (bash 3.2 — целевой для установщика
  macOS), неисполняемый — FAIL; каталог вывода набора после PASS удаляется.
  Опрос WSL — ленивый (только когда выбран shell-набор), но определён в
  композиционном корне `run.lua`. В отчёте — `provenance.posix_env`, в
  итоговой строке — «файлов N (прогонов M)».
- Trace разбит на `tests/lib/trace.lua` (сбор нарушений) и
  `tests/trace.test.lua` (вывод); у сбора два пользователя — trace и его
  самопроверка `tests/lib/trace.test.lua` (набор `trace`, копия дерева в
  `.tests/trace-fixture/`). Самопроверки каркаса `tests/lib/*.test.lua` trace
  не сверяет — в них выдуманные ID как данные.
- Снимок конфигурации (решение 8) нормализует шире «ключи отсортированы,
  функции — метка»: привязки приведены к канонической паре и отсортированы,
  номер `user-defined-N` отброшен, как в снимке `show-keys`. Иначе перестановка
  записей в исходнике (`restructure-wezterm-config`) меняла бы эталон без
  изменения поведения. В шапке `config.*` — версия WezTerm из шапки фикстуры,
  а не `VERSION`: при другой версии бинарника снимок конфигурации сверяется
  как обычно.
- `config-loading.test.lua` кроме решения 7 проверяет сценарии WT-LOAD-11 о
  самом WezTerm (сломанный конфиг, нет файла, нет основного шрифта) и
  самопроверку обёртки. Запуск бинарника общий для двух файлов набора —
  `tests/wezterm/real_wezterm.lua`.
