# Proposal

## Why

SDK picker/setup используют Lua settings, frontend preflight — отдельный PATH
поиск. Владелец2026-11-18 выбрал: сначала verified Core, затем SDK через общие
Lua resolvers. Это позволяет установке на чистой машине читать тот же выбор.

## What Changes

- Подготовить только Core до language SDK preflight существующим SHA transport;
  Core может скачаться даже при missing SDK. Target/обычный nvim не заменяются.
- Запустить Core без init/plugins, получить shared Lua user-scope SDK snapshot;
  Rust сохраняет bounded version probes и action UI, не реализует settings resolver.
- Согласовать private setup с user-scope; project choices остаются для открытого
  проекта, Git/--sdk-path fallback сохраняет прежний native контракт.
- Добавить native frontend/delivery/settings regression и docs/history;
  previews/print-plan не получают Core и не запускают SDK CLI.

## Capabilities

### New Capabilities

- `shared-sdk-preflight`: IDE-BOOT-40 — shared SDK settings через verified Core.

### Modified Capabilities

IDE main specs ещё нет; прежний SDK-before-any-artifacts порядок заменён
согласованным Core-before-SDK. SDK installation по-прежнему только явно.

## Impact

Frontend/runtime preparation, PS/Bash transport prepare-only, shared Core
validation/Lua SDK snapshot, SDK/setup options, native tests и руководства.
Без новых SDK managers/providers, без frontend Lua engine и копирования resolver в Rust.
