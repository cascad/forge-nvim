# Proposal

## Why

IDE-032: исходный IDE-GIT-3 доходит до удаления worktree с открытым файлом, затем показывает E211 и RPC timeout. Neogit на NeogitStatusRefreshed вызывает checktime для открытых файлов; native FileChangedShell deleted без обработчика выдаёт блокирующее сообщение, тогда как ide.buffers.show предупреждает только при явном выборе файла. Нужен регресс исходного удаления и общего жизненного цикла оставшегося в памяти текста.

## What Changes

- Обрабатывать FileChangedShell deleted штатным API Neovim: сохранять буфер/текст/modified и сообщать один раз без E211/ожидания ввода.
- После обнаруженного удаления удерживать autosave, включая уже ожидающую запись; разрешить явную запись/Save As и сбросить состояние после её успеха.
- Сохранить autoread существующих файлов и стандартную защиту внешнего конфликта; не переопределять Neogit/Git backend.
- Постоянные editor E2E удаления worktree и обычного файла, loaded/hidden/modified, pending autosave, восстановления, существующих внешних изменений и конфликта; Windows/Ubuntu, Mac явно не проверен.
- Дописать FIXLOG §95 и обновить историю, план, инбокс и команды; прежние изменения SDK сохранить.

## Capabilities

### New Capabilities

Нет.

### Modified Capabilities

- `buffer-navigation`: IDE-BUF-4 — оставшийся в памяти удалённый файл, уведомление и удержание autosave до явной записи.

## Impact

nvim_forge/lua/ide/buffers.lua, при необходимости публичные autosave события, tests/e2e и registry, документация. Общая политика на Windows/macOS/Linux, без нового SDK/плагинов/сети на старте. Нативные timeout не увеличиваются, source lock и сторонние методы не патчатся.
