# Proposal

## Why

IDE-138 / IDE-BOOT-9: обязательная подготовка может ошибиться, а installer
пишет installed. Native probe подтвердил: nvim +lua error(...) +qa даёт exit0.
Windows/Linux также наследуют чужой config context и используют Lazy sync,
macOS верно выбирает config, но подавляет parser/Mason failures. Нужен общий
строгий setup step, а не разные предупреждения в трёх shell scripts.

## What Changes

- Общий Lua stage runner: native Lazy restore, все backports apply/check,
  Treesitter и Mason commands; command exception даёт явный nonzero exit.
- Все installers используют установленный config и прекращают setup на отказе.
- Native isolated stand с настоящим Neovim и fixture commands: source/target,
  выбранный профиль, errors/missing commands, настоящий backport apply/reject.

## Capabilities

### New Capabilities

- `installer-setup`: явные обязательные шаги подготовки установленного профиля.

### Modified Capabilities

Нет. Полный Default/Custom и проверка наличия каждого language SDK — следующие
срезы IDE-138, не объявляются готовыми по одному успешному fixture setup.

## Impact

Три platform installers, общий Lua stage и POSIX glue, permanent stand,
OpenSpec/docs/history. Без изменения daily startup, SDK/pins/backport payloads,
host package managers или собственного installer framework.
