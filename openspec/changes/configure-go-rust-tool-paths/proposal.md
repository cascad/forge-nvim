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
- SDK path overrides для самого go/cargo требуют отдельного решения владельца:
  текущие test adapters содержат hardcoded SDK commands. Пока SDK выбор штатный.
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
