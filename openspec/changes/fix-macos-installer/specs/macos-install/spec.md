## MODIFIED Requirements

### Requirement: MAC-INST-3 curl | bash: чекаут в FORGE_NVIM_SRC и перезапуск оттуда
При запуске не из файла (`curl … | bash`), а также при запуске из файла вне чекаута монорепо в режиме установки в каталог конфига (MAC-INST-2, MAC-INST-10), `install-macos.sh` SHALL до всех остальных шагов получить чекаут монорепо в `FORGE_NVIM_SRC` (по умолчанию `~/forge-nvim`) — клонировать `FORGE_NVIM_REPO` веткой `FORGE_NVIM_BRANCH` или, если там уже git-чекаут, обновить его `git pull --ff-only` — и MUST перезапуститься (`exec bash`) скриптом из этого чекаута, так что дальше путь установки тот же, что при запуске из чекаута (MAC-INST-1, MAC-INST-10). Если git недоступен — команды `git` нет в PATH или это системная заглушка `/usr/bin/git` на маке без Xcode Command Line Tools, — установщик MUST остановиться с подсказкой про `xcode-select --install` до любых действий, не запуская git.
Платформы: macos
История: FIXLOG §43
Проверка: tests/install-macos.scenarios.sh (S7, S19, S27); вручную — мак без CLT (результат записывается в FIXLOG)

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
- **GIVEN** штатный мак без CLT: `git` в PATH — системная заглушка `/usr/bin/git`, `xcode-select -p` завершается ошибкой
- **WHEN** выполняется `curl … | bash`
- **THEN** в stderr `git is required: run \`xcode-select --install\`, then rerun this command.`, код 1
- **AND** git не запускается (системное предложение поставить CLT не всплывает), ничего не клонировано и не установлено

#### Scenario: git из CLT или Homebrew
- **GIVEN** `xcode-select -p` успешен, либо `git` в PATH — не `/usr/bin/git`
- **WHEN** выполняется `curl … | bash`
- **THEN** git считается доступным, чекаут клонируется или обновляется, как в сценариях выше

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

#### Scenario: файл вне чекаута в режиме установки в каталог конфига
- **GIVEN** скрипт запущен как файл (скачанный отдельно или копия из прежней установки в `~/.config/nvim/scripts/`), двумя уровнями выше его каталога нет `nvim_forge.sh`, `FORGE_NVIM_DEPS_ONLY` не задан или не равен `1`, `FORGE_NVIM_USE_LOCAL_SOURCE` не равен `1`
- **WHEN** запускается установщик
- **THEN** до шагов зависимостей чекаут в `FORGE_NVIM_SRC` клонируется или обновляется, как в сценариях выше, и скрипт перезапускается оттуда с `FORGE_NVIM_DEPS_ONLY=0`: выбранный режим сохраняется
- **AND** дальше — режим установки из этого чекаута (MAC-INST-10): симлинк конфига WezTerm ведёт в `<FORGE_NVIM_SRC>/wezterm.lua`, путь установки — симлинк на `<FORGE_NVIM_SRC>/nvim_forge`
- **AND** если git недоступен, остановка та же, что при `curl … | bash` (код 1, подсказка `xcode-select --install`), путь установки не тронут

### Requirement: MAC-INST-5 Зависимости: ставится только недостающее
`install-macos.sh` SHALL ставить через Homebrew только отсутствующие формулы из набора `git neovim ripgrep fd cmake tree-sitter-cli` одной командой `brew install`, сообщая про каждую уже установленную `<формула>: already installed`; с `FORGE_NVIM_WITH_LANGUAGES=1` он MUST так же ставить только недостающее: формулы `go python rustup-init`, Rust через `rustup-init` (только если нет ни `cargo` в PATH, ни исполняемого `~/.cargo/bin/cargo`) и `gopls`, если его нет.
Платформы: macos
История: FIXLOG §43
Проверка: tests/install-macos.scenarios.sh (S18)

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
- **THEN** шаг `==> Installing optional language toolchains`, недостающие формулы из `go python rustup-init` ставятся одним `brew install`; если Rust ещё не поставлен (нет ни `cargo` в PATH, ни `~/.cargo/bin/cargo`) — `rustup-init -y --no-modify-path`
- **AND** если `gopls` нет ни в PATH, ни в `$(go env GOPATH)/bin` — `go install golang.org/x/tools/gopls@latest` и `gopls -> <GOPATH>/bin (добавь этот каталог в PATH, если его там нет)`, иначе `gopls: already installed`
- **AND** сбой `rustup-init` или `go install` останавливает установку

