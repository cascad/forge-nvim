# Proposal

## Why

Actual Windows Default install/launch/Core workflow прошли, repeat остановился
на uv.fs_lstat EACCES в kit/tmp/bee1.tmp. Native os.lstat показывает AF_UNIX
reparse tag0x80000023, временный узел после работы редактора. Ownership walk
не должен обходить внутренние временные OS resources как постоянный config.
IDE-BOOT-11 должен сохранять безопасный повтор, включая обычную работу IDE.

## What Changes

- Проверять сам tmp по прежним правилам, не обходить его transient contents.
- Runtime/config/bin/log/state/backups и остальные entries проверять как раньше.
- Native closed/live socket repeat и external-link controls Windows/Ubuntu;
  затем продолжить actual Default/Custom archive acceptance.

## Capabilities

### New Capabilities

- `transient-installation-entries`: IDE-BOOT-47.

## Impact

Одна общая filesystem boundary, native regressions, история/план. Без platform
patch к Neovim, special-case reparse tags и удаления tmp активного редактора.
