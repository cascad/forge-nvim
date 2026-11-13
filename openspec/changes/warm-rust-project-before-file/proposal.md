# Proposal

## Why

IDE-131: после cargo check fix подготовка workspace всё ещё начинается только
с первого Rust-файла. Владелец ожидает фоновую подготовку при открытии проекта,
сохраняя отклик редактора. Добавляется IDE-RUST-2, без нового language backend.

## What Changes

- Для выбранного каталога с Cargo.toml заранее определить workspace через
  асинхронный native cargo metadata и запустить готовый rust-analyzer.
- Использовать vim.lsp.start attach=false и штатное повторное использование
  клиента при открытии .rs; Cargo/rust-analyzer cache остаётся стандартным.
- Отменять собственный незавершённый metadata job при смене проекта/quit,
  игнорировать устаревший callback; не устанавливать SDK на startup.
- Native E2E: настоящий build script занят, при этом UI отвечает, первый
  Rust-файл использует тот же client ID; compiler check regression сохранён.
- Профиль IDE-132 показал235ms общего оформления на первом BufReadPost;
  шесть existing UI plugins готовятся на native VeryLazy, IDE-BOOT-7.

## Capabilities

### New Capabilities

- `rust-project-startup`: IDE-RUST-2, ранняя подготовка Cargo workspace.
- `editor-bootstrap`: IDE-BOOT-7, общие элементы редактирования до первого файла.

### Modified Capabilities

Нет.

## Impact

Малый Rust project boundary, init hook, existing Rust fixture/E2E, docs/history.
Первый срез выбирает только проект с Cargo.toml в текущем каталоге: рекурсивного
поиска всех Rust-подпроектов mixed repo нет. Native file-open roots прежние.
Раскрытие Files/IDE-133 и оптимизация количества features не входят в этот срез.
