# Proposal

## Why

IDE-148: при Windows-приёмке после удаления пустого каталога остался диалог,
E21 и практически перестал работать ввод. Ctrl-C сработал с большой задержкой.
Log подтверждает completed delete; interruption stack находится в scheduled
redrawstatus из ide.controls внутри cmp.confirm/filter sync. Это место ожидания,
не доказательство единственной первопричины E21. Найден и отдельный риск:
Neo-tree синхронно удаляет каталог через system()/recursive libuv на UI thread.
Отказ/задержка ОС не должны блокировать остальной редактор.

## What Changes

- Native messagesopt wait:0 вместо hit-enter, с сохранением history/IDE Logs.
- Убрать принудительный synchronous redrawstatus из scheduled panel refresh.
- Enter в prompt-буфере не проходит через synchronous cmp.confirm.
- Neo-tree normal delete: существующие Plenary async/libuv, без shell-команды,
  с сохранением native events/buffer cleanup, root/unsaved guard и OS error.
- Native E2E dialog/empty delete, actual OS denial/retry, held real IO + ввод
  в другом файле, native error/Logs/cancel без автоматического ack сообщений.

## Capabilities

### New Capabilities

- `filesystem-action-responsiveness`: IDE-FILE-7.

### Modified Capabilities

Нет. Прежние IDE-FILE-3/4 guards и остальные панели сохраняются.

## Impact

options, completion, panel controls, один проверяемый companion backport
Neo-tree. Pins/SDK не обновляются. Ошибки ОС не подавляются; retained history
и общая консоль остаются источником полной причины.
