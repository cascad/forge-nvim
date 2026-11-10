# Design

## Context

Persistence сохраняет по cwd/branch на VimLeavePre с cleanup панелей. Config.start пишет modified files и сохраняет проект перед native :restart. Embedded E2E UI пока не реализует restart event; обычный RPC тест мог бы оставить новый server без клиента.

## Goals / Non-Goals

**Goals:** реальные разные backend PID, повторная загрузка общей private session/state, сохранённые files/cursor/root, Explorer при restore; подтверждённые сценарии в E2E.

**Non-Goals:** менять production config, объединять root policies, удалять optional UI, заявлять GUI/Mac/Ubuntu без запуска или объяснять Docker остановки этим baseline.

## Decisions

- Существующий editor helper создаёт private config/plugins/profile и owned process scope. В нём native terminal job запускает второй, настоящий TUI той же SDK. Native TUI самостоятельно обрабатывает restart event и подключается к новому backend; контроллер не имитирует restart.
- Наблюдатель только пишет PID/servername/lifecycle в private files; public RPC читает состояние, ввод идёт через PTY. Parent persistence остановлен, чтобы host fixture не перезаписывал child session при cleanup.
- Проекты с пробелами/Unicode, обычные текстовые файлы без language tools. Никаких downloads, Docker/WSL, дополнительных языковых runtime. Все вложенные процессы остаются в scope host editor.
- Сохранять lifecycle/session source/snapshots/terminal output и primary failure до удаления private runtime. Завершать TUI штатным quit, затем host; assert собственный scope пуст и native exit успешен.

## Risks / Trade-offs

Вложенный terminal даёт native TUI/PTY, но не проверяет физический WezTerm/GUI. RPC-наблюдение не заменяет пользовательские клавиши. Startup/restart readiness подтверждается новым PID и live UI, а не фиксированной задержкой. Если baseline найдёт defect, оставить диагностику и завести отдельный product change; не подгонять контракт под текущий результат.
