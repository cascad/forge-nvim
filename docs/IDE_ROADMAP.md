# nvim_forge — рабочий план мини-IDE

Обновлено: 2026-11-10. Основная сборка: **nvim_forge**.
Статус: базовые e2e настоящего nvim_forge работают на Windows и Ubuntu;
фоновые установки инструментов редактора перенесены в явный setup.
IDE-001 параллельно ждёт диагностических данных с Mac.

## Ближайший маршрут — 2026-11-10

| Порядок | Работа | Результат и граница |
|---|---|---|
| Готово | IDE-043: читаемые ошибки Git | Коммит 5e4dfe8; OSC/title удалены, пользовательские Git E2E Windows/Ubuntu прошли |
| Готово | Test-only cleanup IDE-047 | Коммит fa33150, E2E и §107; причина первичного RPC остаётся отдельной диагностикой |
| Готово | IDE-041: E339 на очень длинном слове | Общая защита, по 3 UI + 10 smoke PASS Windows/Ubuntu; §108 |
| Готово | IDE-009: основные рабочие панели | Tests/Test Output/Search/Tasks в Space w, query сохранён, по 6 новых + 19 прежних UI PASS Windows/Ubuntu; §109 |
| Готово Windows/Ubuntu | Go LSP/format и IDE-050 | По 6 language UI PASS, fallback исправлен (§110); Ubuntu image/прогон выполнены, Mac открыт |
| Готово на Windows | JS/Node и IDE-051 | 8 новых UI PASS: LSP/Prettier/Tasks/js-debug/Jest и missing tools (§111). Ubuntu 8 UI PASS после build, Mac открыт |
| Готово на Windows | Python, IDE-052/053 | 8 real UI PASS: venv/LSP/Ruff/debugpy/pytest; общий selector и классификация ожидаемого adapter close (§112–113). 29 прежних UI PASS; Ubuntu language workflow также проверен; Mac открыт |
| Готово на Windows | Rust/Cargo, IDE-054/055 | 8 real UI PASS; пути/argv/JSON test adapter и output исправлены (§114–115), 37 прежних UI + 9 backports + 364 checks PASS; [команды](RUST_WORKFLOW.md). Ubuntu language workflow также проверен; Mac открыт |
| Готово на Windows | Bash edit/run/tests, IDE-056/058 | 8 real UI PASS: sourced LSP, shfmt, Tasks и Bats; Unicode rename исправлен (§116–117). [Команды](BASH_WORKFLOW.md). Ubuntu language workflow также проверен; Mac открыт |
| Готово на Windows | SQL editor/query, IDE-060/061/063–068 | 20 SQL UI + 2 SDK CLI PASS, native SQLS comments fix/readiness и cache Results при смене workspace (§119–128); 6 common panel UI и 365 unit/trace PASS. Прежние 72 UI/9 backports сохранены как отдельный прогон. Ubuntu 20 SQL UI/2 SDK также PASS; Mac/ARM64/внешние DB не проверены |
| Готово на Windows | IDE-062: SQLLogicTest в Tests | 12 native SDK checks и 12 editor UI PASS (§129–132): nearest/file/all, expected/fix/rerun, stop/output/panels; общий All и native paths исправлены. [Команды](SQL_TESTS.md). Ubuntu 12 SDK/12 UI PASS; Mac открыт |
| Готово на Windows | IDE-075: lifecycle и Windows integration gate | Собственный process scope, 5 новых native E2E и 4 source RED; 111 checks PASS/2 POSIX SKIP, 365 unit/trace, 64 strict valid (§136). Ubuntu/Mac и причины IDE-073/074 открыты |
| Готово Windows/Ubuntu | IDE-077/078/079: process lifecycle и observers | Ubuntu 119 PASS/1 Windows-only SKIP, 365 unit/trace; Windows 27 текущих checks PASS (§137–139). Product Lua/67 pins прежние; Mac/GUI открыты |
| Обзор готов, выбор удалений открыт | IDE-080: фичи, слои, цена и coverage | [Общий обзор/рекомендации](FEATURE_REVIEW.md), [все 67 plugins](PLUGIN_INVENTORY.md), DAP/root/tool ownership и bounded native baseline. Большой переписи нет; UX-удаления ещё не выбраны |
| Следующий конкретный change | IDE-082, затем IDE-083 | Убрать ненужную Go/Delve work при edit и неправильный Glance mappings override. Постоянный native RED/regression, сохранённые language/debug/tests; IDE-084 — отдельная проверка первого Outline focus |
| Отложено до готового backend | Остаток SQL workflow, IDE-062 | SQLS references provider отсутствует. Собственный binder/index/LSP fork отменён (§143); не подменять references grep и не объявлять полную SQL поддержку |
| Затем | Остальная [матрица языков](LANGUAGE_MATRIX.md) | SQL references IDE-062, Bash DAP IDE-057; Mac/native и оставшиеся сценарии матрицы |
| После функциональной матрицы | Упрощение архитектуры | Общее ядро, явные системные границы и setup; сокращение дублирования с сохранением E2E |

**Mac параллельно:** IDE-001 (zsh/Go до запуска nvim) и IDE-002 (Cmd+C)
ждут измерений/GUI на Mac. Сборщик startup готов; после trace исправляется
конкретный инициатор. Windows и Ubuntu не заменяют такую проверку.

SQL Tests Windows шаг сохранён в `eeae06c`; IDE-075 и его Windows regression
gate завершены (§136). [Process lifecycle](../openspec/changes/fix-editor-descendant-lifetime/tasks.md)
имеет 5/7 задач: Ubuntu часть проверена, Mac/native platform verification остаётся открытой.
Работа возобновлена; текущее уточнение владельца — IDE-080 review до рефакторинга.
IDE-073/074 остаются отдельно. Доступные Ubuntu проверки используют уже
запущенный engine без управления Desktop/WSL.

IDE-080, следующий срез: upstream source/backports проверены по exact SHA,
частный вариант без четырёх secondary UI plugins прошёл по 28 core UI E2E
Windows/Ubuntu. Idle/text-buffer snapshots не являются общим startup benchmark;
рабочие фичи пока не удалены, выбор UI ещё обсуждается. Native fzf readiness
выделен в IDE-081: loaded-флаг и рабочий picker не доказывают native sorter.

