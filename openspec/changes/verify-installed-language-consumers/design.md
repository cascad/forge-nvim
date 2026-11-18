# Design

## Decisions

Использовать существующий editor_rpc/editor_process observer pattern. Parent
запускается managed launcher, child получает те же config/runtime/environment.
Observer создаёт маленький mixed project с Go/Cargo/package roots, открывает
каждый файл, ждёт actual LSP/diagnostics и вызывает настоящий :Format на валидном
исправленном тексте. Результаты и cleanup сохраняются. Manager install не вызывается.

## Non-Goals

Новая тестовая инфраструктура/goal loop, замена existing source regressions,
весь debug/test matrix, OS SDK install или объявление public release готовым.
