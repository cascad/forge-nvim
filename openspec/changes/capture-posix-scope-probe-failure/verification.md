# Состояние проверки IDE-117

**Текущая точка2026-11-18:**4/5 tasks завершены, native Ubuntu source/target и
Windows lifecycle выполнены; Mac открыт. Историческое состояние2026-11-12 ниже
сохранено, актуальные результаты — в конце документа.

2026-11-12. Source driver3d0e6b7 заморожен в .tests/ps-probe-baseline и
.tests/ubuntu/ps-probe-baseline. Product Lua и POSIX observer не менялись.

| Проверка | Фактический результат |
|---|---|
| Tasks |0/5 завершены; native source нужен до изменения observer |
| Permanent E2E | Подготовлены4 сценария: native code/signal/spawn и real ps delegation |
| Windows |0 PASS/4 platform SKIP; это не проверка POSIX behavior |
| Fixture syntax | Native Git Bash --noprofile --norc -n PASS; BASH_ENV/ENV пусты |
| Unit/trace Windows |371 PASS/1 SKIP,18 файлов PASS |
| OpenSpec |103 items strict PASS |
| Ubuntu source/target | Не запускались: pipe dockerDesktopLinuxEngine отсутствует |
| Mac | Не проверено |

CLI instructions apply: ready, planning complete, реализация не завершена.
Исходный ps отказ8785983585636/controller8785945678253 сохраняется; code/
signal/stdout из него восстановить нельзя. Причина не установлена. Код
проверяет только ps.code; native signal case ещё должен проверить гипотезу
об ошибочном принятии code0/signal9 как empty groups.

Native E2E использует настоящий clean Neovim/own PGID и частный executable
ps; vim.system/wait не подменяются. После восстановления PATH настоящий ps
отдельно проверяет own groups. Ошибка probe не является доказательством
empty scope. Windows SKIP и синтаксический контроль не засчитываются как
source RED/target PASS. Timeout/retry/fallback policy прежние.

CRITICAL:1.1–1.4 и2.1 не завершены. Desktop/WSL не запускались, не
перезапускались и не ремонтировались. Завершённый read-only tools review
зафиксирован отдельно (§195), не подменяет этот native gate.

## Обновление2026-11-18 — FIXLOG278

Helper exactbytes совпадает с git3d0e6b7, SHA256
3d208a6e5bd88e10cd547044d0132eb66cb8e2839c484af5ae1ebd8f9e7f32b0.
Checkpoint §275 уже дал3 negative FAIL/1 real control PASS; spawn fixture тогда
не обеспечивала ENOENT: execvp продолжал поиск в системном PATH. Для spawn PATH
ограничен private bin. Перед реализацией повторён только frozen source4 cases:
1 PASS/3 FAIL, code-case теряет result, signal ошибочно PASS, spawn теряет error.
Actual source receipt/test/fixture/driver bytes сохранены в
.tests/toolchain-research/probe-source-corrected.json и Ubuntu posix-scope-probe dirs.

Observer сохраняет argv/attempt/elapsed и full result либо spawn_error, принимает
успех только code0/signal0. Ошибка не превращается в empty groups. Timeout2s,
retry count и signal policy прежние. Successful process table не копируется.

Одна target iteration8 files на ОС:

| Проверка | Windows1794997892351697500 (39.94s) | Ubuntu1794997903402941773 (86.54s) |
|---|---|---|
| POSIX boundary |4 platform SKIP |4 PASS |
| Editor process/descendants/runtime/session/lifecycle |15 PASS/2 platform SKIP |14 PASS/2 platform SKIP |
| Trace helper unit |4 PASS |4 PASS |
| Root trace — существующий catalog WIP |5 PASS/48 FAIL/13 SKIP |5 PASS/48 FAIL/13 SKIP |

Итого affected process/helper19 PASS/6 SKIP Windows и22 PASS/2 SKIP Ubuntu.
Общий batch FAIL из-за отдельного root trace; его48 нарушений metadata/native
Python registration не объявлены исправленными и не скрываются фильтром PASS.
Далее отдельный catalog срез; прежние WIP bytes остаются без изменений.

Target negative results: code17/signal0/stdout marker/empty stderr; code0/signal9
с обоими markers; spawn_error ENOENT без выдуманного result. Во всех negative
scope.ok=false, active_after отсутствует, attempt1/probe_count1, root0/signal0,
APIerrors[], group signals не отправлены. После восстановления PATH настоящий ps
отдельно подтвердил отсутствие собственных живых групп. Real control:2 probes,
scope.ok=true, failure отсутствует. Cached stop сохраняет то же доказательство.
.tests/toolchain-research/probe-target-proof.json содержит native receipts.

Raw host logs probe-{source-ubuntu,windows-batch,ubuntu-batch}.txt; immutable
batch00/report сохранены. Syntax2, strict OpenSpec/diff/frozen/staged guards PASS.
Host tmp на F; Docker existing image/offline/limits2CPU/3GiB, без Desktop/WSL
management. Историческая причина117 и native Mac остаются открытыми.
