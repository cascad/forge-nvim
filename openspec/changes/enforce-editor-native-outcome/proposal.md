# Proposal

## Why

IDE-114: общий Windows E2E дал file PASS для SQL tests/plugin-backports,
хотя native roots завершены code1/signal15. tests/lib/editor.lua проверяет
только editor_process.stop.ok (cleanup), теряя фактический outcome процесса.

## What Changes

- Обычный editor.stop после сохранения артефактов и cleanup сообщает nonzero
  exit code или signal, сохраняя первичную ошибку caller.
- Низкоуровневый editor_process.stop сохраняет контракт cleanup: intentional
  negative fixtures сами оценивают ожидаемый native outcome.
- Permanent native E2E: настоящий cquit, сигнал, первичная ошибка, normal
  exit и control низкоуровневого negative fixture, source/target обеих ОС.

## Capabilities

### New Capabilities

Нет; skip_specs=true, исправляется наблюдение тестового harness.

### Modified Capabilities

Нет; product Lua, SDK, timeout/quit policy и поведение IDE прежние.

## Impact

tests/lib/editor.lua, native self E2E/registry и документация тестов/история.
Это обнаружение ранее скрытого отказа, не исправление причин IDE-085/118.
Windows/Ubuntu последовательно, Mac отдельно; Desktop/WSL не управляем.