#### Scenario: Rust без ~/.cargo/bin в PATH
- **GIVEN** Rust уже поставлен прошлым прогоном (`~/.cargo/bin/cargo` есть), `~/.cargo/bin` не в PATH
- **WHEN** установщик снова запускается с `FORGE_NVIM_WITH_LANGUAGES=1`
- **THEN** `rustup-init` не запускается
- **AND** в выводе `rust: already installed (~/.cargo/bin; добавь этот каталог в PATH, если его там нет)`

#### Scenario: FORGE_NVIM_SKIP_DEPS=1
- **WHEN** флаг задан
- **THEN** формулы, языковые тулчейны и Nerd Font (MAC-INST-6) не ставятся

### Requirement: MAC-INST-6 Nerd Font: пропуск при наличии, сбой — предупреждение
`install-macos.sh` SHALL ставить cask `font-caskaydia-cove-nerd-font`, только если файлов `CaskaydiaCoveNerdFont*` нет ни в `~/Library/Fonts`, ни в `/Library/Fonts` и cask ещё не установлен; сбой установки шрифта MUST быть предупреждением, а не остановкой, и не влиять на код возврата.
Платформы: macos
История: FIXLOG §43
Проверка: tests/install-macos.scenarios.sh (S17 — шрифт в `~/Library/Fonts`); `/Library/Fonts` и настоящий cask — вручную на macOS

#### Scenario: шрифт в обоих каталогах
- **GIVEN** `CaskaydiaCoveNerdFont*` есть и в `~/Library/Fonts`, и в `/Library/Fonts`
- **WHEN** запускается установщик
- **THEN** `CaskaydiaCove Nerd Font: already present in Library/Fonts`, cask не вызывается

#### Scenario: шрифт поставлен руками в один каталог
- **GIVEN** `CaskaydiaCoveNerdFont-Regular.ttf` есть только в `~/Library/Fonts` (или только в `/Library/Fonts`), cask не установлен
- **WHEN** запускается установщик
- **THEN** `CaskaydiaCove Nerd Font: already present in Library/Fonts`, cask не вызывается, предупреждения нет

#### Scenario: cask уже стоит
- **WHEN** файлов шрифта нет ни в одном каталоге, а cask числится установленным
- **THEN** `font-caskaydia-cove-nerd-font: already installed`

#### Scenario: шрифта нет
- **WHEN** файлов шрифта нет ни в одном каталоге и cask не установлен
- **THEN** выполняется `brew install --cask font-caskaydia-cove-nerd-font`

#### Scenario: установка упала
- **WHEN** `brew install --cask font-caskaydia-cove-nerd-font` завершился ошибкой
- **THEN** в выводе `!! Nerd Font не поставился — иконки могут быть пустыми (brew install --cask font-caskaydia-cove-nerd-font)`, установка продолжается, код возврата от этого не меняется

#### Scenario: повторный запуск
- **GIVEN** шрифт уже есть любым способом: cask'ом или файлами в одном из каталогов
- **WHEN** установщик запускается снова
- **THEN** cask не вызывается, предупреждения нет

### Requirement: MAC-INST-10 Установка в каталог конфига Neovim
В режиме установки в каталог конфига (MAC-INST-2) `install-macos.sh` SHALL после шагов зависимостей и WezTerm сделать путь установки (`FORGE_NVIM_INSTALL_DIR`, MAC-INST-13) симлинком на абсолютный путь (с раскрытыми симлинками) к `nvim_forge/` чекаута, из которого работает установщик, — локального или полученного в `FORGE_NVIM_SRC` (MAC-INST-3), — и привести плагины к `lazy-lock.json` этого чекаута. Путь, который уже ведёт в этот каталог, MUST NOT трогаться; занятый чем-то другим — уходит в бэкап целиком (MAC-INST-8). Все отказы этого режима MUST происходить до первого бэкапа и до любых изменений путей: отказы бутстрапа — до шага зависимостей (MAC-INST-3), остальные проверки — сразу после него, до шага WezTerm; при отказе код 1, ни путь установки, ни пути конфига WezTerm не тронуты.
Платформы: macos
История: FIXLOG §43
Проверка: tests/install-macos.scenarios.sh (S11, S23–S28); вручную — macOS: `nvim` открывает конфиг через симлинк, `git status` чекаута после установки чистый (результат записывается в FIXLOG)

