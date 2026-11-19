# IDE-080 — текущий обзор сборки перед рефакторингом

2026-11-19, source **8d721c3**. Этот проход — source/inventory review;
редактор, SDK и pins не менялись, новых behavioral PASS или benchmark нет.
[Прежний обзор и измерения](history/FEATURE_REVIEW_2026-11-19.md) сохранены отдельно.
[Все67 plugins/pins](PLUGIN_INVENTORY.md) — полный список зависимостей, не67 отдельных фич.
После этого source review IDE-146 реализован §297: Visual Space t e / Ctrl+Enter
в обычную встроенную системную консоль, native Windows/Ubuntu E2E; следующие
кандидаты — legacy neodev hook и language target helpers DAP.

## Что оставляем

Все основные сценарии владельца сохраняются: проекты/сессии, дерево и файловые
операции, поиск, вкладки, шесть языков, запуск/debug/output/tests, Git, встроенная
консоль, общая клавиатурная модель и логи. Breadcrumbs/navic/Satellite и Comment
сохранены решениями владельца; повторно выбирать их не требуется. IDE-146 —
обязательное выполнение выделения в консоли, реализовано после обзора (§297).

| Возможность | Готовый backend | Собственная ответственность и решение |
|---|---|---|
| Ввод, completion, signatures/snippets | nvim-cmp, LuaSnip, sources, friendly-snippets, autopairs | snippet_input отменяет неактуальное предложение; сохранить ввод и RU/EN maps |
| Go/Rust/Python/JS editing | Native LSP + nvim-lspconfig, Conform, Treesitter | tool_paths/SDK selection, workspace boundaries, async readiness; сохранить, новый LSP не нужен |
| Bash/SQL baseline | Bash Language Server/shfmt/ShellCheck; Sqruff LSP/formatter | Сохранить подсветку и готовые tools; без обязательного DB SDK |
| Definition/implementation/references, Peek, Outline | Native LSP, Glance, Aerial | Общий focus и aliases; сохранить navigation, отдельно native platform gaps |
| Дерево/create/delete/copy/paste | Neo-tree | Lifecycle/async scan/backport и guard кода; сохранить файловые сценарии |
| Имя/текст/команды/replace | Telescope, rg, grug-far, optional fzf-native | Проверка native sorter/fallback и panel routes; роли различаются |
| Diff/hunks/history/branches/worktree/commit/push | Gitsigns, Neogit, Diffview | Разные Git UI; сохранить все три, снимать только доказанные patches |
| Debug/config/breakpoint/locals/stack/output/panic | nvim-dap, dap-ui, adapters | dap.lua содержит язык/target discovery и lifecycle glue; разделять малыми шагами |
| Tests/nearest/file/all/debug/output | Neotest + Go/Rust/Python/Jest adapters | Go workspace и nextest/native SDK policy; сохранить готовый backend |
| Terminal и чтение вывода | ToggleTerm, native terminal, Edgy | Сохранить job/history/scroll; IDE-146 заменил внешний pwsh route на active terminal (§297) |
| Run/build/tasks | Overseer | Не объединять task lifecycle с видимостью панели; сохранить штатные templates |
| Вкладки/другой проект/restore | Bufferline, Alpha, project.nvim, persistence | ide.buffers, session_views и startup; различать selected workspace и language roots |
| Панели/клавиши/focus/hide/zoom | Edgy, native splits, dap-ui | state/registry/controls/guard имеют разные роли; не вводить новый window manager |
| Общие логи и диагностика | Native logs, Trouble, собственный bounded log store | Обязательная консоль; хранить историю отдельно от текущих ошибок |
| Тема, breadcrumbs, overview ruler | Catppuccin/lualine/barbecue/navic/Satellite | Сохранить. Цельные рамки — существующий opt-in pilot до физической оценки |
| Установка/SDK/tools | Private Neovim + upstream managers, Mason, native OS package manager | Native frontend, verified payloads, deferred SDK и user/project paths; не изолировать компиляторы |
| Дополнительный Bash debug/Bats | Upstream bash-debug, WSL2 на Windows, native Bats | Уже сделанные optional возможности; не расширять, не удалять вместе с обязательным Bash |
| Дополнительный SQL | sqls, собственная Results panel/adapter и SQL test executable | Отдельный кандидат удаления; нужны решение владельца и отдельный change |

## Где сосредоточен собственный код

Физические строки включают комментарии/пустые строки. Это стоимость чтения,
не время старта, CPU или доказательство лишнего кода. Third-party sources сюда
не входят; распределение посчитано по tracked source8d721c3.

