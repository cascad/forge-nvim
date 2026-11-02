# Tasks

## 1. Постоянное воспроизведение

- [x] 1.1 Усилить native missing-remote проверку, добавить настоящий hook OSC/BEL/ST и parser matrix; сохранить RED на исходных dependency bytes и описать причину/границы в истории.

## 2. Исправление и явная подготовка

- [x] 2.1 Добавить pin/SHA util companion без изменения worktree primary; проверить LF/CRLF, legacy upgrade, неизвестный companion, реальный Lazy build и отсутствие записей при открытии, обновить инструкцию build/revert.
- [x] 2.2 Подготовить Windows зависимости явно, получить GREEN native/hook/parser; обновить тестовую документацию и команды, отличать UI E2E от parser matrix.

## 3. Интеграция

- [x] 3.0 Разделить SDK class через discovery с прежними лимитами (IDE-045); дождаться UI Head после checkout (IDE-046), проверить 8 SDK и три повтора branch/commit/push. Сохранить исходные два FAIL.
- [ ] 3.1 На уже работающем engine явно пересобрать образ, последовательно проверить Windows unit/e2e/trace и Ubuntu full, strict validate; дописать FIXLOG/HISTORY/ROADMAP/команды и локально закоммитить. Mac/GUI/неприменимые ветки обозначить непроверенными/SKIP.

Выполнены build, Windows full 40 PASS (486 checks), финальный workflow 6 PASS,
strict validate и Ubuntu full дважды. Последний Ubuntu: 41 PASS/2 FAIL/3 SKIP
(650 checks); все OSC/SDK/workflow PASS, прежние Gitsigns RPC/teardown — IDE-047.
Код/история локально фиксируются отдельным проверенным шагом. 3.1 остаётся
открытым до разбора IDE-047 и чистого Ubuntu полного результата; raw FAIL
не подменяется targeted PASS. Mac/GUI остаются непроверенными.
