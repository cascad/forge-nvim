# Verification

2026-11-13, IDE-137 / IDE-PANEL-29. Source3184bc4.

## Результаты

| ОС | Source | Target | Прежний A→B→A control |
|---|---|---|---|
| Windows | 1 PASS | 1 PASS | 1 PASS |
| Ubuntu | 1 RED | 1 PASS | 1 PASS |

Ubuntu source: реальный open_project('/') выдаёт ERROR «Project path is not
a directory: », cwd остаётся исходным. Наблюдатель нового backend истекает,
final_state подтверждает первичный пустой путь. Windows source работает:
native exit save компенсирует пропуск explicit save. Потеря сессии там не
доказана; source PASS не переименован в RED.

Target: корень принят,4 native PID, private файл изменён, сохранён при переходе
в B и восстановлен при возврате к root. Native session/readiness/lifecycle/
file text проверены без mocks. Control сохраняет прежние3 files/2 tabs/cursors,
Quickfix cleanup и запись unsaved текста. По одному target/control на ОС.

Первый Windows test prototype проверил modified до доставки terminal input:
49437891540500, FAIL «Fixture did not modify a file». Добавлено ожидание native
insert/text перед Escape, source-final49472751127900 PASS. Это fixture race,
не воспроизведение продукта. Linux использовал уже исправленный тест.

Все7 host profiles (включая prototype/source RED) exit0/signal0, штатный TUI
exit0, API errors[], scope empty, hard_kill=false. Audit сперва искал test copy
control в native artifact, но wrapper сохраняет её в controller directory;
исправлен только audit path, E2E не повторялись. Raw .tests/project-root-*,
guest equivalents в .tests/ubuntu, audit-project-root.py/project-root-audit.json.
Сохранённые config/test/session helper bytes, frozen hashes и prefixes сверены.

## Границы

Только local normalize/containment в config.start. Root selection/LSP policy,
native restart/persistence, SDK74aff15b,67 pins и6 backports16 files прежние.
Host temp F, UTF-8/LF guest scripts, Win/Linux serial. Готовый engine28.5.1,
imagef63a05ca/private pinned Neogit overlay/network none; без SDK download,
image build или Desktop/WSL lifecycle. Mac/physical, symlink/UNC matrix,
branch sessions и полная suite не проверены. Старые incidents не закрыты.