#### Scenario: источник по умолчанию — клон монорепо
- **GIVEN** `FORGE_NVIM_USE_LOCAL_SOURCE` не задан, установщик работает из чекаута — локального или полученного бутстрапом в `FORGE_NVIM_SRC` (MAC-INST-3)
- **WHEN** выполняется установка
- **THEN** весь монорепо в путь установки больше не клонируется и ничего не копируется: путь становится симлинком на `<чекаут>/nvim_forge`, в выводе `Linked <путь> -> <чекаут>/nvim_forge`
- **AND** `init.lua` конфига виден через симлинк, плагины приведены к `lazy-lock.json`, в конце `forge-nvim installed: <путь>` и `Start with: nvim`, код 0

#### Scenario: локальный источник
- **GIVEN** `FORGE_NVIM_USE_LOCAL_SOURCE=1`, скрипт запущен из чекаута
- **WHEN** выполняется установка
- **THEN** то же, что без флага: путь установки — симлинк на `nvim_forge/` этого чекаута, ничего не копируется
- **AND** из чекаута флаг ничего не меняет (MAC-INST-13)

#### Scenario: локальный источник не из чекаута
- **GIVEN** `FORGE_NVIM_USE_LOCAL_SOURCE=1`, режим установки, скрипт запущен как файл вне чекаута
- **WHEN** запускается установщик
- **THEN** до любых действий `FORGE_NVIM_USE_LOCAL_SOURCE=1 requested, but script is not running from a forge-nvim checkout.` и код 1
- **AND** чекаут в `FORGE_NVIM_SRC` не клонируется, зависимости не ставятся, путь установки не тронут, бэкапа нет

#### Scenario: путь уже ведёт в чекаут
- **GIVEN** путь установки уже ведёт в `<чекаут>/nvim_forge` — абсолютным или относительным симлинком либо через симлинк на родительский каталог
- **WHEN** выполняется установка
- **THEN** `forge-nvim config already linked: <путь>`, путь не меняется, бэкапов нет
- **AND** `nvim_forge/` чекаута остаётся обычным каталогом

#### Scenario: на месте чужой конфиг
- **GIVEN** путь установки — каталог (свой конфиг или копия forge-nvim от прежней версии установщика), файл, симлинк в никуда или симлинк на `nvim_forge/` другого чекаута
- **WHEN** выполняется установка
- **THEN** путь целиком уходит в `<путь>.backup-<время>` (MAC-INST-8; симлинк переносится сам, его цель не трогается), на его месте симлинк на `<чекаут>/nvim_forge`
- **AND** с `FORGE_NVIM_NO_BACKUP=1` — `Install path already exists: <путь>`, код 1, путь не тронут

#### Scenario: каталог уже git-чекаут forge-nvim
- **GIVEN** путь установки — git-чекаут (например, клон всего монорепо, оставленный прежней версией установщика), а чекаут, из которого работает установщик, лежит вне него
- **WHEN** выполняется установка
- **THEN** fetch и pull в нём не выполняются: он уходит в бэкап, как любой занятый путь, на его месте симлинк
- **AND** если чекаут, из которого работает установщик, совпадает с путём установки или лежит внутри него, — `Install path <путь> overlaps the forge-nvim checkout <чекаут>; set FORGE_NVIM_INSTALL_DIR outside it.`, код 1 до шага WezTerm, ничего не тронуто (так же, если путь установки лежит внутри чекаута и не ведёт в `<чекаут>/nvim_forge`)

#### Scenario: скрипт запущен из каталога установки
- **GIVEN** путь установки уже симлинк на `nvim_forge/` чекаута, скрипт запущен через него (`<путь>/scripts/install-macos.sh`) с `FORGE_NVIM_DEPS_ONLY=0`
- **WHEN** выполняется установка
- **THEN** каталог скрипта раскрывается в чекаут, это запуск из чекаута: `forge-nvim config already linked: <путь>`, путь не меняется, бэкапа нет, затем плагины приводятся к `lazy-lock.json`
- **AND** без флага тот же запуск — локальный режим (MAC-INST-2): путь установки не трогается

