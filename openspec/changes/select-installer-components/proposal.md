# Proposal

## Why

IDE-138 требует Default и Custom с галочками. После delivery/setup нет общего
выбора: WithLanguages включает сразу несколько SDK, Mason/parsers готовят весь
каталог независимо от выбора. IDE-BOOT-10 добавляет selection policy и её
применение, не объявляя ещё не проверенные binary delivery/полный Default готовыми.

## What Changes

- Общая таблица Core/Go/Rust/Python/JS/Bash/SQL/Terminal и Node runtime dependency.
- Default без меню, Custom клавиатурой, explicit components для unattended.
- Entry передаёт canonical mask; OS SDK steps, Mason/parsers и Terminal
  учитывают его. Без mask прежний advanced workflow сохраняет поведение.
- Native interactive/HTTP/profile-policy E2E; package handlers в stand
  изолированы, host software не устанавливается.

## Capabilities

### New Capabilities

- `installer-components`: выбор и применение профиля установки.

### Modified Capabilities

Нет. IDE-BOOT-8/9 сохраняются; package registry/binary readiness/SDK distribution
и native Mac остаются отдельными этапами общего IDE-138.

## Impact

Entry/platform scripts, общий TSV и небольшие native shell/Lua readers,
Mason/Treesitter setup policy, stand/docs/history. Daily startup не получает
новых установок. SDK/pins/backports не меняются; Ollama/моделей нет.
