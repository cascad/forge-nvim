# wezterm-config-loading Specification

## Purpose
Как WezTerm находит и загружает `wezterm.lua` этого репо на каждой ОС: подключение файла (Windows — переменная окружения, macOS — симлинк от `install-macos.sh` с нейтрализацией всего, что его молча перекрывает, и проверкой итога, Linux — симлинк), порядок поиска конфига самим WezTerm, перечитывание и признак того, какой конфиг загружен. Не покрывает содержимое конфига — клавиши, режимы, вид, размер окна (WT-KBD, WT-KEYS, WT-CLIP, WT-WIN, WT-PANE, WT-SCROLL, WT-STATE, WT-UI) — и остальные шаги установщика macOS (capability `macos-install`, MAC-INST).

## Requirements

### Requirement: WT-LOAD-1 Один файл конфига в репо, подключается ссылкой
Конфиг терминала SHALL быть одним файлом `wezterm.lua` в корне репо, общим для Windows, macOS и Linux, и WezTerm MUST читать его на месте — через переменную окружения (WT-LOAD-3) или симлинк (WT-LOAD-4, WT-LOAD-13), без копии в домашнем каталоге.
Платформы: все
История: FIXLOG §19, §43

#### Scenario: правка в репо — это и есть системный конфиг
- **GIVEN** конфиг подключён одним из способов WT-LOAD-3, WT-LOAD-4, WT-LOAD-13
- **WHEN** в репо меняется `wezterm.lua`
- **THEN** WezTerm применяет изменение после перечитывания (WT-LOAD-14), синхронизировать или копировать ничего не нужно
- **AND** ни установщики, ни инструкции в шапке файла не копируют его в домашний каталог

### Requirement: WT-LOAD-2 Порядок поиска конфига самим WezTerm
WezTerm 20240203 SHALL загружать ПЕРВЫЙ найденный конфиг в порядке: аргумент `--config-file`; переменная `WEZTERM_CONFIG_FILE`; (только Windows) `wezterm.lua` рядом с `wezterm.exe`; `~/.wezterm.lua`; `$XDG_CONFIG_HOME/wezterm/wezterm.lua` (без переменной — `~/.config/wezterm/wezterm.lua`); (Unix) `wezterm/wezterm.lua` в каталогах `$XDG_CONFIG_DIRS`. Всё, что стоит в этом списке выше способа подключения из WT-LOAD-3/4/13, перекрывает его молча.
Платформы: все
История: FIXLOG §43

#### Scenario: отсутствующий необязательный кандидат пропускается
- **GIVEN** `~/.wezterm.lua` нет или это битый симлинк
- **WHEN** WezTerm стартует
- **THEN** он переходит к следующему кандидату списка

#### Scenario: переменная окружения обязательна
- **GIVEN** `WEZTERM_CONFIG_FILE` указывает на несуществующий файл
- **WHEN** WezTerm стартует
- **THEN** он показывает окно с ошибкой конфигурации (`Error opening <путь>`) и работает на встроенных дефолтах
- **AND** к следующим кандидатам (`~/.wezterm.lua`, `~/.config/wezterm/…`) не переходит

#### Scenario: найденный, но сломанный файл не пропускается
- **GIVEN** `~/.wezterm.lua` существует и содержит ошибку Lua, а симлинк в `~/.config/wezterm` исправен
- **WHEN** WezTerm стартует
- **THEN** он показывает ошибку и работает на встроенных дефолтах, симлинк не используется

#### Scenario: ничего не найдено
- **GIVEN** ни один кандидат не существует
- **WHEN** WezTerm стартует
- **THEN** он работает на встроенных дефолтах, признака WT-LOAD-15 нет

#### Scenario: macOS — окружение зависит от способа запуска
- **GIVEN** macOS
- **WHEN** WezTerm.app запущен из Dock, Spotlight, Finder или `open -a WezTerm`
- **THEN** `WEZTERM_CONFIG_FILE` и `XDG_CONFIG_HOME` берутся из окружения launchd, профили шелла (`~/.zshrc` и др.) не читаются
- **AND** WezTerm, запущенный командой `wezterm` из шелла, видит окружение этого шелла

### Requirement: WT-LOAD-3 Windows: переменная WEZTERM_CONFIG_FILE уровня пользователя
На Windows конфиг SHALL подключаться переменной окружения `WEZTERM_CONFIG_FILE` уровня пользователя (User) с абсолютным путём к `wezterm.lua` репо; выставляется она вручную командой из шапки `wezterm.lua` — `[Environment]::SetEnvironmentVariable("WEZTERM_CONFIG_FILE", "<репо>\wezterm.lua", "User")`, — установщик Windows её не выставляет и WezTerm не настраивает.
Платформы: windows
История: FIXLOG 2026-05-31 «WezTerm: шелл/диск, дополнение путей, шрифт, Ctrl+C/V», §19

