# Design

## Context

Raw native before/after: POLICY_BEFORE42 и POLICY_STDERR сохранены, terminal channel/session/frame тот же; после UI140×45→140×35 исчезли лишь trailing blank rows. Это padding terminal grid, а не доказательство пропавшей истории.

## Goals / Non-Goals

Устранить ложный test failure, сохранить обнаружение потери текста и неизменность raw artifacts. Не менять UI, stdout или runtime buffers, не trim-ить REPL и внутренние blank lines, не увеличивать timeout.

## Decisions

- State читает настоящий buftype. Shared test predicate нормализует только trailing newline padding, когда оба buffers terminal; raw records остаются исходными.
- Unit constants проверяют shrink padding, lost nonblank prefix, internal blank loss, exact REPL и append. Native wrapper запускает реальный существующий Rust/CodeLLDB resize diagnostic с trace, проверяет actual raw substring mismatch и успешное semantic preservation.
- Source RED перед predicate fix и PASS после используют тот же resize scenario; nested controller исполняет тот же выбранный SDK, private editor scope cleanup проверяется.

## Open Questions

Native Ubuntu/Mac здесь недоступны; сценарий переносимый и явно не объявляется проверенным там.
