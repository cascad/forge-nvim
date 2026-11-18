# Proposal

## Why

IDE-BOOT-11 запрещает успешную установку после ошибки подготовки. На Ubuntu
native setup-stage plugins, завершивший себя SIGKILL, дал code=0/signal=9.
scripts/install-private.lua execute проверял только code: backend exit0,
bin/fride опубликован. Repro сохранён в .tests/toolchain-research/setup-signal-kill-native.txt.

## What Changes

- Считать ненулевой signal ошибкой общего execute для probes и setup stages.
- Сохранить native code/signal, command и путь к log в причине ошибки.
- Native regression: stages plugins/parsers/tools, первая/повторная установка,
  runtime probe и прежний nonzero exit. SDK и managers не меняются.

## Capabilities

### New Capabilities

- `setup-process-completion`: IDE-BOOT-44, конкретизирует отказ IDE-BOOT-11.

## Impact

Общий private Lua backend, новый native suite, история и текущий план.