#### Scenario: запуск любым GUI-способом
- **GIVEN** переменная выставлена на уровне пользователя
- **WHEN** WezTerm запускается из меню «Пуск», с панели задач или ярлыком (после установки переменной)
- **THEN** загружается `wezterm.lua` репо
- **AND** в PowerShell панели `$env:WEZTERM_CONFIG_FILE` показывает этот путь

#### Scenario: другие файлы конфига не перекрывают переменную
- **GIVEN** переменная выставлена и существуют `~/.wezterm.lua`, `~/.config/wezterm/wezterm.lua` или `wezterm.lua` рядом с `wezterm.exe`
- **WHEN** WezTerm стартует без `--config-file`
- **THEN** они игнорируются, загружается файл из переменной

#### Scenario: неверный путь в переменной
- **GIVEN** переменная указывает на несуществующий файл (например, репо переехал)
- **WHEN** WezTerm стартует
- **THEN** WezTerm показывает ошибку открытия и работает на встроенных дефолтах (WT-LOAD-2)

#### Scenario: переменная не выставлена
- **GIVEN** переменной нет и других кандидатов из WT-LOAD-2 нет
- **WHEN** WezTerm стартует
- **THEN** он работает на встроенных дефолтах: шелл по умолчанию — `cmd.exe`, признака WT-LOAD-15 нет

### Requirement: WT-LOAD-4 macOS: симлинк там, где конфиг ищет WezTerm из Dock
На macOS `install-macos.sh` SHALL создавать симлинк `<XDG_CONFIG_HOME из launchd, иначе ~/.config>/wezterm/wezterm.lua` → абсолютный путь (с раскрытыми симлинками) к `wezterm.lua`, найденному рядом со скриптом — сначала двумя уровнями выше каталога скрипта (корень монорепо), затем уровнем выше, — и MUST NOT трогать путь, который уже ведёт в этот файл.
Платформы: macos
История: FIXLOG §43
Проверка: tests/install-macos.scenarios.sh (S1, S2, S3, S4, S5, S9, S14, S15)

#### Scenario: чистый HOME
- **GIVEN** `~/.config/wezterm` нет
- **WHEN** запускается установщик
- **THEN** каталог создаётся, в нём симлинк на файл репо, в выводе `Linked <путь> -> <файл репо>`

#### Scenario: путь уже ведёт в репо
- **GIVEN** `…/wezterm/wezterm.lua` уже ведёт в файл репо — абсолютным или относительным симлинком, либо `~/.config/wezterm` сам симлинк на каталог чекаута
- **WHEN** запускается установщик
- **THEN** в выводе `WezTerm config already linked: <путь>`, ничего не меняется и бэкапов нет
- **AND** файл репо остаётся обычным файлом

#### Scenario: на месте чужой файл или битый симлинк
- **GIVEN** `…/wezterm/wezterm.lua` — чужой файл или симлинк в никуда
- **WHEN** запускается установщик
- **THEN** он уходит в бэкап (MAC-INST-8), на его месте симлинк на файл репо

#### Scenario: каталог wezterm — битый симлинк или не каталог
- **GIVEN** `~/.config/wezterm` — симлинк в никуда или обычный файл
- **WHEN** запускается установщик
- **THEN** он уходит в бэкап, создаётся настоящий каталог и симлинк в нём

#### Scenario: каталог wezterm — симлинк на другой существующий каталог
- **GIVEN** `~/.config/wezterm` — симлинк на каталог dotfiles, где лежит чужой `wezterm.lua`
- **WHEN** запускается установщик
- **THEN** `~/.config/wezterm` остаётся симлинком, чужой файл уходит в бэкап внутри каталога dotfiles, там же создаётся симлинк на файл репо

#### Scenario: XDG_CONFIG_HOME задан в launchd
- **GIVEN** в окружении launchd `XDG_CONFIG_HOME=<каталог>`
- **WHEN** запускается установщик
- **THEN** симлинк кладётся в `<каталог>/wezterm/wezterm.lua`, в `~/.config` ничего не создаётся
- **AND** WezTerm, запущенный из шелла без этого `XDG_CONFIG_HOME`, симлинк не найдёт, и установщик об этом не сообщает

#### Scenario: запуск из терминала nvim_forge
- **GIVEN** установщик запущен из шелла внутри nvim_forge, где `XDG_CONFIG_HOME` = корень репо
- **WHEN** выполняется шаг WezTerm
- **THEN** `XDG_CONFIG_HOME` шелла не учитывается: симлинк только в `~/.config/wezterm`, внутри репо ничего не создаётся

