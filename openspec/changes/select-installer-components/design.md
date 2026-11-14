# Design

## Context

См. proposal. До установки Python/Neovim selection должен работать stock
PowerShell/Bash3.2. JSON потребовал бы дополнительного parser на POSIX.

## Goals / Non-Goals

Общий компонентный inventory, mandatory Core, dependency closure, native UI,
mask в существующих install/setup handlers. Не новый package manager или
универсальный dependency framework; только10 фиксированных записей.
Не полная readiness каждого selected binary на этом этапе.

## Decisions

TSV с непустыми полями id/label/deps/Mason/parsers. Hidden node-runtime
подтягивается Python/Bash/JS, go-runtime — Go/SQL. У Core нет toggle. Default выбирает все visible;
Custom начинает с Default, j/k/стрелки, Space, Enter, Esc/q; explicit CSV
обходит UI. Неизвестный ID отказывает до package steps.

Entry выбирает после получения source, перед backend; canonical mask живёт
только в процессе установки, PowerShell восстанавливает caller env. Backends
по mask делят runtime SDK и Terminal; Mason/parsers используют ту же таблицу.
Без mask legacy direct flags и manual install catalogs прежние.

Реальный HTTP/PTY stand проверяет выбор/передачу/cancel. Native policy/OS handler
contract проверяет selected package calls и catalog; host package operations
изолированы. Фактическая доставка всех выбранных SDK и полный clean-machine
acceptance остаются открытыми, ограничения явно в docs.
