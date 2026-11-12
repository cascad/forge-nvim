# Verification — 2026-11-12

- Windows:1 PASS/0 FAIL/0 SKIP, profile19658831179000.
- Ubuntu:1 PASS/0 FAIL/0 SKIP, profile11708549389431.
- Каждый test запущен один раз на ОС; runtime не менялся, повторов не было.

На обеих ОС два реальных Go build/Delve launch через F5→Current Go package,
package path app, cwd workspace root, actual frame app/main.go. Go env GOWORK
указал fixture go.work. Shared dependency без replace/скачивания разрешена
workspace; после native редактирования return42→43 оба evaluate/вывода совпали.
Stdout/stderr получены до паузы, WORK_AFTER сохранён после exit, старый42 не
попал во второй вывод. Тест не подменяет adapters/сессии и не вызывает dap.run.

Shutdown обоих profiles: root0/signal0/APIerrors[], owned scopes пусты.
Config/test copies и shared/answer.go после редактирования проверены audit.
Raw .tests/go-workspace-{windows,ubuntu}/, .tests/go-workspace-audit.json;
Ubuntu artifacts .tests/ubuntu/editor-e2e/11708549389431. DAP trace сохранён.
Готовый Docker image использован без build/start/repair Desktop/WSL, сеть none.

Это новый контекст проверки существующего IDE-DAP-1. source RED/runtime fix
не заявляются. `skip_specs:true`, dependency/framework changes отсутствуют.
Workspace LSP/Tests, полный mixed project, Mac/physical отдельно не проверены.