| Слой | Файлы / строки | Владелец поведения |
|---|---:|---|
| plugins/*.lua | 19 / 5884 | Настройка готовых plugins; dap.lua1629 и lsp.lua750 — самые крупные |
| forge/*.lua | 43 / 5147 | SDK/tools, языковые границы, Logs/session views/guards; рядом один JSON patch30 строк |
| ide/*.lua | 14 / 2731 | State, component registry, activities и keyboard controls |
| config/*.lua | 8 / 2334 | Общие options/keymaps/startup/diagnostics/RU keys |
| installer-ui/src/*.rs | 11 / 3522 | Native CLI/TUI, package recipes, bounded SDK inspection и confirmation/recheck |
| Plugin backports | 6 dependencies / 16 upstream files | Manifest116963 bytes; не отдельные новые плагины |
| Private Windows Neovim SDK | 2 source patches | ConPTY lifecycle и process ancestry; Linux/macOS используют upstream |
| Bash debug SDK correction | 2 точных fragments в одном SDK JS file | Stop/sentinel fix; explicit prepare, не startup patching |

Не следует сливать runtime resolver, installer preflight и setup только из-за
похожих названий: у них разные side effects/сроки жизни. Lua preflight уже общий;
Rust читает его snapshot. Так же различаются state переходов, Edgy layout,
DAP session, process lifetime и view snapshot. Границы разобраны в
[PANEL_OWNERSHIP_REVIEW](PANEL_OWNERSHIP_REVIEW.md),
[WORKSPACE_TOOL_REVIEW](WORKSPACE_TOOL_REVIEW.md) и
[PORTABLE_ARCHITECTURE](PORTABLE_ARCHITECTURE.md).

Backports: Gitsigns2, Neogit5, Neotest4, DAP1, neotest-rust2, Neo-tree2 files.
Сохраняем до upstream equivalent и тех же regression cases. В этом проходе
новые upstream releases не проверялись; старые сравнения остались в архиве.

## Конкретные следующие изменения

| Порядок | Действие | Что сохраняем / как доказываем результат |
|---|---|---|
| Выполнено | IDE-146: выполнение выделения в active integrated terminal | §297: visible/hidden/missing/multiple, точный текст, Unicode, повтор и тот же job; по7 native E2E Windows/Ubuntu |
| 2 | Проверить legacy neodev hook и удалить только при доказанном отсутствии роли | Pinned neodev использует lspconfig.util.on_setup; текущий LuaLS настроен native vim.lsp.config. Нужен native LuaLS/Neovim API/explicit luarc control до удаления pin |
| 3 | Разделить конкретные language target helpers в dap.lua | Те же public DAP entrypoints, async cancellation/cwd/launch.json и F5. Без нового dispatcher/state или смены adapters |
| Решение | Дополнительный SQL: убрать либо оставить optional | Удаление уберёт DB-aware workflow/schema/query Results и SQL assertions, sqls protocol/SDK patch и отдельную сборку SQL runner; Sqruff baseline сохранится |
| Позже | Распространение рамок, platform UX | Только после физической оценки pilot/clipboard/keys; no shadow-panel rewrite |

SQL extras сейчас включают forge/sql.lua239, sql_protocol22, sql_diagnostics55,
sql_tests95, ide/sql60 строк; отдельный Rust runner185 строк, packager69 и SDK
policy/patch. Test preparation/fixtures — дополнительная стоимость. Это не
базовый Sqruff module41 строк. До решения владельца удалений нет. Bash extras
оцениваются отдельно: пользователь уже выбирал WSL2 backend, а Bash run/tests
также используют этот OS boundary.

## Что доказано и что ещё открыто

Каталог на этот snapshot: **160 REGISTERED / 1 PENDING / 0 MISSING**.
PENDING — IDE-SQL-9 semantic references. Это проверка регистрации E2E, не160 PASS.
После обзора IDE-146 получил registered terminal-selection E2E и native PASS (§297).
Реальные platform результаты берём из соответствующих verification/FIXLOG,
а не из наличия файла, pin или загруженного plugin.

| Сценарии | Постоянные E2E / отчёт | Граница |
|---|---|---|
| Files/буферы | [file-explorer](../tests/e2e/file-explorer.test.lua), [file-copy-delete](../tests/e2e/file-copy-delete.test.lua), [buffers](../tests/e2e/buffers.test.lua) | Большой рабочий проект/редкие filesystem ошибки и native Mac отдельно |
| Mixed languages, navigation, Debug/Tests | [mixed-project](../tests/e2e/mixed-project.test.lua), [peek-navigation](../tests/e2e/peek-navigation.test.lua), [dap-output](../tests/e2e/dap-output.test.lua), [test-runner](../tests/e2e/test-runner.test.lua) | [Матрица языков](LANGUAGE_MATRIX.md), не все реальные env/платформы закрыты |
| Панели/terminal/session | [tool-panels](../tests/e2e/tool-panels.test.lua), [project-session](../tests/e2e/project-session.test.lua), [session-tool-views](../tests/e2e/session-tool-views.test.lua), [terminal-selection](../tests/e2e/terminal-selection.test.lua) | Физические keys/рамки отдельно; selection route реализован §297 |
| Git | [git-workflow](../tests/e2e/git-workflow.test.lua) и Git error/conflict suites | Реальные accounts/SSH/OAuth и редкие Windows handles отдельно |
| SDK/install/deferred prepare | [language-environments](../tests/e2e/language-environments.test.lua), [Omarchy verification](../openspec/changes/support-omarchy-installation/verification.md) | Current Windows/Ubuntu/Arch affected packet; actual Omarchy/macOS не запускались |

Omarchy clean CLI прошёл; Wayland/GPU/clipboard/hotkeys/рабочий mixed project —
[O1-O8](../tests/manual/omarchy.md). Исходные macOS zsh/Go delay и Cmd+C также
ждут машины владельца. Native assertions/worktree инциденты без воспроизведения
не закрываются обзором. [Полный план](IDE_ROADMAP.md) хранит конкретные gates.

## Итог обзора

Полная пересборка редактора или смена backend не обоснованы. Основу оставляем;
IDE-146 устранён §297; далее проверяем legacy compatibility
и уменьшаем смешение языковых обязанностей DAP. Удаление SQL extras требует
отдельного решения; массового удаления plugins по их числу не предлагаем.
