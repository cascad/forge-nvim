# Proposal

## Why

IDE-103 — кандидат потери несохранённого текста в Files: закреплённый Neo-tree
после подтверждения удаления файла вызывает clear_buffer → nvim_buf_delete
с force=true (fs_actions.lua:140–160). Надёжность данных IDE-BUF-2/IDE-032
не должна обходиться деревом. В roadmap ещё открыты copy/delete и modified
buffers; IDE-FILE-3 закрепит безопасный normal d, IDE-FILE-4 — native copy
baseline без нового backend. До runtime edit нужен настоящий source RED.

## What Changes

- При normal d не удалять выбранный файл/каталог, если он или descendant
  содержит loaded modified file buffer, включая скрытый. Сообщить, что
  следует сохранить файл или явно закрыть буфер с Discard и повторить.
- Для чистых целей использовать native confirmation/delete/cancel; перед
  удалением повторно проверить modified после подтверждения. Соседние
  пути с общим prefix не блокировать. После save native retry доступен.
- Проверить native y/p и c: Unicode/пробелы, copy file/dir, конфликт/отмена,
  сохранность source на диске и в несохранённом buffer, независимость копии.
- Permanent real UI E2E, immutable source acffa63, Windows/Ubuntu serial,
  docs/FIXLOG/HISTORY/команды и самостоятельный commit.

## Capabilities

### New Capabilities

- `file-explorer-safety`: IDE-FILE-3 (guard normal delete) и IDE-FILE-4
  (проверяемый baseline существующего native copy).

### Modified Capabilities

Нет: main nvim specs ещё не сняты; IDE-FILE-1/2 и IDE-PANEL-4 сохраняются.

## Impact

Существующий Files command boundary в plugins/neo-tree.lua владеет eligibility
до/после решения пользователя; UI inputs.confirm и fs_actions.delete_node/
refresh остаются штатными Neo-tree API. Copy не переписывается. Без private fork, нового
file backend, global BufDelete interception, SDK/pins или shell changes.
Trash/visual multi-select/cross-volume/LSP file operations остаются отдельной
матрицей; Mac/physical GUI требуют настоящего запуска. Все destructive test
targets — заранее проверенные абсолютные пути внутри private project на F:
или guest temp, без действий над рабочими файлами пользователя.
