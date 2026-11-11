# IDE-080 — обзор фич и стоимости поддержки перед рефакторингом

Дата: 2026-11-10. Статус: фактический обзор, coverage/ownership и bounded native
baseline готовы; выбор удаления фич открыт, IDE-082 реализован отдельным change.
Windows/Ubuntu по 27 PASS с реальным gopls restart; Mac gate открыт (§148).
IDE-083 также исправлен отдельным небольшим change: Glance defaults,
по 7 новых + 22 прежних native PASS и по одному project diagnostic (§149).
IDE-084: late Neo-tree cleanup сохраняет фокус, по 3 новых + 23 прежних native
PASS и по 3 cold trace samples Windows/Ubuntu (§150); Mac gate открыт.
IDE-081: optional native fzf/fallback и health, по 30 checks Windows/Ubuntu,
настоящий C scoring без CMake (§151). Единичный qa! → SIGTERM — IDE-085,
причина не установлена, runtime exit fix не заявляется. §152 добавил test-only
quit/native/API-error capture и повторно поймал uninstrumented RED; новые
bounded followup и positive/controlled fixtures не объявляются его исправлением.
[Новая Go metadata/команды](GO_TOOLS.md). Основа обзора —
runtime 7463915 после отмены собственного SQL prototype. Требования не сокращаются
до того, что сейчас легче проверить.

## Цель и правило остановки усложнения

Нужна переносимая клавиатурная IDE для Go/Rust/Python/JS-Node/Bash/SQL:
файлы/поиск, Git/diff/история/ветки/worktree/commit/push, терминал, запуск/debug,
Tests, вкладки и понятный фокус панелей. VS Code — референс возможностей;
Claude Code — понятности управления. Все основные действия доступны без мыши.

Готовый LSP/backend предпочтителен. Свой language server, binder/index или
существенный private fork ради одной строки матрицы не строим. Если готовый
backend не умеет references, это ограничение, а не повод выдавать grep за LSP.
Узкий временный backport с воспроизводимым багом рассматривается отдельно:
тоже имеет цену, source lock, регресс и условие удаления.

Сначала обзор → конкретное решение по фиче/слою → небольшой change с E2E →
рефакторинг/удаление. Во время обзора рабочие плагины и фичи не вырезаются.

## Откуда факты

- `nvim_forge/lua/{config,plugins,ide,forge}` — текущая реализация.
- `nvim_forge/lazy-lock.json` и live Lazy config настоящего тестового Forge:
  по 67 имён, наборы совпали. В idle snapshot загружены 28; это не benchmark
  пользовательского старта и не утверждение, что остальные не используются.
- Live inventory: `.tests/feature-review-runtime.json`, editor artifact
  `3322136536400`, snapshot/config/штатный shutdown. Установок при запуске 0.
  Повторяемая диагностика: `<nvim> -l tests/diagnostics/inspect-plugins.lua`
  после явной подготовки editor-deps; Windows temp variables — как в E2E README.
- Полный список: [PLUGIN_INVENTORY.md](PLUGIN_INVENTORY.md). Не все 67 записей
  самостоятельные фичи: есть библиотеки, bridges и dependency-only plugins.
- DAP/panels: [карта ответственности и следующий порядок](PANEL_OWNERSHIP_REVIEW.md),
  source review и по 9 настоящих E2E Windows/Ubuntu с диагностической трассой.
- Git/workspace/tools/save: [границы ответственности](WORKSPACE_TOOL_REVIEW.md).
  Реальный offline Go probe выявил IDE-082; runtime ещё не менялся.
- [LANGUAGE_MATRIX.md](LANGUAGE_MATRIX.md), [E2E README](../tests/e2e/README.md),
  FIXLOG и source artifacts — фактические проверки. Windows/Ubuntu native UI
  не доказывают Mac/GUI, а unit/trace не заменяют editor E2E.

## Что пользователь получает и чем это обеспечивается

