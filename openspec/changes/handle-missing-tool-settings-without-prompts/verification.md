# Verification

## Причина и исправление

IDE-BOOT-41, 2026-11-18. В checkpoint §275 strict override бросал ошибку из
ts_ls/bashls root callback и Run/Debug readiness. Node default config обращался
к SDK раньше readiness. Stack нового save-case дополнительно подтвердил:
Conform.get_formatter_info вызывает command до condition, поэтому защищать
только condition недостаточно.

Strict resolver/report/preflight не изменён. Runtime boundaries возвращают
отказ, показывают короткое предупреждение и записывают source/reason в Logs.
LSP guard дедуплицирует buffer/server/reason, очищается после успеха и не
показывает устаревшее отложенное предупреждение. Native root/RPC APIs сохранены.
Node config до readiness декларативный; Node/Bash adapters проверяют зависимости
до callback, Run не создаёт task при ошибке. Prettier command/args/condition
защищены: пустой command штатно даёт unavailable в Conform, без fake binary/
shim/PATH fallback. Глобальный notification backend не менялся.

## Проверки

Один affected batch после цельного изменения, только failed/affected повторы:

| ОС | Начальный batch | Окончательный retry | Aggregate |
| --- | --- | --- | --- |
| Windows |1794995382072765300 (9 files)|1794995899266979700 (new+Node)|54 PASS/0 SKIP|
| Ubuntu |1794995393335041240 (10 files)|1794995908292669822 (new+Node)|57 PASS/0 SKIP|

Это composite per-file результата, а не полный зелёный regression: исходные
отчёты с ошибками сохранены. Initial new suite дал3 FAIL/4 PASS: ошибочный ввод
комментария в fixture, затем настоящий BufWritePost/Conform command throw.
Первый retry только нового файла (Windows1794995699291577000 /
Ubuntu1794995711277831148) подтвердил save throw. Исправлен command; финально
повторены new7 и Node8. Остальные suites не повторялись.
Windows initial445.21s /Ubuntu285.64s; final135.09s /76.68s.

7 новых случаев:
- Invalid Node env при рабочем Node в PATH: edit/save, no task/session/adapter,
  source в Logs, dedup, затем реальные ts_ls и NodeRunFile после исправления.
- Malformed project и user JSON: strict inspection остаётся ошибкой, редактирование
  доступно, после ручного исправления запускается настоящий Node без restart.
- JS и Bash invalid adapter: F5 не создаёт session, источник сохранён, файл доступен.
- Invalid native Bash: нет fallback/WSL, после исправления настоящий BashRunFile.
- Общий LSP guard: explicit missing gopls не мешает edit/save, клиент не запускается.

Controls: Node8, Bash8, Logs3, sources8 (реальное js-debug recovery), focus2,
tool paths4 (strict invalid/no fallback), Go/Rust7 (native LSP/format/tests/DAP),
setup7 (native Mason SDK environment). Ubuntu дополнительно Bash debug3,
включая настоящий adapter/bashdb breakpoint/eval/stop. На Windows этот native
WSL workflow не запускался; оба missing adapter cases покрывает новый suite.
Все editor shutdown проверяются прежним harness; новые cases не принимают
hit-enter автоматически. Native Mac не запускался.

## Отчёты и границы

- `.tests/batches/<Windows IDs>` / `.tests/ubuntu/batches/<Ubuntu IDs>`: raw00.log,
  plan.json/report.json; `.tests/toolchain-research/missing-tools-composite.json`.
- `missing-tools-{windows,ubuntu}-{batch,retry,format-retry}.txt` в том же research.
- Старый полный report до замены mutable report.json сохранён отдельно:
  `.tests/ubuntu/batches/1794989655059525809/registry-report.json` (122 runs/14 FAIL).
- Некоторые initial и retry процессы кратко пересеклись в одном OS harness;
  общие `.tests/logs`/report.json менялись. Aggregate строится из отдельных
  immutable batch00.log, не из общего последнего отчёта. Артефакты editor имеют
  собственные уникальные каталоги. Полный regression второй раз не запускался.

Шесть прежних failed files теперь PASS: node-language, bash-language,
bash-debug (Ubuntu), ide-logs, ide-log-sources, debug-focus-order.
Оставшиеся8 из checkpoint не перепроверены: test-runner (gopls PATH),
rust-language, ui-capture, dap-launch-routes, mixed-project (sqls→Sqruff),
gitsigns-live-read, существующие WIP posix-scope-probe и tests/trace.test.lua.
Terminal input gate и Mac/Windows WSL acceptance остаются. Default не готов.

Host temp/cache на F; Docker existing image, offline/--pull never, limits2CPU/3GiB,
без Desktop/WSL start/stop/reconfigure. Lockfiles/native SDK не менялись.
Frozen25/WIP проверяются с исключением ровно одной собственной registry строки;
в index эта строка добавляется к HEAD без двух прежних WIP entries.
FIXLOG276/AGENT_COMMANDS184 append-only; exact owned index20, local commit без push.
