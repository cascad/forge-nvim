## Context

См. proposal.md. launch-managed PS/sh и install-private.lua дублируют неполные GOPATH/GOCACHE/npm/pip cache assignments. GOENV/GOBIN/GOMODCACHE, CARGO_HOME/CARGO_INSTALL_ROOT/RUSTUP_HOME, npm prefix/config и Python user/cache/config остаются inherited/default. Штатные SDK env semantics сверены по primary docs Rust/Go/npm/pip/Python.

## Goals / Non-Goals

Goals: одна декларативная policy и согласованный child env для probes/setup/launch, private mutable bins, state persistence, native Windows/Ubuntu/offline SDK E2E.
Non-Goals: HOME sandbox, копирование credentials/config, Rust toolchain manager/seed implementation, изменение project venv/build outputs или language inventory. Готовые Rust parts должны отдельно содержать/подготовить toolchain для private RUSTUP_HOME, probes не допускают пустой runtime к release.

## Decisions

- scripts/sdk-environment.tsv kind/key/relative-path: dir/file/clear/bin. Один набор путей; PS/sh только применяют policy, Lua готовит dirs/files и тот же env. Policy копируется в kit/bin и читается быстро без subprocess на startup.
- SDK state хранится в sdk-state, caches в cache; npm upper aliases очищаются перед canonical lower options. GOBIN/CARGO_INSTALL_ROOT/npm prefix задаются явно; PIP target/prefix/user redirects очищаются. GOENV/npm/pip private config files создаются пустыми только если отсутствуют, личные configs/tokens не копируются. Не считать это security sandbox: пользовательские explicit CLI/project settings остаются ответственностью пользователя.
- Runtime executable paths имеют прежний приоритет, затем собственные Go/Cargo/npm mutable bin dirs, затем inherited PATH. HOME/USERPROFILE и VIRTUAL_ENV/CARGO_TARGET_DIR/Go/Rust project flags не заменяются; checkout launchers не затрагиваются.
- PS finally восстанавливает все затронутые env values; POSIX изменения только в child. Подготовка использует один Lua reader с portable validation; native config files не перезаписываются при обновлении. Нет настройки Go toolchain policy/Rustup auto-install глобально.
- Native stand: настоящий installed Neovim, controlled init/stage fixture, реальные SDK offline операции из readonly ready binaries. Source RED для inherited CARGO_HOME, snapshots чужих homes и caller env. SDK artifacts не публикуются этой проверкой.

## Risks / Trade-offs

- [SDK config homes становятся отдельным профилем] → документировать собственные locations; project/env auth сохраняется, tokens не мигрировать автоматически.
- [RUSTUP_HOME ещё без toolchain] → это инвентарь/инициализация Rust module, не молчаливый fallback в ~/.rustup; release probes/native SDK acceptance обязательны.
- [macOS недоступен] → те же native команды владельцу, не выдавать Linux за Mac.

## Migration Plan

Новый install публикует policy вместе с launchers; повтор сохраняет sdk-state/cache. Старые kits до обновления используют прежние launchers. При ошибке setup прежний launcher/runtime остаётся; state самого kit уже имел ограниченный rollback, чужие state не меняются.
