# Proposal

## Why

Матрица языков после §113 подтверждает Go/Node/Python на Windows, но Rust
имеет только настройку и отрицательный codelldb discovery E2E. Следующий
пункт принятого roadmap — реальные LSP/format/debug/test в Cargo workspace.

## What Changes

- Явная подготовка тестовых Rust tools/parser с manifest/hash и отдельными
  cache/temp/target на диске checkout; установленный host SDK не обновляется.
- Настоящий workspace с двумя local crates, несколькими binary targets,
  unit/integration pass/fail tests, Unicode/пробелами и без сетевых dependencies.
- UI E2E navigation/rename/completion/diagnostics/format, F5 default/project,
  breakpoint/eval/continue/output, nearest/file/debug тестов.
- Registry, простые команды, platform limits и append история/матрица/roadmap.
- Доказанный runtime FAIL получает отдельные ID/delta/source RED до fix.

## Capabilities

### New Capabilities

Нет: tests/tooling/docs; skip_specs: true.

### Modified Capabilities

Нет: проверяется существующий Rust workflow. IDE-DAP-4/5 discovery/lifecycle
сохраняются; найденные нарушения не обходятся fixture configuration.

## Impact

tests/e2e, tests/lib, registry, явная Ubuntu подготовка, docs и FIXLOG.
Runtime plugins/pins/hotkeys не меняются этим change. На Windows обнаружены
Rust 1.96.1/rust-analyzer/rustfmt/clippy/rust-src и CodeLLDB 1.12.2; наличие
не является PASS поведения. Ubuntu engine недоступен, Mac запускается владельцем.
