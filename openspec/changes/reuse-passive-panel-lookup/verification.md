# Verification — reuse-passive-panel-lookup

2026-11-11, source ef9e921. Schema spec-driven, skip_specs:true: внутренний
refactor без новых/изменённых требований, removal/rename нет.

| Измерение | Результат |
|---|---|
| Completeness | 4/5 после истории/commit; Mac/physical task2.1 открыт |
| Correctness | Spec coverage N/A: no delta. Source/target native2+2 checks на ОС, после изменения ещё37 прежних UI checks на ОС |
| Coherence | Два loops удалены, прежний activities API без изменения; net−16 строк/2 runtime файла, новый framework/module не появился |

Init передаёт составной FT/source predicate без FT аргумента; Lua and
сохраняет short-circuit source predicate. Registry проверяет FT каждого окна
в прежнем window-first порядке, metadata читается при каждом focus вызове.
Custom callbacks и nil default return сохраняются. Activities/main/guard и
lock source hashes совпали; backend/SDK/6 plugin patches не менялись.

`tests/e2e/window-lookup.test.lua` проверяет реальные normal/float windows,
несколько FT с противоположным приоритетом, live filetypes/empty/no-match,
background tab, topology, custom focus, реальные три Neo-tree sources и close.
Тот же test source сохранён во всех baseline/target artifacts и совпал по SHA.
Source PASS → target PASS; новый bugfix/source RED не заявляются.

Windows source46671175518500/46679011438200, target46757570198700/46764848030200.
Ubuntu source41647591409644/41652352422456, target41742980780220/41749461213202.
Финальный subset7 files: debug-panels, outline, file-explorer, work-panels,
tool-panels, ide-logs, frame-layout:37 checks/ОС. Вместе с target2 —39 checks/ОС.

Audit `.tests/lookup-audit.py` сверил actual config-source hashes baseline
и target во всех52 profiles:26/ОС, включая исходные4. Native root0/signal0,
APIerrors[], quit→exited, no hard kill, owned scope empty; Windows runtime
пути из snapshots отсутствуют. Evidence `.tests/lookup-evidence.json` и
архивы `.tests/lookup-regression-{windows,ubuntu}-logs` с JSON отчётами.

Unit/trace:360+11 PASS, trace1 SKIP на ОС. Strict OpenSpec95 PASS.
Scoped regression не заменяет global full, Mac и физические клавиши WezTerm.
Critical до archive: task2.1, выполнить на Mac и сохранить реальный результат.
UI removal ждёт выбора владельца; этим change optional plugins не менялись.
