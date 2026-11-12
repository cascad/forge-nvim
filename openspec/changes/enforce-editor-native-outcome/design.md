# Design

## Context

editor_process.stop.ok означает cleanup, intentional stopped/exit fixtures
используют native code/signal отдельно. Обычный editor.stop уже сохраняет
артефакты, удаляет runtime и объединяет cleanup error с primary_error.

## Goals / Non-Goals

**Goals:** fail обычного E2E при nonzero code/signal, прежняя очистка и причина.
**Non-Goals:** менять generic cleanup.ok, product/SDK, срок quit/RPC, повторять
полный набор ради зелёного статуса или чинить причины IDE-085/118.

## Decisions

- Проверка только в stop_process обёртке editor.lua после generic stop.ok;
  rpc=nil при ошибке подготовки не требует outcome несуществующего процесса.
- Использовать существующий pcall/merge/remove путь editor.stop. Cleanup
  результат и native outcome остаются разными данными в shutdown.json.
- Native self E2E запускает настоящую сборку, cquit23 и SIGKILL собственного
  child; сохраняет expected-negative receipt только после проверки actual
  outcome. Source driver заморожен git archive af982a9, не mock результата.
- Низкоуровневый control использует настоящий clean Neovim cquit24 и
  editor_process.stop: cleanup.ok=true с nonzero code остаётся допустимым.

## Risks / Trade-offs

- Старые скрытые отказавшие процессы начнут давать FAIL — это цель исправления,
  не основание повышать timeout. Проверить normal lifecycle, runtime failure,
  sessions и реальные SQL Tests/plugin-backports, не выполнять весь набор.
- Повторный stop после удаления runtime остаётся безопасным; первичная ошибка
  присутствует в общем исключении и shutdown.json при nonzero root.
- macOS доступен отдельно; Windows/Ubuntu actual исходный и target обязательны.
