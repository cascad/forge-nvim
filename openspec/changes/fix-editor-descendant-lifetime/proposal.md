# Proposal

## Why

IDE-075: после успешных assertions Rust integration Neovim завершился code 0,
но собственный cargo clippy пережил его и удерживал файлы private runtime
(артефакт 30860580344400). `tests/lib/editor_process.lua` ждёт только основной
RPC child, поэтому штатный `editor_runtime.remove` не смог очистить профиль.
Это нарушение принятого lifecycle тестового каркаса, не поведения SQL.

## What Changes

- Общая граница владения процессами одного тестового редактора: остановка
  охватывает оставшихся потомков, включая worker с уже завершившимся родителем.
- Системные реализации за одним интерфейсом: Windows Job Object, POSIX
  отдельная process group с явными ограничениями отделившихся sessions.
- Установка владения до исполнения пользовательского конфига; отсутствие
  защиты или ошибка attach считаются отказом запуска, без скрытого fallback.
- Штатный qa!/сохранение артефактов остаются первыми; завершение остатка scope
  и проверка освобождения ресурсов выполняются до удаления private runtime.
- Реальные process/editor E2E: обычное закрытие, ранний exit, orphan grandchild,
  file lock, принудительное завершение и сохранение чужого параллельного child.
- Exact source RED текущего драйвера, Windows Rust regression, история и
  команды. Ubuntu/macOS не считать проверенными по наличию POSIX ветки.

## Capabilities

### New Capabilities

Нет. Меняется исключительно тестовая инфраструктура, `skip_specs: true`.

### Modified Capabilities

Нет. Пользовательские LSP/DAP/Tasks и main specs не меняются; реальные анализ,
тестирование и отладка не отключаются ради прохождения cleanup.

## Impact

`tests/lib/editor_rpc.lua`, `editor_process.lua` и новый модуль process scope,
постоянные E2E/реестр/README, FIXLOG/HISTORY/команды/roadmap. Ни глобального
taskkill, ни поиска процессов по имени, ни управления Docker/WSL; Windows
temp остаётся на диске checkout. SQL integration task остаётся открытым,
пока его требуемый прогон не завершён с реальным успешным cleanup.
