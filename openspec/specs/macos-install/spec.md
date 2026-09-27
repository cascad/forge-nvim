# macos-install Specification

## Purpose
Установщик `nvim_forge/scripts/install-macos.sh` целиком: запуск одной командой из чекаута, выбор режима, бутстрап через `curl | bash`, Homebrew и зависимости, Nerd Font, приложение WezTerm, бэкапы, установка в `~/.config/nvim`, итоговый код возврата, повторные запуски и совместимость с `/bin/bash` 3.2. Подключение, нейтрализация перекрытий и проверка конфига WezTerm описаны в capability `wezterm-config-loading` (WT-LOAD-4…WT-LOAD-12), здесь на них только ссылки; установщики Windows и Linux не покрыты (Linux-симлинк — WT-LOAD-13).

## Requirements

### Requirement: MAC-INST-1 Одна команда из чекаута
Запуск `./nvim_forge/scripts/install-macos.sh` из чекаута монорепо без флагов SHALL выполнить всю установку для macOS — Homebrew в PATH, зависимости, Nerd Font, приложение WezTerm и подключение его конфига (WT-LOAD-4…WT-LOAD-12) — не трогая `~/.config/nvim`, и MUST завершиться подсказкой, как запускать IDE.
Платформы: macos
История: FIXLOG §43
Проверка: tests/install-macos.scenarios.sh (S1)

#### Scenario: чистый мак с Homebrew
- **GIVEN** чекаут монорепо, Homebrew установлен
- **WHEN** запускается `<чекаут>/nvim_forge/scripts/install-macos.sh` из любого текущего каталога
- **THEN** выполняются шаги `==> Installing base dependencies`, `==> Installing Nerd Font (иконки в nvim/wezterm)`, `==> Setting up WezTerm`
- **AND** в конце печатается `Dependencies and WezTerm are ready; ~/.config/nvim untouched.`, `Launch: <корень>/nvim_forge.sh` и `(first start downloads plugins automatically)`
- **AND** `~/.config/nvim` не создаётся и не меняется

#### Scenario: плагины nvim
- **WHEN** установка в локальном режиме завершилась
- **THEN** установщик плагины Neovim не ставит — они скачиваются при первом запуске `./nvim_forge.sh`

#### Scenario: аргументы командной строки
- **WHEN** скрипту переданы аргументы
- **THEN** они игнорируются; настройки задаются только переменными окружения (MAC-INST-13)

### Requirement: MAC-INST-2 Режим определяется сам
`install-macos.sh` SHALL выбирать локальный режим (не трогать `~/.config/nvim`), когда он запущен как файл и двумя уровнями выше его каталога (в чекауте — корень монорепо) лежит `nvim_forge.sh`, а иначе — установку в каталог конфига Neovim (MAC-INST-10); непустой `FORGE_NVIM_DEPS_ONLY` MUST отключать автоопределение, причём локальный режим включает только значение `1`.
Платформы: macos
История: FIXLOG §43
Проверка: tests/install-macos.scenarios.sh (S1, S7, S11)

#### Scenario: из чекаута без флагов
- **WHEN** скрипт запущен из чекаута монорепо
- **THEN** локальный режим, в конце `Launch: <корень>/nvim_forge.sh`

#### Scenario: явный FORGE_NVIM_DEPS_ONLY=0 из чекаута
- **WHEN** скрипт запущен из чекаута с `FORGE_NVIM_DEPS_ONLY=0`
- **THEN** после шагов зависимостей и WezTerm выполняется установка в каталог конфига (`==> Installing forge-nvim`)

#### Scenario: FORGE_NVIM_DEPS_ONLY=1 вне монорепо
- **GIVEN** двумя уровнями выше каталога скрипта нет `nvim_forge.sh`
- **WHEN** скрипт запущен с `FORGE_NVIM_DEPS_ONLY=1`
- **THEN** локальный режим, подсказка без пути: `Launch from the repo checkout: ./nvim_forge.sh`

#### Scenario: значение, отличное от 1
- **WHEN** скрипт запущен с `FORGE_NVIM_DEPS_ONLY=yes`
- **THEN** автоопределение отключено и режим — установка в каталог конфига, как при `0`

