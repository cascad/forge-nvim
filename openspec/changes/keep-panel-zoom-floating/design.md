# Design

## Context

См. proposal. Pinned Edgy README документирует vim.w[win].edgy_disable; layout.lua:113 проверяет его до выбора view. controls.zoom создаёт отдельный float с shared buffer. Поэтому buffer-local disable затронул бы также исходную панель.

## Goals / Non-Goals

**Goals:** сохранить native zoom и прежние controls одним window-local признаком.

**Non-Goals:** менять default style, Border renderer, layout/state machine, backend API или SDK. Цветной test-only prototype отдельный.

## Decisions

- После native nvim_open_win пометить только новый window документированным edgy_disable. Флаг исчезает вместе с окном, новой lifecycle группы/registry нет.
- Старый IDE-PANEL-2 regression после marker выявил зависимость focus cleanup от Edgy: source уже закрыт, overlay удалён, но current стал другой Debug-секцией. Existing refresh теперь явно вызывает focus_code только при невалидном source; обычный явный выбор другой панели не перехватывается.
- Native DAP E2E до runtime edit: source zoom→help обязан показать docking RED без загрузки preview. После fix тот же сценарий сохраняет floating300ms, original geometry/IDs/buffer, pause/stdout и возврат через q/Esc.
- Запуск Windows/Ubuntu последовательно, Mac/GUI отдельно; source immutable archive2719e39. RGB tooling не считается причиной этого source отказа и не маскирует его.

## Risks / Trade-offs

- Нельзя ставить buffer flag → проверить shared buffer и отсутствие disable у original window.
- Edge refresh асинхронен → bounded negative observation300ms, actual config и сохранённый JSON до assert.
- Другие zoom backends → общий marker и существующие tool/debug/outline/buffer regression.
