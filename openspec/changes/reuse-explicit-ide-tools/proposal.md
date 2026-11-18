# Proposal

## Why

Владелец подтвердил: готовый IDE tool, явно выбранный в tools.json, удовлетворяет
setup; дополнительный Mason package не нужен. Runtime уже использует эти paths,
но setup требует все Mason receipts и build SDK даже для выбранного внешнего gopls.

## What Changes

- Общая setup проверка уже поддерживаемых user tool paths, без project overrides.
- Native MTI condition пропускает external tool в preserve и baseline; missing
  без override устанавливается как раньше. Startup не читает settings ради setup.
- Build guard/postconditions проверяют оставшиеся Mason packages; external paths
  проверяются отдельно и показываются в setup log с источником.
- Неверный путь/недостающий Node для JS entrypoint запрещает publication;
  путь внутрь заменяемых runtime/config/bin собственного kit не принимается.

## Capabilities

### New Capabilities

- `explicit-setup-tools`: IDE-BOOT-45.

### Modified Capabilities

- `managed-ide-tools`: IDE-BOOT-22 учитывает выбранный external tool вместо package.

## Impact

Catalog/setup и общий существующий resolver, native fixtures/E2E, guides/history.
Список инструментов и SDK managers не расширяется, publisher strict API прежний.
