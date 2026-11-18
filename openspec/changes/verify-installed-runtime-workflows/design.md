# Design

## Context

См. proposal Why; готовые native Default stands §285–287, tools не fixtures.

## Decisions

Использовать existing driver profile/ownership и editor_rpc/editor_process.
Отдельный observer создаёт маленькие application/test projects и вызывает
публичный DAP/Neotest; не подменяет adapter cmd и не копирует config из repo.
Project pytest/Jest — обычные зависимости, готовятся явно offline из прежних
native test inputs; они не становятся IDE SDK/packages. Для программы проверяются
реальный breakpoint, evaluate42, завершение и stdout, для теста — native passed
и output. По одному запуску/ОС, далее только affected failures.

## Non-Goals

Весь GUI/physical hotkeys, SQL/Bash расширения, новый runner/manager. Cold SDK,
Mac/WSL/publication остаются отдельно. Продуктовый баг фиксируется отдельным change.
