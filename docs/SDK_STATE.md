# Граница IDE и языковых SDK

§267: базовый SQL runtime использует готовый Sqruff LSP/formatter без DB SDK;
прежние native SQL parts ниже относятся к дополнительным операциям. §268 убрал
их обязательность в installer. Явно переданный bundle проверяется при наличии
его собственных SQL executables; обычный SQL/Bash выбор их не требует.

[Обзор установки и обновления инструментов](TOOLCHAIN_INSTALLATION_APPROACHES.md)
описывает подходы экосистем и решение владельца2026-11-17: штатные менеджеры,
upstream-пакеты и настраиваемые SDK/tool paths по образцу VS Code. Общий контракт
настроек пользователя/проекта реализован первым срезом для Python/Node/Bash
и JS entrypoints (§265, [формат и границы](TOOL_PATHS.md)). Текущее реализованное
поведение, включая ограничения explicit setup, описано ниже и этим решением не меняется.

§270: владелец подтвердил native environment как основу (вариант1). §271:
[выбор установленного Go/Rust SDK](SDK_SELECTION.md) реализован: `Space l S`,
найденный или ручной SDK, user/project/«Авто», явное переоткрытие с сессией.
Windows/Ubuntu E2E прошли; native Mac отдельно. Меняются только затрагиваемые
переменные процесса fride и его потомков. Глобальные PATH/profiles/homes и
SDK installations не меняются. §272 добавил Python/Node в это меню через
прежний tools.json: scoped set/reset, сохранение venv и native restart.
Их provider не меняет окружение SDK. Windows/Ubuntu E2E прошли, Mac отдельно.
Следующий шаг — согласовать installer/setup/runtime выбор.

Решение владельца2026-11-15: fride изолирует собственные компоненты, а Go,
Rust/Cargo/Rustup, Node/npm и Python использует штатно. Исправление §244
заменяет ошибочную общую SDK policy §243 / 6387a4b.

| Компонент | Расположение и выбор |
|---|---|
| Neovim, конфигурация, launchers | Выбранный InstallPath: runtime/, config/forge/, bin/ |
| Plugins, Mason LSP/DAP и IDE tools | Штатный Neovim data приложения NVIM_APPNAME=fride |
| IDE state, sessions, cache | Штатные каталоги приложения fride, отдельно от обычного nvim |
| Core/install logs и temp | InstallPath/log и tmp; внутренние IDE logs — stdpath('state') |
| Языковые SDK | Исходный PATH/project rules/venv; явный Go/Rust SDK через sdk.json |

XDG_CONFIG_HOME/DATA_HOME/STATE_HOME/CACHE_HOME, HOME/USERPROFILE не меняются.
Не задаются GOPATH/GOBIN/GOCACHE/GOMODCACHE/GOENV, CARGO_HOME/INSTALL_ROOT,
RUSTUP_HOME, npm cache/prefix/config, pip cache/config/targets и Python userbase.
Заданные значения сохраняются; незаданные остаются незаданными. Это сохраняет
и native defaults SDK, зависящие от XDG. IDE runtime directories добавляются
перед исходным PATH; каталогов sdk-state в PATH нет. На Windows сам Neovim
дополнительно добавляет свой bin в конец PATH, порядок SDK не меняется.

Mason использует штатные private install locations своих providers. Установка
IDE tool может явно выбрать destination/venv только для конкретной установки;
это не новый глобальный профиль языка. Общие компиляторы, package managers,
SDK registries/auth и caches не принадлежат fride.

§246: explicit SDK checks и подготовка IDE tools задают только своим subprocess
GOTOOLCHAIN=local и RUSTUP_AUTO_INSTALL=0, чтобы отсутствие toolchain не вызывало
скрытую загрузку языка. Обычный launcher эти политики пользователя сохраняет.
Prerequisites проверяются по PATH: Go, rustc/cargo, Python3, Node; npm entrypoint
проверяется на наличие, без shell запуска .cmd. Ready означает базовую CLI
готовность, не совместимость всех packages/версий проекта. PATH symlinks
сохраняются, в том числе активная venv. Проверки ограничены2s на CLI и не
выполняются на обычном startup или в preview/print-plan.

Конфигурация из kit выбирается явно через -u и runtimepath; FRIDE_CONFIG
содержит её фактический путь. Lazy использует lockfile этой конфигурации и
сохраняет её runtimepath. «Открыть конфиг» открывает kit/config/forge/init.lua,
а не несуществующий init в стандартном config namespace.

