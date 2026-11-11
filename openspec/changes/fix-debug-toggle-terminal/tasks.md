## 1. Regression и исправление

- [x] 1.1 Добавить два native CodeLLDB editor E2E; Windows source 5d07d2b даёт RED в обоих случаях, native exit/API errors записаны.
- [x] 1.2 Включить существующий PTY в общую Debug visibility/close; Windows новые2 и прежний output/panel/language regression проходят без изменения timeout.
- [x] 1.3 Прогнать Windows quick/strict и добавить историю FIXLOG §160 (IDE-PANEL-13 ADDED), HISTORY/PROBLEMS/roadmap/команды; сохранить неизвестность IDE-090/Docker.
- [x] 1.4 Запустить Ubuntu native regression при доступном engine: 2026-11-11 оба CodeLLDB/PTY cases PASS, прежний buffer/channel/pause и stdout сохранены (§170).
- [ ] 1.5 Native Mac/GUI и физические клавиши проверены владельцем; до результата Mac gate открыт, change не архивировать.

Windows:32 PASS/26 captured UI profiles, quick353/13files, strict76. Тогда Linux engine pipe отсутствовал. Ubuntu 2026-11-11:2 новых cases и общий22-check DAP/Output/language regression PASS (§170), image прежний, Desktop/WSL не управлялись. Mac не проверен. Исторический IDE-090 не приписывается одному caller без trace.
