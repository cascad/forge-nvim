## 1. Capture

- [x] 1.1 Добавить failure-preserving output attempt и опциональную bounded native trace; исходные assertions/timeout и production source не меняются.
- [x] 1.2 Проверить на настоящем Windows Rust/CodeLLDB до/после capture, включая запись ошибки при неуспехе и native exit/API errors/scopes; raw before/after сохраняются.
- [x] 1.3 Записать установленные факты и ограничения IDE-090, FIXLOG §162/HISTORY/команды/roadmap, quick/strict и проверку append-only; закоммитить завершённый диагностический шаг.

Windows:5 existing native checks PASS + trace2/control6 cycles PASS. Resize даёт сохранённый history RED только на padding; отдельный running probe показывает caller1419 от800ms watchdog. Это диагностические результаты, не runtime fixes. Negative pilot cleanup оставил dangling junction (IDE-094); native exit/Job/API errors проверены отдельно. Ubuntu/Mac не запускались.