DAP/panels разобраны в [карте ответственности](PANEL_OWNERSHIP_REVIEW.md):
по 9 неизменённых native E2E Windows/Ubuntu с trace; repeated show не равен
recreate. Кандидаты — единая политика Output и совпадающие части поиска окна
кода. PTY/session cleanup остаётся отдельной ответственностью. Runtime не
переписывался; выбор вторичных UI и оставшаяся часть общего review открыты.

Git/workspace/tools/save разобраны в [WORKSPACE_TOOL_REVIEW](WORKSPACE_TOOL_REVIEW.md).
Выявлен IDE-082: до debug запускаются синхронные Go env для Delve, а статуслайн
запрашивает go version; auto toolchain work подтверждён offline Windows/Ubuntu.
После review это приоритетный небольшой fix с RED и Go language/debug/tests.
Глобально запрещать GOTOOLCHAIN=auto или переписывать готовый LSP не планируется;
исходная задержка zsh до nvim на Mac этим не объяснена.

Фактическая часть большого review сведена в FEATURE_REVIEW (§147): coverage
всего ядра/явные gaps, 3 project/focus/idle samples на Windows и Ubuntu.
Peek q остаётся RED 6/6 (IDE-083); default Q завершает cleanup, native scopes
пусты. Решение о breadcrumbs/ruler/Peek не подменяется тишиной; defaults пока
прежние. Следующая работа — небольшие отдельные bug changes IDE-082/083,
после них проверка первого Outline focus и остальной согласованный порядок.

SQL references — [отдельный change](../openspec/changes/add-sql-semantic-references/tasks.md):
§142 сохраняет исходный RED и исследование собственного resolver. Этот подход
отменён (§143): не строить своё language ядро ради полноты матрицы. SDK forge.1
и прежний workflow сохранены. Возвращаться к интеграции только после выбора
готового поддерживаемого backend; IDE-062/IDE-SQL-9 остаются открытыми.

**Ограничение текущего шага:** полный Ubuntu IDE-047 — 43 PASS/1 FAIL/3 SKIP,
653 checks. Cleanup/процессные проверки прошли; новый FAIL ожидания Git-read
зарегистрирован IDE-048. Он не становится PASS и не объявляется исправлением
IDE-047. Повторные full без нового изменения/доказательства не запускаются.
Сначала завершается текущий проверенный шаг, самостоятельные проблемы получают
свои ID/воспроизведение и явный приоритет; объём шага не расширяется молча.

Для каждого исправления остаются обязательными воспроизведение, постоянный
регресс, применимые ОС, история и честный результат PASS/FAIL/SKIP.

## Цель и принятые решения

Терминальная мини-IDE для Go, Rust, Python, JS/Node.js, Bash и SQL.
Активные целевые среды: **Windows, macOS и Ubuntu**. Mint временно отложен.
VS Code — референс возможностей; Claude Code — референс понятного
клавиатурного взаимодействия. Все основные действия доступны без мыши;
мышь остаётся дополнительным способом управления.

- Развиваем существующий `nvim_forge`, без пересборки с нуля.
- `nvim_astro` и `nvim-ide` остаются экспериментами; переносить туда работу
  или удалять их в рамках этого плана не требуется.
- Повседневный запуск shell и редактора отделяем от установки и обновления.
- Для каждого инструмента определяем один основной источник и явные исключения.
- Общая логика IDE едина; системные различия — на границах shell/process,
  путей, clipboard и установки. [Архитектурный план](PORTABLE_ARCHITECTURE.md).
- Каждая фича и каждый исправленный баг получают e2e. Владелец запускает
  VM нужных ОС; репозиторий обеспечивает простые команды и отчёт. [Подход и
  матрица покрытия](../tests/e2e/README.md). Unit не заменяют e2e.
- Основной объект e2e — **редактор nvim_forge с реальными плагинами и
  проектами**, включая файлы, окна, LSP, completion, DAP, тесты и Git.
  WezTerm — отдельная граница ввода/GUI/clipboard, а не замена e2e редактора.
- Сначала устраняем задержки и потерю вывода, затем выравниваем UX,
  расширяем языки и только после этого сокращаем архитектурную сложность.

## Как ведём работу

Это основной маршрут работ, а не описание уже реализованного поведения.
Старый `docs/PANELS_PLAN.md` — контекст прежних решений по панелям.

- Новая жалоба получает стабильный ID `IDE-xxx` в [PROBLEMS.md](../PROBLEMS.md).
  Там хранятся исходный симптом, воспроизведение и ожидаемое поведение.
- Здесь ведём приоритет, этап и критерий завершения. Новые проблемы можно
  добавлять по ходу работы; срочные регрессии поднимаем выше расширений.
- Для изменения поведения используем отдельный OpenSpec change по правилам
  `CLAUDE.md`; существующие changes сначала проверяем на пересечение.
  Сам этот план не означает, что все перечисленные изменения реализованы.
- Завершение: воспроизведение → причина → исправление → подходящая проверка
  → docs/FIXLOG → ссылка из инбокса. Не закрываем проблему по одному наличию кода.
- У каждого исправления история: **что было → причина → что сделали →
  проверка/e2e → вывод**. Шаблон — [ENTRY_TEMPLATE.md](history/ENTRY_TEMPLATE.md),
  единая хронология — [HISTORY.md](HISTORY.md). Исторические источники из
  прежнего workspace хранятся в `docs/history/legacy`, планы и гипотезы
  сохраняют свой статус и не становятся доказанными исправлениями.
- Автоматические проверки выполняем в репозитории. Результаты, зависящие от
  macOS/GUI, записываем после реальной проверки на Mac, отдельно от Windows.

## Очередь пользовательских проблем

