# Design

## Context

См. proposal. Native vim.lsp.start поддерживает attach=false и reuse по
name/workspace. Cargo metadata уже определяет workspace_root у nvim-lspconfig;
та же native команда используется асинхронно при выборе проекта без файла.

## Goals / Non-Goals

**Goals:** сдвинуть существующую подготовку к выбору проекта, сохранить native
client lifecycle, текущие settings и roots при открытии файла.
**Non-Goals:** новый LSP, свой parser/cache/workspace index, форсирование
SDK installs, скрытое закрытие чужих clients/jobs, оптимизация всех UI операций.

## Decisions

- Один forge.rust_project module: User VeryLazy и global DirChanged ставят
  проверку cwd в очередь; обычные local window directory changes игнорируются.
- Только top-level Cargo.toml; require existing LSP config, готовые binaries,
  native async metadata, workspace_root из ответа, vim.lsp.start attach=false.
- Один owned metadata job и generation: смена cwd/quit отменяют его; callback
  проверяет актуальность. Это не manager Rust processes — клиентами владеет Neovim.
- RUSTUP_AUTO_INSTALL=0 для фоновых команд. Ошибки/пропущенные инструменты идут
  в существующий IDE Logs, без нового UI/повторных timers или отдельного cache.
- Real build.rs fixture публикует PID/start marker и ждёт release, не подменяя
  Cargo/RA. Пока job жив, проверяются keyboard input и first file open; затем
  release и native readiness/reuse. Raw latency сохраняется, тестовый предел300ms.
- Source target уже показал451ms первого txt; native Lazy diagnostic выделил
 147ms Gitsigns +236ms BufReadPost. Comment/indent/illuminate/barbecue/Satellite/
 hlslens используют VeryLazy: один existing lifecycle до первого файла,
 без отдельного loader scheduler/cache и удаления функций. Gitsigns не меняется.

## Risks / Trade-offs

- Root без верхнего Cargo.toml → обычный file-triggered native LSP сохранён;
  рекурсивный поиск mixed подпроектов не добавляется.
- Неизвестная длительность build scripts → UI проверяется отдельно от окончания
  анализа; по-прежнему используются native incremental artifacts.
- Root callback pinned lspconfig имеет отдельный synchronous sysroot probe;
  это кандидат для IDE-132, не объявляется исправленным ранним start.
