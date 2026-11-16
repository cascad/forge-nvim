# Proposal

## Why

IDE-138, inventory §250/251: managed setup пропускает Windows codelldb, не применяет принятый Bash patch и не доставляет patched sqls/forge-sqltest. Пользователь после установки вынужден выполнять отдельные prepare-команды; stock sqls receipt не доказывает принятые SQL возможности.

## What Changes

- Готовить pinned codelldb1.12.2 через текущий Mason на Windows и POSIX; готовить существующий Bash adapter/patch в tools stage с честным nonzero при ошибке.
- SQL доставлять существующим native runtime component: patched sqls и forge-sqltest, без требования Go/Rust/C compiler у пользователя SQL. Для publisher использовать уже проверенные native builds и их manifests; не создавать нового build/provider framework.
- Проверять native versions/readiness до публикации готового kit, сохранять user SDK/чужие adapters и исключать installs на startup.
- Native E2E: debugger handshake/launch, Bash patch success/repeat/failure, SQLLogicTest и SQL query, выбранные/пропущенные components, отказ/сохранность старого kit.

## Capabilities

### New Capabilities

- `managed-debug-test-tools`: подготовка существующих debugger/test tools штатным setup и доставкой native SQL component.

### Modified Capabilities

Нет.

## Impact

Component/SDK prerequisites, tool catalog, Bash patch API, native SQL package/checks/lookup и existing packager. Installer guide/история/целевые native E2E. Без нового LSP/adapter, global SDK installs, изменений Neovim/lazy-lock/backports; native Mac/publication отдельно открыты.
