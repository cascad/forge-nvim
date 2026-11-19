# Proposal

## Why

§285–289 проверяют actual installed Default с готовыми SDK/cache. Они не
доказывают холодный путь IDE-138: чистая Ubuntu, native SDK actions, реальные
downloads/setup и первый запуск. Владелец поручил продолжить именно этот пункт.

## What Changes

- Выполнить настоящий Default через source/bootstrap/native frontend в отдельном
  чистом Ubuntu container: без SDK, fride profiles, Mason и plugin cache.
- Переиспользовать существующие native archives/PTY и installed observers;
  зафиксировать baseline, выбранные действия, stdout/logs и повторную установку.
- Найденные продуктовые отказы чинить отдельным FIX/change с regression,
  не заменять upstream SDK и не ослаблять readiness ради успешного теста.

## Capabilities

### New Capabilities

Нет. Это диагностический стенд для существующего installation contract.

### Modified Capabilities

Нет; skip_specs. Новый порядок установки SDK требует отдельного решения/артефакта.

## Impact

tests/diagnostics/containers, существующие installer/installed observers,
FIXLOG290/commands198/roadmap/history. Только собственные контейнеры2CPU/3GiB
и artifacts на F. Desktop/WSL и SDK/profile рабочей машины не меняются.