#### Scenario: нет git
- **WHEN** git нет
- **THEN** из чекаута установка без него обходится: симлинк создаётся, git не вызывается
- **AND** вне чекаута бутстрап останавливается до любых действий с подсказкой `xcode-select --install`, код 1 (MAC-INST-3); путь установки не тронут, бэкапа нет

#### Scenario: запуск из терминала nvim_forge
- **GIVEN** шелл внутри nvim_forge (`XDG_CONFIG_HOME` = корень репо, `NVIM_APPNAME=nvim_forge`), `FORGE_NVIM_INSTALL_DIR` не задан
- **WHEN** установщик запущен с `FORGE_NVIM_DEPS_ONLY=0`
- **THEN** путь установки — `~/.config/nvim` (MAC-INST-13), внутри репо ничего не создаётся
- **AND** плагины приводятся для установленного конфига (каталог данных `nvim`), а не для сборки nvim_forge, чьи `XDG_CONFIG_HOME` и `NVIM_APPNAME` унаследовал шелл

#### Scenario: нет nvim
- **WHEN** `nvim` не в PATH
- **THEN** `nvim is not available in PATH. Install Neovim or restart the shell.`, код 1
- **AND** проверка идёт сразу после шага зависимостей, до шага WezTerm: бэкапов и новых симлинков нет

#### Scenario: установка невозможна
- **GIVEN** любая причина отказа: `FORGE_NVIM_USE_LOCAL_SOURCE=1` вне чекаута; вне чекаута нет git или бутстрап не смог (MAC-INST-3); в чекауте нет `nvim_forge/init.lua` (`No init.lua in <чекаут>/nvim_forge: this is not a Neovim config.`); путь установки и чекаут вложены друг в друга; `nvim` нет в PATH
- **WHEN** выполняется установка
- **THEN** код 1 с объяснением: отказ бутстрапа — до шага зависимостей, остальные — сразу после него, до шага WezTerm
- **AND** бэкапов и новых симлинков нет: ни путь установки, ни пути конфига WezTerm не тронуты

#### Scenario: синхронизация плагинов
- **WHEN** симлинк на месте — новый или прежний
- **THEN** выполняется `Lazy! restore`: плагины приводятся к версиям из `lazy-lock.json` чекаута (сбой — остановка), затем установка Treesitter-парсеров и Mason-инструментов (сбой — только сообщение)
- **AND** установщик не меняет отслеживаемых файлов чекаута: `lazy-lock.json` не переписывается, `git status` чекаута после установки тот же, что до неё

### Requirement: MAC-INST-11 Повторный запуск
Повторный запуск `install-macos.sh` с теми же флагами — в локальном режиме и в режиме установки в каталог конфига — SHALL ничего не переустанавливать и не менять, если всё уже на месте, — ни новых бэкапов, ни новых строк в профилях, ни подсказки о перезапуске, код 0, — а то, что разъехалось с прошлого раза, MUST чинить тем же прогоном (WT-LOAD-4…WT-LOAD-8, MAC-INST-10).
Платформы: macos
История: FIXLOG §43
Проверка: tests/install-macos.scenarios.sh (S2, S3 rerun, S9, S17, S18, S20, S23, S24)

#### Scenario: всё на месте
- **GIVEN** предыдущий прогон с теми же флагами (в том числе с `FORGE_NVIM_WITH_LANGUAGES=1` или `FORGE_NVIM_DEPS_ONLY=0`) завершился успешно; шрифт стоит любым способом (MAC-INST-6)
- **WHEN** установщик запускается снова
- **THEN** формулы, cask'и и шрифт — `already installed`/`already present`, Rust и `gopls` заново не ставятся, симлинк — `WezTerm config already linked`, строка `brew shellenv` не дублируется; в режиме установки — `forge-nvim config already linked`
- **AND** бэкапов не прибавилось, блоки в профилях не дублируются, подсказки о перезапуске нет, код 0

#### Scenario: перекрытие появилось снова
- **GIVEN** после установки снова появился чужой `~/.wezterm.lua`, симлинк побился, в launchd опять задана переменная, в профиль после блока forge-nvim дописано новое присваивание (WT-LOAD-7) или путь установки конфига Neovim снова занят чем-то, что не ведёт в чекаут
- **WHEN** установщик запускается снова
- **THEN** это нейтрализуется так же, как при первом запуске