#### Scenario: рядом со скриптом нет wezterm.lua
- **GIVEN** скрипт запущен как файл не из чекаута монорепо и ни `<скрипт>/../../wezterm.lua`, ни `<скрипт>/../wezterm.lua` нет
- **WHEN** выполняется шаг WezTerm
- **THEN** в выводе `wezterm.lua not found near the config; skipping terminal config link`; симлинка, нейтрализации (WT-LOAD-5…8) и проверок (WT-LOAD-10…12) нет
- **AND** шаг не считается сломанным, код возврата от него не зависит

### Requirement: WT-LOAD-5 macOS: ~/.wezterm.lua, не ведущий в репо, уходит в бэкап
Если `~/.wezterm.lua` существует (файл, каталог или симлинк, в том числе битый) и не ведёт в `wezterm.lua` репо, `install-macos.sh` SHALL переместить его в бэкап (MAC-INST-8), так как он перекрывает симлинк WT-LOAD-4; `~/.wezterm.lua`, ведущий в файл репо, MUST остаться как есть.
Платформы: macos
История: FIXLOG §43
Проверка: tests/install-macos.scenarios.sh (S3, S10)

#### Scenario: чужой ~/.wezterm.lua
- **GIVEN** `~/.wezterm.lua` — обычный файл (содержимое неважно, даже корректный конфиг)
- **WHEN** запускается установщик
- **THEN** в выводе `~/.wezterm.lua перекрывает ~/.config/wezterm/wezterm.lua` (текст фиксированный, даже если симлинк кладётся по `XDG_CONFIG_HOME` из launchd), файл перемещён в `~/.wezterm.lua.backup-<время>`

#### Scenario: битый симлинк ~/.wezterm.lua
- **GIVEN** `~/.wezterm.lua` — симлинк в никуда (WezTerm его и так пропустил бы)
- **WHEN** запускается установщик
- **THEN** он тоже уходит в бэкап

#### Scenario: ~/.wezterm.lua — симлинк на файл репо
- **GIVEN** `~/.wezterm.lua` ведёт в `wezterm.lua` репо
- **WHEN** запускается установщик
- **THEN** он не трогается, бэкапов нет, симлинк WT-LOAD-4 всё равно создаётся
- **AND** итог — `WezTerm загрузит: $HOME/.wezterm.lua -> <файл репо>` (WT-LOAD-10)

### Requirement: WT-LOAD-6 macOS: WEZTERM_CONFIG_FILE в launchd снимается
Если в окружении launchd (окружение GUI-приложений) задана `WEZTERM_CONFIG_FILE` и она не ведёт в `wezterm.lua` репо, `install-macos.sh` SHALL снять её для текущего сеанса (`launchctl unsetenv`) с сообщением `launchd: WEZTERM_CONFIG_FILE=<значение> снят`; переменная, ведущая в файл репо, MUST остаться.
Платформы: macos
История: FIXLOG §42, §43
Проверка: tests/install-macos.scenarios.sh (S3, S8)

#### Scenario: чужой путь
- **GIVEN** в launchd `WEZTERM_CONFIG_FILE=/elsewhere.lua` (файл может и не существовать)
- **WHEN** запускается установщик
- **THEN** переменная снята, WezTerm из Dock, запущенный после этого, её не видит

#### Scenario: путь ведёт в репо
- **GIVEN** в launchd `WEZTERM_CONFIG_FILE` указывает на `wezterm.lua` репо (в том числе через симлинк)
- **WHEN** запускается установщик
- **THEN** переменная остаётся, итог — `WezTerm загрузит: <этот путь> -> <файл репо>`

#### Scenario: путь — тот самый симлинк
- **GIVEN** в launchd `WEZTERM_CONFIG_FILE=~/.config/wezterm/wezterm.lua` (абсолютным путём), а самого симлинка ещё нет
- **WHEN** запускается установщик
- **THEN** симлинк создаётся раньше, чем проверяется переменная, поэтому она ведёт в репо и остаётся

#### Scenario: переменную снова выставляют при входе
- **GIVEN** переменную при каждом входе выставляет LaunchAgent
- **WHEN** пользователь перелогинивается после установки
- **THEN** снятие не держится — поэтому такой LaunchAgent называется и шаг ломается (WT-LOAD-8)

### Requirement: WT-LOAD-7 macOS: профили шелла получают дописанный блок unset
Для каждого существующего профиля шелла из фиксированного списка, где `WEZTERM_CONFIG_FILE` упоминается вне комментария и ещё нет блока forge-nvim, `install-macos.sh` SHALL дописать в конец помеченный блок, снимающий переменную, и MUST NOT изменять ни одной существующей строки файла.
Платформы: macos
История: FIXLOG §43
Проверка: tests/install-macos.scenarios.sh (S3, S12, S16)