#### Scenario: копия скрипта в установленном конфиге
- **GIVEN** скрипт запущен из `~/.config/nvim/scripts/` (конфиг, установленный копией)
- **WHEN** флаг не задан
- **THEN** это не монорепо — режим установки в каталог конфига

### Requirement: MAC-INST-3 curl | bash: чекаут в FORGE_NVIM_SRC и перезапуск оттуда
При запуске не из файла (`curl … | bash`) `install-macos.sh` SHALL до всех остальных шагов получить чекаут монорепо в `FORGE_NVIM_SRC` (по умолчанию `~/forge-nvim`) — клонировать `FORGE_NVIM_REPO` веткой `FORGE_NVIM_BRANCH` или, если там уже git-чекаут, обновить его `git pull --ff-only` — и MUST перезапуститься (`exec bash`) скриптом из этого чекаута, так что дальше путь установки тот же, что в MAC-INST-1.
Платформы: macos
История: FIXLOG §43
Проверка: tests/install-macos.scenarios.sh (S7)

#### Scenario: чистый мак
- **GIVEN** `~/forge-nvim` нет, git есть
- **WHEN** выполняется `curl -fsSL …/install-macos.sh | bash`
- **THEN** `==> Cloning <репо> -> <HOME>/forge-nvim`, затем локальный режим из клона
- **AND** симлинк конфига WezTerm ведёт в `~/forge-nvim/wezterm.lua`, в конце `Launch: <HOME>/forge-nvim/nvim_forge.sh`

#### Scenario: чекаут уже есть
- **GIVEN** `FORGE_NVIM_SRC` содержит каталог `.git`
- **WHEN** выполняется `curl … | bash`
- **THEN** `==> Updating checkout <каталог>` и `git pull --ff-only` текущей ветки чекаута (`FORGE_NVIM_BRANCH` не применяется)

#### Scenario: git нет в PATH
- **GIVEN** команды `git` нет в PATH
- **WHEN** выполняется `curl … | bash`
- **THEN** в stderr `git is required: run \`xcode-select --install\`, then rerun this command.`, код 1, ничего не установлено

#### Scenario: нет Xcode Command Line Tools
- **GIVEN** штатный мак без CLT: `/usr/bin/git` — системная заглушка, `git` в PATH есть
- **WHEN** выполняется `curl … | bash`
- **THEN** проверка на git проходит, `git clone` вызывает системное предложение поставить CLT и завершается ошибкой; установка останавливается с сообщением git, подсказки скрипта про `xcode-select --install` нет (по устройству macOS, на месте не проверено)

#### Scenario: git не смог
- **GIVEN** pull не fast-forward или `FORGE_NVIM_SRC` — непустой каталог без `.git`
- **WHEN** выполняется `curl … | bash`
- **THEN** установка останавливается с ненулевым кодом и сообщением git

#### Scenario: FORGE_NVIM_SRC — чекаут другого репо
- **GIVEN** `FORGE_NVIM_SRC` — git-чекаут, в котором нет `nvim_forge/scripts/install-macos.sh`
- **WHEN** выполняется `curl … | bash`
- **THEN** чекаут обновляется `git pull --ff-only`, затем перезапуск падает (`No such file or directory`, код 127)

#### Scenario: флаги переходят в перезапуск
- **GIVEN** `FORGE_NVIM_DEPS_ONLY=0` (или другие `FORGE_NVIM_*`) заданы в окружении
- **WHEN** скрипт перезапускается из чекаута
- **THEN** флаги действуют и там
- **AND** перезапуск идёт через `bash` из PATH (на штатном маке — `/bin/bash` 3.2)

### Requirement: MAC-INST-4 Homebrew в PATH
Если `brew` не в PATH, но исполняемый `/opt/homebrew/bin/brew` или `/usr/local/bin/brew` есть (в этом порядке), `install-macos.sh` SHALL подключить его в текущем прогоне и один раз дописать в профиль логин-шелла помеченную строку `eval "$(<путь>/brew shellenv)"`; без Homebrew шаг зависимостей MUST остановить установку с кодом 1, если не задан `FORGE_NVIM_SKIP_DEPS=1`.
Платформы: macos
История: FIXLOG §43

