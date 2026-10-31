## Why

IDE-006: после запуска теста под курсором остаётся «No active session» поверх
кода. Источник этого текста найден в DAP expression widget; обычный neotest
не вызывает его напрямую. Требования IDE-TEST-1 и IDE-DAP-3 закрепляют
раздельные сценарии тестов и eval. Точное сочетание действий владельца пока
не подтверждено, нужен настоящий E2E с исходным красным результатом.

Дополнительно pinned neotest-go строит shell-команду всех тестов без фильтра
nearest и склеивает путь без quoting. Проверим на двух тестах и пути с пробелами.

## What Changes

- Обычный ближайший Go-тест работает без DAP и показывает свой результат.
- Debug nearest действительно запускает выбранный тест через Delve.
- Eval без paused-сессии сообщает о необходимом состоянии без пустого float;
  DAP float закрывается Esc/q, без остановки сессии и потери файла.
- Реальные Go/neotest/Delve E2E, pinned Go parser в явной подготовке среды.
- Red подтвердил несовместимый Go query; заменяем Go-адаптер на закреплённый
  neotest-golang, используем общий gotestsum runner с JSON-файлом.
- Закрепляем исправленный upstream neotest core для рабочего Treesitter worker.
  UI и хоткеи сохраняются; запуск не устанавливает инструменты автоматически.

## Capabilities

### New Capabilities

- `test-runner`: IDE-TEST-1/2, ordinary/debug nearest и результат.
- `debug-eval`: IDE-DAP-3, безопасный eval и закрытие transient DAP float.

### Modified Capabilities

Нет: eval-окно и вывод процесса разделены по наблюдаемому поведению.

## Impact

plugins/tests.lua, plugins/dap.lua, config/keymaps.lua и небольшой helper eval;
lazy-lock/plugin catalog при замене адаптера. E2E harness, parser preparation,
Dockerfile, docs/FIXLOG/хронология. Mac и Python/Rust честно остаются непроверенными.