| ID | Приоритет | Симптом / пожелание | Этап | Состояние |
|---|---|---|---|---|
| IDE-001 | P0 | WezTerm: медленные вкладки/clear, повторная загрузка Go 1.26.0 | 1 | Подготовлен пассивный сборщик; нужен отчёт/trace с Mac |
| IDE-002 | P1 | Cmd+C на Mac продолжает не работать | 2 | Повторное воспроизведение поверх прежнего исправления |
| IDE-003 | P1 | При повторном запуске DAP пропало окно вывода | 2 | Go remote/integrated и ранний вывод исправлены; E2E Win/Ubuntu, исходный конфиг/Mac/прочие адаптеры открыты |
| IDE-004 | P1 | После остановки на panic нужен текст ошибки в Output | 2 | Go panic на паузе исправлен; E2E Win/Ubuntu, Mac/прочие адаптеры открыты |
| IDE-005 | P2 | Как перевести фокус в Locals и DAP Output | 3 | Space w d/c/0, индикатор и помощь; real DAP E2E Win/Ubuntu, Mac/GUI открыт (§74) |
| IDE-006 | P2 | Запуск теста под курсором оставляет «No active session» поверх кода | 2 | Go nearest/file/debug и eval исправлены, E2E Win/Ubuntu; исходный Mac/Python/Rust открыты |
| IDE-007 | P2 | Ручной ввод должен сбрасывать неактивный предлагаемый хвост сигнатуры | 2 | Исправлены параметры LuaSnip; 11 E2E Win/Ubuntu, Mac ещё не проверен (§71) |
| IDE-008 | P2 | Outline в левой панели, как в VS Code | 3 | Общий маршрут, единый модуль и 6 E2E Windows/Ubuntu (§76–77); Mac/GUI открыты |
| IDE-009 | P2 | Единое понятное управление фокусом и действиями панелей | 3 | Debug/Outline/Files/Git/Tests/Test Output/Search/Tasks подключены, E2E Windows/Ubuntu; Mac/GUI и terminal/Trouble отдельно (§74–109) |
| IDE-010 | Сквозной | Универсальная сборка Windows/macOS/Ubuntu; Mint позже | Все | Границы модулей записаны; runtime ещё не переработан |
| IDE-011 | Сквозной | E2E каждой фичи/бага, простые команды для VM | Все | CLI и базовый editor e2e готовы на Win/Ubuntu; Mac и полная матрица открыты |
| IDE-012 | P2 | Отсутствующий codelldb предупреждает уже при открытии Go | 2 | Проверка перенесена на запуск; 3 E2E Windows/Ubuntu, Mac открыт (§72) |
| IDE-013 | P2 | Windows Starship: Git timeout при первом prompt в cs2d | 1 | Лимит 500 мс, повторные WARN подавляются; тёплый замер 212–223 мс, причина первого превышения открыта |
| IDE-014 | P2 | Satellite: Invalid height при закрытии debug-панелей | 3 | Актуальные DAP FT исключены, real UI E2E Win/Ubuntu (§75) |
| IDE-015 | P2 | Neo-tree: follow на закрытом буфере и позднее открытие | 3 | События жизненного цикла согласованы, real editor E2E (§77) |
| IDE-016 | P2 | Файловые операции и общий маршрут дерева | 3 | 7 real Neo-tree E2E, selector/источники и буферы (§78) |
| IDE-017 | P2 | Move повторно добавляет каталог к полному пути | 3 | Штатный absolute input, регресс на диске (§79) |
| IDE-018 | P2 | Отложенный reveal использует путь до rename | 3 | Одно открытие/reveal, ожидание готового renderer (§80) |
| IDE-019 | P2 | Enter/rename из zoom используют прежнюю строку | 3 | Выбор переносится после WinEnter, real E2E (§81) |
| IDE-020 | P2 | Esc иногда оставляет фокус в дереве | 3 | Удалён конфликт <esc>/<Esc>, runtime-regression и 5 циклов (§82) |
| IDE-021 | P2 | Удобные файловые вкладки/выбор/закрытие/reopen | 3 | Общая модель и 8 real editor E2E (§83) |
| IDE-022 | P1 | Закрытие dirty файла меняет окна и запускает autosave до решения | 3 | Confirm до мутаций, защита autosave/Save/Discard/Cancel (§84) |
| IDE-023 | P2 | Ctrl-\ из native terminal открывает ToggleTerm | 3 | Открыто для terminal/jobs; F7 проверен, Esc Esc — normal |
| IDE-050 | P2 | Common trim блокирует LSP форматирование без внешних tools | 4 | Общая политика исправлена; RED/6 language UI PASS Windows (§110), Ubuntu/Mac ещё не проверены |

P0 мешает базовой работе; P1 ломает основной сценарий; P2 — поведение и UX,
которые последовательно доводим после критических проблем.

## Этап 0. Зафиксировать основу

- [x] Выбрать `nvim_forge` основной сборкой.
- [x] Разделить старую копию `F:/claude_code/vim/nvim` и актуальный проект
  `F:/repo/forge-nvim`; новые работы вести во втором.
- [x] Записать маршрут, пользовательские проблемы и критерии завершения.
- [ ] Сверить версию/commit и путь реально загруженного конфига на Mac.

## Этап 0.5. Базовый e2e настоящего nvim_forge

Общие команды, Ubuntu-контейнер и минимальный набор самого редактора работают.
10 случаев editor.test.lua пройдены на Windows native и Ubuntu Docker;
Mac остаётся непроверенным. Дальше растим покрытие с задачами этапов 1–6.

- [x] Запускать отдельный настоящий Neovim с `nvim_forge/init.lua`, pinned
  плагинами и изолированными data/state/cache/HOME. Подготовка зависимостей
  — отдельный воспроизводимый шаг; тестовый запуск не скачивает их скрыто.
- [x] Подключить управление и настоящий UI через RPC; пользовательские
  команды и mappings проверять вводом, проходить UIEnter/VeryLazy.
- [x] Базовый набор: запуск сборки без ошибок; открыть/изменить/сохранить файл;
  открыть дерево и выбрать файл; поиск имени/содержимого и переход к результату;
  сменить/закрыть буфер; перевести фокус между кодом и панелью и вернуть его.
- [x] Проверять содержимое файла, активный буфер, видимость/принадлежность окон,
  состояние редактора и ошибки процесса. При падении сохранять logs и состояние;
  ожидать готовности по условию с deadline.
- [x] Прогнать этот один набор Windows native / Ubuntu Docker.
- [ ] Прогнать на Mac теми же командами на машине владельца.
- [ ] Подключить PTY/ConPTY для доставки терминальных клавиш; GUI WezTerm — отдельно.