#### Scenario: Apple Silicon, brew не в PATH
- **GIVEN** `$SHELL` — zsh, `/opt/homebrew/bin/brew` есть, в PATH его нет
- **WHEN** запускается установщик
- **THEN** в `${ZDOTDIR:-~}/.zprofile` дописаны пустая строка, `# [forge-nvim] Homebrew on PATH (install-macos.sh)` и `eval "$(/opt/homebrew/bin/brew shellenv)"`, в выводе `<профиль>: добавлен brew shellenv`
- **AND** brew доступен уже в этом прогоне

#### Scenario: логин-шелл bash
- **GIVEN** `$SHELL` оканчивается на `/bash`
- **WHEN** brew не в PATH
- **THEN** строка дописывается в `~/.bash_profile`

#### Scenario: другой логин-шелл
- **GIVEN** `$SHELL` — fish или другой не-bash шелл
- **WHEN** brew не в PATH
- **THEN** строка всё равно дописывается в `${ZDOTDIR:-~}/.zprofile`, где `ZDOTDIR` берётся из окружения самого установщика

#### Scenario: строка уже есть или brew уже в PATH
- **WHEN** в профиле уже есть точно такая строка или brew уже в PATH
- **THEN** профиль не меняется

#### Scenario: Homebrew нет
- **GIVEN** brew нет ни в PATH, ни в стандартных путях, `FORGE_NVIM_SKIP_DEPS` не задан
- **WHEN** запускается установщик
- **THEN** в stderr `Homebrew is required for automatic dependency install: https://brew.sh` и `Install brew or rerun with FORGE_NVIM_SKIP_DEPS=1 after installing dependencies manually.`, код 1 до шага WezTerm

#### Scenario: FORGE_NVIM_SKIP_DEPS=1
- **WHEN** установщик запущен с `FORGE_NVIM_SKIP_DEPS=1`
- **THEN** `Skipping dependency install`, brew в PATH не прописывается, а шаг WezTerm находит brew, только если он уже в PATH (MAC-INST-7)

### Requirement: MAC-INST-5 Зависимости: ставится только недостающее
`install-macos.sh` SHALL ставить через Homebrew только отсутствующие формулы из набора `git neovim ripgrep fd cmake tree-sitter-cli` одной командой `brew install`, сообщая про каждую уже установленную `<формула>: already installed`; с `FORGE_NVIM_WITH_LANGUAGES=1` он MUST так же ставить недостающие из `go python rustup-init`, затем запускать `rustup-init`, если `cargo` нет в PATH, и ставить `gopls`, если его нет.
Платформы: macos
История: FIXLOG §43

#### Scenario: всё уже стоит
- **WHEN** все формулы установлены
- **THEN** `brew install` не вызывается, по каждой — `already installed`

#### Scenario: часть отсутствует
- **WHEN** отсутствуют, например, `fd` и `cmake`
- **THEN** выполняется один `brew install fd cmake`

#### Scenario: brew install упал
- **WHEN** `brew install` завершился ошибкой
- **THEN** установка останавливается с ненулевым кодом, следующие шаги не выполняются

#### Scenario: языковые тулчейны
- **GIVEN** `FORGE_NVIM_WITH_LANGUAGES=1`
- **WHEN** запускается установщик
- **THEN** шаг `==> Installing optional language toolchains`, недостающие формулы из `go python rustup-init` ставятся одним `brew install`; если нет `cargo` в PATH — `rustup-init -y --no-modify-path`
- **AND** если `gopls` нет ни в PATH, ни в `$(go env GOPATH)/bin` — `go install golang.org/x/tools/gopls@latest` и `gopls -> <GOPATH>/bin (добавь этот каталог в PATH, если его там нет)`, иначе `gopls: already installed`
- **AND** сбой `rustup-init` или `go install` останавливает установку

#### Scenario: Rust без ~/.cargo/bin в PATH
- **GIVEN** Rust уже поставлен прошлым прогоном, `~/.cargo/bin` не в PATH
- **WHEN** установщик снова запускается с `FORGE_NVIM_WITH_LANGUAGES=1`
- **THEN** `rustup-init -y --no-modify-path` запускается снова

