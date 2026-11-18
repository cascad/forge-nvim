# Proposal

## Why

Владелец выбрал сохранение установленных Mason tools при повторной установке.
Сейчас pinned ensure_installed и strict readiness возвращают изменённый пользователем
tool к baseline. Новое IDE-BOOT-43 отделяет заполнение отсутствующих packages
от явного возврата к закреплённым версиям.

## What Changes

- Default preserve; CLI --tools-versions preserve|baseline, отражение в плане/логе.
- Native mason-tool-installer condition пропускает установленные pinned packages
  при preserve; отсутствующие получают прежний baseline/штатный provider.
- Postconditions проверяют receipt/exports при любом режиме, expected version —
  при baseline. Готовые Go tools не требуют нового compiler при preserve.
- Baseline явно возвращает только версии, закреплённые fride; остальные packages
  сохраняют штатные правила Mason. SDK/plugins/Neovim к этому выбору не относятся.

## Capabilities

### New Capabilities

- `managed-tool-version-policy`: IDE-BOOT-43.

### Modified Capabilities

- `managed-ide-tools`: IDE-BOOT-22 согласован с принятыми preserve/baseline и
  отдельным Go consent IDE-BOOT-42; прежние exports/SDK/Prettier условия сохранены.

## Impact

Existing catalog/readiness/setup/frontend/root flags, native Mason version E2E,
guides/история. Без своего updater, registry/version solver или фоновых операций.
