# Proposal

## Why

IDE-117: process_scope_posix.close потерял code/signal/stdout отказавшего ps,
сохранив только пустой stderr. Исходный отказ не объяснён; повторный зелёный
session test не восстанавливает утраченные данные. Код также проверяет
только code, поэтому native signal требует отдельного отрицательного теста.

## What Changes

- Сохранить argv, elapsed, порядковый номер и полный native результат
  неуспешного ps probe; отдельно сохранять ошибку запуска команды.
- При code/signal/spawn failure оставлять cleanup FAIL и active_after
  неизвестным; не считать отсутствие результата пустым списком процессов.
- Добавить native E2E с настоящим clean Neovim/process groups и частным ps
  executable: nonzero code, signal, spawn error и delegation реальному ps.
- Source 3d0e6b7/target на Ubuntu, Windows normal lifecycle отдельно; Mac открыт.

## Capabilities

### New Capabilities

Нет; skip_specs=true, тестовый каркас, product policy прежняя.

### Modified Capabilities

Нет. Причину первичного ps failure этот change не объявляет установленной.

## Impact

POSIX boundary tests/lib/process_scope_posix.lua, native self E2E/fixture/
registry и test docs/история. Windows Job backend, SDK, pins, timeout и
signal policy owned groups прежние. Desktop/WSL не управляем.
