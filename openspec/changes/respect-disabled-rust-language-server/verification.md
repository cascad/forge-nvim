# Verification

2026-11-13. IDE-RUST-3 / IDE-136, source91baabb. Runtime change: два native
is_enabled guards в forge.rust_project; никаких root/cache/backend changes.

## Исходное воспроизведение

Один source-прогон existing rust-language.test.lua на Windows и Ubuntu:
по0 PASS/2 FAIL. Initial disable всё равно запускает настоящую Cargo metadata.
Disable при held реальном ответе вызывает native start с enabled=false;
snapshot содержит настоящий rust-analyzer spawn, lsp.log — initialize.
Пустой get_clients до initialization не означает отсутствие процесса.

## Итог новой версии

| ОС | Source RED | Target PASS | Controls PASS |
|---|---:|---:|---:|
| Windows | 2 | 2 | 3 |
| Ubuntu | 2 | 2 | 3 |

Target: initial disable не запускает metadata/LSP, Rust файл редактируется;
native re-enable даёт initialized/quiescent настоящий attached клиент.
In-flight disable сохраняет false, callback завершён, native start не вызван.
Controls: IDE-RUST-2 early warmup/reuse/UI; language completion/diagnostics/
correction; IDE-DAP-9 held metadata input/picker cancel с прежним default
producer plugins/dap.lua. Каждый selector выполнен один раз на новой версии.
Здесь нет промежуточных prototype FAIL или неизменённых повторов.

Все14 native profiles (включая source RED) exit0/signal0, API errors[],
hard_kill=false, успешный shutdown и пустые process scopes. Source runner
exit1 относится к двум ожидаемым failed assertions, не native exit.
Артефакты: .tests/rust-disabled-{source,target,warmup,completion,observer}.txt,
guest equivalents в .tests/ubuntu, host rust-disabled-ubuntu.txt.
Audit .tests/audit-rust-disabled.py → rust-disabled-audit.json сверяет native
данные, сохранённые config/test/helper bytes, frozen hashes и journal prefixes.

## Среда и границы

Windows SDK74aff15b; готовый Rust SDK проверен existing helper. Ubuntu готовый
engine28.5.1, imagef63a05ca, private Neogit overlay через pinned applier,
network none. Win/Linux serial, jobs2, host temp F. Без SDK downloads,
image build, Docker Desktop/WSL lifecycle.67 pins/6 backports16 files прежние.
Frozen test infrastructure drafts не изменялись и не запускались.

Scope — уже настроенный LSP; initial config/Mason enable policy, LspStop и
root/library алгоритм прежние. Callback gate не доказывает SIGTERM/cancel ещё
живого metadata процесса (старый IDE-RUST-2 gate остаётся открытым). Mac,
physical/large project и полная suite не проверялись. Старые IDE-121/129/133
и worktree incidents не закрываются этим выбранным регрессом.
