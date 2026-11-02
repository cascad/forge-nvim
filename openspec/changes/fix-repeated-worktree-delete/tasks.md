# Tasks

## 1. Object read и реальный Git

- [x] 1.1 Сохранить CLI A/B живого show и UI live gate в tests/: marker PID/живой процесс, реальные code/stdout/stderr, source variant; проверить baseline remove 255 на Windows и контроль common cwd, в Ubuntu записать все пять native результатов.
- [x] 1.2 Проверить private candidate, обновить существующий Gitsigns pin/SHA backport и явную подготовку; исходный completed gate IDE-035 и live UI сценарии с разными HEAD, включая уже текущий linked cwd, должны пройти Windows/Ubuntu, repeat/check/revert и Lazy build тоже.
- [x] 1.3 Дописать FIXLOG §100 со строкой `Спека: IDE-GIT-9 (ADDED)`, HISTORY, PROBLEMS/roadmap, E2E docs и команды; сохранить прежний префикс истории. Отдельно записать, что владелец handle исходного случайного отказа не установлен; Mac/GUI не проверены.

## 2. Интеграция

- [x] 2.1 Прогнать прежние Git/worktree/active/deleted-file/Diffview и unit/trace на Windows/Ubuntu; записать результаты и исходные FAIL, проверить strict OpenSpec validate, неизменность source lock и git diff --check, затем коммитить завершённый шаг.

IDE-039/040 и другие причины Permission denied не объявлять исправленными.
Desktop/WSL не запускать/перезапускать ради тестов; использовать только уже
работающий engine. После коммита продолжать roadmap.

Итог: Windows unit/e2e/trace 38 PASS/0 FAIL/0 SKIP, 471 проверка;
Ubuntu full 41 PASS/0 FAIL/3 SKIP (42 файла/44 прогона), 640 проверок.
Live 4 + completed 2 + подготовка 8 PASS на обеих ОС. Previous baseline
8339345485800 даёт remove 255, upstream 8351711096700 — исходный traceback.
Промежуточные варианты и первый full с IDE-042 сохранены, их результаты
не подменяют итоговые verified reports. Mac/GUI/ConPTY IDE-039 открыты.
