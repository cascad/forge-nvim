# Proposal

## Why

§253 воспроизвёл падение init на длинном Unicode пути: встроенный `vim.loader` превращает весь source path в cache basename, превышающий255 символов. Небезопасный disk cache включается Lazy по умолчанию в config/lazy.lua; сбой мешает IDE-138. Новый контракт IDE-BOOT-25 — работоспособная загрузка конфигурации и Lua modules на допустимых путях ОС.

## What Changes

- Штатная настройка Lazy отключает экспериментальный дисковый bytecode cache для сборки на всех ОС; обычная загрузка Lua и работа плагинов сохраняются.
- Native E2E полного редактора: длинный Unicode path, запуск, загрузка и изменение Lua module, повторный запуск, отсутствие фоновых установок; сохраняется время старта.
- Parser delivery fixture использует production policy вместо временного test-only cache обхода.

## Capabilities

### New Capabilities

- `safe-lua-loading`: запуск и загрузка Lua на длинных Unicode путях без обязательного bytecode cache.

### Modified Capabilities

Нет; baseline specs посвящены WezTerm/macOS installer.

## Impact

Одна штатная настройка config/lazy.lua, targeted E2E/fixture, история и release gates. Версия/байты Neovim, loader.lua, plugin pins/backports и обычные SDK не меняются. Настройки чужого nvim не затрагиваются.
