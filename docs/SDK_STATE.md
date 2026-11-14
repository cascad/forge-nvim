# Состояние SDK установленного fride

Установленный комплект использует scripts/sdk-environment.tsv как общую policy
для подготовки/probes и PS/Bash launchers. Файл копируется в kit/bin. На старте
launcher читает готовые значения; SDK discovery/install и миграция настроек
не выполняются. Checkout fride продолжает прежний development workflow.

| SDK | Собственные пути внутри kit |
|---|---|
| Go | sdk-state/go (GOPATH), sdk-state/go/bin (GOBIN), cache/go-build, cache/go-mod, sdk-state/go/env (GOENV) |
| Cargo/Rustup | sdk-state/cargo (CARGO_HOME/CARGO_INSTALL_ROOT), sdk-state/rustup (RUSTUP_HOME) |
| npm | cache/npm, sdk-state/npm (global prefix), user.npmrc/global.npmrc в sdk-state/npm |
| Python/pip | sdk-state/python/user (PYTHONUSERBASE), cache/python-bytecode, cache/pip, sdk-state/python/pip.conf |

Go/Cargo/npm mutable bin directories добавляются после runtime и до caller PATH.
Унаследованные npm uppercase aliases и pip target/prefix/user redirects не
перенаправляют SDK install в прежние каталоги. HOME/USERPROFILE, VIRTUAL_ENV,
CARGO_TARGET_DIR и project build flags сохраняются. При Windows exit/error все
затронутые caller env values восстанавливаются; POSIX env живёт только в child.
Это SDK defaults, не файловый sandbox: explicit project/CLI settings остаются
пользовательским выбором.

Каталоги/пустые native config files создаются только явной установкой. Повтор
сохраняет уже существующие файлы; sdk-state/.gitignore исключает собственное
состояние из случайного git add. Личные config/credentials не копируются.
SDK config теперь отдельный профиль: настройки корпоративных registries/auth
задаются проектом, окружением или штатными SDK-командами в этом профиле.
Git/SSH HOME не меняется.

RUSTUP_HOME сам по себе не содержит toolchain. Release Rust module обязан
подготовить проверенный compiler/toolchain для этого home; это отдельный
inventory/provisioning gate, никакого fallback в ~/.rustup проверка не обещает.
Правила Go toolchain/Rustup auto-install глобально не меняются. Python scripts
могут использовать native version-specific user scheme; функциональный Python
SDK должен проверять свои entrypoints, не угадывать номер версии в PATH.

Native SDK env semantics: [Cargo](https://doc.rust-lang.org/cargo/reference/environment-variables.html),
[Rustup](https://rust-lang.github.io/rustup/environment-variables.html),
[Go](https://pkg.go.dev/cmd/go), [npm](https://docs.npmjs.com/using-npm/config/),
[pip](https://pip.pypa.io/en/stable/topics/configuration/),
[Python](https://docs.python.org/3/using/cmdline.html#environment-variables).

Проверки: Windows `python -B tests/install-sdk-state.test.py`, Linux/macOS
`python3 -B tests/install-sdk-state.test.py`. Нужны готовые native Neovim,
Go/Rustup/Rust SDK и Node24.11.0 SDK из прежнего stand cache; SDK не скачиваются.
В image системный Python без pip использует готовый pip module из Python stand
venv readonly. Native операции: go env -w, rustup local settings, cargo install
--offline локального crate, npm global install локального tarball и pip --user
локального wheel. Последний явно использует только private userbase; разрешение
PEP668 в controlled stand не означает запись в system packages.

Init/setup callbacks — fixtures; это state/launch E2E, не полный SDK inventory.
Source RED доказывает inherited SDK redirects; env reports наблюдают native
probe/все3 setup stages/launch, caller/project context и foreign SDK snapshots.
Windows native SDK loader может создать пустой INetCache/IE/container.dat в
тестовом user profile: только exact empty bookkeeping file исключён и отдельно
записан; непустой файл не скрывается. Никакие личные SDK/config файлы не
исключаются из snapshot. Native Mac остаётся отдельным запуском владельца.
