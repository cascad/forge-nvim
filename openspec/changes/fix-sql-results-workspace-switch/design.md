# Design

## Context

Причина проверки — proposal.md. ide.sql уже хранит records[root] отдельно
в каждом tab. select меняет выбранный root/record, render пока вызывается
только из open/update. ide.state.show идемпотентен, видимый component не
переоткрывает. UI должен проверять настоящее содержимое панели.

## Goals / Non-Goals

**Goals:** один путь обновления видимого SQL output после явного выбора,
без повторного query и без потери cache/background generation guards.

**Non-Goals:** SQL test framework/references IDE-062, native SDK/driver,
новые hotkeys/плагины и изменение общей идемпотентности ide.state.show.

## Decisions

1. Явный выбор root должен применять уже существующий render к выбранной
   записи. Не заставлять общий менеджер переоткрывать каждый видимый component:
   это изменило бы другие панели и могло бы повторять backend операции.
2. Пустой cache использует существующий placeholder; record не заимствуется
   у соседнего root. Completion callback обновляет buffer только если его
   root выбран. Общий контроль фокуса/zoom/hide остаётся прежним.
3. Real UI использует два existing SQLite workspace/helper и дополнительный
   workspace без query. Counters подтверждают отсутствие повторного SQL,
   реальный EXCLUSIVE lock подтверждает delayed callback, без canned output.

## Risks / Trade-offs

- Rendering может затронуть фокус/zoom → SQL focus/hide/zoom/help и late
  callback проверяются тем же UI; общие work-panel E2E выполняются отдельно.
- SDK/source baseline должны совпасть → d43c094 full config-source RED,
  действующий patched SQLS не меняется. Source/payload/test SHA сохраняются.
- Нет других ОС → Windows native E2E, Ubuntu/Mac явно непроверены; Desktop/
  WSL не запускаются, команды применимы к тем же тестам на машине владельца.
