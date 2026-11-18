# Verification — 2026-11-18

## RED

Реальный child Neovim setup-stage на Ubuntu завершал только собственный PID
SIGKILL. Старый execute принимал code0/signal9 за успех: backend exit0,
published=true и bin/fride существовал. Лог:
.tests/toolchain-research/setup-signal-kill-native.txt. SIGTERM обрабатывается
Neovim как exit1 и такого обхода не даёт; отдельный native probe это подтвердил.

## Change

scripts/install-private.lua execute требует code0 и signal0/nil. Сообщение
сохраняет Command failed (code), добавляет signal, command и путь к child log.
Это общая проверка probes и setup, до publication. Других process APIs нет.

## Tests

Один affected batch/ОС: Windows1795010203091073000, Ubuntu1795010215384730150.
Новый tests/install-process-exit.test.py —12 cases:8 POSIX SIGKILL для
plugins/parsers/tools и runtime probe, первая/повторная установка;3 native
cquit13 controls,1 успешная установка/повтор/launch. Проверяется сохранение
runtime/config/bin/owner и command registration, остановка следующих stages,
child output/status/log и отсутствие нового ready launcher.

Windows initial1 PASS/3 FAIL/8 POSIX SKIP: assertion сравнивал разные разделители
путей. Ubuntu9 PASS/3 ERROR: nonzero и signal first cases делили имена каталогов.
При сохранении Ubuntu artifacts обнаружены оставшиеся после SIGKILL Unix sockets;
copy исключает non-regular nodes, сохраняет обычные logs/reports/fixtures.
Продуктовых изменений после первой правки не потребовалось.

Windows только3 failed nonzero:18.023s PASS. Ubuntu первый affected запрос
повторил3 уже прошедших nonzero и1 signal repeat для artifact-copy5.184s PASS;
это не закрывало3 first errors. Затем именно3 failed signal first3.900s PASS.
Все исходные logs и errors сохранены. Latest native12 cases:
Windows4 PASS/8 POSIX SKIP, Ubuntu12 PASS. Existing UI13 PASS на обеих ОС;
trace8 PASS/1 informational SKIP. Aggregate Windows25 PASS/9 SKIP,
Ubuntu33 PASS/1 SKIP. Full regression не повторялся.

Первый exploratory container по ошибке использовал bind stand вместо /tmp и
был остановлен только по известному ID6fda427308df; Desktop/WSL не управлялись.
Далее все Linux stands /tmp, artifacts на F. Неудачный первый запуск probe
не видел host .tests из-за bind overlay, скрипт перенесён в .tests/ubuntu.

## Bounds

Конфигурация/stages — fixtures, процесс/backend/SDK/launcher настоящие.
Это installer process lifecycle, не полный Default. Native macOS владельцем
остаётся открытым, Windows POSIX signals не эмулируются. SDK/locks/backports/
UI payloads и старые записи журналов сохранены; syntax/strict/trace gates пройдены.
