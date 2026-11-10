# Design

## Context

См. proposal.md. Выбор сейчас раздвоен между plugins/dap.lua и ide/dap.lua; пассивный компонент dap.terminal уже умеет возвращать сохранённый буфер. Legacy Dv в прежнем review назван неверно: реальный opener — Space m d, Dv — Variables.

## Goals / Non-Goals

**Goals:** убрать разные правила выбора, повторно использовать существующие компоненты и проверить реальные адаптеры.

**Non-Goals:** новый panel/session manager, новый PTY backend, изменение ConPTY backports, LSP или lifecycle завершения. IDE-085 остаётся открытым с действующим quit capture.

## Decisions

1. Resolver в ide.dap принимает конфигурацию для автоматического выбора либо использует видимый/последний канал для ручного. Правила CodeLLDB/remote Go/integratedTerminal/default переносятся без изменения. Память обновляется компонентами и реальным runInTerminal, поэтому прямой выбор и закрытие также учитываются. Отдельный session cache не нужен.
2. show_section различает подготовку нового запуска (PTY создаст адаптер) и восстановление/continue (пассивный dap.terminal.open). Существующий свежий буфер на новый запуск сохраняется; manual reopen не вызывает termopen.
3. Space D c делегирует общему focus_output. Явные Space m o (Console), Space dR (REPL), Space D v (Variables) сохраняются.
4. Native RED до исправления, затем Go/Rust/Python/Node E2E. Проверяются реальный session/frame, buffer/channel, текст, native exit и own process scopes. Никаких моков протокола.

## Risks / Trade-offs

- Закрытие прежнего компонента может перезаписать канал → помнить закрываемый только если он видим, итоговый новый канал записывать после переключения.
- Reopen до runInTerminal может показать старый буфер → новый launch/initialized оставляют существующую подготовку, reuse применяется к ручному открытию/continue/паузе.
- RPC UI не доказывает физические клавиши macOS/WezTerm → отдельный native Mac gate.
