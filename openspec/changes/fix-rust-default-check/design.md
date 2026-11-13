# Design

## Context

См. proposal. Действующий backend уже выполняет проверки асинхронно.
Неподходящий check command — самостоятельная причина отказа; менять backend
или его lifecycle ради этого не требуется. Native defaults: check/extraArgs[].

## Goals / Non-Goals

**Goals:** восстановить обязательную compiler diagnostic на минимальном
toolchain, не требуя Clippy; native source/target на одинаковом fixture.
**Non-Goals:** project warmup, смена features/proc macros, собственный cache,
новые LSP, Cargo wrappers/protocol mocks, устранение IDE-132/133.

## Decisions

- Заменить check.command и удалить --no-deps; сохранить остальные settings.
- Fixture копирует неизменённый Cargo в private directory, исключает Clippy
  из PATH/CARGO_HOME; настоящий cargo clippy --version подтверждает отсутствие.
  RUSTC и cmd rust-analyzer явно указывают прежний подготовленный native SDK.
  Ни один SDK binary не патчится, native Cargo/RA protocol не заменяются.
- Требовать compiler diagnostic source=rustc, проверить gl и save/correction.
  Настройки и native RA-only diagnostics не заменяют compiler result.

## Risks / Trade-offs

- Clippy lints больше не автоматические → явный cargo clippy в Terminal/Tasks.
- Холодная workspace подготовка остаётся дорогой → отдельный следующий срез;
  данный fix не объявляет compile-time deps/Files latency исправленными.
