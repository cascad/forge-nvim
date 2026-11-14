# Verification

2026-11-14. IDE-138 / IDE-BOOT-8. Base bde7b52. Новая transport feature;
не source/target воспроизведение старого native install и не full Default PASS.

## Проверено

Windows PowerShell5.1, tests/install-bootstrap.test.py: финальные6 distinct
PASS. Stand скачивает сам entry через HTTP и исполняет ScriptBlock, затем
настоящий ZIP download, .NET SHA/extraction, persistent source/fixture backend.
UTF-8/Unicode/space paths на F;7 invocations включая repeat, source directory
один, sentinel повтором сохранён, staging пустой. Отказы404/incomplete source/
broken archive/incomplete cache проверяются по конкретной причине и не вызывают
backend. Отказ backend7 возвращается как7, source остаётся для диагностики.
Stand не устанавливает host packages и не читает/переписывает личный IDE config.

Первый run:6 cases/2 FAIL, Get-FileHash не распознан. Negative cases тогда
проверяли только nonzero, поэтому их4 initial PASS не доказывают нужные ветки.
Встроенный .NET SHA и точные negative assertions →6 PASS. Затем code review
сохранил separator SourceRoot drive root; новая версия один раз6 PASS.
Raw logs .tests/install-bootstrap-windows{,-final,-verified}.txt, artifacts
пути напечатаны в них. summary содержит entry/test SHA, HTTP requests;
run-*.json — exact argv/output/exit. Audit проверил текущие bytes/records/cache,
SDK/lock/backports/legacy installers/frozen drafts и append-only journals.
Первая версия audit ошибочно ожидала7 records у run с первым failed case:
до repeat тогда не дошли; исправлен только audit count, E2E не повторялся.

Git Bash bash -n install.sh — PASS; это только syntax, не native POSIX E2E.
Ubuntu docker version отказал: dockerDesktopLinuxEngine channel отсутствует.
Compose не выполнялся, Desktop/WSL не запускались/не ремонтировались. Владельцу
задан async вопрос; команда Ubuntu stand сохранена. Mac не запускался.

## Открыто

tasks1.3 не закрыт: нужен native Ubuntu transport. tasks2.1 — native Mac.
Полные Default/Custom, package prerequisites, supported SDK delivery,
lock/backports/parsers/tools setup и actual installed editor acceptance
остаются дальнейшей очередью IDE-138. Новые files не опубликованы/pushed;
публичные one-liners до готовности этого пути не обещаны. Legacy installers
не изменялись; их direct remote clone/preparation gaps описаны в inventory.
Нового Neovim запуска, SDK downloads/builds, Docker lifecycle, OS changes
или проверки whole suite здесь не было. Host temp и артефакты на F.
