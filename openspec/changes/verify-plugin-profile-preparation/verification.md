# Проверка установленного профиля

Продолжение 2026-11-13, FIXLOG226. Runtime/pins/SDK не менялись.

| Среда | Legacy3 | Полный setup | Case / Locals |
|---|---|---|---|
| Windows | 1 RED, точная config ERROR Neo-tree | 1 PASS | 8298ms / 359ms |
| Ubuntu | 1 RED, точная config ERROR Neo-tree | 1 PASS | 4668ms / 74ms |
| Mac | не проверено | не проверено | не проверено |

Один final запуск каждого варианта на каждой ОС. Одинаковые final test bytes;
native диагностические перехваты выключены. Native applier начинает с6 исходных
payloads, target all/check готовит16 files. Открыты Files, обычный файл, Tests,
Locals; notifications[], install0, dap.session nil, plugin bytes/mtime прежние.
Target native exit0/signal0/APIerrors[]/hard_kill=false/scope empty на обеих ОС.

Legacy native notification содержит `Failed to run config for neo-tree.nvim`
и `Backport neo-tree.nvim не подготовлен`, как в сообщении владельца. Parent
test FAIL на Files/RPC timeout из-за нативного error prompt, а не watchdog124.
Windows source cleanup1/signal15, Ubuntu0/0; scopes пусты, без hard kill/API
ошибок. Исходный bug доказывает ERROR, код выхода cleanup его не определяет.
Первый audit ошибочно требовал nonzero source native exit и отказал на
Ubuntu0/0; исправлена только эта проверка артефактов, E2E не повторялся.

Предварительный диагностический профиль39868897959000 PASS с native event/
Locals begin/end capture. Он отдельно от final source/target и не доказывает
причину старого обрыва33445583136000/124. В постоянном тесте сохранены stages;
`FORGE_PLUGIN_STAGE_TRACE=1` включает native capture при новом проявлении.
Deadline/RPC limit/SDK не повышались, иных runtime исправлений здесь нет.

Raw .tests/startup-stage-observed.txt/legacy.txt/target.txt/ubuntu.txt,
startup-stage-audit.json и guest .tests/ubuntu/startup-stage-*; copied config/
test и manifests сверены. Native профили: Windows39944011612800/40010990465400,
Ubuntu33928073232403/33942668160731. Ready imagef63a05ca/network none/private
Neogit overlay, Win/Linux serial, без build/download/Desktop/WSL lifecycle.
Temp F, frozen infra WIP/SDK/lock/backports прежние. Mac/physical owner review
отдельно; полный suite этим двумя случаями не заявлен.
