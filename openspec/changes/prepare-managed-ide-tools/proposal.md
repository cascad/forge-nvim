# Proposal

## Why

IDE-138: managed setup объявляет успешность без gopls/stylua/gofumpt/golines/prettier, хотя существующие LSP/format consumers используют их. Инвентаризация §250 обнаружила этот пробел: components.tsv/tool_catalog не включают эти пакеты, а установка с чистой машины не должна требовать global go/cargo/npm install.

## What Changes

- Добавить пять существующих инструментов в текущий Mason setup с закреплёнными версиями: stylua в Core, три Go tool в Go, prettier в Node.
- Обозначить в Node checkbox также JSON/YAML/Markdown formatting; Core не получает обязательную зависимость Node. Пропуск Node не заявляет готовность Prettier.
- Использовать тот же package catalog при install и postconditions; проверять pinned receipt version и возможность существующего consumer найти инструмент/Prettier entrypoint.
- Не запускать установку на startup, не менять SDK homes и не устанавливать packages глобально. SDK build compatibility и full release readiness остаются явными границами.

## Capabilities

### New Capabilities

- `managed-ide-tools`: штатная подготовка уже используемых LSP/formatter tools внутри fride.

### Modified Capabilities

Нет.

## Impact

components.tsv, tool_catalog, LSP Mason opts и explicit setup postconditions; native setup/editor E2E, installer guide и история. Без новых LSP/SDK/provider, новых Rust dependencies, изменений lazy-lock/backports. Native Mac — отдельный запуск владельца.
