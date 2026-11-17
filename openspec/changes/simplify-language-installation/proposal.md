# Proposal

## Why

Владелец выбрал базовые SQL/Bash на готовых LSP/форматтерах. Runtime §267 уже
отделён от БД, но installer всё ещё требует native SQL bundle, Bash DAP и
языковые runtime archives поверх штатной подготовки Mason.

## What Changes

- Basic SQL: Sqruff; Bash: BLS/shfmt/ShellCheck с Node prerequisite.
- Убрать обязательные SQL native checks и Bash debug preparation из setup.
- Runtime catalog требует только собственные Core/выбранный Terminal assets;
  языки готовят tools/parsers существующим setup, SDK остаются штатными.
- Привести inventory и прямые legacy install scripts к базовому составу.
- Сохранить ручную подготовку SQL/Bash дополнительных инструментов и runtime
  composition API для явно предоставленных старых bundles.

## Capabilities

### New Capabilities

- `basic-language-installation`: IDE-BOOT-35, базовый состав без advanced tools.

### Modified Capabilities

Нет main IDE specs: предыдущие контракты находятся в changes базовой линии.

## Impact

components/setup/catalog, native frontend runtime selection, publisher inventory,
транспортные/профильные регрессы и документация. SDK installation/updates,
доставка публичного Default, удаление старого кода и Mac acceptance вне среза.
