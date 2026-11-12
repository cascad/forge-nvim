# Design

## Context

См. proposal. Backport IDE-053 уже отличает unexpected stdio exit от client
close до onexit. Config wrapper повторно подавляет результат по имени процесса.
Прежний negative E2E называл adapter forge_failure и не покрывал этот фильтр.

## Goals / Non-Goals

**Goals:** передавать уже классифицированное предупреждение backend в UI/store.
**Non-Goals:** новая классификация процессов, изменение patch/SDK, Go/TCP policy,
session manager или фильтр по номеру exit code.

## Decisions

- Удалить benign_patterns/loop debugpy из существующего wrapper.
  Native original_notify остаётся единственным путём для stdio exit WARN.
- Сохранить Go flags/filter: server-spawn callback отличается от stdio и
  не использует тот же client-close guard. Удалять его по аналогии нельзя.
- Тест задаёт публичную adapter configuration, вызывает настоящий debugpy
  с invalid option. Native process/argparse/stderr/session не подменяются.
  Target также проверяет ForgeLogs и редактирование после warning.

## Risks / Trade-offs

- Возврат ложного normal-close WARN → actual Python/pytest debug и raw logs.
- Изменение других adapters → Go output/panic и Python custom failure control.
- Hit-enter ожидаемого WARN → точный ack_warning только нужного type/exit2.