| Возможность | Реализация | Оценка для обзора |
|---|---|---|
| Дерево и операции с файлами | Neo-tree, `ide` controls, lifecycle glue | Ядро. Сохранить keyboard/file/root semantics; убрать лишь доказанные дубли |
| Быстрый поиск имени/контента и replace | Telescope, grug-far | Поиск — ядро. Interactive replace отдельная фича, не просто второй grep |
| Git status/stage/commit/push/ветки/worktree | Neogit + `ide` integration | Ядро. Ошибки/credentials и редкий worktree Permission denied ещё открыты |
| Diff/история/merge | Diffview + Neogit | Проверить границы UI. Наличие двух плагинов не доказывает дублирование сценариев |
| Hunk signs/actions | Gitsigns | Дополняет Git UI; не заменяет commit/worktree/history |
| Language editing | nvim-lspconfig, готовые серверы, cmp, snippets, Treesitter | Ядро. Разделить реальные language semantics и buffer/text completion |
| Форматирование/диагностика | Conform + LSP и языковые tools | Ядро. Проверить необходимость цепочек formatters и единый fallback |
| Run/tasks | Overseer, tasks.json, language glue | Ядро. Generic task и структурированный test runner не одно и то же |
| Debug и Output/Locals | nvim-dap, dap-ui, готовые adapters, `ide.dap`, DAP glue | Ядро; один из главных участков сложности. Сначала карта ownership/lifecycle |
| Tests | Neotest/adapters, общий All/Output, Overseer bridge | Ядро. Не потерять nearest/file/all/debug/output при упрощении |
| Bash/SQL Tests | Собственные публичные Neotest adapters; Bats/SQLLogicTest runner | Отдельно оценить реальную пользу и цену собственного glue/SDK |
| SQL query/schema/results | SQLS forge.1, Sqruff, `forge.sql`, `ide.sql` | Рабочий workflow сохранить. References и procedural debug не готовы |
| Терминал | ToggleTerm + Edgy/общие controls | Ядро. Shell selection и terminal exit требуют отдельной проверки |
| Файловые вкладки/сессии/проекты | Bufferline, persistence, project/start glue | Вкладки — ядро; восстановление/recents оценивать отдельными сценариями |
| Панели/фокус/zoom/help | `ide` registry/state/controls/activities, Edgy | Ядро. Общий Space w — контракт; сначала выяснить, кто владеет окнами |
| Outline/Problems | Aerial, Trouble | Outline явно запрошен. Проверить пересечение дополнительных symbol views |
| Peek/references UI | Glance, Trouble, quickfix/Telescope routes | Кандидат сократить число способов и хоткеев, не language semantics |
| Breadcrumbs | navic + barbecue | Дополнительная навигация; кандидат на отключение по итогам обзора |
| Overview ruler/декор | Satellite, icons, indent guides, theme/statusline | Отдельная цена и ценность. Возможные упрощения, без предположения «всё лишнее» |
| Dashboard/recents | Alpha + start/project/session glue | Дополнительный workflow; сверить с обычным открытием проекта/поиском файлов |
| Autosave | auto-save + events + format guards | Политика редактирования. Нельзя удалять как косметику без оценки save/test/debug |

## Где наслоения заслуживают проверки

| Участок | Наблюдение | Что проверить до изменения |
|---|---|---|
| DAP | `plugins/dap.lua` 1661 строк, плюс `ide.dap`, dap-ui, Output/hover glue | Владение adapter/terminal/output/session, повторные stop/open/focus, launch.json/default/debug tests; готовые plugin APIs против собственных overrides |
| Панели | `ide` 14 файлов/2624 строки, Edgy config 348, panel_guard 267 | Карта open/close/focus/zoom/autocmd и кто исправляет чужое состояние. Не вводить ещё один panel manager |
| LSP | `plugins/lsp.lua` 797 строк + language tool/root/interpreter helpers | Что общее по смыслу, где реальная разница языка/ОС, какие hooks нужны для прежних ошибок |
| Рабочий root | project/session, Neo-tree, Git/worktree и language roots | Кто меняет cwd; один большой resolver не вводить до доказательства одинаковой политики |
| Save/format | autosave events, Conform manual/save, language fallback, LSP checks | Разделить user save и autosave; сохранить асинхронность и запись результата на диск |
| UI-навигация | Outline, breadcrumbs, peek, Trouble/qf, symbol pickers | Одна основная точка входа на действие; вторичные способы оставить только при понятной пользе |
| Language tools | Overrides/PATH/project env/Mason/managed paths | Явные источники и подготовка, без startup install. Не создавать framework резолверов ради структуры |
| Тестовая инфраструктура | RPC UI/process scope, отдельные SDK/tools/контейнеры | Это стоимость разработки, отличная от runtime пользователя. Не записывать её всю в «тормоза редактора» |