#### Scenario: FORGE_NVIM_SKIP_DEPS=1
- **WHEN** флаг задан
- **THEN** формулы, языковые тулчейны и Nerd Font (MAC-INST-6) не ставятся

### Requirement: MAC-INST-6 Nerd Font: пропуск при наличии, сбой — предупреждение
`install-macos.sh` SHALL пропускать установку шрифта с `CaskaydiaCove Nerd Font: already present in Library/Fonts`, только когда файлы `CaskaydiaCoveNerdFont*` есть одновременно и в `~/Library/Fonts`, и в `/Library/Fonts`, а иначе ставить cask `font-caskaydia-cove-nerd-font`, если тот ещё не установлен; сбой установки шрифта MUST быть предупреждением, а не остановкой, и не влиять на код возврата.
Платформы: macos
История: FIXLOG §43

#### Scenario: шрифт в обоих каталогах
- **GIVEN** `CaskaydiaCoveNerdFont*` есть и в `~/Library/Fonts`, и в `/Library/Fonts`
- **WHEN** запускается установщик
- **THEN** `CaskaydiaCove Nerd Font: already present in Library/Fonts`, cask не вызывается

#### Scenario: шрифт поставлен руками в один каталог
- **GIVEN** `CaskaydiaCoveNerdFont-Regular.ttf` есть только в `~/Library/Fonts` (или только в `/Library/Fonts`), cask не установлен
- **WHEN** запускается установщик
- **THEN** проверка наличия не срабатывает и вызывается `brew install --cask font-caskaydia-cove-nerd-font`; по комментарию в коде cask падает на конфликте файлов (на Mac не проверено) — тогда предупреждение, и так при каждом запуске

#### Scenario: cask уже стоит
- **WHEN** cask установлен (шрифт лежит только в `~/Library/Fonts`)
- **THEN** `font-caskaydia-cove-nerd-font: already installed`

#### Scenario: установка упала
- **WHEN** `brew install --cask font-caskaydia-cove-nerd-font` завершился ошибкой
- **THEN** в выводе `!! Nerd Font не поставился — иконки могут быть пустыми (brew install --cask font-caskaydia-cove-nerd-font)`, установка продолжается, код возврата от этого не меняется

### Requirement: MAC-INST-7 Приложение WezTerm
Если не задан `FORGE_NVIM_SKIP_WEZTERM=1`, `install-macos.sh` SHALL ставить cask `wezterm`, только когда нет ни команды `wezterm` в PATH, ни `/Applications/WezTerm.app`, и затем MUST подключить и проверить его конфиг (WT-LOAD-4…WT-LOAD-12); с `FORGE_NVIM_SKIP_WEZTERM=1` ни приложение, ни конфиг, ни окружение WezTerm не трогаются.
Платформы: macos
История: FIXLOG §43

#### Scenario: WezTerm уже есть
- **WHEN** есть `wezterm` в PATH или `/Applications/WezTerm.app`
- **THEN** `WezTerm: already installed`, cask не вызывается

#### Scenario: WezTerm нет, brew есть
- **WHEN** WezTerm отсутствует, brew в PATH
- **THEN** выполняется `brew install --cask wezterm` (или `wezterm: already installed`, если cask числится установленным)
- **AND** сбой этой установки останавливает скрипт с ненулевым кодом (в отличие от шрифта)

#### Scenario: WezTerm.app только в ~/Applications
- **GIVEN** приложение лежит в `~/Applications`, команды `wezterm` в PATH нет, brew есть
- **WHEN** запускается установщик
- **THEN** оно не распознаётся: ставится cask `wezterm`

#### Scenario: нет ни WezTerm, ни brew
- **WHEN** WezTerm отсутствует и brew не в PATH
- **THEN** `brew not found; install WezTerm manually: https://wezterm.org`, конфиг всё равно подключается, проверка загрузки пропускается (нет CLI, WT-LOAD-11), код 0

#### Scenario: FORGE_NVIM_SKIP_WEZTERM=1
- **WHEN** флаг задан
- **THEN** `Skipping WezTerm setup`, шаг на код возврата не влияет