Готово, когда стартует именно наша сборка и базовые пользовательские действия
проходят без mock-подмены плагинов. Подготовка runner и CLI-тесты этот этап не
закрывают. Блокировку подготовки/запуска фиксируем как дефект с воспроизведением.

## Этап 1. Быстрый и предсказуемый запуск

Во всех этапах: сначала воспроизводимый e2e сценарий; после исправления —
регрессионный тест и результат в применимых целевых средах. Непроверенное
на VM не закрываем наличием mock/unit-проверки.

- [ ] IDE-001: отделить запуск WezTerm, shell, prompt/hooks, `clear` и Neovim.
  Инструкция: [MACOS_STARTUP_DIAGNOSTICS.md](MACOS_STARTUP_DIAGNOSTICS.md).
- [x] Подготовить сборщик сведений одной командой без запуска Go/shell;
  проверки на временных HOME и интеграция в unit-прогон.
- [ ] Найти конкретную команду, файл и hook, вызывающий Go на Mac.
  Проверить `GOTOOLCHAIN`, `GOSUMDB`, пользовательский GOENV, `go.mod/go.work`,
  повторный `source`, shell-плагины и prompt. Пока это кандидаты, не диагноз.
- [ ] Убрать установку/сетевые проверки из shell startup и prompt.
- [x] Перенести автоматическую установку инструментов Neovim в явный setup/update.
  Убраны таймер mason-tool-installer, автоустановка Treesitter и неявный
  registry refresh mason-lspconfig. IDE-BOOT-1: Windows/Ubuntu PASS; Mac — ниже.
- [ ] Подтвердить пассивный старт редактора на Mac: тот же editor e2e.
- [ ] Проверки версии для UI сделать пассивными: не скачивают SDK и не
  блокируют ввод. Различать установленный Go и требование текущего проекта.
- [ ] Составить таблицу инструмент → источник → версия/политика обновления →
  проверка; убрать конкурирующие установки, сохранив нужные fallback явно.
- [ ] Снять время до/после: новая вкладка, первый prompt, Enter, clear, старт nvim.

Готово, когда при обычном открытии вкладок, Enter, clear и старте редактора
нет неожиданных установок/скачиваний; команды-инициаторы найдены, изменение
проверено на Mac и задержка измерена. Целевой бюджет выберем после замеров.
Сборка/тест/дебаг проекта, которому нужен другой SDK, показывают понятное
требование вместо скрытого скачивания из UI. Не отключаем `GOSUMDB` и не
меняем глобально настройки корпоративной сети ради маскировки симптома.

## Этап 2. Надёжность повседневной работы

- [ ] IDE-002: воспроизвести Cmd+C отдельно в shell, при выделении WezTerm,
  в copy mode и при Visual-выделении Neovim; английская и русская раскладки.
  Проверить реально загруженный конфиг и прежний change
  `fix-copy-clobbers-clipboard`. Выделение терминала и выделение редактора
  учитывать как разные источники текста.
- [x] IDE-003/004, Go/Delve: реальный E2E первого/повторного запуска,
  stdout/stderr, remote + integratedTerminal, ранний output, скрытие панелей,
  panic на паузе и после выхода. Вывод сохраняется до нового initialize.
  Windows/Ubuntu PASS, FIXLOG §64–66.
- [ ] IDE-003/004: сверить исходный конфиг владельца, прогнать Mac и отдельно
  Python/debugpy и Rust/codelldb с их каналами stdout/stderr/PTY.
- [x] IDE-006, Go: ближайший успешный/падающий тест, весь файл, debug nearest
  на настоящем Delve, eval 42, отсутствие пустого eval без paused-сессии,
  Esc/q из float и Esc из кода. Windows/Ubuntu E2E, FIXLOG §68–70.
- [ ] IDE-006: исходная последовательность на Mac и Python/Rust. Debug Go
  показывает итог в REPL, neotest оставляет skipped — это отдельное ограничение.
- [x] IDE-007: параметры LuaSnip после настоящего completion; manual вне поля
  отменяет только нетронутые параметры, ввод/Tab/Shift-Tab/Esc/undo сохранены.
  11 E2E Windows/Ubuntu, включая Unicode, multiline и разные буферы (§71).
- [ ] IDE-007: Mac и реальные ответы completion языковых серверов — отдельно
  от уже проверенной общей cmp/LuaSnip цепочки и механизма параметров.
- [x] IDE-012: искать codelldb при запуске его конфигурации; Go/F9 без чужого
  предупреждения, F5 без binary даёт понятный WARN, повтор и код доступны.
  3 E2E Windows/Ubuntu (§72); Mac и positive Rust/C/C++ DAP открыты.
- [ ] Проверить Go/Rust/Python: breakpoint → шаг → variables → output → stop
  → повторный запуск. Для каждого адаптера свой источник вывода и проверки.

Готово, когда каждую исходную жалобу можно воспроизвести до исправления и
показать корректный результат после него; проверенные платформы записаны.

## Этап 3. Единая клавиатурная модель панелей

