# IDE-080 — обзор фич и стоимости поддержки перед рефакторингом

Дата: 2026-11-10. Статус: первичная инвентаризация; решения об удалении фич и
рефакторинг ещё не выполнены. Основа — код 341aba2 после удаления собственного
неподключённого SQL references prototype. Требования владельца не сокращаются
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
11 изменяемых файлов. Upstream status на 10 ноября ещё **не перепроверен**;
поэтому ни один patch здесь не объявляется готовым к удалению.

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

## Что должно быть готово до рефакторинга

- [x] Зафиксировать пользовательскую цель и запрет собственного language ядра.
- [x] Снять live inventory и сверить все 67 pins; разделить plugin/dependency/glue.
- [x] Составить карту фич, слоёв и предварительных кандидатов; сохранить ограничения.
- [ ] Проверить использование вторичных UI/хоткеев в повседневных сценариях,
  представить короткий конкретный набор оставить/убрать/заменить с потерями.
- [ ] Перепроверить upstream status и возможность удаления каждого временного patch.
- [ ] Измерить startup/открытие проекта/файла/фокус/idle нагрузку на одинаковых
  fixture проектах. Не приписывать системные зависания терминалу по гипотезе.
- [ ] Сопоставить feature coverage с реальными editor E2E и явными Mac/GUI gaps.
- [ ] Предложить порядок небольших изменений; у каждого — сохраняемый UX,
  удаляемая ответственность, регресс и проверяемая польза. Только затем рефакторинг.

Принятых удалений рабочих фич пока нет. Termide frames (IDE-076) остаются
отдельным будущим прототипом; оформление не должно добавлять ещё один lifecycle.