### Requirement: MAC-INST-8 Бэкапы и FORGE_NVIM_NO_BACKUP
Всё, что установщик заменяет (`~/.wezterm.lua`, `…/wezterm/wezterm.lua` или сам `…/wezterm`, если это не каталог, каталог установки конфига Neovim), SHALL перемещаться целиком в `<путь>.backup-ГГГГММДД-ЧЧММСС` рядом с оригиналом, а не удаляться; с `FORGE_NVIM_NO_BACKUP=1` установщик MUST вместо бэкапа остановиться с кодом 1 на первом занятом пути.
Платформы: macos
История: FIXLOG §43
Проверка: tests/install-macos.scenarios.sh (S2, S3, S8, S9, S10, S14, S15)

#### Scenario: бэкап
- **WHEN** заменяемый путь занят
- **THEN** выводится `==> Backing up existing config` и `<путь> -> <путь>.backup-<время>`, оригинал с содержимым лежит под новым именем

#### Scenario: путь уже ведёт в репо
- **WHEN** заменяемый путь уже ведёт в файл репо
- **THEN** он не бэкапится (WT-LOAD-4, WT-LOAD-5)

#### Scenario: FORGE_NVIM_NO_BACKUP=1 и занятый путь
- **WHEN** установщику нужно заменить занятый путь
- **THEN** в stderr `Install path already exists: <путь>` и `Remove it manually or run without FORGE_NVIM_NO_BACKUP=1.`, код 1
- **AND** шаги до этого момента уже выполнены (зависимости, приложение WezTerm); в шаге WezTerm отказ происходит до правок launchd и профилей (WT-LOAD-9)

#### Scenario: FORGE_NVIM_NO_BACKUP=1 без занятых путей
- **WHEN** заменять нечего
- **THEN** установка идёт как обычно

#### Scenario: бэкапы копятся
- **WHEN** несколько прогонов что-то заменяли
- **THEN** каждый оставил свой бэкап; установщик их не удаляет и не ротирует

### Requirement: MAC-INST-9 Код возврата
`install-macos.sh` SHALL завершаться с кодом 1, если шаг WezTerm признан сломанным (WT-LOAD-8, WT-LOAD-10, WT-LOAD-11), напечатав после всех остальных шагов в stderr `!! WezTerm: конфиг из репо НЕ будет загружен — см. сообщения выше.` и `Исправь указанное и запусти этот скрипт ещё раз.`; сломанный шаг WezTerm MUST NOT прерывать остальные шаги, а при успешном или пропущенном шаге WezTerm код — 0.
Платформы: macos
История: FIXLOG §43
Проверка: tests/install-macos.scenarios.sh (S6, S13, S16)

#### Scenario: сломанный конфиг в локальном режиме
- **GIVEN** `wezterm.lua` не загружается
- **WHEN** установщик запущен из чекаута
- **THEN** печатается и `Dependencies and WezTerm are ready; ~/.config/nvim untouched.`, и затем сообщение о сломанном шаге WezTerm, код 1

#### Scenario: сломанный шаг WezTerm в режиме ~/.config/nvim
- **WHEN** шаг WezTerm сломан при установке в каталог конфига
- **THEN** установка конфига и синхронизация плагинов всё равно выполняются, затем код 1

#### Scenario: жёсткие ошибки
- **WHEN** нет Homebrew, отказ по `FORGE_NVIM_NO_BACKUP`, нет git, упал git, `brew install`, `rustup-init` или `go install`, нет `init.lua` или `nvim` (MAC-INST-10), либо упала любая другая команда скрипта
- **THEN** скрипт останавливается сразу с ненулевым кодом, финального сообщения о WezTerm нет

#### Scenario: предупреждения
- **WHEN** не поставился шрифт, профиль шелла только для чтения или не найден CLI WezTerm
- **THEN** код возврата 0

### Requirement: MAC-INST-10 Установка в каталог конфига Neovim
В режиме установки в каталог конфига (MAC-INST-2) `install-macos.sh` SHALL после шагов зависимостей и WezTerm поставить конфиг в `FORGE_NVIM_INSTALL_DIR` и синхронизировать плагины, и MUST остановиться с кодом 1, если в каталоге после установки нет `init.lua` или нет `nvim` в PATH, а не отчитываться об успешной установке.
Платформы: macos
История: FIXLOG §43
Проверка: tests/install-macos.scenarios.sh (S11)

