# Tasks

## 1. История при смене worktree

- [x] 1.1 Добавить real Git gate и editor e2e быстрого visit; получить red текущей ASCII-сборки на Windows с исходным traceback/артефактами.
- [x] 1.2 Выбрать штатный Unicode renderer, проверить gate, Head/recent/log и сохранность файлов/HEAD/index на Windows/Ubuntu.
- [x] 1.3 Добавить естественную серию быстрых visit без gate и проверить боковую панель/полный tab на Windows/Ubuntu без ожидания Head перед следующим переходом.
- [x] 1.4 Записать FIXLOG/HISTORY с причиной и red/green, обновить PROBLEMS/ROADMAP/QUICKSTART/команды/E2E README; проверить ссылки и неизменность старого FIXLOG.

## 2. Интеграция

- [x] 2.1 Пройти существующий Git и Diffview наборы, полный Windows/Ubuntu регресс последовательно, strict validate и git diff --check; сохранить реальные итоги/известный IDE-027, Mac/GUI отметить непроверенными.

Результат: новый набор 3 PASS на Windows/Ubuntu. Windows full 30 PASS / 2 FAIL, после исправления транспорта повтор двух файлов 2 PASS / 0 FAIL; исходный CLI timeout IDE-031 открыт. Ubuntu full 33 PASS / 0 FAIL / 3 SKIP. Подробности — FIXLOG §91; Mac/GUI не проверены.
