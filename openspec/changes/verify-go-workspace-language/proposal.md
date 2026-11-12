# Proposal

## Why

WF-10 требует переходов между модулями, включая реализации. Go.work debug и
Tests проверены §206–207, но обычный gd/gi/gr через gopls на таком root ещё нет.
Нужен конкретный acceptance с готовым server, прежде чем добавлять runtime glue.

## What Changes

- Два маленьких navigation fixture файла с интерфейсом/реальной реализацией.
- Native E2E: app→shared definition и назад, implementation type/method,
  references обратно в приложение с выбором результата клавиатурой.
- Проверка общего workspace root, ответов настоящего gopls и installs0.
- По одному прогону Windows/Ubuntu, история и точная platform matrix.

## Capabilities

### New Capabilities

Нет: только проверка существующего native LSP поведения, skip_specs:true.

### Modified Capabilities

Нет. Общие gd/gi/gr остаются штатными; при дефекте сначала новая bug delta.

## Impact

Только fixture/E2E/registry/docs/history. Runtime, SDK, pins и LSP backend
не меняются. Mac/physical и весь mixed-language проект отдельно.
