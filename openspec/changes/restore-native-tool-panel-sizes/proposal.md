# Proposal

## Why

WF-01 уже возвращает Files/Logs/Outline. Tests теряет открытость и ширину;
после перезапуска прежние размеры Terminal/Debug не возвращаются. Владелец
выбрал: Terminal/Debug скрыты до явного открытия/запуска, затем вернуть размер,
без фонового shell/debug из восстановления сессии.

## What Changes

- Возвращать открытую Tests sidebar и её ширину по вкладкам/проектам.
- Сохранять размеры встроенной Terminal, debug sidebar и Output даже после
  скрытия; применять при следующем явном открытии, не запускать процессы.
- Расширить прежний sidecar/native dimension helper без нового backend.
- Native Tests/Bats, Terminal и Bash debug E2E, прежний session/panel regression.

## Capabilities

### New Capabilities

- `tests-session-view`: IDE-PANEL-27, native открытость/ширина Tests.
- `deferred-tool-sizes`: IDE-PANEL-28, размеры Terminal/Debug после явного открытия.

### Modified Capabilities

Нет. Full Tests expansion snapshot, per-section DAP высоты и произвольный
layout/scroll не заявляются; native follow/discovery остаются прежними.

## Impact

session_views, его setup в прежнем Persistence config, public Win/Buf events,
Edgy resize и существующие Tests/ToggleTerm/DAP components. Новых plugins/
SDK/providers/renderer/process manager и изменений shell profiles нет.
