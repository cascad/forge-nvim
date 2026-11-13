# Proposal

## Why

После §215 Bash F5 использует native PTY, но interactive stdin и чтение
предыдущего вывода остаются открытым пользовательским сценарием WF-06/13.

## What Changes

- Два native keyboard E2E: breakpoint→читать scrollback→continue→ввести строку;
  отдельный Stop из terminal-mode, пока программа ждёт read.
- Windows с уже работающим default WSL2 и Ubuntu, существующие SDK/backend.
- Фиксация результата, ограничений и исправление доказанного дефекта при наличии.

## Capabilities

### New Capabilities

IDE-SH-6: изоляция Bash debug Stop от других Editor jobs и явная подготовка
проверенного SDK. IDE-128 подтверждён native Ubuntu sentinel RED.

### Modified Capabilities

Нет на этапе проверки готового поведения.

## Impact

Точечный SDK patch официального adapter, public F5 readiness guard/явная
подготовка; E2E fixture/registry/документация. Без нового backend/runner,
WSL/Docker lifecycle, новых plugin pins и переписывания stdin протокола.