#### Scenario: локальный источник
- **GIVEN** `FORGE_NVIM_USE_LOCAL_SOURCE=1`, скрипт запущен из чекаута (уровнем выше скрипта есть `init.lua` и `lua/`)
- **WHEN** выполняется установка
- **THEN** занятый каталог уходит в бэкап, в него копируется `nvim_forge/` чекаута (без `.git` и `nvim.log`)
- **AND** затем `Lazy! sync` (сбой — остановка), установка Treesitter-парсеров и Mason-инструментов (сбой — только сообщение), в конце `forge-nvim installed: <каталог>` и `Start with: nvim`

#### Scenario: локальный источник не из чекаута
- **GIVEN** `FORGE_NVIM_USE_LOCAL_SOURCE=1`, скрипт запущен не из чекаута
- **WHEN** выполняется установка
- **THEN** занятый каталог сначала уходит в бэкап, затем `FORGE_NVIM_USE_LOCAL_SOURCE=1 requested, but script is not running from a forge-nvim checkout.` и код 1

#### Scenario: источник по умолчанию — клон монорепо
- **GIVEN** `FORGE_NVIM_USE_LOCAL_SOURCE` не задан, git есть
- **WHEN** выполняется установка
- **THEN** занятый каталог уходит в бэкап, в него клонируется весь монорепо (`FORGE_NVIM_REPO`, ветка `FORGE_NVIM_BRANCH`), в корне которого нет `init.lua`
- **AND** установка останавливается с `No init.lua in <каталог>: this is not a Neovim config.` и подсказкой `From a checkout, install with FORGE_NVIM_USE_LOCAL_SOURCE=1, or just run the script without flags (local mode).`, код 1; в каталоге остаётся клон, прежний конфиг — в бэкапе

#### Scenario: каталог уже git-чекаут forge-nvim
- **GIVEN** каталог — git-чекаут, чей origin равен `FORGE_NVIM_REPO` или содержит `forge-nvim`
- **WHEN** выполняется установка
- **THEN** fetch, checkout и `pull --ff-only` ветки без бэкапа, затем та же проверка `init.lua`

#### Scenario: скрипт запущен из каталога установки
- **WHEN** каталог скрипта `..` и есть каталог установки
- **THEN** `Already running from the target config directory`, ничего не копируется, затем синхронизация плагинов

#### Scenario: нет git
- **WHEN** git нет
- **THEN** из чекаута — копия, как с `FORGE_NVIM_USE_LOCAL_SOURCE=1`; не из чекаута — занятый каталог уходит в бэкап, затем `git is required to clone <репо>`, код 1

#### Scenario: запуск из терминала nvim_forge
- **GIVEN** шелл внутри nvim_forge (`XDG_CONFIG_HOME` = корень репо), `FORGE_NVIM_INSTALL_DIR` не задан
- **WHEN** установщик запущен с `FORGE_NVIM_DEPS_ONLY=0`
- **THEN** каталог установки — `<репо>/nvim`: конфиг копируется или клонируется внутрь репо

#### Scenario: нет nvim
- **WHEN** `init.lua` на месте, а `nvim` не в PATH
- **THEN** `nvim is not available in PATH. Install Neovim or restart the shell.`, код 1

### Requirement: MAC-INST-11 Повторный запуск
Повторный запуск `install-macos.sh` в локальном режиме SHALL ничего не переустанавливать и не менять, если всё уже на месте, — ни новых бэкапов, ни новых строк в профилях, ни подсказки о перезапуске, код 0, — а то, что разъехалось с прошлого раза, MUST чинить тем же прогоном (WT-LOAD-4…WT-LOAD-8).
Платформы: macos
История: FIXLOG §43
Проверка: tests/install-macos.scenarios.sh (S2, S3 rerun, S9)

#### Scenario: всё на месте
- **GIVEN** предыдущий прогон завершился успешно; шрифт стоит cask'ом (или лежит в обоих каталогах, MAC-INST-6), `FORGE_NVIM_WITH_LANGUAGES` не задан
- **WHEN** установщик запускается снова
- **THEN** формулы, cask'и и шрифт — `already installed`/`already present`, симлинк — `WezTerm config already linked`, строка `brew shellenv` не дублируется
- **AND** бэкапов не прибавилось, блоки в профилях не дублируются, подсказки о перезапуске нет, код 0

