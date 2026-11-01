# Tasks

## 1. Воспроизведение и исправление

- [x] 1.1 Добавить реальный Git gate и e2e закрытия загружающейся истории; получить red исходной сборки и сохранить артефакты Windows.
- [x] 1.2 Реализовать адаптер close с учётом backend lifecycle; проверить aliases, повтор, другой view и возврат файлов/геометрии e2e Windows/Ubuntu.
- [x] 1.3 Проверить начальный/пустой/готовый просмотр и повторное открытие без зависаний; e2e Windows/Ubuntu, без fixed sleep вместо готовности.
- [x] 1.4 Дополнить FIXLOG/HISTORY, QUICKSTART и PROBLEMS/ROADMAP: причина, изменение, red/green, ограничения; побайтово сохранить прежний FIXLOG.

## 2. Общий регресс

- [x] 2.1 Зарегистрировать набор, описать команды и артефакты в AGENT_COMMANDS/E2E README, явно указать Mac/GUI; проверить ссылки и strict OpenSpec validate.
- [x] 2.2 Выполнить полный Windows и Ubuntu регресс последовательно; записать фактические PASS/FAIL/SKIP и следующую задачу IDE-028.

Примечание проверки: Windows full — 30 PASS / 1 FAIL (известный native crash IDE-027), новые сценарии PASS; Ubuntu — 32 PASS / 0 FAIL / 3 SKIP. Mac/GUI не проверены. Подробности — FIXLOG §89–90 и tests/e2e/README.md.
