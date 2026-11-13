# Design

## Context

См. proposal. Шесть build hooks используют один ide.backports applier.
CLI без --plugin обходит декларацию целиком. Actual user cache имеет65/67
правильных HEAD, исходные16 patch files; два clean checkout восстановлены
из уже существующих objects, затем all/check успешны, backup на F.

## Goals / Non-Goals

**Goals:** проверить путь из исходных payloads до настоящих открытых panels,
исправить человеческую инструкцию, сохранить refusal неизвестных revisions.
**Non-Goals:** новая система установки, автоматическое исправление на startup,
отключение guards, обновление lock, Cargo/SDK/растущий каталог E2E.

## Decisions

- Один новый case в существующем plugin-backports file; private data получает
  все6 original payloads через существующий revert до старта child.
- Legacy replay выполняет прежние3 prepare calls; ожидается native config RED.
  Target вызывает общий public applier без списка plugins, проверяет все16
  hashes и затем UI. Внешний CLI apply/check проверен отдельно на actual user
  profile. Первый nested CLI pilot остановился по15s deadline до запуска UI;
  логи сохранены, исходный pilot не объявлен Neo-tree reproduction.
- Использовать настоящий applier, Neovim UI/input и плагины. Tests/Locals открываются
  без запуска тестов/debug adapter, исходник обычный .txt: без Cargo/LSP builds.
- Actual установленный профиль исправлен отдельно и проверен по67 pins/16 hashes;
  private native E2E не выдаётся за просмотр владельцем его live окна.

## Risks / Trade-offs

- Другие версии/user edits → действующий pin/SHA refusal; инструкция сначала
  использует штатный Lazy restore. Неизвестные правки не перезаписываются.
- Полный GUI/real project ещё не принят → результат назвать узким startup
  regression; Rust readiness и Files latency остаются открытыми отдельными ID.
