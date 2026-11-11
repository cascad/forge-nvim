# Proposal

## Why

IDE-097: native session profile45802477968200 показал assert !stream->closed в wstream.c, но точный процесс/caller/stack не сняты. Один повтор прошёл; suppress assert или новый SDK patch без причины не доказывают исправление.

## What Changes

- Подготовить явный диагностический захват через уже закреплённый CodeLLDB с PDB выбранного SDK; системный LLDB с отсутствующим python310.dll не использовать.
- Проверить захват controlled assertion в собственном Neovim и обычный detach, затем ограниченные native TUI trials; записать отдельно caller evidence и отсутствие воспроизведения.
- Отладчик подключается только к свежим PID собственного fixture, с удержанным identity handle, проверкой image/creation time и private owner metadata. Остановленный assertion target завершается после capture, чтобы не оставлять CRT popup.

## Capabilities

### New Capabilities

Нет: diagnostic/test-only, skip_specs:true.

### Modified Capabilities

Product config, выбранный SDK и его проверки не меняются; IDE-097 остаётся открыт до причинного доказательства и отдельного исправления.

## Impact

tests/diagnostics, при необходимости test-only helpers/E2E; явные команды, FIXLOG/HISTORY/план. Все temporary/log/profile на F:. Windows-specific debugger boundary отделена от общей сборки; Linux/macOS SDK прежние.
