# Tasks

## 1. IDE-027: native граница

- [x] 1.1 Получить свежие red обоих IDE-BUF-1, native exception/symbol и минимальный --clean resize repro; сохранить Windows artifacts.
- [x] 1.2 Вынести чистый probe в tests/diagnostics и единственный patch в scripts/sdk, проверить official red/passive и private patched green без debugger на Windows; контроль Ubuntu, понятные CLI/артефакты.
- [x] 1.3 Проверить исходные buffer e2e на candidate SDK, оформить FIXLOG/HISTORY/PROBLEMS/ROADMAP/команды с реальными границами; сохранить старые байты истории.

## 2. IDE-031 и целостность

- [x] 2.1 Проверить реальные CLI повторы с прежним timeout, сохранять диагностические данные ошибки, пройти E2E контракта диагностики; не закрывать исходный timeout без установленной причины.
- [x] 2.2 Проверить strict validate, trace/quick и git diff --check, отсутствие leftover runtime/C temp; зафиксировать дальнейший выбор поддержки SDK и непроверенный Mac/GUI.

## 3. Выбранный владельцем Windows SDK (IDE-BOOT-3)

- [x] 3.1 Вынести lock/patch и явную подготовку SDK, проверить source/patch/binary metadata; подготовить SDK на Windows, без изменения установленного Neovim.
- [x] 3.2 Подключить общий resolver к nvim_forge.cmd и scripts/test.ps1, проверять missing/stale/corrupt SDK, argv/exit/env и явный system override реальными CLI E2E Windows; проверить официальный POSIX launcher на Ubuntu.
- [x] 3.3 Пройти полный Windows регресс выбранным SDK, Ubuntu full, strict/trace; записать Спека: IDE-BOOT-3 (ADDED), историю и команды; Mac/GUI отдельно непроверены. Windows 37 PASS/1 FAIL (открытый IDE-032)/2 SKIP; Ubuntu final 36 PASS/0 FAIL/3 SKIP. Повтор Git на обоих SDK не объявлен фиксом, исходный full сохранён.
- [x] 3.4 Исправить найденную в full ConPTY границу: выбранный SDK, private config/data/cache/state и pinned plugins вместо пользовательских; реальный ConPTY E2E проверяет stdpath и source lock invariance Windows. Весь набор 66 PASS, 0 FAIL/SKIP; 0 runtime leftovers.
