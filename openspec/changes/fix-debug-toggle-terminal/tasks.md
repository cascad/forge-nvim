## 1. Regression и исправление

- [x] 1.1 Добавить два native CodeLLDB editor E2E; Windows source 5d07d2b даёт RED в обоих случаях, native exit/API errors записаны.
- [x] 1.2 Включить существующий PTY в общую Debug visibility/close; Windows новые2 и прежний output/panel/language regression проходят без изменения timeout.
- [x] 1.3 Прогнать Windows quick/strict и добавить историю FIXLOG §160 (IDE-PANEL-13 ADDED), HISTORY/PROBLEMS/roadmap/команды; сохранить неизвестность IDE-090/Docker.
- [ ] 1.4 Запустить Ubuntu native regression при доступном engine; Mac не проверен, gate открыт.

Windows:32 PASS/26 captured UI profiles, quick353/13files, strict76. Read-only docker version: Linux engine pipe отсутствует; контейнер не создавался, Desktop/WSL не запускались. Команда Ubuntu записана в tests/e2e/README.md. IDE-090 не объявлена исправленной.
