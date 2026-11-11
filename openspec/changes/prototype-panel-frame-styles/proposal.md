# Proposal

## Why

IDE-076: владелец подтвердил, что в Termide нравятся цельные рамки, цвет и аккуратность. Отдельного предпочтения по заголовкам не выразил; в прототипе название Locals размещено в верхней линии рамки. До общего оформления нужен работающий прототип с настоящим paused DAP и наглядным сравнением. Native Neovim border относится к floating windows; переносить его на split без исследования геометрии и управления нельзя.

## What Changes

- Отдельный test-only preview для Locals: полный native border в существующем zoom, активный/неактивный цвет, название в верхней линии без дублирующего winbar. Рабочий default и все прочие панели не меняются.
- Снять реальные RGB UI events, экспортировать сравнение и измерить viewport/geometry, проверить help/focus/resize/restore и ту же DAP pause/stdout.
- Opt-in UI capture в тестовом RPC, переносимый renderer без обязательных графических packages; native E2E capture и preview, документация и история.
- Референс: Termide d701d7b9244eebe513c3a3d893a44808343b0b65, panel_rendering.rs (полная рамка и accent/dim), MIT. Rust-код не переносится, цвета берутся из нынешней темы Forge.

## Capabilities

### New Capabilities

Нет: tooling/research, skip_specs=true. Постоянный стиль продукта ещё не выбран и не вводится этим прототипом.

### Modified Capabilities

Нет. Проверяются прежние UI/DAP инварианты; default style/pins/SDK остаются прежними. Найденный независимо docking общего zoom исправляется отдельным keep-panel-zoom-floating (IDE-PANEL-18), а не объявляется частью нового оформления.

## Impact

tests/lib/editor_rpc.lua и opt-in forwarding в editor.lua; test-only capture/renderer/preview, E2E/registry, docs/history. Без нового window manager, plugin, product autocmd/timer, shell/setup или lifecycle Docker/WSL. Прототип не выдаётся за готовые постоянные рамки вокруг всех split: этот результат и цена должны быть показаны владельцу отдельно.
