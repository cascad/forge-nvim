# Proposal

## Why

IDE-090: одиночный Rust toggle failure остался без последовательности принятия/обработки клавиш и вызовов, открывающих sidebar. Старый helper пишет before/after только после успешных assertions; неуспешный history assertion также теряет сырые данные. Нужна доказательная диагностика, а не правка таймеров на предположении.

## What Changes

- Сохранять стадию, before/after Output и session при любом исходе настоящего reopen.
- Опционально собирать ограниченную native in-memory трассу клавиш, окон и публичных переходов Debug; без записи на каждом событии и без принудительной загрузки плагинов.
- Прогнать реальные Rust сценарии с capture и без него; сохранить неизвестность причины, если отказ не повторится.

## Capabilities

### New Capabilities

Нет. `skip_specs: true`: меняется только тестовая наблюдаемость.

### Modified Capabilities

Нет изменений поведения редактора и прежних assertions/timeouts.

## Impact

tests/lib/output_policy.lua, новый test-only capture, native E2E/диагностика, история и команды. Без production Lua, SDK, LSP и управления Docker/WSL.
