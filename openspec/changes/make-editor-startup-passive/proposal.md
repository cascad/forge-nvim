## Why

IDE-001, этап 1 roadmap: обычный запуск не должен устанавливать инструменты.
Реальный e2e подготовленной сборки на Windows воспроизвёл автоматический
curl за tree-sitter-rust при запуске. Причина: setup_main в treesitter.lua
вызывает ts.install(languages), если CLI найден. Дополнительно LSP ensure
и mason-tool-installer настроены устанавливать инструменты при открытии файла/
VeryLazy. Это отдельный механизм от исходного zsh-сбоя Mac.

## What Changes

- Убираем установку парсеров при старте; ForgeTreesitterInstall остаётся
  явным действием и подготавливает PATH для tree-sitter CLI.
- mason-lspconfig включает уже установленные серверы, не устанавливает их.
- mason-tool-installer сохраняет каталог для явных MasonToolsInstall/Sync,
  но не запускается автоматически.
- Регресс: настоящий nvim_forge, реальные процессы и окно наблюдения после
  VeryLazy; исходный тест красный на curl. Без тестовых отключателей.
- Ubuntu e2e дополнительно выявил hit-enter из-за missing-gopls уведомления
  при открытии .txt; предупреждение ограничивается Go-контекстом (IDE-BOOT-2).

## Capabilities

### New Capabilities

- `editor-bootstrap`: пассивный обычный запуск подготовленного редактора.

### Modified Capabilities

Нет. Основная спека bootstrap ещё не заведена; добавляется delta ADDED.

## Impact

plugins/lsp.lua, plugins/treesitter.lua, docs, FIXLOG, реальный editor e2e.
Исходная IDE-001 на Mac остаётся открытой до отчёта/trace.
