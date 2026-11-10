# Proposal

## Why

IDE-089: Windows `os_proc_tree_kill_rec` в закреплённом Neovim сравнивает только PPID. Native proof из §158 показывает завершение более старого собственного worker при устаревшей связи snapshot; это нарушает намерение завершать только потомков. Причина двух остановок Docker (IDE-087) ещё не доказана. Владелец уже выбрал временный проверяемый Windows SDK и поручил исправлять регрессии автономно.

## What Changes

- Проверять время создания parent/child перед рекурсивным завершением; при неизвестном времени не обходить эту связь.
- Закрепить отдельный process patch/hash, сохранить ConPTY patch.
- Собирать SDK отдельно от выбранного, проверять native fixtures и реальные Neovim jobs до замены; сохранять прежнюю сборку.
- Отвергать старый manifest без новых проверок. Обычный запуск остаётся пассивным, Linux/macOS используют официальный Neovim.

## Capabilities

### New Capabilities

- `editor-sdk`: IDE-BOOT-6 — ограниченный обход Windows process ancestry и проверяемое продвижение SDK; дополняет IDE-BOOT-3 из существующего change.

### Modified Capabilities

Нет изменений опубликованной базовой линии.

## Impact

Windows SDK patch/lock/resolver/preparer, native process diagnostics, CLI/editor E2E, руководство и история. Не меняет Docker/WSL, плагины, LSP или системный Neovim.