Размеры — навигация для чтения, а не доказательство плохого кода. В source
срезе config: 8 файлов/2315 строк, plugins: 19/5878, ide: 14/2624, forge: 18/2005;
сумма 12822 строк включает комментарии. Производительность из LOC не выводится.

## Временные доработки, которые нельзя забыть

| Компонент | Зачем сейчас существует | Условие пересмотра |
|---|---|---|
| Windows Neovim SDK | IDE-027, native ConPTY lifecycle bug | Подтверждённый upstream fix и тот же core/buffer regression на официальном SDK |
| Gitsigns, 2 patch files | IDE-035/038, стабильный cwd Git jobs/worktree | Проверить upstream на закреплённом кандидате, прежние race/worktree E2E |
| Neogit, 2 | IDE-034/043, worktree scheduling и ANSI/title output | Upstream equivalent + worktree/Unicode/error regression |
| Neotest, 4 | IDE-051/070, native/canonical path identity | Upstream equivalent + Node/Python/Rust/SQL discovery/nearest/all |
| nvim-dap, 1 | IDE-053, expected adapter close | Upstream equivalent + normal stop и настоящий unexpected exit |
| neotest-rust, 2 | IDE-054, Cargo workspace/native paths/results | Upstream equivalent + workspace/nearest/integration/debug tests |
| SQLS comments patch | IDE-066, ведущие comments ошибочно выбирали Exec | Upstream equivalent + реальная query с comments/literals/rows |
| SQL protocol adapter | IDE-061, pinned backend coordinates/rename | Смена backend/version + Unicode/первый символ/rename E2E |
| SQLLogicTest SDK/glue | Отдельный SQLite assertion runner и Tests UI | Нужен ли этот workflow в работе; можно ли штатно использовать готовый CLI |

Реестр plugin patches: `nvim_forge/patches/plugins.json` — 5 dependencies,
11 изменяемых файлов. Source review выполнен ниже по exact SHA; native
compatibility regression новых версий ещё нужен. Ни один patch здесь
не объявляется готовым к удалению.

## Конкретные кандидаты для следующего прохода

1. Breadcrumbs navic/barbecue, Satellite, Glance, dashboard/recents — сравнить
   удобство без них, количество отдельных UI и собственных защитных hooks.
   Это кандидаты, а не уже одобренные удаления.
2. Comment.nvim и другие небольшие editor helpers — сравнить со штатными
   возможностями закреплённого Neovim, включая RU/EN mappings и block comments.
3. Neo-tree/Edgy/DAP/ide lifecycle — искать повторное владение окнами и обходы
   соседнего слоя. Переносить код по папкам без уменьшения ответственности не цель.
4. Tools/root/interpreter selection — найти одинаковые политики, а не просто
   одинаковые вызовы exepath. Не объединять venv и Node project resolution вслепую.
5. SQLLogicTest и прочие расширения сверх повседневной работы — оценить пользу
   против SDK/адаптеров/подготовки. Сами SQL query/format/schema не удалять вместе с ними.

## Проверка upstream — 2026-11-10

Default HEAD разрешены через read-only `git ls-remote`; исходники прочитаны
через GitHub connector по конкретным SHA. Сохранены 16 source files и их
hash в `.tests/upstream-review-20261110/manifest.json`. Работающие pins,
SDK и patches не обновлялись. Проверка source не означает, что новые версии
прошли native compatibility regression.

