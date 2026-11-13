# Design

## Context

Native enable(false) выключает FileType autostart и останавливает имеющиеся
клиенты, но manual lsp.start может создать новый. Warmup делает такой manual
start с attach=false после Cargo metadata. Нужны native state guards.

## Goals / Non-Goals

**Goals:** не обходить disable, корректно обработать поздний ответ, сохранить
обычный native re-enable и existing startup/reuse.

**Non-Goals:** новый режим включения, отслеживание до загрузки конфигурации,
переписывание LspStop, root/library resolver, SDK/cache/новый LSP backend.

## Decisions

Проверять vim.lsp.is_enabled после загрузки конфигурации и после epoch/cwd
проверки ответа (очистив pending handle). Пропуск — INFO в existing Logs,
без popup. Никакого отдельного state/listener manager; native API владеет
остановкой уже запущенных клиентов и последующим включением.

Existing Cargo observer получает optional producer, default DAP прежний.
До cd тест загружает LSP, задаёт native enable, наблюдает настоящий warmup
и native lsp.start без подмены результата. In-flight case удерживает только
готовый actual Cargo callback. После release проверяются native start count
и отсутствие клиента, не только отсутствие окна. Enabled controls отдельно.

## Risks / Trade-offs

Scope — уже настроенный LSP. Reload конфигурации/политика Mason не меняются.
Удержанный callback не доказывает отмену живого metadata процесса по SIGTERM:
тот прежний gate IDE-RUST-2 остаётся открытым. Mac/physical отложены отдельно.
