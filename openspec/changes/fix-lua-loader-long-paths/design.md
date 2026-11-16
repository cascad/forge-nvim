# Design

## Context

См. proposal.md и §253. В pinned Lazy штатная performance.cache.enabled управляет включением встроенного vim.loader. Native loader формирует cache filename из URI-encoded полного source path; проблема также описана в upstream issue neovim/neovim#29372.

## Goals / Non-Goals

Goals: безопасный полный запуск и выполнение актуального Lua source на всех ОС, измеримый cold startup.

Non-Goals: patch/fork Neovim loader, новый cache implementation, смена SDK/locks/backports, full Default language readiness, исправление filesystem limits ОС.

## Decisions

- Отключить optional disk bytecode cache штатной настройкой Lazy. Другие механизмы lazy loading/indexing сохраняются. Это общий параметр конфигурации, а не платформенный monkey patch.
- Альтернативы: хешировать filenames в native loader — добавляет fork/runtime patch lifecycle; переключить cache implementation — второй loader; укорачивать пользовательский путь — нарушает выбор каталога. Для текущей сборки optional cache не оправдывает эти изменения.
- Native E2E использует существующий editor harness с полной копией настоящей конфигурации и67 pinned plugins. Deep Unicode profile создаётся отдельно, native user profile не трогается. Модули реально require/reload, файл действительно редактируется и сохраняется; два запуска и Lazy startuptime сохраняются.
- Parser fixture читает cache policy из настоящего config/lazy.lua через перехват setup options, затем передаёт её настоящему Lazy. Остальная fixture изоляция parsers сохраняется. Полный editor E2E непосредственно загружает production config.

## Risks / Trade-offs

- Source compilation вместо чтения bytecode может увеличить cold startup → сохранить native timings Windows/Ubuntu; не выдавать эмуляцию или fixture timings за полную IDE.
- Сторонний init, включивший vim.loader до конфигурации, не является штатным managed launcher → не менять чужой loader глобально.
- Native Mac не проверяется Windows/Linux запуском → оставить owner gate.
