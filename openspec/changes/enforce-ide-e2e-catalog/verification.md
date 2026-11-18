# Verification

2026-11-18.5/6 tasks выполнены; native Mac открыт, archive не выполнялся.

Frozen8c92268 exact Lua drivers и первоначальные12 native CLI cases дали
Windows3 PASS/9 FAIL, Ubuntu3 PASS/9 FAIL. Старый trace давал false PASS готовым
контрактам без E2E и не поддерживал JSON. Native argv/exit/stdout/test/driver
сохранены в .tests/{ubuntu/,}e2e-catalog; host logs catalog-source-*.txt.

Общий native inventory обнаружил отдельный report bug: при переданном registry
Python suites пропадали из JSON обычного runner. Новый native case дал Windows
14 PASS/1 FAIL (PENDING вместо REGISTERED), затем with_native применяется в обеих
ветках. Log: .tests/toolchain-research/catalog-report-source-windows.txt.

Изменения: ADDED/MODIFIED proof metadata, inline Проверка после Платформы;
недостающие Peek/sorter/Outline/SDK/setup ссылки; единый native_suites в batch_plan
для planner/trace вместо Python glob;24 прежних suites и runner в JSON. Два
настоящих CLI/Core gate cases выделены из unit в tests/e2e/test-batch.test.lua,
pure selection остался unit. Container shell drivers — helpers; ancestry
diagnostic вынесен в Диагностика, его три E2E сохранены. Unit/manual не стали E2E.

| Проверка | Windows | Ubuntu |
|---|---|---|
| Initial6 files |1794998513992668800,3.74s,PASS |1794998526164990090,41.67s,PASS |
| Report correction affected3 |1794998601054979200,2.78s,PASS |1794998614235167482,46.63s,PASS |
| Final root после Outline proof |exit0,146 REGISTERED/1 PENDING/0 MISSING |exit0,та же сводка |
| Selected SQL references |exit1,IDE-SQL-9 MISSING |exit1,IDE-SQL-9 MISSING |

Latest affected:38 PASS/2 informational SKIP на ОС,6 файлов. Native catalog15,
batch CLI2, selection unit2, spec index7, mutation trace4, root8. Root после
Outline проверен отдельно: manual metadata отсутствует и SQL PENDING дают2 SKIP;
до Outline batch имел3 SKIP. Это presence, не runtime/platform feature PASS.
JSON: .tests/toolchain-research/catalog-root-windows.json и
.tests/ubuntu/catalog-root-ubuntu.json. SQL references не реализованы и не
архивированы; text search не выдаётся за semantic references.

Syntax10 Lua/AST Python, strict изменённых OpenSpec/diff/frozen/raw+staged checks
PASS. Все14 failed файлов §275 имеют affected PASS после §276–279; новый полный
checkpoint не запускался. Terminal/Default/native Mac открыты. Host tmp на F,
Docker existing/offline/2CPU/3GiB; Desktop/WSL не управлялись.
