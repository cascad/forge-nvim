# Design

## Context

Мотивация — proposal.md. Существующий editor helper запускает настоящий
nvim_forge с изолированным профилем, вводом RPC и snapshot/source artifacts.
gopls включается по PATH; cmp берёт LSP source, публичные gd/gr/F2/gl/lf уже
настроены. Conform Go использует golines/gofumpt и LSP fallback.

## Goals / Non-Goals

**Goals:** доказать пользовательскую семантику и переносимую явную подготовку.
**Non-Goals:** новые языки, смена plugins/SDK, глобальная установка инструментов,
управление Docker Desktop/WSL и выдача mock/server config за language E2E.

## Decisions

1. prepare_lsp.py собирает фиксированные Go modules в собственные bin и
   format-bin, проверяет go version -m, сохраняет metadata/SHA. Go 1.26.0
   уже подготовлен; GOTOOLCHAIN=local/GOENV=off, caches/temp на диске checkout.
   Сборка ограничена двумя workers; обычные tests ничего не скачивают.
2. Те же fixture и tests Windows/Ubuntu/macOS. Изоляция PATH позволяет
   проверить настоящую нехватку внешних форматтеров, оставив gopls/Go/Git/rg.
   Зависимости проекта отсутствуют; runtime GOPROXY=off, Go telemetry off.
3. Действия выполняются штатными клавишами. Read-only API наблюдает LSP clients,
   cmp entries, diagnostics, quickfix, buffers/files и spawned commands.
   Completion обязан прийти из nvim_lsp; buffer source не считается успехом.
4. Fixture содержит несколько файлов, Unicode/пробелы в пути. Rename проверяет
   объявления и usages на диске, diagnostics — появление и устранение ошибки,
   format — точный сохранённый текст и реальный formatter/LSP путь.
5. Регистрируем отдельный файл с собственным budget. Ubuntu Dockerfile явно
   готовит deps на build; runtime image остаётся offline. Если engine недоступен,
   Ubuntu задача остаётся открытой, Windows работа продолжается.

## Risks / Trade-offs

- Индексация gopls асинхронна → ждать клиента и наблюдаемый результат команды.
- Пользовательский PATH маскирует отсутствие formatter → контролируемый PATH
  и публичная executable/get_formatter_info проверка, не mock backend.
- Новый server выявит runtime bug → воспроизведение, ID/delta до исправления.
- Build расходует ресурсы → последовательные платформы, Go -p 2, свои caches.
- Нет Mac/GUI → не объявлять их PASS по Windows/Ubuntu headless.
