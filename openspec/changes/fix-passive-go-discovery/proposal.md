# Proposal

## Why

IDE-082 уточняет пассивность IDE-BOOT-1: открытие Go-файла запускает
синхронные `go env GOBIN/GOPATH` из `plugins/dap.lua`, а Lualine вызывает
`go version` через `forge/go.lua`. В модуле с отсутствующим toolchain это
начинает ненужный выбор/скачивание SDK до запуска debug; offline RED Windows/
Ubuntu сохранён в FIXLOG §146. Требуемое поведение фиксирует новый IDE-BOOT-4.

## What Changes

- Поиск Delve выполняется при настоящем запуске Go debug или явном DapGoDlvInfo,
  учитывая актуальные override/PATH/GOBIN/GOPATH/Mason и прежний приоритет версий.
- Отрисовка Go label читает только режим/сохранённую версию; до явного запроса
  показывает Go auto/local/выбранный toolchain. Она не запускает процессы.
- GoVersion/GoToolchain остаются явными асинхронными действиями; ответ версии
  относится к текущему cwd/toolchain, повторная отрисовка не создаёт дублей.
- Добавляется постоянный native E2E: отсутствующий SDK при edit, явная версия,
  смена контекста и поздний override Delve с настоящим breakpoint/output.

## Capabilities

### New Capabilities

- `editor-bootstrap`: IDE-BOOT-4, пассивная Go metadata и отложенный поиск
  отладчика. Capability уже используется открытым make-editor-startup-passive,
  но ещё не перенесена в main specs; IDE-BOOT-1/2/3 не переопределяются.

### Modified Capabilities

Нет изменений существующих main specs.

## Impact

`forge/go.lua`, GoVersion в `plugins/lsp.lua`, nvim-dap-go setup в
`plugins/dap.lua`, новый E2E/registry, пользовательские docs и история.
Существующие Go language/DAP/tests проверяются на Windows/Ubuntu. Mac отдельно.
Готовый gopls, project SDK для реальной работы, pins и установка не меняются.
IDE-001 (zsh до nvim) и Glance/Outline IDE-083/084 — отдельные изменения.