#### Scenario: перекрытие появилось снова
- **GIVEN** после установки снова появился чужой `~/.wezterm.lua`, симлинк побился или в launchd опять задана переменная
- **WHEN** установщик запускается снова
- **THEN** это нейтрализуется так же, как при первом запуске

#### Scenario: повтор с исключениями
- **GIVEN** шрифт поставлен руками в один каталог или задан `FORGE_NVIM_WITH_LANGUAGES=1` без `~/.cargo/bin` в PATH
- **WHEN** установщик запускается снова
- **THEN** снова вызывается cask шрифта (MAC-INST-6) или `rustup-init` (MAC-INST-5)

#### Scenario: повтор установки в ~/.config/nvim из локального источника
- **GIVEN** конфиг уже поставлен с `FORGE_NVIM_DEPS_ONLY=0 FORGE_NVIM_USE_LOCAL_SOURCE=1`
- **WHEN** установщик запускается снова с теми же флагами
- **THEN** каталог установки снова уходит в новый бэкап и конфиг копируется заново — каждый прогон добавляет бэкап

### Requirement: MAC-INST-12 Совместимость с /bin/bash 3.2
`install-macos.sh` SHALL работать под штатным `/bin/bash` 3.2.57 macOS так же, как под bash 5, без внешних утилит, которых нет в чистой macOS (`realpath`, `readlink -f`), и MUST одинаково определять запуск не из файла (`curl | bash`) в обеих версиях.
Платформы: macos
История: FIXLOG §43
Проверка: tests/install-macos.scenarios.sh <репо> <bash> — S1–S16 под bash 5.2 и bash 3.2.57

#### Scenario: весь набор под bash 3.2
- **WHEN** сценарии запускаются с bash 3.2.57 (собран из исходников; WSL)
- **THEN** все проверки проходят, как и под bash 5.2 (прогон 2026-09-27: 61 из 61 под обоими, без zsh)

#### Scenario: curl | bash в обоих bash
- **WHEN** скрипт читается со stdin
- **THEN** и в bash 3.2, и в bash 5 скрипт понимает, что запущен не из файла, и выполняет бутстрап (MAC-INST-3) — без ошибки «unbound variable» и без поиска `wezterm.lua` от текущего каталога

#### Scenario: петля симлинков
- **WHEN** путь — петля симлинков
- **THEN** после 40 переходов раскрытие прекращается, скрипт не зависает

### Requirement: MAC-INST-13 Флаги окружения
Настройки `install-macos.sh` SHALL задаваться только переменными окружения `FORGE_NVIM_*`, и для установки из чекаута ни одна из них MUST NOT быть нужна; включённым булев флаг считается только при значении `1`, пустое значение равно незаданному.
Платформы: macos
История: FIXLOG §43

#### Scenario: переменные и умолчания
- **WHEN** переменная не задана
- **THEN** действует умолчание: `FORGE_NVIM_SRC` — `~/forge-nvim`; `FORGE_NVIM_REPO` — `https://github.com/cascad/forge-nvim.git`; `FORGE_NVIM_BRANCH` — `main`; `FORGE_NVIM_DEPS_ONLY` — определяется само (MAC-INST-2); `FORGE_NVIM_INSTALL_DIR` — `${XDG_CONFIG_HOME:-~/.config}/nvim` по `XDG_CONFIG_HOME` шелла, из которого запущен установщик
- **AND** `FORGE_NVIM_SKIP_DEPS`, `FORGE_NVIM_SKIP_WEZTERM`, `FORGE_NVIM_WITH_LANGUAGES`, `FORGE_NVIM_USE_LOCAL_SOURCE`, `FORGE_NVIM_NO_BACKUP` — выключены

#### Scenario: без флагов из чекаута
- **WHEN** флаги не заданы
- **THEN** выполняется полная установка в локальном режиме (MAC-INST-1)

#### Scenario: значение флага не 1
- **WHEN** задано `FORGE_NVIM_SKIP_DEPS=true`
- **THEN** флаг считается выключенным, зависимости ставятся
