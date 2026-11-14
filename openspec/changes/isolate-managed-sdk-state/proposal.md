## Why

IDE-138/140: private launcher/setup уже задают часть caches, но Cargo/Rustup, GOBIN/GOMODCACHE/GOENV, npm global prefix/config и Python user state могут остаться пользовательскими. Нужна одна политика SDK env для подготовки и запуска без изменений existing installations.

## What Changes

- Общая декларативная SDK environment policy для native Lua setup и PS/Bash launchers.
- SDK homes/cache/global tools/config paths внутри kit, mutable bin paths доступны до host PATH, ранее заданные redirect variables не уводят установку наружу.
- State/config directories создаются при явной установке, пользовательские state files сохраняются при повторе. Startup читает готовую policy без подготовки SDK.
- HOME/project env/targets остаются прежними; config/credentials не импортируются. Native SDK artifacts ещё должны обеспечить toolchain contents отдельным inventory.
- Source RED и native Windows/Ubuntu E2E с реальными offline go/npm/pip/cargo/rustup actions, проверкой host state и caller env.

## Capabilities

### New Capabilities

- `managed-sdk-state`: IDE-BOOT-16, согласованное private SDK окружение.

### Modified Capabilities

Нет. Full-runtime/module delivery, readiness и обычный checkout launcher сохраняются.

## Impact

Private installer environment и managed launchers, shared policy/helper, native regression/docs. Нет global SDK install/PATH/profile updates, новых LSP, credential migration или своего SDK manager. Runtime Core/language inventory/native Mac/publication остаются следующими gates.
