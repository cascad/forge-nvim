# Источники общей консоли IDE

IDE-106, 2026-11-11, baseline84f619c. Это inventory для реализации,
первые UI и native restart проверки выполнены, итог — в change verification.
Пути основаны на закреплённых исходниках из
.tests/editor-deps, сверенных с lazy-lock/manifest; backend/pins не меняются.

| Источник | Где сейчас | Доступность и действие |
|---|---|---|
| Forge/plugins/setup | vim.notify, :messages; Lazy errors через notify | Native сообщения есть до LspAttach; сейчас централизованной persistent history нет |
| Native Neovim | NVIM_LOG_FILE либо stdpath(log)/log | Файл может ещё не существовать; нулевой размер отличается от отсутствия |
| LSP | vim.lsp.log.get_filename(); прежняя :LspLog | Вызов filename не стартует сервер; причина отсутствия сервера — :checkhealth forge/vim.lsp |
| DAP | stdpath(cache)/dap.log и dap*.log; :DapShowLog | Logger create_logger открывает файл; обзор должен читать существующие файлы без этого вызова |
| Format | stdpath(log)/conform.log; :ConformInfo | Public conform.log.get_logfile при загруженном module; отсутствие formatter обычно notify с действием |
| Tests | stdpath(log)/neotest.log и neotest output buffers | Logger require создаёт файл, поэтому console не загружает Neotest ради проверки |
| Git | stdpath(cache)/neogit.log, Neogit command history | Native logger.config.use_file по умолчанию false; показать disabled. Default известен, logger не включать автоматически |
| Tasks | stdpath(log)/overseer.log и существующие job/output buffers | Сам просмотр не вызывает OverseerRun/Open/создание job |
| Setup/Mason | stdpath(log)/mason.log | Содержит explicit setup errors; console не инициирует install/update |
| Fidget | stdpath(cache)/fidget.nvim.log, notification.get_history | Logger может быть переопределён options.path; notification history128 removed + active, только текущая сессия |
| Общая готовность | :checkhealth forge, native LSP/formatter info | Явное действие из console, PATH lookup и подсказки; passive open health автоматически не запускает |
| Program/test output | загруженные dap-repl/dap-terminal/neotest-output-panel/terminal buffers | Отдельные каналы существующего вывода; читать доступный buffer, не повторять запуск |

Fidget889e2e96: override_vim_notify=false, загрузка event LspAttach; прямой
fidget.notify используется в ide.buffers. Поэтому только vim.notify hook
теряет этот маршрут, а только Fidget history теряет ранние сообщения.
Документированный update_hook допускает запись direct notifications с
сохранением native set_content_key. LSP progress skip_history остаётся прежним.

Conformdca1a190/Neotest27bf9214/Neogitd7bb91b4/Overseerf818eeff/DAP45a69eba:
read-only просмотр исходников log modules; session/history и UI adapters не
меняются. Native fields private не выбираются новым public контрактом.

## Проверка native observer

`nvim -l tests/diagnostics/ide-log-events.lua` запускает настоящий Forge,
подписывается на msg_show с set_cmdheight=false и возвращает false. WARN notify
и native nvim_echo появились в callback и в обычном :messages, cmdheight1
сохранился. Windows profile38188300228900, Ubuntu33615563780821. Native quit/
shutdown/source artifacts лежат рядом; это proof API forwarding, не готовая фича.

Позднейшая проверка показала, что этот proof не доказывает visual forwarding:
ext_messages неявно включает ext_cmdline и первое console text input стало
невидимым. Подписка отвергнута и снята из runtime. Native history читается
снимком при open/r/VimEnter/VimLeavePre с явной подписью времени снимка.
Прямой notify delegate и Fidget hook записывают сообщения сразу.

Mac/physical GUI не запускались. Диагностика включается только явной командой,
не меняет SDK. Native подробности читаются bounded tail с
обозначенной границей; console не обещает восстановить отсутствующий log.
