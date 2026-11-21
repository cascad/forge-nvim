# Design

## Context

Source17e81ff. Фактические Logs user fride: PATH → E:/msys64/mingw64/bin/python3.EXE,
затем launcher connect timeout. Прямой SDK probe воспроизводит missing encodings;
C:/Python314/python.exe работает. Runtime выбор использовал python3 перед python,
а native installer Windows discovery уже предпочитает python.

## Goals / Non-Goals

Goals: корректный default без venv и ранняя диагностика непригодного SDK,
проверяемая через настоящий F5. Non-Goals: ремонт MSYS2/SDK пользователя,
новый manager, перебор/замена explicit SDK, изменение launch.json/attach/pytest,
увеличение DAP timeouts, глобальное подавление предупреждений.

## Decisions

- Меняется только fallback names Windows; explicit settings/VIRTUAL_ENV/Conda/
  project venv сохраняют приоритет. POSIX сохраняет python3 → python.
- Current-file python option — штатная nvim-dap coroutine, аналог существующего
  Rust target resolution. Существующий runtime_sdk.probe асинхронен и bounded3s;
  на провал возвращается dap.ABORT до запуска adapter. Смена cwd отменяет stale run.
- Полный path/stderr → log_store, короткий ERROR → штатный Fidget notify.
  Command-line vim.notify вместе с native Run aborted вызывал hit-enter даже
  с коротким текстом; float Fidget не добавляет message-scroll prompt.
- E2E использует настоящие CPython и debugpy. SDK из PATH — реальный venv вне
  проекта; project venv и SDK overrides отсутствуют. Непригодный CLI fixture
  моделирует исполняемый файл, который не может выполнить Python command;
  реальная MSYS2 ошибка сохранена отдельно как incident evidence.

## Risks / Trade-offs

Проверка запуска добавляет один короткий async SDK probe на Current File F5;
ordinary startup не запускает version probes. Custom launch.json не расширяется
этой политикой. Stale cwd → ABORT, другие debug sessions не прерываются.
