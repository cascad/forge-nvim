# Proposal

## Why

Checkpoint §275 оставил отказы нескольких реальных workflow. Сохранённый
экран DAP содержит PROJECT_SINGLE с переносом строки; Rust fixture исключает
rust-analyzer из PATH вместе с Clippy. Это ошибки доказательства, а не основание
менять рабочие адаптеры. Остальные отказы надо разобрать по native артефактам.
После восстановления gopls обнаружен настоящий IDE-DAP-10/IDE-TEST-2 отказ:
probe_output yield попадает в nio coroutine, которую dap.async.run переиспользует.
Запуск теста через Space T d даёт hit-enter вместо Delve. Native stack сохранён.

## What Changes

- Исправить Rust fixture через поддерживаемый tools.json, сохранив отсутствие Clippy.
- Проверять фактические DAP argv и stdout независимо от терминального переноса.
- Согласовать Go prerequisites, SQL server и native scroll capture с текущим продуктом.
- В Git live-case ждать сохранности живого чтения; обязательный следующий ошибочный read оставить completed-case.
- Передать Delve discovery из callback в main loop, чтобы native DAP coroutine не нарушала nio protocol.
- После цельного исправления выполнить один затронутый пакет Windows/Ubuntu.

## Capabilities

### Modified Capabilities

- `go-debug-discovery`: IDE-DAP-10, запуск Go test debug из neotest без hit-enter.

Остальные исправления — fixtures/assertions существующих IDE-RUST-1,
IDE-DAP-1 и языковых контрактов. Подмена native процессов заглушками не допускается.

## Impact

Go adapter callback, существующие E2E и test helpers, документация и история. SDK/locks/backports
и чужой process/trace WIP не меняются. macOS проверяет владелец отдельно.