#### Scenario: какие файлы проверяются и что дописывается
- **WHEN** установщик проверяет профили
- **THEN** список: `~/.zshenv`; `$ZDOTDIR/.zshenv`, `.zprofile`, `.zshrc`, `.zlogin` (ZDOTDIR спрашивается у самого `/bin/zsh`); `~/.zprofile`, `~/.zshrc`, `~/.zlogin`, `~/.bash_profile`, `~/.bashrc`, `~/.profile`, `~/.config/fish/config.fish`
- **AND** блок — пустая строка, `# >>> forge-nvim: WezTerm config is the symlink ~/.config/wezterm/wezterm.lua (install-macos.sh) >>>`, `unset WEZTERM_CONFIG_FILE`, `# <<< forge-nvim <<<`

#### Scenario: export в ~/.zshrc
- **GIVEN** `~/.zshrc` содержит `export WEZTERM_CONFIG_FILE=…` среди своих строк
- **WHEN** запускается установщик
- **THEN** прежнее содержимое остаётся нетронутым префиксом файла, в конец дописан блок
- **AND** в выводе `<файл> задаёт WEZTERM_CONFIG_FILE — в конец дописан 'unset WEZTERM_CONFIG_FILE' (свои строки не тронуты)`
- **AND** после `source` профиля переменной нет

#### Scenario: любое упоминание вне комментария
- **GIVEN** профиль не присваивает переменную, а только упоминает её (например, `echo "$WEZTERM_CONFIG_FILE"`) или присваивает ей путь к файлу репо
- **WHEN** запускается установщик
- **THEN** блок всё равно дописывается

#### Scenario: сложные строки остаются синтаксически целыми
- **GIVEN** профиль с `…; fi` в строке присваивания, продолжением строки `\`, несколькими присваиваниями в одной строке и без перевода строки в конце файла
- **WHEN** установщик дописывает блок
- **THEN** файл по-прежнему разбирается `bash -n` и `zsh -n`
- **AND** остальные переменные из тех же строк (например, `EDITOR`) после `source` на месте, `WEZTERM_CONFIG_FILE` снята

#### Scenario: профиль — симлинк
- **GIVEN** `~/.bashrc` — симлинк на файл в каталоге dotfiles
- **WHEN** установщик дописывает блок
- **THEN** блок попадает в целевой файл, `~/.bashrc` остаётся симлинком
- **AND** один и тот же файл, достижимый под двумя именами, обрабатывается один раз

#### Scenario: упоминание только в комментарии
- **GIVEN** в профиле `WEZTERM_CONFIG_FILE` встречается только после `#` в той же строке
- **WHEN** запускается установщик
- **THEN** профиль не трогается

#### Scenario: fish
- **GIVEN** `~/.config/fish/config.fish` задаёт переменную
- **WHEN** запускается установщик
- **THEN** в блоке `set -e WEZTERM_CONFIG_FILE`, помечающие строки те же

#### Scenario: профиль недоступен для записи
- **GIVEN** профиль задаёт переменную и доступен только для чтения
- **WHEN** запускается установщик
- **THEN** в выводе `!! <файл> задаёт WEZTERM_CONFIG_FILE, но недоступен для записи — допиши в конец: unset WEZTERM_CONFIG_FILE` (для fish — `set -e WEZTERM_CONFIG_FILE`), файл не изменён
- **AND** шаг WezTerm от этого не считается сломанным (WezTerm из Dock профили не читает)

#### Scenario: повторный запуск не дублирует блок
- **GIVEN** в профиле уже есть блок forge-nvim
- **WHEN** установщик запускается снова
- **THEN** профиль не меняется

#### Scenario: присваивание, добавленное после блока, не нейтрализуется
- **GIVEN** в профиле уже есть блок forge-nvim, а после него позже дописан новый `export WEZTERM_CONFIG_FILE=…`
- **WHEN** установщик запускается снова
- **THEN** профиль не меняется, после `source` переменная задана

#### Scenario: что блок не отменяет
- **GIVEN** переменная задаётся в файле вне списка (например, подключаемом через `source` или в `~/.config/fish/conf.d/`) или строкой `launchctl setenv WEZTERM_CONFIG_FILE …` в профиле
- **WHEN** запускается установщик
- **THEN** файл вне списка не проверяется; профиль со строкой `launchctl setenv` получает блок, но launchd-переменную, которую эта строка выставит при следующем старте шелла, блок не снимает

### Requirement: WT-LOAD-8 macOS: LaunchAgent, выставляющий переменную, называется по имени
Если plist в `~/Library/LaunchAgents` или `/Library/LaunchAgents` текстом упоминает `WEZTERM_CONFIG_FILE` и не содержит текстом раскрытый путь к `wezterm.lua` репо, `install-macos.sh` SHALL не изменять его, а назвать в stderr — `!! <plist> выставляет WEZTERM_CONFIG_FILE при каждом входе в систему — убери из него эту переменную` — и MUST считать шаг WezTerm сломанным (код возврата 1, MAC-INST-9).
Платформы: macos
История: FIXLOG §43
Проверка: tests/install-macos.scenarios.sh (S13)

