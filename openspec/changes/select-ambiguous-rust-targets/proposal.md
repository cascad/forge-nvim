# Proposal

## Why

Пункт3 продуктовой очереди требует понятного выбора цели запуска. Сейчас
rust_current_program при неоднозначных Cargo bin/example предупреждает,
но выбирает первый target. Дадим пользователю выбрать исполняемую цель.

## What Changes

- Native picker имени/kind только при неоднозначном автоматическом выборе.
- Отмена прерывает debug launch через штатный DAP ABORT.
- Сохранить выбор текущего source target, package-name bin, единственной цели
  и явный program из launch.json.
- Permanent E2E с двумя реальными Cargo binaries, отменой и CodeLLDB pause/output.

## Capabilities

### New Capabilities

- `rust-debug-targets`: IDE-DAP-7, выбор неоднозначной Cargo цели.

### Modified Capabilities

Нет.

## Impact

plugins/dap.lua, existing rust-language E2E и новая offline fixture,
RUST_WORKFLOW/LANGUAGE_MATRIX/roadmap/история. Cargo build task и зависимости
прежние; сборка example/особые build flags задаются проектной конфигурацией.
