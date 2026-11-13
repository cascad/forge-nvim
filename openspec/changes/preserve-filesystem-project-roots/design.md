# Design

## Context

См. proposal.md. config.start уже владеет normalizing выбранных путей и
проверяет их при session save. Native :restart и persistence остаются backend.

## Goals / Non-Goals

Сохранить '/' и drive root; prefix принадлежности должен иметь ровно один
separator. Не менять case policy, symlink handling, LSP root или выбранную
папку автоматически. Не строить новый path/session framework.

## Decisions

Добавить POSIX root к существующему исключению drive root в normalize_dir.
Для containment добавлять slash только при его отсутствии. Regex остаётся
local; вынос пары строк в общий модуль с новой политикой не требуется.

Existing session_tui запускает настоящий native backend и следит за PID
через реальные :restart. Новый case выбирает filesystem root, но открывает
и изменяет только private fixture; root itself не получает новых файлов.
Native session file хранится в private XDG. Existing A→B→A — control.

## Risks / Trade-offs

Root Explorer может читать верхний уровень диска → первый вход code-only,
после restore обычное штатное дерево без рекурсивного обхода. POSIX '/' нельзя
проверить Windows-эмуляцией → Ubuntu source/target обязателен, Mac отдельно.
