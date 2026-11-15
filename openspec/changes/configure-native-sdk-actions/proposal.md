# Proposal

## Why

IDE-BOOT-18 показывает missing/unavailable SDK и завершает setup. Следующий согласованный пункт §245 — дать пользователю выбор существующего SDK, штатной установки, пропуска зависимых компонентов или отмены прямо с клавиатуры.

## What Changes

- SDK action menu для нерешённых prerequisites, включая Default в TTY; noninteractive сохраняет отказ без установки.
- Existing path / CLI --sdk-path: проверка root/bin/Scripts, fallback paths после caller PATH. Запись выбранных locations в launcher metadata только после успешного IDE setup; без SDK homes и global PATH edits.
- Native package-manager install после отдельного review/confirm; логи, повторная проверка, error/retry без ложного success.
- Skip показывает зависимые компоненты и пересчитывает plan. Отмена оставляет прежний kit; уже явно установленные standalone SDK не удаляются.
- Обновлённый итоговый plan подтверждается до IDE backend; preview/check-sdks остаются read-only.

## Capabilities

### New Capabilities

- `native-sdk-actions`: IDE-BOOT-19, явные действия пользователя над prerequisites.
- `managed-install-locks`: IDE-BOOT-20, bounded Windows rename при реально найденном EPERM в UI control; permanent failure сохраняет rollback.

### Modified Capabilities

Нет main IDE specs. IDE-BOOT-17/18 сохраняются; новые fallback locations только по выбору пользователя.

## Impact

Native frontend/action modules, SDK report persistence, private setup/launch metadata, native PTY SDK cases и существующие readiness/delivery/UI controls. Windows/Ubuntu выполняются здесь; Mac/real package-manager installation — native owner acceptance. Реальные SDK на машине агента не устанавливаются, package manager в E2E — fixture.