#### Scenario: plist с чужим путём
- **GIVEN** `~/Library/LaunchAgents/env.plist` выставляет `WEZTERM_CONFIG_FILE=/elsewhere.lua`
- **WHEN** запускается установщик
- **THEN** plist назван в stderr и не изменён, код возврата 1

#### Scenario: plist с путём репо
- **GIVEN** plist выставляет переменную с абсолютным путём к `wezterm.lua` репо (в раскрытом виде)
- **WHEN** запускается установщик
- **THEN** перекрытием он не считается, код возврата 0

#### Scenario: проверка текстовая
- **GIVEN** plist указывает на файл репо другим путём (через симлинк или `~`), или только снимает переменную (`launchctl unsetenv WEZTERM_CONFIG_FILE`), или задаёт её лишь собственному процессу агента (`EnvironmentVariables`)
- **WHEN** запускается установщик
- **THEN** plist всё равно назван, шаг сломан, код возврата 1

#### Scenario: несколько таких plist
- **GIVEN** переменную упоминают два plist
- **WHEN** запускается установщик
- **THEN** назван только один (последний в порядке перебора), второй будет назван при следующем запуске после исправления первого

### Requirement: WT-LOAD-9 macOS: порядок шага и отказ при FORGE_NVIM_NO_BACKUP до правок окружения
`install-macos.sh` SHALL выполнять шаг WezTerm в порядке: запомнить исходный итог для Dock; файлы (WT-LOAD-5, WT-LOAD-4); окружение (WT-LOAD-6, поиск plist WT-LOAD-8, WT-LOAD-7); проверки (WT-LOAD-10, WT-LOAD-8, WT-LOAD-11, WT-LOAD-12) — так что отказ по `FORGE_NVIM_NO_BACKUP=1` (MAC-INST-8) MUST происходить до правок launchd и профилей.
Платформы: macos
История: FIXLOG §43
Проверка: tests/install-macos.scenarios.sh (S8)

#### Scenario: NO_BACKUP и занятый путь
- **GIVEN** `FORGE_NVIM_NO_BACKUP=1`, есть чужой `~/.wezterm.lua`, в launchd и в `~/.zshrc` задана `WEZTERM_CONFIG_FILE`
- **WHEN** запускается установщик
- **THEN** он останавливается с кодом 1 и `Install path already exists: <путь>`
- **AND** `~/.wezterm.lua` на месте, переменная в launchd не снята, в профиль ничего не дописано

#### Scenario: NO_BACKUP без занятых путей
- **GIVEN** `FORGE_NVIM_NO_BACKUP=1` и чистый HOME
- **WHEN** запускается установщик
- **THEN** шаг проходит как обычно, код 0

### Requirement: WT-LOAD-10 macOS: проверка, какой конфиг загрузит WezTerm из Dock
После правок `install-macos.sh` SHALL определить тем же порядком, что у WezTerm из Dock (`WEZTERM_CONFIG_FILE` из launchd, даже если файла нет; `~/.wezterm.lua`; `<XDG_CONFIG_HOME из launchd или ~/.config>/wezterm/wezterm.lua`; иначе встроенные дефолты), какой файл тот загрузит, и MUST считать шаг WezTerm сломанным, если этот файл не ведёт в `wezterm.lua` репо.
Платформы: macos
История: FIXLOG §43
Проверка: tests/install-macos.scenarios.sh (S1, S5, S10)

#### Scenario: итог ведёт в репо
- **WHEN** проверка находит файл, ведущий в репо
- **THEN** в выводе `WezTerm загрузит: <путь> -> <файл репо>`

#### Scenario: итог не ведёт в репо
- **GIVEN** после правок первым кандидатом остаётся не файл репо (или кандидатов нет)
- **WHEN** выполняется проверка
- **THEN** в stderr `!! WezTerm из Dock загрузит НЕ конфиг из репо: <путь или «встроенные дефолты»>`, в конце код возврата 1

#### Scenario: учитывается только запуск из Dock
- **GIVEN** WezTerm будут запускать из шелла или с `--config-file`
- **WHEN** выполняется проверка
- **THEN** окружение шелла, `--config-file` и `XDG_CONFIG_DIRS` не учитываются; битый симлинк-кандидат пропускается, как у WezTerm

### Requirement: WT-LOAD-11 Конфиг загружается без ошибок
`wezterm.lua` SHALL загружаться WezTerm 20240203 без ошибок — `wezterm --config-file <файл> ls-fonts` печатает непустой stdout и ни одной строки с `ERROR` в stderr; на macOS `install-macos.sh` MUST выполнять эту проверку и при провале считать шаг WezTerm сломанным.
Платформы: все (автоматически — в установщике macOS)
История: FIXLOG §43
Проверка: tests/install-macos.scenarios.sh (S1, S6, S16); вручную — `wezterm --config-file <репо>/wezterm.lua ls-fonts`