| Компонент | Проверенный upstream | Наблюдение и решение |
|---|---|---|
| Gitsigns | [cmd/repo, ef707fb93301](https://github.com/lewis6991/gitsigns.nvim/blob/ef707fb93301a9b856f36eae4c8f56f5b988a794/lua/gitsigns/git/repo.lua) | Оригинальный context обеих доработок ещё присутствует: cwd зависит от toplevel; stable common-dir варианта нет в этих местах. Снимать patch по одному обновлению нельзя |
| Neogit worktree | [ba2f33b64b99](https://github.com/NeogitOrg/neogit/blob/ba2f33b64b996ff5530c4c45a3c432fb63aaa95b/lua/neogit/popups/worktree/actions.lua) | Файл совпал с исходным unpatched hash; после смены cwd по-прежнему сразу удаляется worktree. Native проверка scheduling нужна до снятия patch |
| Neogit output | [util.lua, ba2f33b64b99](https://github.com/NeogitOrg/neogit/blob/ba2f33b64b996ff5530c4c45a3c432fb63aaa95b/lua/neogit/lib/util.lua) | **Частичное исправление upstream:** continuation byte больше не используется как ANSI prefix. Прямой probe точной pure function сохраняет UTF-8/CSI, но не убирает OSC title/hyperlink. Весь наш output patch снимать рано |
| Neotest | [27bf92149804](https://github.com/nvim-neotest/neotest/blob/27bf921498043f7ecd821d6db68d05de244bbd02/lua/neotest/lib/file/init.lua) | HEAD совпал с pin; все 4 unpatched file SHA совпали с before_sha256. Нового эквивалента наших path fixes в этом срезе нет |
| nvim-dap | [cfa2d58f4537](https://github.com/mfussenegger/nvim-dap/blob/cfa2d58f4537aca6ca83e2de1a0d9f1491121264/lua/dap/session.lua) | Original callback context остаётся: ненулевой adapter exit рассматривается без нашей client-initiated close проверки. Без stop/unexpected-exit E2E patch не снимать |
| neotest-rust | [2c9941d4a358](https://github.com/rouge8/neotest-rust/blob/2c9941d4a358839918fac21d20fc8fef0e1ad05f/lua/neotest-rust/dap.lua) | HEAD совпал с pin; оба unpatched file SHA совпали. Shell/regex обработка Cargo output в этом срезе осталась; native-path/debug тесты нужны при замене адаптера |
| SQLS | [920fde7867c1](https://github.com/sqls-server/sqls/blob/920fde7867c1348f95a55cab3cd63c85b6599840/internal/handler/execute_command.go) | Caller и [classifier](https://github.com/sqls-server/sqls/blob/920fde7867c1348f95a55cab3cd63c85b6599840/internal/database/query_type.go) сохраняют прежнюю работу с leading prefix. Удаление comments patch не подтверждено |
| Neovim Windows | [v0.12.6, 779c36969e31](https://github.com/neovim/neovim/blob/779c36969e31080503be2dfccbcc3f999e289606/src/nvim/os/pty_proc_win.c), [master 0c4b90023dac](https://github.com/neovim/neovim/blob/0c4b90023dac24f42ef24278b22fa357b39d38c6/src/nvim/os/pty_proc_win.c) | В закрытии/resize остаётся исходная последовательность; [ConPTY wrapper](https://github.com/neovim/neovim/blob/779c36969e31080503be2dfccbcc3f999e289606/src/nvim/os/pty_conpty_win.c) обращается к объекту напрямую. Source не подтверждает снятие нашего lifecycle patch; официальный binary v0.12.6 здесь не запускался |

Это не утверждение, что каждая новая версия обязательно воспроизводит старый
баг. Проверенные исходники не дают основания снять все backports разом.
Neogit probe исполнял только точную pure function из закреплённого source,
не весь новый plugin: это ручная source диагностика, а не plugin E2E PASS.

## Проверенный частный вариант UI

Для сравнения создана копия 78 tracked файлов конфигурации на базе 7463915,
добавлен только `lua/plugins/zz_review_optional.lua`: disabled barbecue,
navic, satellite, Glance. Manifest/SHA — `.tests/review-ui-config-20261110.json`.
Рабочая конфигурация и lock не менялись; default 67 pins сохранились.
Windows declarations: 67 → 63, Ubuntu: 66 → 62. Разница в единицу вызвана
условием cmake для native fzf, а не отдельным Linux/Windows конфигом (IDE-081).

| Сценарии без изменения tests | Windows | Ubuntu |
|---|---:|---:|
| Go language: настоящий LSP/format/navigation | 6 PASS | 6 PASS |
| Общие Tests/Search/Tasks panels | 6 PASS | 6 PASS |
| Core editor smoke | 10 PASS | 10 PASS |
| Outline/Aerial и его управление | 6 PASS | 6 PASS |
| Всего | **28 PASS** | **28 PASS** |

Это выбранные core сценарии частного варианта, не полный регресс всех языков,
Git/DAP/GUI и не проверка Mac. Доставку физических клавиш/WezTerm эти RPC
прогоны не заменяют. Docker использовал уже работающий engine; Windows и
Ubuntu выполнялись последовательно, с GOMAXPROCS=2.

### Наблюдения времени/памяти

Три чередующиеся пары Windows на одном SDK/host, отдельные private profiles.
В idle берётся Lazy UIEnter metric (`real_cputime=false`), а при открытии
plain-text fixture — время от RPC input до подтверждённого buffer/filetype.
Это **не пользовательский startup benchmark**: есть driver/UI-attach overhead,
cache effects, всего 3 samples; Go/Rust project load и системные зависания
так не измерены. RSS — один снимок основного процесса, не вся память IDE.

| Наблюдение, медиана | Default | Частный вариант |
|---|---:|---:|
| Idle Lazy UIEnter metric | 856,9 ms | 875,6 ms |
| Idle main-process RSS | 28,32 MiB | 29,18 MiB |
| Loaded plugins idle | 28 | 28 |
| Открытие plain-text fixture, RPC wait | 592,9 ms | 527,2 ms |
| Main-process RSS после открытия | 37,84 MiB | 36,68 MiB |
| Loaded plugins после открытия | 45 | 42 |

При открытом файле baseline действительно загрузил barbecue/navic/satellite,
Glance остался lazy/unloaded. Во всех 12 снимках startup installs=0 и собственные
editor scopes штатно завершились. Idle ускорение не подтверждено; в малом
text fixture различие ограниченное и не объясняет прежние тормоза системы.
Сокращать UI стоит ради понятности и уменьшения hooks/ответственности, без
обещания заметного ускорения работы на всех проектах.

### Варианты для решения по фичам

| Вариант | Что теряется | Что сохраняется |
|---|---|---|
| Оставить Peek, убрать breadcrumbs/ruler | Путь символа над кодом и overview ruler; минус 3 plugins | Outline/Problems, gd/gr, Peek по gpd/gpr, остальное ядро |
| Минимальная вторичная навигация | То же плюс peek-окна gpd/gpr/gpt/gpi; минус 4 plugins | Outline/Problems и обычные LSP переходы/quickfix; этот точный private вариант проверен выше |
| Сохранить весь UI | Фичи не удаляются | Можно сокращать внутренние overrides/дубли после отдельного плана |

Предварительно разумно оставить Peek по запросу и оценить удаление breadcrumbs/
ruler: Glance не создавал фоновой нагрузки в этих снимках, а первые три
активируются при открытии файла и имеют отдельные hooks/ограничения. Это
предложение для выбора UX, не уже выполненное удаление. Вариант из трёх
удалений требует собственного regression перед применением; он не выдаётся
за проверенный по одному сходству с четырьмя. Остальные DAP/Git/tool/root слои
пересматриваются отдельно от этих дополнительных UI.

## Исходный gap: native sorter Telescope — IDE-081

В исходном срезе §144 `plugins/telescope.lua` включает fzf-native при наличии cmake и подавляет ошибку
load_extension через pcall. В Windows test-deps готовой libfzf.dll нет, хотя
plugin отображается загруженным в Lazy. В Ubuntu image cmake нет и plugin
вообще исключён условием. Повторяемая ручная проверка настоящего Forge явно
попыталась загрузить extension: на обеих ОС extension_loaded=false, installs=0.
Обычный picker остаётся работоспособным через Lua fallback.

Это исходная граница покрытия: 67 pins/loaded-флаг и успешный picker сами по
себе не доказывают native acceleration. Исправление §151 сохраняет optional
политику существующего fallback, использует реальную загрузку DLL/SO без
runtime build tools и показывает режим/причину в health. Новый SDK готовится
явно upstream CMake; по 4 editor matrix + 1 native health и 25 integration
checks Windows/Ubuntu, реальные C scores/keyboard/rg/Enter и F5 picker проверены.
Это не benchmark ускорения и не проверка повседневного профиля владельца/Mac.

Результаты: `.tests/review-fzf-windows.json`,
`.tests/ubuntu/review-fzf-ubuntu.json`; artifact 5713543445200 (Windows),
4994315945805 (Ubuntu). Это ручная диагностика capability, не полный native
sorter E2E. При исправлении нужен постоянный regression, а не изменение
ожидаемого loaded-флага ради зелёного теста.

## Реальная coverage карта и границы

Это сопоставление существующего source/реестра и записанных результатов, не
новый полный regression. Общая граница всех строк: Mac и физический GUI/input
здесь не запускались; не превращаем наличие plugin в доказательство функции.

| Пользовательская возможность | Постоянные editor E2E / источник | Что остаётся за границей |
|---|---|---|
| Файлы/дерево, create/rename/move/cut/paste | file-explorer, editor, deleted-files | Разные filesystem/permissions и Mac; неизвестные редкие ошибки отдельно |
| Вкладки/закрытие/reopen, удалённый файл | buffers, deleted-files, native ConPTY/buffer gates | Tabpage/session restore не равен файловым вкладкам |
| Поиск имени/контента/replace panel | search-sorter: native/fallback + health; editor/rg, buffers, work-panels и F5 picker Windows/Ubuntu (§151) | Mac/GUI и полный replace workflow отдельно; native скорость не измерялась |
| Git/hunks/status/diff/history/worktree/commit/local push | git-workflow, git-errors/conflicts, diffview-close, active-worktree, gitsigns/worktree-refresh | Credentials/sequence editor, первый неизвестный IDE-038 handle и GUI |
| Общие panel keys/focus/zoom/help | debug-panels, outline, file-explorer, work-panels, git-workflow; tool-panels:9 native Windows/Ubuntu (§172), [шпаргалка](PANEL_KEYS.md) | Первый async Go Outline focus — IDE-084; Mac/GUI и произвольный tool-only/restore layout отдельно |
| Debug/output/panic/nearest/eval | dap-output, test-runner, language suites, dap-discovery | Не каждый adapter/exception/reopen путь; Bash DAP открыт IDE-057 |
| Go/Rust/Python/Node editing/format/run/debug/tests | go/node/python/rust-language; LANGUAGE_MATRIX с фактическими counts | Monorepo/stdlib/необычные env отдельно; Go passive work — IDE-082 |
| Bash и SQL | bash/sql-language, sql-tests, sql-sdk/sql-test-sdk | SQL references IDE-062 не поддержан готовым backend; внешние DB/Mac, Bash DAP открыты |
| Autosave и explicit async format | language suites, deleted-files, прежний IDE-050 regression | Сложные simultaneous save/edit/cancel не закрывать одним successful format |
| Terminal buffers/jobs/tasks | buffers, work-panels; terminal-escape:6 native (§171); tool-panels:9 native Windows/Ubuntu, source8 RED (§172) | Native escape, common controls, current hide при двух views и job/history проверены; полный create/name/reorder terminal workflow и Mac/GUI отдельно |
| Recent projects/Alpha/persistence | Native TUI quit/restore/A→B→A,3 files/2 tabs/cursors/write/Quickfix (§166); общий focus и legacy winfix/hidden file direct/restart (§167) Windows | [Project/session review](PROJECT_SESSION_REVIEW.md): Ubuntu/Mac, branch sessions/select/last/stop/DAP и failure paths ещё открыты |
| Peek/breadcrumbs/overview ruler | peek-navigation: 7 real gopls keyboard E2E Windows/Ubuntu; diagnostic gpd/navic Use; source/старый private UI вариант | q RED исправлен IDE-083 (§149); ruler markers, Mac и визуальный GUI отдельно |
| WezTerm/shell startup/clipboard | Собственные wezterm/install/ConPTY наборы, manual checklists | Они дополняют Nvim E2E; исходные Mac/zsh/Cmd+C не проверены |

Все названные editor suites присутствуют в tests/registry.lua; diagnostics не
выдаются за постоянный feature regression. Точная языковая полнота —
[LANGUAGE_MATRIX](LANGUAGE_MATRIX.md), границы транспорта/SDK —
[E2E README](../tests/e2e/README.md).

## Ограниченный project/focus/idle baseline

Три свежих native profiles на ОС с одним fixture из go-language: go.mod,
library.go и use.go в каталоге с пробелом/Unicode. Настоящий подготовленный
gopls; GOTOOLCHAIN=local, proxy/offline и private caches. Source/config/pins
одинаковы; Windows и Ubuntu запускались последовательно, CPU Go ограничен 2.
Повторяемая команда — [profile-project.lua](../tests/diagnostics/profile-project.lua).

| Медиана, 3 samples | Windows | Ubuntu |
|---|---|---|
| Driver start, включая копирование SDK/config | 6416 ms | 5040 ms |
| cd + вход в уже выбранный project/Explorer | 1363 ms | 88 ms |
| edit Go → initialized gopls | 3386 ms | 269 ms |
| Первый Outline → символ Use виден | 2435 ms | 240 ms |
| Прямой code/Outline focus, 18 переходов на ОС | 10,3 ms | 3,5 ms |
| Первый gpd → реальный library.go preview | 143 ms | 39 ms |
| RSS только Nvim: idle → project | 28,59 → 50,56 MiB | 26,63 → 44,90 MiB |
| CPU только Nvim за ~1 s idle | 16,0 ms | 17,1 ms |

Это не сравнение скорости ОС и не пользовательский cold startup benchmark:
driver копирует зависимости, Windows fixture на F:, контейнерный runtime на
native Linux filesystem, shared SDK/cache уже подготовлены. Полный restart
при открытии другого проекта не измерялся. Тайминги input/фокуса включают RPC.
RSS/CPU не включают gopls/прочие процессы, WezTerm или систему в целом; одна
секунда и три samples недостаточны для вывода об исходных системных зависаниях.
Lazy startuptime отдельно: Windows median 1380,6 ms с real_cputime=false,
Ubuntu 169,8 ms с real_cputime=true. Это разные часы, их нельзя сравнивать
как одинаковый wall-clock startup показатель.

В 6/6 profiles gpd показывает определение, но q вызывает E21 и оставляет
Glance. Source объясняет IDE-083: семь строковых overrides подменили штатные
function mappings. Default Q не переопределён, закрывает Peek и возвращает код.
Diagnostic сохраняет RED и выходит code=1 после сбора; child editors exit=0,
scopes empty. Успешный сбор данных не выдаётся за работающий keyboard workflow.
Правильное упрощение — убрать лишний mappings override, затем проверить keys
постоянным native E2E, без нового слоя/плагина.

Сразу после первых данных Outline фокус aerial в Windows 3/3, Ubuntu 2/3;
один раз Ubuntu сохранил go. Позднейший прямой Space w a работает. IDE-084
сохраняет investigation: определить устойчивый результат async opening,
а не объявлять мгновенный snapshot доказательством постоянного сбоя. Ранний
pilot ждал focus+symbols вместе; его финальный snapshot не хранит current win,
поэтому прежнее предположение о причине уточняется, а raw timeout сохраняется.

Артефакты Windows 10310785798200/10327577855000/10344309595000;
Ubuntu 9265858326624/9281597222561/9295146798511. В каждом source diagnostic,
78 config sources, snapshots до/после Peek q, LSP manifest, profile/shutdown.
Сводки `.tests/review-project-windows.json`,
`.tests/ubuntu/review-project-ubuntu.json`; audit/метрики —
`.tests/audit-project-review.py`, `.tests/project-review-evidence.json`.

## Рекомендуемый набор и порядок изменений

Решений об удалении пользовательских фич пока нет. Это конкретные предложения
по завершённому фактическому обзору; выбор дополнительных UI ещё открыт.

| Действие | Что сохранить | Что убрать / какой результат проверить |
|---|---|---|
| IDE-082: отложить Delve discovery и сделать Go label пассивным | Настоящий project SDK для language/build/debug и явный toolchain picker | Ненужные subprocess при edit; не запрещать GOTOOLCHAIN глобально |
| IDE-083: вернуть готовые Glance defaults | Peek и его штатные keys | Удалить семь ошибочных overrides; q/Esc/Enter/navigation/splits через native regression |
| IDE-084/086 выполнены Windows/Ubuntu | Первое открытие/focus, output history и PTY lifetime | Late tree cleanup не меняет окно (§150); Output resolver и passive reuse проверены на Windows/Ubuntu (§153), Mac открыт |
| IDE-081 выполнен | Рабочий поиск и optional native/fallback | Реальный load result, explicit artifact preparation, health и regression (§151) |
| Breadcrumbs/ruler | Outline, Problems, gd/gr; Peek по запросу | Рекомендуется убрать barbecue/navic/satellite после выбора UX; вариант без 4 UI уже проверен частно, удаления по 3 требуют своего regression |
| Git/DAP/panel ядро | Gitsigns + Neogit + Diffview, state/registry + DAP UI + Edgy, guard | Сокращать только дублирующие правила, не разные рабочие роли |
| Alpha/project/persistence | Folder/recents/session workflows | Сначала native restart/restore coverage, затем оценка цены удаления/упрощения |
| Comment.nvim и вторичные helpers | Line/block comments и RU/EN keys | Сравнение со штатным Nvim, без потери block/context действий ради минус одного plugin |
| SQLLogicTest | SQL queries/schema/format и Tests остальных языков | Отдельно решить нужность SQL assertion runner/SDK; не удалять рабочий SQL вместе с ним |
| Временные patches/Windows SDK | Проверенные исправления и portability | Снимать только после native equivalent regression на готовом upstream |

IDE-081/082/083/084 реализованы и проверены Windows/Ubuntu (§148–151).
Bounded IDE-085 capture выполнен (§152), причина открыта; далее общий выбор Output.
После каждого свой RED,
permanent E2E, Windows/Ubuntu regression, история и commit. Mac gates явно
остаются открытыми. Выбранные UI-удаления и общий refactor не смешивать с этим
bugfix. Нужного нового LSP/framework из обзора не следует.

## Готовность фактического обзора

Вторая часть ownership review завершена: Git-интерфейсы, выбранный workspace,
language/test roots, interpreter/tools и save/format разобраны в
[WORKSPACE_TOOL_REVIEW](WORKSPACE_TOOL_REVIEW.md). Нельзя объединять эти root
по одинаковому имени. Конкретный новый приоритет — IDE-082: поиск Delve
синхронно запускает Go при edit, Go label тоже может инициировать toolchain work.
Это подтверждено offline native probes, а не гипотезой по числу плагинов.

- [x] Зафиксировать пользовательскую цель и запрет собственного language ядра.
- [x] Снять live inventory и сверить все 67 pins; разделить plugin/dependency/glue.
- [x] Составить карту фич, слоёв и предварительных кандидатов; сохранить ограничения.
- [x] Сопоставить вторичные UI/хоткеи с контролируемыми workflow, показать
  варианты оставить/убрать/заменить и потери. Реальное предпочтение владельца
  и визуальные ruler/GUI проверки остаются отдельными открытыми решениями.
- [x] Проверить upstream source для 5 plugin backports, SQLS и Windows Neovim;
  exact SHA/contexts записаны выше. Native regression новых versions не выполнялся.
- [x] Снять ограниченный startup/current-project/file/focus/idle baseline
  Windows/Ubuntu на одинаковом fixture. Cold restart/GUI/Mac не измерялись,
  исходные системные зависания этим не объяснены; границы и часы указаны выше.
- [x] Сопоставить feature coverage с реальными editor E2E и явными Mac/GUI gaps.
  Для DAP/panels карта готова: PANEL_OWNERSHIP_REVIEW; Go focus/output и первый
  Rust PTY проверены, остальные adapters/restore/физические клавиши разграничены.
- [x] Предложить порядок небольших изменений; у каждого — сохраняемый UX,
  удаляемая ответственность, регресс и проверяемая польза. Только затем рефакторинг.
  DAP-кандидаты: единый выбор Output, затем одинаковые части поиска окна кода;
  process/PTY lifecycle не объединять с видимостью. Это пока план, не runtime fix.
  IDE-081/082/083/084 уже выполнены; capture IDE-085 готов, причина открыта.
  IDE-086 Output policy проверен на Windows/Ubuntu (§153).
  Поиск окна кода разобран: [CODE_WINDOW_REVIEW](CODE_WINDOW_REVIEW.md),
  по 5 native profiles Windows/Ubuntu. IDE-088:22 Windows checks (§156),
  Ubuntu22 checks/16 native profiles повторены2026-11-11 (§170); Mac открыт.
  широкое объединение find/create/relocate отклонено по разным обязанностям.
  Удаления optional UI по-прежнему требуют выбора.
  Project/session restart получил отдельный Windows native baseline §166;
  [границы](PROJECT_SESSION_REVIEW.md). IDE-095 source RED→Windows PASS (§167):
  общий LoadPost вместо второго cleanup/open, необходимый file fallback сохранён.
  Ubuntu native baseline и4 legacy cases также PASS2026-11-11 (§170), Mac открыт.
  Uniform interpreter/root policies ещё требуют отдельных сценариев;
  существующие Git результаты не заменяют их полной проверки.

Принятых удалений рабочих фич пока нет. Termide frames (IDE-076) получили
отдельный opt-in native Locals prototype: [сравнение и ограничения](PANEL_FRAME_REVIEW.md),
§173. Он украшает существующий zoom, включая компактный визуальный образец;
постоянные рамки обычных split ещё не реализованы. Default style прежний,
новый window manager/lifecycle не добавлен. Найденный IDE-101 исправляет
штатный zoom отдельным window-local флагом, без новой layout-обёртки.
Дальнейшие варианты постоянных рамок разобраны по pinned source в
[PANEL_FRAME_DESIGN](PANEL_FRAME_DESIGN.md), §174. Nui уже установлен, но
Popup/Layout добавляет владение окнами; это не бесплатная border-настройка.
Замена Edgy или внедрение shadow panels этим разбором не приняты.
