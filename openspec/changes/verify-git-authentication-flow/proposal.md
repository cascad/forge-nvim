# Proposal

## Why

Очередь4/WF-09: native interactive rebase проверен, но Git credential prompts,
отмена/отказ и повтор push ещё не защищены E2E. Neogit runner уже использует
native input/inputsecret и Git PTY; сначала проверяем готовое поведение.

## What Changes

- Два E2E через обычный Neogit Push и настоящий Git HTTP backend: отмена
  username→повтор; неверный password→понятный отказ→повтор тем же commit.
- Проверка скрытого ввода, сохранения local/remote refs при отказе и реального
  remote HEAD после успешного push; временный HTTP auth fixture на loopback.
- Windows/Ubuntu по одному прогону, документация/история с точными границами.

## Capabilities

### New Capabilities

IDE-GIT-14: быстрый Push до публикации первого repo refresh и native
credential cancel/rejection/retry с сохранением refs и скрытым вводом.

### Modified Capabilities

IDE-125: source дважды не дошёл до Git process; diagnostic стек подтвердил
`hooks.exists` → `vim.tbl_contains(nil, hook)` при начальном repo state.
IDE-126: native runner отправляет CR+LF, после Username Git получает пустой
Password на Windows. Диагностическая замена на один CR дала настоящий HTTP push.

## Impact

E2E/HTTP fixture/registry/docs/history и узкий companion существующего Neogit
backport: отсутствие опубликованного hook metadata не мешает запуску Git.
Git http-backend остаётся
настоящим backend, новый auth manager в продукт не добавляется. Данные
синтетические, private repo и127.0.0.1, global Git/helper не меняются.
Real OAuth/SSH agent/remote account и Mac/physical отдельно.
