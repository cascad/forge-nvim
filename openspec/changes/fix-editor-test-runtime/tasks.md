# Tasks

## 1. Диск и жизненный цикл

- [x] 1.1 Найти/проверить старые C runtime, зафиксировать объём и перенести подтверждённые профили на F с журналом; проверить остаток и свободное место.
- [x] 1.2 Вынести пути/маркер в общий runtime manager, очистить stop/start error, настроить Windows launcher; real runtime e2e Windows проверяет удаление, данные артефактов и чужой маркер.
- [x] 1.3 Получить red старого драйвера и green Windows/Ubuntu; проверить полный редакторский регресс, отсутствие прироста runtime после выполнения.
- [x] 1.4 Записать FIXLOG/HISTORY, PROBLEMS, команды, пути и ограничения платформ/автопроверки; проверить append-only старой истории.

## 2. Регресс

- [x] 2.1 Проверить scripts/test.ps1 quick, полный Windows/Ubuntu и strict validate; результаты и storage policy в E2E README/CLAUDE.

Примечание проверки: Windows full — 30 PASS / 1 FAIL (известный native crash IDE-027), новые сценарии PASS; Ubuntu — 32 PASS / 0 FAIL / 3 SKIP. Mac/GUI не проверены. Подробности — FIXLOG §89–90 и tests/e2e/README.md.
