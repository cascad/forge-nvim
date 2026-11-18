# Design

## Decisions

Использовать публичный condition mason-tool-installer для pinned spec в preserve.
Он проверяется при явной установке, не сканирует packages на startup. Baseline
сохраняет прежний pinned spec: native manager устанавливает другую выбранную
версию. Unpinned specs и ручные обновления через :Mason остаются штатными.

Readiness получает явные options.preserve_versions; default его strict API
сохраняется для publisher/диагностики. Setup stage передаёт policy одинаково в
build guard и postconditions. Экспорт/receipt ошибки не маскируются preserve.
Кастомные executable paths и проектные SDK не меняются. Consent Go download
остаётся отдельным. Переданный parent env не подменяет CLI choice frontend.

## Non-Goals

Автоматический latest на startup, закрепление всех upstream packages вместо
их менеджера, откат plugins/SDK, собственный dependency solver и обещание
совместимости произвольной вручную установленной версии со всеми языками.

## Verification

Один законченный affected Windows/Ubuntu пакет: native frontend/private Neovim,
реальный Mason/local HTTP и настоящий self-versioned fixture executable v1/v2:
missing install, manual v2 preserve, baseline v1 reset, failures/receipts/aliases,
Go readiness unit и existing controls. Native Mac отдельно.
