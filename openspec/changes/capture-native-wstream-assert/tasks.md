# Tasks

## 1. Capture boundary

- [x] 1.1 Подготовить явный debugger worker/launcher: bundled hashes/version/PDB, owned identity/Job и bounded attach/detach; native controlled assert/refusal/detach Windows E2E, указать platform boundary.
- [x] 1.2 Выполнить bounded original TUI trials, сохранить phase/PID/native caller stack либо явное отсутствие capture; не считать debugger-induced control оригинальным RED.
- [x] 1.3 Проверить affected harness, quick/trace/strict, записать commands/FIXLOG/HISTORY/roadmap/границы и commit. Product/selected SDK/pins не меняются; IDE-097 не закрывается без причинного evidence и исправления.

Результат:4 native control PASS,4 original trials без capture (debugger меняет
timing). Соседние проверки вместе с control17PASS/1POSIX SKIP, quick358/trace11,
strict84. Подробности: FIXLOG169 и docs/NATIVE_ASSERT_DIAGNOSTICS.md.
Диагностический шаг завершён; исходный IDE-097 и другие platform gates открыты.
