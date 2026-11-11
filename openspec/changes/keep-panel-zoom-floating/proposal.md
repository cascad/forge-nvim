# Proposal

## Why

IDE-101 найден при IDE-076: после Space w z → ? native zoom Locals превращается в обычный split, теряя полную рамку. Frame trace17598934382700: win1019 relative=editor → relative="", restore не вызывался, session/frame прежние. Edgy ловит overlay по filetype; controls.zoom не задаёт штатный window-local opt-out. Старый IDE-PANEL-2 требует сохранять zoom/паузу; новый IDE-PANEL-18 уточняет границу размещения.

## What Changes

- Пометить native zoom документированным window-local edgy_disable; исходный split/shared buffer остаётся в Edgy.
- Zoom сохраняет floating geometry и рамку, пока поверх него открыта помощь. q/Esc/restore/focus и штатное изменение размеров не меняют DAP/job/output.
- Постоянный native DAP E2E с source RED до marker, теми же Windows/Ubuntu PASS и соседним регрессом. Без нового контроллера, plugin patch или таймера.

## Capabilities

### New Capabilities

- `panel-zoom-placement`: IDE-PANEL-18, overlays принадлежат controls и не перехватываются docking.

### Modified Capabilities

Нет: main specs ещё не содержат nvim baseline; прежние IDE-PANEL-1…17 сохраняются.

## Impact

Window marker и явный возврат в код при исчезновении source в ide/controls.lua (4 добавленные строки), debug-panels E2E и документация/история. Native API Edgy уже поддерживает этот признак (README, lua/edgy/layout.lua:113). Отдельный test-only RGB/frame prototype остаётся в prototype-panel-frame-styles; этот fix не включает оформление по умолчанию.