#### Scenario: код возврата и show-keys ошибок не показывают
- **GIVEN** `wezterm.lua` сломан
- **WHEN** выполняется `wezterm --config-file <файл> ls-fonts` или `show-keys`
- **THEN** код возврата 0 в обоих случаях, а `show-keys` молча (пустой stderr) печатает дефолтные привязки — поэтому признак загрузки только вывод `ls-fonts`

#### Scenario: рабочее дерево на Windows
- **GIVEN** Windows, WezTerm 20240203, рабочее дерево 2026-09-27
- **WHEN** выполняется `wezterm --config-file F:/repo/forge-nvim/wezterm.lua ls-fonts`
- **THEN** stdout перечисляет шрифты, stderr пуст

#### Scenario: установщик, конфиг грузится
- **WHEN** проверка проходит
- **THEN** в выводе `wezterm.lua загружается без ошибок`

#### Scenario: ошибка синтаксиса, времени выполнения или нет файла
- **GIVEN** `wezterm.lua` не загружается
- **WHEN** установщик выполняет проверку
- **THEN** stdout пуст, в stderr строка с `ERROR`; установщик печатает в stderr `!! wezterm.lua не загружается:` и текст ошибки
- **AND** остальные шаги доходят до конца, код возврата 1

#### Scenario: какой CLI используется
- **WHEN** установщик ищет CLI
- **THEN** берётся `/Applications/WezTerm.app/Contents/MacOS/wezterm`, иначе `wezterm` из PATH
- **AND** если нет ни того, ни другого — `wezterm CLI не найден — не проверяю, что wezterm.lua загружается`, шаг не считается сломанным

#### Scenario: нет основного шрифта
- **GIVEN** шрифт из начала списка `font_with_fallback` не установлен
- **WHEN** выполняется `ls-fonts`
- **THEN** в stderr только `Unable to load a font specified by your font=… configuration. Fallback(s) are being used instead…` без `ERROR`, stdout непустой — проверка проходит (проверено на Windows, WezTerm 20240203)

#### Scenario: проверяется файл репо
- **WHEN** установщик выполняет проверку
- **THEN** он грузит файл репо напрямую, а не путь, который откроет WezTerm (сегодня это один и тот же файл через симлинк)
- **AND** временный лог проверки удаляется

### Requirement: WT-LOAD-12 macOS: подсказка о перезапуске WezTerm
При успешном шаге WezTerm и запущенном `wezterm-gui` `install-macos.sh` SHALL вывести `WezTerm запущен со старым конфигом — закрой его (Cmd+Q) и открой заново, один раз`, если до правок WezTerm из Dock загрузил бы не файл репо или если в панели WezTerm (`WEZTERM_PANE`) путь `$WEZTERM_CONFIG_DIR/wezterm.lua` не ведёт в репо (или переменной нет); иначе подсказки MUST NOT быть.
Платформы: macos
История: FIXLOG §43
Проверка: tests/install-macos.scenarios.sh (S3: restart hint; rerun: no restart hint)

#### Scenario: первая установка при запущенном WezTerm
- **GIVEN** WezTerm запущен, до установки из Dock грузился не конфиг репо (или дефолты)
- **WHEN** установщик отработал успешно
- **THEN** выводится подсказка про Cmd+Q

#### Scenario: повторный запуск
- **GIVEN** предыдущий запуск уже подключил конфиг
- **WHEN** установщик запускается снова при запущенном WezTerm — из Dock-окружения или из панели, где `WEZTERM_CONFIG_DIR` = каталог симлинка
- **THEN** подсказки нет

#### Scenario: WezTerm не запущен или шаг не успешен
- **WHEN** `wezterm-gui` не запущен, шаг WezTerm сломан или пропущен
- **THEN** подсказки нет

#### Scenario: панель WezTerm на встроенных дефолтах
- **GIVEN** установщик запущен из панели WezTerm, у которой нет `WEZTERM_CONFIG_DIR` (этот WezTerm не нашёл конфиг)
- **WHEN** установщик отработал успешно
- **THEN** подсказка выводится, даже если для Dock всё уже было подключено

#### Scenario: панель WezTerm, загрузившего ~/.wezterm.lua
- **GIVEN** `~/.wezterm.lua` — симлинк на файл репо, запущенный WezTerm загрузил именно его, установщик запущен из его панели
- **WHEN** установщик отработал успешно
- **THEN** подсказка всё равно выводится (путь `$WEZTERM_CONFIG_DIR/wezterm.lua` = `~/wezterm.lua` не ведёт в репо)