- [ ] IDE-076: рамки и заголовки панелей по образцу Termide. Исследовать
  [референс](https://github.com/termide/termide/blob/main/doc/en/architecture.md),
  ограничения Neovim split и Edgy/winbar/statusline; сделать прототип одной
  панели, сравнить активную/неактивную рамку и title. Затем решить, применять
  ли ко всем панелям. Сохранить Space w, zoom/resize, рабочую площадь и
  Windows/macOS/Ubuntu; реализация требует UI E2E и visual/GUI проверки.

Первый пилот — **Run & Debug**: он сразу проверяет переходы между кодом,
Locals, стеком и Output. После проверки переносим модель на Outline,
файлы, тесты, Git, поиск и задачи.

Run & Debug, Outline и Neo-tree используют Space w; остальные панели подключаются далее.
Normal mode, прежние aliases сохранены:

| Действие | Ожидаемое поведение |
|---|---|
| `Space w h/j/k/l` | Фокус в соседнюю видимую область; нет соседа — безопасный no-op |
| `Space w d/c/0` | Locals / Output / код |
| `Space w a` | Открыть/сфокусировать Outline слева |
| `Space w e` | Открыть/сфокусировать Files слева |
| `Space w g` | Открыть/сфокусировать Neogit справа |
| `j/k` или стрелки в списке | Перемещение по элементам |
| `Enter` | Основное действие выбранного элемента |
| Действия дерева | Пока штатные действия backend; новые h/l без prefix не вводились |
| `Esc` | Отменить локальный ввод/выбор или закрыть временное окно |
| `q` в обычной tool-панели | Спрятать панель, вернуть фокус в код; не завершать DAP/job |
| `Space w z` | Тот же буфер Debug/Outline/Neo-tree/Git в увеличенном overlay / исходное окно |
| `?` | Краткая подсказка по действиям текущей панели |

Принцип: отдельно перемещение фокуса, выбор элемента и изменение раскладки.
Смена фокуса никогда не запускает/продолжает отладку, не убивает процесс и
не очищает вывод. В REPL, терминале и строках ввода печатные клавиши остаются
вводом текста; команды панели действуют после выхода в normal либо через
безопасную общую комбинацию. `Esc` не обязан закрывать постоянную панель.

- [x] IDE-005/009, пилот Debug: выбран Space w, проверены конфликты normal
  mappings, ru/en RPC input, Locals/Output/code, q/Esc/help/zoom (§74).
- [x] Debug: индикатор [focus] и контекстная помощь; прежние aliases сохранены.
- [ ] Mac/GUI и физическая доставка ru/en; PTY Rust/Python. Печатный ввод
  в insert/terminal сохраняется, prefix используется после перехода в normal.
- [x] Outline: общий фокус/help/hide/zoom и переход Enter; 6 real Aerial E2E (§76–77).
- [x] Дерево: общий маршрут, selector/источники, создание/rename/move/cut-paste,
  отмена/конфликт и сохранённые буферы; 7 E2E (§78–81).
- [x] Git status: общий маршрут Space w g, q/Esc/help/zoom (§85).
- [x] Tests/Test Output/Tasks/Search: Space w t/r/b/f, focus/hide/help/zoom,
  query/results/jobs сохраняются; 6 новых E2E Windows/Ubuntu (§109).
  Общая шпаргалка показывает один основной маршрут, aliases m*/p*/P*/D* сохранены.
- [ ] Terminal/Trouble: оставшиеся локальные controls и E2E; IDE-023 отдельно.
- [x] IDE-008 Windows/Ubuntu: открыть слева, найти/раскрыть символ, перейти
  в код, скрыть/вернуть фокус; дерево и Outline заменяют друг друга в left-слоте.
- [ ] IDE-008 Mac/GUI: тот же сценарий на машине владельца.
- [ ] Дерево: Mac/GUI, несохранённые буферы, отдельные copy/delete/trash,
  case-only rename/cross-volume и LSP file operations — расширение матрицы.
- [x] Windows/Ubuntu, буферы/вкладки: общий цикл/picker/BufferLine, safe-close,
  alpha/reopen с курсором; 8 E2E (§83–84). Tabpages/WezTerm не меняются.
- [ ] Буферы: Mac/GUI и физические модифицированные сочетания; Save As dialog
  для unnamed, persistent reopen/session и Git/Diffview матрица отдельно.
- [ ] Одна краткая шпаргалка; основные действия находятся без чтения Lua.

Готово, когда один и тот же сценарий управления проходит без мыши во всех
основных панелях, включая паузу DAP и работающий терминал.

## Этап 4. Языки

Первичная [матрица кода и покрытия](LANGUAGE_MATRIX.md) снята 2026-11-02;
текущие Windows результаты Go/Node/Python/Rust/Bash обновлены в ней отдельно.
Подсветка и общие buffer completion/trim/tasks не считаются готовностью IDE
языка. SQL, Bash DAP и непроверенные целевые ОС сохраняют открытые задачи.

- [x] Первичный аудит конфигурации и покрытия шести языков, без новых PASS.
- [x] Go LSP/format Windows: definition/references/rename/completion/diagnostics,
  внешний/LSP formatter, save/health и cleanup без tools; 6 UI E2E (§110).
- [x] Go language Ubuntu: явный build и те же 6 E2E, вместе с остальной матрицей (§137–139).
- [x] Bash Windows edit/run/tests: 8 real UI, исходный RED и Unicode rename
  регресс (§116–117), без новых plugins и startup installs.
- [ ] Bash DAP: IDE-057, выбор Linux backend Windows; Mac Bash UI. Ubuntu edit/run/tests проверены (§137).
- [ ] Матрица Go/Rust/Python/JS-Node/Bash/SQL: LSP, completion, definition,
  references, rename, diagnostics, format, run, debug и tests где применимо.
- [ ] Сохранить работающие Go/Rust/Python; добавить отсутствующие JS/Node.js,
  Bash и SQL. Выбрать инструменты и тестовые адаптеры по реальным проектам.
- [ ] Проверить venv, Cargo workspace, Go workspace, package scripts,
  локальные зависимости и SQL dialect/подключение при необходимости.
- [ ] Явный `launch.json` имеет приоритет; без него стартует разумный сценарий
  по проекту/языку. При нескольких целях — выбор, при отсутствии инструмента
  — понятное сообщение с командой подготовки.

Готово, когда для каждого языка есть небольшой проверенный рабочий сценарий
и честно указано, какие действия поддерживаются или неприменимы.

## Этап 5. Полный Git-сценарий

- [x] Diff файла/изменений, stage/unstage hunks, история файла и репозитория.
- [ ] Выбор/создание ветки, commit, push; понятные результаты и ошибки.
  Happy path и два отказа push покрыты; credentials и остальные ошибки открыты.
- [x] IDE-GIT-10: rejected push → No force → подробности `$` → обычный retry;
  отсутствующий origin → код → исправление URL → тот же commit. Windows/Ubuntu
  по 2 новых и 6 прежних Git E2E PASS (§102). Хвост title в Windows INFO — IDE-043.
- [x] Worktree, обычный путь: список, создание, переход, удаление с защитой незакоммиченного.
- [x] Общие Space w g/q/z/? и status q/Esc/g?, сохранение полного Git-tab.
- [x] IDE-024: upstream исправление hunk patch Windows, без собственного Git backend.
- [x] IDE-025: стабильный cwd выбранного worktree при фокусе старых файлов.
- [x] IDE-026: закрытие Diffview во время загрузки, повтор, другой view и
  возврат файла/раскладки; real Git gate и естественное раннее закрытие (§89).
- [x] IDE-GIT-11/IDE-044: merge/rebase resolve/continue и abort, Alt+e в
  writable result diff3 из дерева и версии; 4 real editor E2E Windows/Ubuntu (§103).
- [ ] Credentials, interactive sequence editor и остальные ошибки Git;
  отдельные сценарии ещё открыты.
- [x] IDE-GIT-12/IDE-043: полный OSC title/hyperlink удаляется до CSI,
  видимый UTF-8/обычные пути сохранены; 3 UI + matrix 10, подготовка 9 (§104).
- [x] IDE-028: быстрые visit между worktree с разными HEAD во время обновления
  status; согласованный Unicode-граф и 3 real editor e2e Windows/Ubuntu (§91).
- [x] IDE-034: удаление активного linked worktree после смены cwd; временный
  проверяемый backport Neogit с явной подготовкой, 2 editor + 5 подготовки E2E
  Windows/Ubuntu (§96). Mac остаётся отдельной проверкой.
- [x] IDE-035: удаление между initial Git reads, сохранение текста и дальнейший
  stage/unstage в нужном repo; 2 UI + 7 подготовки E2E Windows/Ubuntu (§99).
- [ ] IDE-038: единичный Windows Permission denied при повторном удалении
  после dirty cancel/commit/visit; установить удерживающий cwd/handle.
- [x] IDE-GIT-9: явный process cwd common git-dir, включая уже текущий linked;
  CLI + 3 UI с разными HEAD, явная подготовка двух файлов. Windows/Ubuntu
  4 live + 2 completed + 8 подготовки PASS. Первоначальный владелец handle
  IDE-038 не доказан (§100).

Готово, когда обычная рабочая задача проходит от создания worktree до push
без мыши и без необходимости искать необъявленные команды в конфиге.

## Этап 6. Упрощение и переносимость

- [ ] IDE-080 — обязательный review до рефакторинга: карта всех фич/плагинов,
  собственного glue/SDK/backports, полезность, пересечения, source/E2E evidence,
  platform gaps и цена. Сначала конкретный список оставить/убрать/заменить,
  затем небольшие изменения. Первичный срез — [FEATURE_REVIEW.md](FEATURE_REVIEW.md).
- [ ] При расширении language workflow использовать готовые LSP/backend;
  не делать собственный binder/index/server или существенный private fork.
  Ограничения готовых tools явно сохранять в матрице.

- [ ] IDE-010: выполнять переносимость на протяжении всех этапов;
  выделять системные границы по `PORTABLE_ARCHITECTURE.md` с e2e на активных ОС.
- [ ] По исправленным сценариям разделить ответственность `ide`, Edgy,
  DAP-оркестрации и `panel_guard`; убрать доказанное дублирование состояния.
- [ ] Удалять плагины/обёртки только с сохранением проверенных сценариев,
  без большой переписи ради уменьшения числа файлов.
- [ ] Проверить чистую установку, повторный setup и полные рабочие сценарии
  на Windows/macOS/Ubuntu; Mint временно отложен, SSH и обычный терминал без WezTerm —
  дополнительные сценарии. Зафиксировать версии пакетов и возможности GUI.
- [ ] Базовые команды остаются доступны без специальных WezTerm-сочетаний;
  определить clipboard/шрифты/клавиши в удалённой сессии и fallback.
- [ ] Обновить единую точку входа в документацию; старые планы пометить
  историческими, когда их актуальные решения сверены.

## Сквозной этап. E2E и VM (IDE-011)

- [x] Добавить команды quick/e2e/full для Windows и POSIX-гостей,
  suite `e2e` в общий runner и настоящий CLI e2e диагностики.
- [x] Собрать и выполнить Ubuntu Docker на Windows: непривилегированный
  процесс, readonly чекаут, runtime без сети, отчёты в `.tests/ubuntu/`.
- [x] Записать правила фича/баг → сценарий → регресс и честную матрицу долга.
- [ ] Изучить `cs2d` после получения пути; сверить его подход с нашим каркасом.
- [ ] Добавить metadata и проверку полноты каталога: отсутствие e2e у
  затронутой фичи/бага не позволяет объявить change завершённым.
- [x] Подготовить backend настоящего Neovim с RPC UI и базовыми сценариями.
- [x] IDE-030: Windows temp на диске checkout, очистка частных runtime,
  повторное использование Go cache и 4 постоянных lifecycle E2E (§90).
- [ ] Добавить PTY/ConPTY и GUI WezTerm; общие сценарии при разных адаптерах.
- [ ] Основное расширение покрытия вести по редактору: LSP/completion/format,
  DAP/output/panic, neotest, Git/worktree и задачи. Каждый соответствующий этап
  закрывается вместе со своими e2e; не откладывать их до конца разработки.
- [ ] Заполнить e2e исходных проблем и базовых возможностей по матрице.
- [ ] Воспроизводимая подготовка/снимки VM, наборы версий и сбор артефактов.
  Владелец запускает VM и команды в госте; гипервизор пока не закреплён.
- [ ] Пройти активную матрицу Windows/Ubuntu/macOS; Mint временно отложен.
  SKIP/MANUAL/не реализовано — отдельный долг,
  не подтверждение работоспособности.

## Что уже можно использовать

По текущему коду `nvim_forge`, **normal mode**, leader = Space:

| Клавиши | Действие |
|---|---|
| `Space D v` | Открыть при необходимости sidebar и сфокусировать Locals/Scopes |
| `Space D c` | Фокус в уже открытый DAP REPL/Console/Terminal; иначе нижний слот |
| `Space D 0` | Вернуться в код |
| `Space p o` | Раскладка Outline слева (может сменить прочие панели) |
| `Space l o` | Переключить Aerial слева |
| `Space w a` | Открыть/сфокусировать Outline через общий менеджер |
| `Space w e` | Открыть/сфокусировать Files через общий менеджер |
| `Ctrl+w`, затем `h/j/k/l` | Перейти в соседнее окно Neovim |
| `F6` / `F7` | Следующее окно / фокус в редактор |

Из terminal mode сначала `Ctrl+\`, затем `Ctrl+n`; после этого работают
normal-привязки. IDE-005/008 проверены на Windows/Ubuntu; Mac может загружать
другую версию и ждёт проверки. Общая локальная модель остальных панелей открыта.

## Текущая точка продолжения

2026-11-10: после §142 владелец уточнил подход; собственный SQL prototype
отменён (§143). Актуальный следующий пункт — IDE-080 feature/cost review в таблице
ближайшего маршрута выше. Следующие абзацы сохраняют контекст прежних этапов;
их исторические результаты не заменяют текущую platform matrix.

IDE-037: владелец выбрал чистый Docker вместо восстановления прежнего диска.
Новый engine проверен container/volume write/read, данные на F:, AutoStart
выключен. Lifecycle Desktop/WSL без отдельного поручения не менять. Старый
диск сохранён; незавершённая копия не используется (удаление отклонено средой).
Инструкция — `docs/DOCKER_WINDOWS_SETUP.md`. По подтверждению владельца engine
запущен 2026-11-02. Результаты IDE-035 и исходные красные Windows прогоны
сохранены в §99. ConPTY RU Ctrl+/ (IDE-039) остаётся открытым: последний
отдельный прогон 65 PASS/1 FAIL, эталон не менялся. Полный Windows PASS
с ConPTY не заявлен; Mac/GUI не проверены.

IDE-039 (§101): постоянная `tests/diagnostics/conpty-layout.py` сохраняет
actual/expected/diff, metadata каждой сессии и исходный вердикт. Наблюдаемый
RU FAIL поймал RU → EN между сессиями и ровно четыре прежних отличия Ctrl+/;
контрольный EN прошёл 66 проверок (один sample без foreground). Эталон не менялся. Изоляция
раскладки input thread и устойчивое RU покрытие остаются открытыми; старые
прогоны без metadata не приписываются этой причине задним числом. Следующий
функциональный Git шаг IDE-GIT-11 завершён в §103; IDE-039 остаётся диагностикой.

IDE-GIT-10 (§102): rejected/missing remote и повтор проверены в настоящем
Neogit на Windows/Ubuntu. Runtime менять не потребовалось; два новых E2E
постоянно входят в registry, прежние шесть тоже прошли на обеих ОС.
Согласование историй перед retry делается Git CLI в fixture: это не покрытие
UI merge в том change. IDE-GIT-11 (§103) отдельно покрывает merge/rebase
resolve/continue/abort и исправляет Alt+e в diff3; по 4 PASS Windows/Ubuntu.
Credentials/sequence editor остаются открытыми; Mac/GUI не проверены.
IDE-043 закрыт в §104: util companion, явный Lazy build, baseline RED,
native/hook UI и parser matrix; worktree primary и lock сохранены.
IDE-045/046 (§105–106) исправляют организацию E2E: отдельные SDK сценарии с
прежними deadline, UI Head перед поиском после checkout. Исходные FAIL сохранены.
Windows unit/e2e/trace: 40 PASS/0 FAIL/0 SKIP, 486 checks; после последней
правки ожидания все 6 Git workflow повторно PASS. Ubuntu full: сначала
42 PASS/1 FAIL/3 SKIP (IDE-046), затем 41 PASS/2 FAIL/3 SKIP, 650 checks.
В последнем все новые OSC/SDK/workflow проверки прошли; два прежних Gitsigns
сценария дали RPC/teardown сбой IDE-047. Это не чистый Ubuntu full PASS.
Cleanup собственных child и сохранение первой ошибки выполнены в §107,
IDE-041 — в §108. Без новых изменений полный набор не зацикливаем.

IDE-047 (§107): cleanup/сохранение первой ошибки выполнены, Windows 11 PASS/
2 POSIX SKIP и Ubuntu 13 PASS. Следующий full — 43 PASS/1 FAIL/3 SKIP,
653 checks; единственный FAIL — отдельное ожидание read IDE-048, child
завершился штатно, первичная ошибка не потеряна. Причина прежних двух RPC
не установлена; новые полные повторы без изменений не планируются. Metadata/
история IDE-047 сохранены коммитом fa33150.

IDE-041 (§108): реальный UI RED E339, общий word budget 4096 UTF-8 bytes
и одинаковая защита в обычном/large-file режимах. По 3 новых + 10 smoke PASS
Windows/Ubuntu; Windows unit/trace 15 файлов PASS, 364 checks. Следующий
пользовательский этап Space w завершён для tests/поиска/задач в §109.

IDE-009/049 (§109): Tests/Test Output/Search/Tasks получили общий маршрут,
контекстные действия и сохранение состояния; исправлены удаление поискового
buffer и чтение старого cursor при Enter из zoom. По 6 новых и 19 прежних UI
PASS Windows/Ubuntu, Windows unit/trace 364 checks. Следующий этап — фактическая
матрица шести языков и недостающие рабочие сценарии; без полной переработки
архитектуры до проверки функций. Mac/GUI, terminal/Trouble и IDE-047/048 открыты.

IDE-050 (§110): common trim ошибочно считался языковым formatter и блокировал
LSP fallback. Порядок задаёт общий filetype resolver, callers его наследуют;
cleanup без tools сохранён. Windows 6 новых UI, Go tests 5, smoke 10 и 364
unit/trace PASS. Ubuntu engine 2026-11-03 недоступен, Docker lifecycle не менялся;
проверка и сборка image остаются открытыми. Далее — JS/Node и остальная матрица.

IDE-038 (§100): process cwd явно common git-dir. Итоговый Windows
unit/e2e/trace — 38 PASS/0 FAIL/0 SKIP (471 проверка); Ubuntu full —
41 PASS/0 FAIL/3 SKIP (42 файла/44 прогона, 640 проверок). Live 4, completed 2
и подготовка 8 PASS на обеих ОС. Первый вариант с наследуемым cwd и его
широкие результаты сохранены как промежуточные: current linked дал RED
до коммита и потребовал изменения решения. Владелец handle первого отказа
551474721600 не установлен; этот остаток IDE-038 не закрыт задним числом.
Первый Ubuntu full при параллельном Windows имел один 60s timeout key-ownership
(IDE-042); raw FAIL сохранён, одиночный повтор 46 PASS и новый полный serial
не устанавливают причину timeout. Тяжёлые наборы на этом хосте выполнять
поочерёдно. IDE-039 (ConPTY Ctrl+/) остаётся диагностикой; обычные Git
ошибки push, merge/rebase и читаемый output покрыты IDE-GIT-10/11/12.
Исходный владелец handle IDE-038 и IDE-031/036/040/047/048 остаются
открытыми; Mac/GUI не запускались. IDE-041 завершён в §108.

IDE-036: эпизод сильных тормозов ввода/окон закончился только после рестарта
ПК, по сообщению владельца. GPU hangs Code и AMD Code 43 зафиксированы,
но причинная связь не доказана; перезапуск GPU child не помог. Пункт открыт,
данные — `docs/WINDOWS_UI_LAG_DIAGNOSTICS.md`. Владелец поручил продолжить план
после перезагрузки. Ubuntu full IDE-034 прошёл; Windows full сохранён прерванным.
Исторические результаты завершения IDE-034 — §96; после них IDE-035
завершён в §99, а установленный класс object read — §100.

Базовое ядро этапа 0.5 проверено на Windows/Ubuntu, запуск на Mac открыт.
Go/Delve часть IDE-003/004 исправлена и проверена реальными E2E (§64–66);
Mac/Python/Rust и исходный конфиг владельца остаются открытыми.
Go-часть IDE-006 проверена на Windows/Ubuntu (§68–70): обычный nearest/file,
debug/eval и закрытие DAP float. Исходный Mac и Python/Rust открыты.
IDE-007 реализована и проверена 11 E2E на Windows/Ubuntu (§71); Mac открыт.
IDE-012 исправлена: codelldb ищется при запуске, 3 E2E Windows/Ubuntu (§72).
Пилот Run & Debug (IDE-005/009) реализован: Space w, 4 real DAP/editor E2E
Windows/Ubuntu (§74); по пути исправлен Satellite/нулевая высота (§75).
IDE-008: единый Outline слева, общий маршрут и 6 real Aerial E2E Windows/Ubuntu
(§76–77). Дерево: общий маршрут и 7 файловых/panel E2E (§78–81).
Буферы/вкладки: 8 real editor E2E и общая модель (§83–84).
Git/worktree: общий маршрут, hunks, diff/история, branch/commit/push и сквозной
worktree → файл → commit/push покрыты 6 real editor E2E (§85–87).
IDE-026: безопасное закрытие загружающегося Diffview и 7 E2E (§89).
IDE-030: старые тестовые профили и Go cache перенесены с C: на F:;
очистка runtime и единый Windows cache исправлены, 4 lifecycle E2E (§90).
IDE-028: согласованная история/граф при быстром visit, 3 real Git/editor
e2e Windows/Ubuntu (§91). IDE-GIT-10 покрывает два отказа push (§102),
IDE-GIT-11 — merge/rebase-конфликты (§103). Credentials/sequence editor
и известные ошибки остаются в очереди этапа 5, далее упрощение/переносимость.
IDE-027: причина установлена — native ConPTY lifecycle в Neovim Windows,
подтверждены symbol/чистый repro и A/B одного source/компилятора (§92).
Владелец выбрал временный Windows SDK с явной подготовкой, lock/patch/hash
и общим resolver launcher/test entrypoint; Linux/macOS — официальный SDK.
Core probe (50 циклов) и исходные 8 buffer E2E прошли на patched SDK;
прямой системный nvim всё ещё воспроизводит ошибку. Удаление патча после
подтверждённого upstream fix — отдельный шаг, не бессрочная ветка ядра.
IDE-031: единичный 10s timeout PowerShell CLI unknown-mode в полном IDE-028;
10 повторов/30 CLI процессов прошли с прежним deadline; добавлены PID,
время, stdout/stderr и fixture artifacts, E2E ошибки/timeout (§93).
Причина исходного timeout неизвестна, пункт открыт. IDE-032: общий lifecycle
удалённых файлов исправлен через native FileChangedShell, без E211 и потери
текста; pending autosave удерживается, явный write/Save As возвращает его.
Пять новых real editor E2E прошли на Windows/Ubuntu; старый config-source
в том же сценарии даёт E211 (§95). При обнаружении исчезнувшего каталога
освобождаются GitSigns watchers скрытых файлов. Другие native конфликты сохранены.
IDE-034: ожидание смены cwd до Git remove исправляет удаление активного
worktree; явный backport закреплённого Neogit, 2 editor + 5 подготовки E2E
Windows/Ubuntu (§96). Существующей установке нужен `:Lazy build neogit`
и перезапуск; обычный startup исходники не меняет.
IDE-035/038 покрывают initial attach и живой object read (§99–100),
IDE-GIT-10 — отказы push (§102), IDE-GIT-11 — конфликты (§103);
IDE-031 и исходный владелец случайного handle IDE-038 остаются в диагностике.
IDE-033: старый ConPTY набор менял source lock через user plugins;
выделен private профиль и выбранный SDK, добавлена проверка изоляции (§94).
Владелец поручил агенту коммитить проверенные шаги и продолжать этот план
самостоятельно; новое «давай дальше» между шагами не требуется.
Mac/GUI и остальные панели не объявлены проверенными.
IDE-013 Starship остаётся в диагностике; настройки prompt не менялись.
Данные Mac не блокируют эту работу; исходную IDE-001 не объявляем
исправленной изменениями Neovim.

На Windows изучены исходники; доступа к Mac в этой сессии нет. Владелец
подтвердил: задержка и сообщение возникают до nvim, используется zsh.
Сообщение Go доказывает неудачную автозагрузку toolchain, но не показывает
инициатора. Для исходной жалобы сначала исследуем zsh, не DAP/Mason.
Сборщик `nvim_forge/scripts/diagnose-shell.py` подготовлен в change
`diagnose-macos-shell-startup`. Следующее действие: запустить его на Mac
из проблемного каталога, подтвердить инициатор через trace, записать версии
и замеры в IDE-001; затем оформить точечное исправление. Кандидат Starship
проверен по его исходникам, но на данном Mac пока не подтверждён.
