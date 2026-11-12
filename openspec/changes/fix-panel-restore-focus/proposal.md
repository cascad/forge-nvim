# Proposal

## Why

IDE-116: Ubuntu panel-transitions после toggle all возвращает neo-tree вместо
кода. Native trace7aa0ba9: restore вернулся в text на8.8 ms, отложенный
navigate открыл дерево на66 ms и оставил фокус там на571 ms. IDE-PANEL-23
уточняет фокус восстановления, дополняя IDE-PANEL-21.

## What Changes

- Восстановление общего набора и fallback Files возвращают фокус в код после
  завершения штатного открытия Neo-tree.
- Более поздний явный выбор фокуса общими командами IDE сохраняется.
- Использовать existing Neo-tree lifecycle и публичные команды backend;
  сохранить видимость, данные, вкладки и процессы.
- Добавить постоянный native regression с удержанием настоящего callback
  navigate после штатного debounce в private root.

## Capabilities

### New Capabilities

- `panel-controls`: IDE-PANEL-23, фокус после восстановления. Основная IDE
  baseline пока в changes, прежние IDE-PANEL-21/22 сохраняются.

### Modified Capabilities

Нет.

## Impact

ide.state/init/registry и forge.neo_tree_lifecycle, native E2E/registry,
история Windows/Ubuntu. SDK/pins/backports, DAP/PTY и backend source не меняются.
Mac и physical delivery отдельно.
