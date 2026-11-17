# Proposal

## Why

Общий tools.json уже используется Python/Node/Bash/Sqruff. Go/Rust IDE tools
остаются привязаны к PATH, а неверный Delve override молча заменяется другим.
Нужен единый выбор без новых SDK wrappers или глобальной подмены окружения.

## What Changes

- Подключить gopls/rust-analyzer, gofumpt/golines/rustfmt, dlv/codelldb
  к project/user пути и общим логам.
- Сохранить native LSP roots, go.work/Cargo workspace, native SDK environment
  и существующий fallback выбора установленного Delve/CodeLLDB.
- LSP путь выбирать для его root; formatter — для обрабатываемого
  файла; DAP — для запускаемого проекта. Invalid explicit path не заменяется.
- Владелец выбрал native SDK environment как основу (вариант1, §270).
  Отдельные go/cargo executable overrides внутри всех test adapters не входят
  в этот срез. Следующий продуктовый этап — явный выбор существующей SDK среды
  с ручным путём и при необходимости переоткрытием проекта; см. IDE_ROADMAP.
- Gotestsum остаётся штатным PATH tool: pinned adapter делает fallback до
  публичного RunSpec. Его отдельный путь требует upstream API, не runtime patch.

## Capabilities

### New Capabilities

- `go-rust-tool-paths`: IDE-BOOT-36 — пути существующих Go/Rust IDE tools.

### Modified Capabilities

Нет main IDE specs, предыдущие контракты находятся в changes базовой линии.

## Impact

Общий resolver и существующие LSP/format/DAP/tests consumers, native E2E,
руководство и история. Установка/версии SDK, новые адаптеры и их patching не входят.
