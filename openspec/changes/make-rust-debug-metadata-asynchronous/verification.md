# Проверка

2026-11-13. Source c4e44b8; SDK/pins/backports/deadlines прежние.

| Среда | Source IDE-DAP-9 | Target IDE-DAP-9 | Existing IDE-DAP-7 | Held input |
|---|---|---|---|---|
| Windows | 2 RED на sync Cargo | 2 PASS | 1 PASS | 40.293ms |
| Ubuntu | 2 RED на sync Cargo | 2 PASS | 1 PASS | 8.001ms |
| Mac/рабочий проект | отложены владельцем | отложены | отложены | не измерено |

Реальные Cargo JSON/exit/argv и DAP producer stack сохранены. Observer удерживает
готовый callback native процесса, не подменяет protocol/данные. Input/cancel и
stale cwd — два независимых profiles. Каждый завершился native Run aborted,
session nil; перед quit RA завершил свою фоновую работу. Target и control
вышли0/0/APIerrors[]/scope0/hard_kill=false. Полный Rust suite не запускался.
Windows control выполнен на том же runtime до последнего изменения только
новых cases; его сохранённый IDE-DAP-7/common helpers совпадают, не повторялся.

Prototype ошибки сохранены: custom dap.configurations не входит в smart F5;
объединённый быстрый cancel→repeat оставлял код в Insert и не доходил до picker;
попытка нормализации Ctrl-\\/Ctrl-N тоже не годится. Это не доказательства бага
нового resolver. Новые ветки разделены, existing IDE-DAP-7 по-прежнему проверяет
настоящие cancel/repeat/второй bin/breakpoint/eval/output и PASS на обеих ОС.

Intermediate41303674536800 имел functional ok, но native quit1/signal15 после
VimLeavePre, scope0. Он остаётся FAIL семейства IDE-121, причина неизвестна.
Финальный regression ждёт завершения native ABORT и quiescent RA, потому что
проверяет program resolution, а не quit активного compiler/LSP. Deadline quit2s
не повышен; этим PASS исходный quit не объявляется исправленным.

Raw .tests/rust-debug-async-* и guest .tests/ubuntu/rust-debug-async-*;
audit rust-debug-async-audit.json сверяет10 final profiles и7 prior profiles,
config/test/helper/SDK/frozen/prefix guards. Отдельные fixture/race/quit logs
сохранены. Ready imagef63a05ca/network none/private Neogit overlay; serial
Win/Linux, готовые SDK, без build image/download/Desktop/WSL lifecycle.
Использовалась лишь маленькая reference Cargo fixture, jobs2, temp F.
Spawn/exit/JSON error ветки сохранены; отдельного fault-injection прогона нет.
