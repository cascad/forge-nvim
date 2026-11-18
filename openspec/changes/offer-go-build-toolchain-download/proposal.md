# Proposal

## Why

После предложения рекомендованного варианта владелец поручил продолжить план.
Для установки Go IDE tools нужен явный выбор: штатный Go может скачать более
новый build toolchain, сохраняя SDK проекта. Сейчас setup-stage.lua и
install-private.lua всегда задают GOTOOLCHAIN=local, а build_sdks требует Go1.26+.
На старом доступном SDK установка gopls/gofumpt/golines останавливается без
предложения. Это новый IDE-BOOT-42, не отмена прежнего запрета скрытой загрузки.

## What Changes

- Отдельное предложение в интерактивном установщике для Go tools, по умолчанию Нет.
- Явный CLI выбор allow/deny, отображение в плане/логе; headless default deny.
- Штатный GOTOOLCHAIN=auto только у согласованного tools stage до Mason init.
- Readiness допускает старый Go1.21+ при allow; свежий compiler выбирает сам Go.
- Не менять проектный SDK, go env -w, profiles, GOENV/GOPROXY/GOSUMDB и SDK homes.
- Native regressions UI/CLI/setup/Mason boundary, отказ offline и сохранность kit.

## Capabilities

### New Capabilities

- `go-build-toolchain-policy`: IDE-BOOT-42, явное согласие на native build toolchain.

## Impact

Existing Rust frontend/private Lua setup/readiness, E2E и документы. Mason/native
Go providers сохраняются. Остальная политика обновления IDE tools и native Mac —
следующие отдельные пункты. Системные SDK во время реализации не устанавливаются.
