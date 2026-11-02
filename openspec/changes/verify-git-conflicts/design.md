# Design

## Context

Штатный merge_tool — diff3_horizontal; `Alt+e` сейчас вызывает selector правой
крайней diff-панели, как Alt+l. В трёхстороннем layout результат может быть
средним. Подтвердить настоящим UI до runtime правки.

## Goals / Non-Goals

**Goals:** четыре real editor сценария continue/abort для merge/rebase,
одинаковые клавиши на всех ОС, сохранность Git refs/index/файлов.

**Non-Goals:** credentials, внешний remote, interactive sequence editor,
автоматическое разрешение, Git backend и очистка title IDE-043.

## Decisions

1. Git CLI готовит только две конфликтующие локальные ветки и проверяет
   результат. Neogit popup/picker/confirm, Diffview focus/choose, запись,
   stage, continue/abort выполняются клавишами, без вызова приватных handlers.
2. Если RED подтвердится, Alt+e выбирает writable normal buffer среди diff
   окон по публичным атрибутам Neovim. Alt+h/l сохраняют крайние стороны.
   Альтернатива — координаты/Windows branch — ненадёжна для diff3/vertical.
3. Точные штатные conflict ERROR разрешены только в соответствующем сценарии;
   неизвестный ERROR/нативный E…/блокировка остаются FAIL. Все prompts и
   native Git observations сохраняются.
4. Проверить новый набор, прежние git-workflow/git-errors/diffview-close на
   Windows и Ubuntu последовательно; Mac/GUI отдельно и непроверенными.

## Risks / Trade-offs

- При rebase ours/theirs имеют Git-семантику → проверять фактическое выбранное
  содержимое, не называть стороны "моё/чужое" без контекста.
- Continue может открыть commit editor → дождаться штатной карты ZZ,
  подтвердить настоящим вводом и проверить Git metadata завершения.
- Abort должен сохранять исходное → отдельный private fixture для каждого
  случая, сравнить HEAD/index/файлы до/после.
