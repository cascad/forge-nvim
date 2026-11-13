# Design

## Context

См. proposal. session_views уже имеет version1 per-tab JSON и порядок
Files→Logs→next. Aerial управляет символами/выбором/scroll по code cursor;
native center_symbol_in_view вызывается при смене контекста и готовности данных.

## Goals / Non-Goals

**Goals:** открытость/геометрия Outline через существующие components/Edgy.
**Non-Goals:** arbitrary browsing scroll/folds вместо native follow, Tests
expansion snapshot, новый provider/state manager, plugin patches или timers.
Public on_first_symbols есть, но переопределять native centering этим срезом
не требуется. В Tests public summary API не даёт getter раскрытых узлов;
эмуляция private tree state не входит в этот change.

## Decisions

- Optional tab.outline=false/table(width,columns), nil — прежний snapshot.
  Та же version1/hash/tab-order/JSON. Код вкладки по-прежнему хранит mksession.
- После Files вернуть Outline, затем Logs. Left slot взаимоисключающий;
  ide.show('outline') использует native AerialOpen для текущего code buffer.
  Capture не сериализует символы и чужие внутренние структуры provider.
- Общую процедуру scheduled Edgy dimension/optional native winrestview
  перенести из Logs.restore_view в session_views local helper. Два пользователя
  теперь доказанно совпадают по геометрии, нового module/controller нет.
- Width масштабируется при меньших columns; minimum/clamping оставляет Edgy.
  Code focus и Files/Logs completion маршруты сохраняются.
- E2E: Lua provider из встроенного Tree-sitter Neovim (наличие проверено),
  реальные functions и native navigation; LSP/mock/parser download не нужен.

## Risks / Trade-offs

- Async symbol readiness → проверять реальные Aerial symbols в TUI; произвольный
  scroll не обещан и native follow не отключается ради теста.
- Left slot и Files → прежний Files session E2E и Outline focus controls.
- Logs geometry helper переезжает → прежний Logs native restart E2E.
- Windows/Ubuntu selected локально; Mac/physical явно отдельные gates.
