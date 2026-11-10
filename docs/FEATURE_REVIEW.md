# IDE-080 — обзор фич и стоимости поддержки перед рефакторингом

Дата: 2026-11-10. Статус: инвентаризация, upstream source review и частное UI
сравнение; решения об удалении фич и рефакторинг ещё не выполнены. Основа —
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

## Найденный gap: native sorter Telescope — IDE-081

`plugins/telescope.lua` включает fzf-native при наличии cmake и подавляет ошибку
load_extension через pcall. В Windows test-deps готовой libfzf.dll нет, хотя
plugin отображается загруженным в Lazy. В Ubuntu image cmake нет и plugin
вообще исключён условием. Повторяемая ручная проверка настоящего Forge явно
попыталась загрузить extension: на обеих ОС extension_loaded=false, installs=0.
Обычный picker остаётся работоспособным через Lua fallback.

Это конкретная граница доказанного покрытия: 67 pins/loaded-флаг и успешный
picker не доказывают native acceleration. Про обычный пользовательский профиль
по тестовому SDK вывод не делается. До изменения следует выбрать mandatory/
optional policy, отделить явную подготовку artifact от runtime условия, показывать
fallback в health и проверять native/fallback ветки отдельно. Исправление и
новая native сборка в рамках review не делались.

Результаты: `.tests/review-fzf-windows.json`,
`.tests/ubuntu/review-fzf-ubuntu.json`; artifact 5713543445200 (Windows),
4994315945805 (Ubuntu). Это ручная диагностика capability, не полный native
sorter E2E. При исправлении нужен постоянный regression, а не изменение
ожидаемого loaded-флага ради зелёного теста.

## Что должно быть готово до рефакторинга

Вторая часть ownership review завершена: Git-интерфейсы, выбранный workspace,
language/test roots, interpreter/tools и save/format разобраны в
[WORKSPACE_TOOL_REVIEW](WORKSPACE_TOOL_REVIEW.md). Нельзя объединять эти root
по одинаковому имени. Конкретный новый приоритет — IDE-082: поиск Delve
синхронно запускает Go при edit, Go label тоже может инициировать toolchain work.
Это подтверждено offline native probes, а не гипотезой по числу плагинов.

- [x] Зафиксировать пользовательскую цель и запрет собственного language ядра.
- [x] Снять live inventory и сверить все 67 pins; разделить plugin/dependency/glue.
- [x] Составить карту фич, слоёв и предварительных кандидатов; сохранить ограничения.
- [ ] Проверить использование вторичных UI/хоткеев в повседневных сценариях,
  представить короткий конкретный набор оставить/убрать/заменить с потерями.
- [x] Проверить upstream source для 5 plugin backports, SQLS и Windows Neovim;
  exact SHA/contexts записаны выше. Native regression новых versions не выполнялся.
- [ ] Измерить startup/открытие проекта/файла/фокус/idle нагрузку на одинаковых
  fixture проектах. Не приписывать системные зависания терминалу по гипотезе.
  Первые idle/text-buffer samples выше; project load/focus/остальные ОС ещё открыты.
- [ ] Сопоставить feature coverage с реальными editor E2E и явными Mac/GUI gaps.
  Для DAP/panels карта готова: PANEL_OWNERSHIP_REVIEW; Go focus/output и первый
  Rust PTY проверены, остальные adapters/restore/физические клавиши разграничены.
- [ ] Предложить порядок небольших изменений; у каждого — сохраняемый UX,
  удаляемая ответственность, регресс и проверяемая польза. Только затем рефакторинг.
  DAP-кандидаты: единый выбор Output, затем одинаковые части поиска окна кода;
  process/PTY lifecycle не объединять с видимостью. Это пока план, не runtime fix.
  До них стоит IDE-082; дальше IDE-081 readiness и выбранные удаления optional UI.
  Project/session restart и uniform interpreter/root policies требуют отдельных
  сценариев; существующие Git результаты не заменяют их полной проверки.

Принятых удалений рабочих фич пока нет. Termide frames (IDE-076) остаются
отдельным будущим прототипом; оформление не должно добавлять ещё один lifecycle.
