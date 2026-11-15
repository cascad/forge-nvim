# Tasks

## 1. SDK prerequisites и раздельный delivery plan

- [x] 1.1 Разделить Plan.components/native_sdks, убрать native SDK artifacts и согласовать backend validation. Проверка: source RED обеих ОС; runtime16 PASS Windows/Ubuntu, host Node/IDE tool, прежние failure gates.
- [x] 1.2 Добавить passive PATH/version checks, timeout, JSON/logs, --check-sdks/--sdk-report и installation preflight до artifacts. Проверка:11 SDK cases Windows проверены; Ubuntu10 PASS/1 Windows-only skip, включая настоящую venv; UI13 selectors проверены на обеих ОС.
- [x] 1.3 Зафиксировать границы и команды, FIXLOG §246 со «Спека: IDE-BOOT-18 (ADDED)», HISTORY/roadmap. Проверка: append-only raw/staged journal prefixes, frozen SDK/pins/WIP, strict OpenSpec; Mac явно открыт.

## 2. Интеграция

- [x] 2.1 Подготовить native frontend Windows/Ubuntu из pinned Cargo sources, выполнить один целевой прогон и необходимые адресные повторы после изменений; stage exact allowlist и локальный commit. Проверка: receipts/raw summaries, git diff/check. Публикации нет.

Следующий срез §245: interactive existing-path/install/skip/cancel. Здесь эти действия не реализуются; нерешённый prerequisite останавливает actual setup с отчётом.