### Requirement: WT-LOAD-13 Linux: симлинк в ~/.config/wezterm
На Linux конфиг SHALL подключаться симлинком `${XDG_CONFIG_HOME:-~/.config}/wezterm/wezterm.lua` → `wezterm.lua` репо — вручную (команда в шапке `wezterm.lua`) или шагом `install-linux.sh`, который MUST выполняться только в GUI-сессии (`DISPLAY` или `WAYLAND_DISPLAY`) либо с `FORGE_NVIM_FORCE_WEZTERM=1` и пропускаться с `FORGE_NVIM_SKIP_WEZTERM=1`.
Платформы: linux (по возможности)

#### Scenario: GUI-сессия, чистый HOME
- **WHEN** запускается `install-linux.sh` из чекаута
- **THEN** создаётся симлинк на файл репо, в выводе `Linked <путь> -> <файл репо>`

#### Scenario: симлинк уже есть
- **GIVEN** по пути лежит симлинк, чья цель побайтно равна абсолютному пути файла репо
- **WHEN** запускается `install-linux.sh`
- **THEN** `WezTerm config already linked: <путь>`, ничего не меняется

#### Scenario: что угодно другое на месте
- **GIVEN** по пути чужой файл, битый симлинк или относительный симлинк на тот же файл репо
- **WHEN** запускается `install-linux.sh`
- **THEN** он уходит в `<путь>.backup-<время>` (с `FORGE_NVIM_NO_BACKUP=1` — остановка с кодом 1), затем создаётся симлинк

#### Scenario: без GUI
- **GIVEN** нет ни `DISPLAY`, ни `WAYLAND_DISPLAY`, `FORGE_NVIM_FORCE_WEZTERM` не задан
- **WHEN** запускается `install-linux.sh`
- **THEN** `No GUI session detected; skipping WezTerm setup (FORGE_NVIM_FORCE_WEZTERM=1 to force)`, конфиг не подключается

#### Scenario: перекрытия не нейтрализуются и итог не проверяется
- **GIVEN** есть `~/.wezterm.lua` или задана `WEZTERM_CONFIG_FILE`
- **WHEN** запускается `install-linux.sh`
- **THEN** они молча перекрывают симлинк (WT-LOAD-2), установщик об этом не сообщает и завершается с кодом 0

#### Scenario: ~/.config/wezterm — симлинк на каталог чекаута
- **GIVEN** `~/.config/wezterm` ведёт в каталог чекаута
- **WHEN** запускается `install-linux.sh`
- **THEN** `wezterm.lua` репо перемещается в `wezterm.lua.backup-<время>` внутри чекаута, а на его месте появляется симлинк сам на себя

#### Scenario: ~/.config/wezterm — битый симлинк
- **GIVEN** `~/.config/wezterm` — симлинк в никуда
- **WHEN** запускается `install-linux.sh`
- **THEN** `mkdir` падает с `File exists`, установка останавливается с кодом 1

#### Scenario: запуск из терминала nvim_forge
- **GIVEN** `XDG_CONFIG_HOME` шелла = корень репо
- **WHEN** запускается `install-linux.sh`
- **THEN** симлинк создаётся внутри репо: `<репо>/wezterm/wezterm.lua`

#### Scenario: curl | bash
- **GIVEN** `install-linux.sh` читается со stdin (bash 5)
- **WHEN** выполняется шаг WezTerm
- **THEN** `wezterm.lua` ищется от текущего каталога (`./../../wezterm.lua`, `./../wezterm.lua`); обычно его там нет — `wezterm.lua not found near the config; skipping terminal config link`

### Requirement: WT-LOAD-14 Перечитывание конфига: Ctrl+Shift+R и автоматически
Конфиг SHALL перечитываться по Ctrl+Shift+R (физическая клавиша R, любая раскладка, все ОС; варианта на Cmd нет), командой «Reload configuration» (на macOS — пункт меню WezTerm → Reload Configuration; везде — палитра команд, WT-WIN) и автоматически при изменении загруженного файла (поведение WezTerm по умолчанию, конфиг его не отключает), и перечитывание MUST применяться ко всем окнам без перезапуска WezTerm.
Платформы: все
История: FIXLOG §19

#### Scenario: Ctrl+Shift+R на любой раскладке
- **GIVEN** активна английская или русская раскладка (на русской клавиша печатает «К»)
- **WHEN** нажат Ctrl+Shift+R
- **THEN** WezTerm перечитывает конфиг

#### Scenario: внутри полноэкранной программы
- **GIVEN** в панели nvim, less или Claude Code (альтернативный экран, программа могла включить расширенный клавиатурный протокол)
- **WHEN** нажат Ctrl+Shift+R
- **THEN** комбинацию перехватывает WezTerm, в программу она не уходит

#### Scenario: сохранение файла
- **WHEN** загруженный файл сохраняется на диск
- **THEN** WezTerm сам перечитывает конфиг примерно через 200 мс