Точные native пути: `:echo stdpath('data')`, `:echo stdpath('state')`.
Имя каталога data — fride на Unix и fride-data на Windows. Несколько установок
fride у одного пользователя используют общий стандартный namespace данных.
Обычные nvim/nvim-data и checkout-профиль nvim_forge остаются отдельными.

При обновлении старые kit data/state/cache/sdk-state сохраняются на месте и
не копируются в SDK пользователя. Новый launcher их не выбирает; явный setup
готовит plugins/tools в штатном namespace fride. SDK credentials не мигрируются.
При завершении Windows launcher восстанавливает caller environment и код
выхода; POSIX изменения ограничены дочерним процессом. На запуске ничего не
устанавливается. §247: недостающий SDK предлагается через native TUI, включая
Default. Existing path/install/skip/refresh/cancel доступны с клавиатуры;
install требует отдельного подтверждения команды. SDK живёт отдельно и не
удаляется при отмене IDE. См. [план](INSTALLATION_PLAN.md).

Выбранные existing locations — только metadata в bin/sdk-paths.txt, после
успешного IDE commit. Они добавляются после caller PATH и сохраняются на upgrade;
project venv имеет приоритет. Установщик не пишет global PATH сам. Windows
после explicit install/refresh читает registered PATH/CPython InstallPath,
сохраняя лишь найденные SDK bin directories. Неисправный SDK раньше в PATH
не маскируется fallback. --sdk-path DIR поддерживается frontend для automation.
Root/bin/Scripts распознаются в TUI, locations внутри заменяемого kit запрещены.

§251: gopls/stylua/gofumpt/golines/prettier готовятся через Mason в штатном
fride data, не в пользовательские global prefixes. Когда нужна сборка Go
tools, tools stage проверяет обычный Go1.26.0+; готовые pinned packages
переиспользуются без обновления build SDK. SDK homes/env не переносятся,
normal launch сохраняет SDK policies. [Версии и границы](INSTALLATION_PLAN.md#подготовка-существующих-ide-tools--251).

§252: managed SQL получает готовые sqls/forge-sqltest из native runtime part,
Go/Rust/C compiler у пользователя SQL не требуется. FRIDE_RUNTIME — только
контекст собственных IDE tools; PowerShell caller value восстанавливается.
Codelldb с его LLDB/Python bundle принадлежит Mason/fride, не Python SDK
проекта. Ручная Bash preparation патчит только свой Mason package; WSL2 не устанавливается.

WinGet использует exact IDs/no-upgrade; APT install --no-upgrade, brew
HOMEBREW_NO_INSTALL_UPGRADE. Их зависимостями управляет штатный менеджер;
версия — из его настроенного репозитория, не обещанная project version.
При missing package manager меню предлагает отдельную установку WinGet или
Homebrew (§249), по умолчанию «Нет». SDK подтверждается после этого отдельно.
Bootstrap, ошибка, retry и cancel логируются; exit0 без менеджера не даёт
запустить SDK install. Уже имеющийся WindowsApps alias или Homebrew в
стандартном prefix переиспользуется без изменения global PATH/profile.
Отсутствие APT в Ubuntu требует исправления ОС владельцем; другой менеджер
молча не ставится. Native Mac и настоящая установка менеджеров здесь не проверены.

Проверка: Windows `python -B tests/install-sdk-state.test.py`, Linux/macOS
`python3 -B tests/install-sdk-state.test.py`. Нужны готовые native Neovim,
Go/Rust SDK/Rustup, Node24.11.0 из прежнего stand cache и Python. Stand не
скачивает SDK и не выполняет go env -w/cargo install/npm install/pip install.
Настоящие SDK queries внутри fride сравниваются с теми же командами снаружи.
Проверяются setup/probes/launch, явные и unset SDK values, XDG defaults,
активная настоящая venv, repeat с прежним sdk-state и Windows caller restore.
Init/setup callbacks — fixtures; это не полный release/языковой acceptance.
Raw/env/argv/exit/summary сохраняются в .tests/install-isolation/<id>.

Готовый Docker image, без build/pull/сети и управления Desktop/WSL:

```sh
docker compose -f tests/containers/compose.yaml run --rm --no-deps --pull never -e FORGE_INSTALL_STAND_ROOT=/tmp/fride-native-sdk --entrypoint python3 ubuntu -B tests/install-sdk-state.test.py
```

Host .tests/ubuntu — guest /workspace/.tests; тяжёлые stand runtime copies
остаются в /tmp и удаляются вместе с контейнером. Mac проверяется нативно
владельцем. Результаты каждой ОС записываются отдельно, Ubuntu не заменяет Mac.