#### Scenario: повтор с исключениями
- **GIVEN** шрифт поставлен руками в один каталог, или задан `FORGE_NVIM_WITH_LANGUAGES=1`, а `~/.cargo/bin` не в PATH (прежде это были исключения из правила)
- **WHEN** установщик запускается снова
- **THEN** исключений больше нет: ни cask шрифта (MAC-INST-6), ни `rustup-init` (MAC-INST-5) не вызываются

#### Scenario: повтор установки в ~/.config/nvim из локального источника
- **GIVEN** конфиг уже поставлен с `FORGE_NVIM_DEPS_ONLY=0` (с `FORGE_NVIM_USE_LOCAL_SOURCE=1` или без него)
- **WHEN** установщик запускается снова с теми же флагами
- **THEN** `forge-nvim config already linked: <путь>`: новый бэкап не создаётся, ничего не копируется (прежде каждый прогон добавлял бэкап и копировал заново)
- **AND** плагины снова приводятся к `lazy-lock.json` (MAC-INST-10); если версии уже совпадают, ничего не меняется, код 0

### Requirement: MAC-INST-13 Флаги окружения
Настройки `install-macos.sh` SHALL задаваться только переменными окружения `FORGE_NVIM_*`, и для установки из чекаута ни одна из них MUST NOT быть нужна; включённым булев флаг считается только при значении `1`, пустое значение равно незаданному.
Платформы: macos
История: FIXLOG §43
Проверка: tests/install-macos.scenarios.sh (S26, S27)

#### Scenario: переменные и умолчания
- **WHEN** переменная не задана
- **THEN** действует умолчание: `FORGE_NVIM_SRC` — `~/forge-nvim`; `FORGE_NVIM_REPO` — `https://github.com/cascad/forge-nvim.git`; `FORGE_NVIM_BRANCH` — `main`; `FORGE_NVIM_DEPS_ONLY` — определяется само (MAC-INST-2); `FORGE_NVIM_INSTALL_DIR` — `${XDG_CONFIG_HOME:-~/.config}/nvim` по `XDG_CONFIG_HOME` шелла, из которого запущен установщик, кроме случая, когда он ведёт в чекаут (сценарий ниже)
- **AND** `FORGE_NVIM_SKIP_DEPS`, `FORGE_NVIM_SKIP_WEZTERM`, `FORGE_NVIM_WITH_LANGUAGES`, `FORGE_NVIM_USE_LOCAL_SOURCE`, `FORGE_NVIM_NO_BACKUP` — выключены

#### Scenario: XDG_CONFIG_HOME указывает в чекаут
- **GIVEN** `XDG_CONFIG_HOME` шелла после раскрытия симлинков — корень чекаута, из которого работает установщик, или каталог внутри него (терминал nvim_forge), `FORGE_NVIM_INSTALL_DIR` не задан
- **WHEN** выбирается путь установки
- **THEN** `XDG_CONFIG_HOME` не учитывается, путь — `~/.config/nvim`, внутри репо ничего не создаётся
- **AND** соседний каталог с тем же началом имени (`<чекаут>-other`) внутри чекаута не считается: его `XDG_CONFIG_HOME` учитывается

#### Scenario: флаги режима установки
- **WHEN** выполняется установка в каталог конфига (MAC-INST-10)
- **THEN** `FORGE_NVIM_INSTALL_DIR` — где создаётся симлинк на `<чекаут>/nvim_forge`; `FORGE_NVIM_SRC` — чекаут для `curl | bash` и для запуска из файла вне чекаута (MAC-INST-3)
- **AND** `FORGE_NVIM_USE_LOCAL_SOURCE=1` — источник только чекаут, из которого запущен скрипт: вне чекаута отказ до любых действий вместо бутстрапа, из чекаута флаг ничего не меняет

#### Scenario: без флагов из чекаута
- **WHEN** флаги не заданы
- **THEN** выполняется полная установка в локальном режиме (MAC-INST-1)

#### Scenario: значение флага не 1
- **WHEN** задано `FORGE_NVIM_SKIP_DEPS=true`
- **THEN** флаг считается выключенным, зависимости ставятся
