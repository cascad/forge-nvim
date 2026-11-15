# Proposal

## Why

После IDE-BOOT-17 SDK окружение сохраняется, но installer-ui/src/runtime.rs всё ещё требует архивы node-runtime/go-runtime из canonical closure. Так установка Node-функций при готовом системном Node требует упакованный SDK. Следующий согласованный срез §245 — отделить prerequisites и пассивно показать их готовность.

## What Changes

- Разделить итоговый plan на IDE components и native SDK prerequisites.
- Получать только IDE artifacts, отклонять SDK IDs как private artifacts.
- Добавить явную read-only проверку Go/Rust/Python/Node из PATH: пути, версия, missing/unavailable; ограниченный timeout, без SDK installs и auto toolchains.
- До скачивания artifacts остановить установку при нерешённом prerequisite; сохранить отчёт и показать действия для следующего шага.
- Preview/print-plan не запускают SDK; предоставить --check-sdks для отдельного отчёта.
- Перестроить delivery E2E: host Node плюс маленький IDE-tool part вместо копии всего Node SDK.

## Capabilities

### New Capabilities

- `native-sdk-prerequisites`: IDE-BOOT-18, отдельный план и пассивная проверка SDK.

### Modified Capabilities

Нет main IDE specs: предыдущие контракты находятся в changes. IDE-BOOT-17 сохраняется.

## Impact

Native frontend, shared install validation, runtime/UI tests и установка/docs/history. Штатные SDK install actions и выбор пути/пропуска в TUI — следующий отдельный пункт §245; в этом срезе SDK не устанавливаются. Новые LSP/providers/package managers не добавляются.
