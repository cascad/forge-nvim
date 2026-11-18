# Proposal

## Why

§288 выявил два actual installed Rust Tests отказа: Default не обеспечивает
cargo-nextest; file run main.rs/lib.rs пропускает тесты вне mod tests, вопреки
IDE-TEST-3. Владелец выбрал normal CARGO_HOME/bin, reuse/preserve и upstream.

## What Changes

- Проверять nextest отдельно от Rust SDK/Mason; показать штатное existing/
  install/skip/refresh/cancel меню. Official installer готового binary только
  после отдельного выбора; ready версию сохранять, чужой файл не заменять.
- Поддержать user/project cargo-nextest path через общую настройку и native
  Neotest RunSpec; missing tool понятен в Logs, без startup downloads.
- Исправить root file selection на прежнем pinned adapter через существующий
  hash-guarded backport, сохранив nearest/workspace/integration/debug.
- Один affected пакет/ОС после всей реализации, затем only failed repeats и
  Rust-only actual installed acceptance. Mac отдельно.

## Capabilities

### New Capabilities

- `rust-test-runtime`: IDE-BOOT-49, подготовка готового native nextest.

### Modified Capabilities

Нового контракта Rust file selection нет: исправление existing IDE-TEST-3.

## Impact

Frontend native prerequisite actions, shared Lua resolver/setup/runtime, pinned
neotest-rust backport, native regression/docs. SDK/PATH/profiles не переписываются;
нового test adapter/package manager/registry или сборки nextest не требуется.
