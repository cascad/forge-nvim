# Tasks

## 1. Rejected push

- [x] 1.1 Добавить IDE-GIT-10 real editor E2E divergence → push → отказ force → подробности `$` → явное согласование fixture → retry; проверить native Windows, сохранность refs/index/файлов и отсутствие force, описать команды/ограничение UI merge.
- [x] 1.2 Добавить E2E отсутствующего origin → видимая причина → код → исправление URL → retry того же commit; проверить Windows и сохранить Git/UI/notification артефакты, зарегистрировать оба сценария.

## 2. Интеграция

- [x] 2.1 Выполнить новые и прежние Git workflow E2E Windows/Ubuntu последовательно, strict validate/trace; записать FIXLOG/HISTORY/ROADMAP/команды и реальные ограничения Mac/GUI, локально закоммитить завершённый шаг.

Итог: Windows/Ubuntu по 2 новых и 6 прежних PASS; после строгого контроля
hit-enter новые 2 повторены на обеих ОС (confirmed logs). Trace обеих ОС
7 PASS/1 SKIP, strict validate PASS, 167 local links/prefix/test SHA PASS.
Runtime/pin/SDK не менялись. IDE-043 title tail, credentials, UI merge/rebase
и Mac/GUI остаются открытыми. Полные результаты и raw FAIL — FIXLOG §102.
