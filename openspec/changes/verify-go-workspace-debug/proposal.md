# Proposal

## Why

Очередь3/WF-05/07 требует подтвердить работу в настоящем Go.work с несколькими
модулями и локальной зависимостью. Сейчас current_file_configs('go') уже
использует native Delve/package/workspaceFolder; существующие DAP E2E берут
один go.mod. Поддержку workspace нельзя объявлять проверенной по одному модулю.

## What Changes

- Локальный двухмодульный fixture: app использует shared через go.work, без replace.
- Native E2E существующего IDE-DAP-1: F5 без launch.json, breakpoint/evaluate,
  stdout/stderr/Output после exit; правка shared через редактор и повтор F5 с
  новым результатом, без старого вывода.
- Документы показывают фактически подтверждённую часть Go workspace и границы ОС.
- Если backend уже работает, runtime не меняется. При найденном поведенческом
  баге до runtime правки потребуется delta/обновление change; private resolver
  и новый LSP не планируются.

## Capabilities

### New Capabilities

Нет. Это проверка существующего native поведения, `skip_specs: true`.

### Modified Capabilities

Нет. IDE-DAP-1 из fix-dap-output-lifecycle/debug-output покрывает первый и
повторный вывод; этот change добавляет реальный workspace контекст проверки.

## Impact

Только fixture/E2E/одна registry row, GO_TOOLS/LANGUAGE_MATRIX/roadmap,
FIXLOG/HISTORY/commands и verification. Готовые Editor/Go/Delve SDK;
ни plugins/pins/backports, ни setup/терминал/общая тестовая инфраструктура
не меняются. Ubuntu scope gate IDE-117 и native Mac остаются явными.
