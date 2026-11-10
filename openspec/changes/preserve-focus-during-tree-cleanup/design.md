# Design

## Context

См. proposal.md. Native trace фиксирует повторное acquire_window Neo-tree,
наш scheduled close и Edgy on_hide → goto_main. Neo-tree до закрытия уже
возвращает прежнее окно, но Edgy после уничтожения дерева снова выбирает код.
Штатный public get_prior_window() даёт ту же цель возврата, что renderer.close.

## Goals / Non-Goals

**Goals:** сохранять актуальное окно вокруг уже существующей очистки лишнего
дерева, без нового focus manager, observer в product или дополнительного таймера.

**Non-Goals:** менять LSP/Aerial, pin/исходники Edgy/Neo-tree, постоянное удержание
фокуса Outline, рефакторинг всех panel controls, отмена всех фоновых producer.

## Decisions

- Guard запоминает текущее окно перед close; если это само позднее дерево,
  берёт прежнее через public Neo-tree API. После штатного close возвращает
  только действительное окно той же вкладки. Это учитывает уже совершённый
  переход в код; безусловный comp.focus() украл бы такой выбор.
- Public producer в E2E создаёт настоящую позднюю Neo-tree UI операцию после
  выбора Outline/кода. Плагин, render/close/Edgy и gopls исполняются реально;
  случайный cold race дополняется управляемым порядком действий без fake LSP.
- Diagnostic сохраняет call stacks и 24 последующих наблюдения. RPC вызывается
  из обычного цикла, не внутри vim.wait predicate: вложенные wait в первом pilot
  раздули polling и были остановлены. Этот pilot не является acceptance.

## Risks / Trade-offs

- Предыдущее окно могло исчезнуть → проверять valid/tab до возврата; остаётся
  штатный fallback backend. Никаких отложенных принудительных refocus.
- Cold race зависит от таймингов → отдельный контролируемый late producer E2E.
- Windows/Ubuntu не заменяют Mac → native Mac gate остаётся открытым.

## Migration Plan

Получить RED постоянного E2E на исходном guard, внести узкий fix, прогнать
native regression/diagnostic и записать историю. Откат — revert коммита.
