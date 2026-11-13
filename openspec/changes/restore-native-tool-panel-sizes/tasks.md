# Tasks

## 1. Native Tests и отложенные размеры процессов

- [x] 1.1 Добавить session-tool-views.test.lua с настоящими Tests/Bats, Terminal echo и Bash DAP; один Windows source до runtime, реальные RED/ошибки и артефакты сохранить.
- [ ] 1.2 Расширить прежние sidecar/setup/native size helper и применить решение владельца без запуска процессов из restore. Один Windows target + Files/Logs/Outline/Terminal/DAP выбранный регресс; реальные размеры/absence auto session/installs0 проверить E2E.
- [x] 1.3 Один Ubuntu прогон той же версии через готовый image/SDK, без build/lifecycle; Mac/physical явно непроверены.
- [x] 1.4 FIXLOG220 со строками Спека: IDE-PANEL-27/28 (ADDED), HISTORY/roadmap/guides/commands; strict/diff/prefix/frozen/index guards, реальные verdicts/границы и commit законченного шага.

Windows gate задачи1.2 пока открыт: новый функционал3 PASS, основной selected21
PASS/1 FAIL (IDE-129). Один отдельный instrumented probe PASS не закрывает
исходный native quit latency. Причинного исправления нет; без нового проявления
не запускаем повтор общего набора и не повышаем timeout.
