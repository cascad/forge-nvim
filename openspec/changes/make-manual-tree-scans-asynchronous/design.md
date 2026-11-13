# Design

## Context

Pinned Neo-tree документирует `auto`: refresh async, ручные команды sync.
`always` — поддерживаемая настройка; текущий backport уже защищает порядок
асинхронных результатов. Собственный scanner/renderer не нужен.

## Goals / Non-Goals

**Goals:** убрать синхронный путь чтения при ручном раскрытии; проверить
реальный ввод до завершения native IO и существующие freshness сценарии.

**Non-Goals:** новый cache, форк плагина, изменение Git/LSP, гарантия полной
отрисовки произвольно большого каталога за фиксированное время.

## Decisions

Одна настройка `filesystem.async_directory_scan="always"`. Existing test-only
observer удерживает только EOF callback настоящего `uv.fs_readdir` внутри
частного проекта. Дополнительно считает sync/async `fs_opendir`, передавая
аргументы и результаты без замены. Source dc23a30 обязан показать sync путь;
target обязан обработать клавиатуру при удержанном async callback. Остальные
семь случаев того же E2E проверяют native freshness.

## Risks / Trade-offs

Результат появляется позднее события раскрытия: это штатный async lifecycle.
Работа Lua renderer/Git и реальная стоимость большого проекта этим узким
исправлением не доказаны. Mac проверяется отдельно на машине владельца.