#### Scenario: Windows — наблюдается весь каталог файла
- **GIVEN** Windows, конфиг загружен из корня репо
- **WHEN** создаётся, меняется или удаляется любой другой файл в корне репо (например, `README.md` или `nvim.log`)
- **THEN** WezTerm тоже перечитывает конфиг — он следит за каталогом загруженного файла целиком (без подкаталогов), если это не домашний каталог (по исходнику 20240203, вживую не наблюдалось)

#### Scenario: macOS — правка через симлинк
- **GIVEN** macOS, конфиг загружен через симлинк `~/.config/wezterm/wezterm.lua`
- **WHEN** файл правится в репо
- **THEN** Ctrl+Shift+R применяет изменение
- **AND** WezTerm следит за путём симлинка и каталогом `~/.config/wezterm`; срабатывает ли автоматическое перечитывание при правке цели симлинка — не проверено

#### Scenario: ошибка при перечитывании
- **GIVEN** WezTerm уже работает на успешно загруженном конфиге, файл сохранён с ошибкой
- **WHEN** WezTerm перечитывает конфиг
- **THEN** он показывает окно с ошибкой и продолжает работать на прежнем конфиге

#### Scenario: перечитывается тот же путь
- **GIVEN** WezTerm при старте успешно загрузил конфиг из пути P (он запоминает P в своём окружении как `WEZTERM_CONFIG_FILE`)
- **WHEN** появляется кандидат выше по порядку поиска (например, новый `~/.wezterm.lua`) или меняется значение переменной в launchd/реестре, и нажат Ctrl+Shift+R
- **THEN** снова читается P; новое подключение действует только после перезапуска WezTerm (WT-LOAD-12) (по исходнику 20240203)

#### Scenario: по пути P теперь другой файл
- **GIVEN** WezTerm загрузил P = `~/.config/wezterm/wezterm.lua`, и установщик заменил чужой файл по этому пути симлинком в репо
- **WHEN** срабатывает перечитывание (автоматически или по Ctrl+Shift+R)
- **THEN** загружается конфиг репо без перезапуска (по исходнику 20240203)

#### Scenario: P больше нет
- **GIVEN** WezTerm загрузил P = `~/.wezterm.lua`, и установщик унёс его в бэкап (WT-LOAD-5)
- **WHEN** срабатывает перечитывание
- **THEN** WezTerm показывает ошибку открытия P и остаётся на прежнем конфиге до перезапуска (по исходнику 20240203)

#### Scenario: WezTerm стартовал без конфига
- **GIVEN** при старте ни один кандидат не нашёлся, WezTerm на встроенных дефолтах (автоперечитывания нет — следить не за чем)
- **WHEN** файл появился по одному из путей WT-LOAD-2 и конфиг перечитан вручную (дефолтная клавиша WezTerm или меню)
- **THEN** поиск идёт заново и находит новый файл (по исходнику 20240203)

### Requirement: WT-LOAD-15 Как понять, какой конфиг загружен
Загруженный конфиг репо SHALL быть виден без инструментов: панель вкладок всегда внизу (даже при одной вкладке), справа в ней — имя активного воркспейса; кроме того, WezTerm MUST передавать в окружение каждой новой панели `WEZTERM_CONFIG_FILE` и `WEZTERM_CONFIG_DIR` с путём загруженного файла (в том виде, как он был открыт, без раскрытия симлинков) и его каталога.
Платформы: все

#### Scenario: загружен конфиг репо
- **WHEN** открыто окно WezTerm с одной вкладкой
- **THEN** панель вкладок внизу, справа имя воркспейса (`default`, пока не переключались)

#### Scenario: загружены встроенные дефолты
- **GIVEN** конфиг не найден или сломан (WT-LOAD-2)
- **WHEN** открыто окно WezTerm
- **THEN** панели вкладок внизу с именем воркспейса нет; на Windows шелл — `cmd.exe`
- **AND** если файл не найден вовсе, `WEZTERM_CONFIG_FILE` и `WEZTERM_CONFIG_DIR` в панелях нет

#### Scenario: путь загруженного файла из панели
- **WHEN** в шелле панели прочитать переменные
- **THEN** на Windows `$env:WEZTERM_CONFIG_FILE` = `<репо>\wezterm.lua`, `WEZTERM_CONFIG_DIR` = корень репо (проверено 2026-09-27)
- **AND** на macOS `WEZTERM_CONFIG_FILE` — путь симлинка (`~/.config/wezterm/wezterm.lua`), не раскрытый; `WEZTERM_CONFIG_DIR` — `~/.config/wezterm`

#### Scenario: блок unset в профиле скрывает WEZTERM_CONFIG_FILE
- **GIVEN** macOS, профиль шелла получил блок из WT-LOAD-7
- **WHEN** в шелле панели прочитать переменные
- **THEN** `WEZTERM_CONFIG_FILE` снята профилем, `WEZTERM_CONFIG_DIR` на месте
