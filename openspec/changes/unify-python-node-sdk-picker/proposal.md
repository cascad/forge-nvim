# Proposal

## Why

После §271 общий ForgeSdk обслуживает Go/Rust, а Python/Node уже имеют общие
резолверы tools.json, но не меню. Следующий согласованный пункт — дать выбирать
их установленную среду через тот же вход, сохранив native venv/project rules.

## What Changes

- Добавить Python/Node в Space l S / ForgeSdk: async версии/пути/источники,
  обнаружение доступных сред, ручной executable/root, refresh/cancel.
- Сохранять путь в существующий user/project tools.json без дублирования
  настроек в sdk.json. Сброс области наследует прежние user/legacy/native rules.
- Дать сохранить для следующих workflow либо явно переоткрыть проект с сессией;
  active work guard сохраняется. Не устанавливать SDK и не менять global env.
- Native E2E меню/settings/настоящих Python venv и Node процессов Windows/Ubuntu;
  Mac отдельно, прежние tools paths и Go/Rust menu остаются controls.

## Capabilities

### New Capabilities

- `python-node-sdk-picker`: IDE-BOOT-38 — единый вход выбора Python/Node.

### Modified Capabilities

Нет IDE main specs в текущей базовой линии; существующие резолверы сохраняются.

## Impact

ForgeSdk UI и Python/Node provider, атомарная запись tools.json, native editor
E2E/registry и документация/история. Installer/providers/update policy отдельно.
