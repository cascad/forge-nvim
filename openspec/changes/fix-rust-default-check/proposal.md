# Proposal

## Why

IDE-131: plugins/lsp.lua принудительно выбирает cargo clippy --no-deps.
В user LSP log Flycheck завершается exit1: в выбранном custom toolchain нет
cargo-clippy. Обязательная компиляторная диагностика не должна зависеть от
необязательного линтера; это фиксируется новым IDE-RUST-1.

## What Changes

- Вернуть штатный cargo check и его обычные аргументы для проверки на save.
- Сохранить rust-analyzer, background checkOnSave, Cargo workspace и остальные settings.
- Проверить настоящую compiler diagnostic и исправление в окружении без Clippy.
- Оставить Clippy явной командой пользователя в Terminal/Tasks.

## Capabilities

### New Capabilities

- `rust-diagnostics`: IDE-RUST-1, базовая диагностика без обязательного Clippy.

### Modified Capabilities

Нет. Rust language baseline пока не описан в основных specs.

## Impact

Existing LSP settings, один case rust-language.test.lua, docs и история.
Project warmup, cold build/cache, Files latency и IDE-133 не входят в этот срез.
