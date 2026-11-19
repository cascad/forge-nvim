# Design

## Context

Причина — proposal.md. Pinned ToggleTerm уже имеет get_last_focused/get_all,
exec и native open/send. Его selection helper не выбирает last active по умолчанию
и использует собственное byte slicing; Neovim getregion сохраняет Unicode,
line/block/exclusive semantics без собственного parser/yank.

## Goals / Non-Goals

Goals: один Visual callback, тот же Terminal job/cwd/history, native reveal/create,
portable keys и проверка реального stdin/output. Повтор не создаёт консоли.
Non-Goals: новый terminal manager/state/parser, автоматический REPL/interpreter
по filetype, смена shell/SDK, выполнение debug console или private task terminals.
SQL scope и neodev/refactor не входят в эту реализацию.

## Decisions

- Callback в существующем keymaps.lua: getregion до выхода из Visual/Select,
  затем public ToggleTerm API. Без globals/нового module/реестра active IDs.
  WinLeave хранит одну ссылку на native Terminal: get_last_focused на деле
  описывает view snapshot, а TermClose удаляет instance из native списка.
- Последняя сфокусированная public terminal, иначе первый обычный native terminal; private
  hidden=true исключён. Если ни одного нет — native default с текущим cwd.
- Массив исходных строк отправляется native Terminal:send без trim/quoting/
  временных source files. Каждый Enter/newline добавляет backend по platform
  policy; exec(string) с embedded LF теряет Windows line boundaries.
  Job/cwd/REPL существующей консоли прежние.
- Native send управляет focus: split возвращает код, float сохраняет штатное
  поведение. Завершённый job определяется nonblocking jobwait0, показывается
  его старый вывод/предупреждение; новый job вместо него молча не создаётся.
- Space t e свободен в Visual mode. Ctrl+Enter остаётся alias; существующая
  Windows WezTerm Ctrl+F19 доставка и RU alias wrapper сохраняются.

## Risks / Trade-offs

PTY readiness/Unicode → реальные shell и Python stdin reader E2E, не mocks API.
Native float/dead session → отдельные assertions job/buffer/history и focus.
Physical modified keys → portable alias основной; Mac/Omarchy отдельный gate.

## Migration Plan

Обновление config заменяет один legacy Visual mapping и добавляет один alias.
Плагины/SDK/state не мигрируют; rollback — прежний config commit.
