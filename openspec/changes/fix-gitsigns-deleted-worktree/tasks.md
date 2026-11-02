# Tasks

## 1. Исчезнувший worktree и подготовка

- [x] 1.1 Сохранить постоянный real Git gate/argv proxy и UI regression исходного ENOENT; проверить red replay прежнего Gitsigns на Windows и green на Windows/Ubuntu, не синтезируя Git результаты.
- [x] 1.2 Добавить pin/SHA Gitsigns backport и явный выбор одного плагина; проверить CLI apply/check/revert/unknown и настоящий Lazy build на Windows/Ubuntu, обновить руководство подготовки.
- [x] 1.3 Проверить оба UI сценария с последующим stage/unstage и сохранностью main/linked на Windows/Ubuntu; Mac оставить непроверенным. Проверить поздние callback и отсутствие ERROR/hit-enter.
- [x] 1.4 Дописать FIXLOG §99 со строкой `Спека: IDE-GIT-8 (ADDED)`, HISTORY, roadmap/PROBLEMS, команды и E2E покрытие; проверить неизменность прежнего префикса истории и ссылки.

## 2. Интеграция

- [x] 2.1 Проверить прежние Git/worktree/deleted-file и подготовку на Windows/Ubuntu, Windows ConPTY, unit/trace, strict OpenSpec validate и git diff --check; записать точные результаты и ограничения.

Результаты 2026-11-02: новый contract 2 UI + 7 подготовки PASS Windows/Ubuntu;
Ubuntu full 40 PASS/0 FAIL/3 SKIP (41 файл/43 прогона). Windows targeted
6 файлов PASS/1 FAIL: Permission denied active delete (IDE-038), отдельный
повтор 2 PASS не считается фиксом. Unit/trace прошли; ConPTY 65 PASS/1 FAIL
сравнения RU Ctrl+/ (IDE-039). Единичный RPC timeout сохранён как IDE-040.
Все raw FAIL сохранены, эталон ConPTY не менялся; 2.1 означает выполненные
проверки с этими ограничениями, а не полный Windows PASS. Следующий шаг —
IDE-038/039. Mac/GUI и старые IDE-031/036 не объявлены исправленными.

После завершения проверок закоммитить шаг и продолжить roadmap. IDE-031/036,
исходный Mac startup и Mac/GUI здесь не объявлять исправленными.
