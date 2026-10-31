## Why

IDE-003/004: при повторном запуске исчезает окно вывода; при остановке на
panic нужен текст ошибки в Output. В plugins/dap.lua вывод очищается в
нескольких listeners, панель восстанавливается на initialized, а stopped
восстанавливает только sidebar. nvim-dap показывает exceptionInfo как
diagnostic в исходнике, что само по себе не даёт текст в Output.
Это наблюдения кода и кандидаты причин; точное воспроизведение нужно закрепить E2E.

## What Changes

- Закрепляем жизненный цикл Output: первый/повторный запуск, пауза и выход.
- Показываем доступный текст исключения при паузе, не продолжая программу.
- Не теряем уже полученный stdout/stderr из-за позднего ответа launch.
- Добавляем реальные Go/Delve E2E в изолированную сборку и явную подготовку
  инструментов Ubuntu; Mac запускает тот же набор отдельно.

## Capabilities

### New Capabilities

- `debug-output`: IDE-DAP-1/2, доступность вывода и текста panic/exception.

### Modified Capabilities

Нет: базовая линия DAP ещё не описана в openspec/specs.

## Impact

nvim_forge/lua/plugins/dap.lua, ide/dap.lua при необходимости;
tests/e2e, общий editor harness и подготовка Docker. История и инструкции.
Новые хоткеи, смена DAP-плагинов и исправление shell Mac сюда не входят.
