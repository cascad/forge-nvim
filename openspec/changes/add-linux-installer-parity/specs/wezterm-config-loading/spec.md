## MODIFIED Requirements

### Requirement: WT-LOAD-13 Linux: симлинк в ~/.config/wezterm
На Linux конфиг SHALL подключаться симлинком `${XDG_CONFIG_HOME:-~/.config}/wezterm/wezterm.lua` → `wezterm.lua` репо — вручную (команда в шапке `wezterm.lua`, работающая и на чистом HOME) или шагом `install-linux.sh`, который MUST выполняться только в GUI-сессии (`DISPLAY` или `WAYLAND_DISPLAY`) либо с `FORGE_NVIM_FORCE_WEZTERM=1` и пропускаться с `FORGE_NVIM_SKIP_WEZTERM=1`. Этот шаг MUST NOT трогать путь, который уже ведёт в файл репо, и MUST NOT создавать ничего внутри чекаута: `XDG_CONFIG_HOME`, указывающий внутрь чекаута, не учитывается.
Платформы: linux (по возможности)
История: FIXLOG §43 (те же дефекты исправлены для macOS)
Проверка: tests/install-linux.scenarios.sh (L1–L11)

#### Scenario: GUI-сессия, чистый HOME
- **WHEN** запускается `install-linux.sh` из чекаута
- **THEN** создаётся каталог `~/.config/wezterm` и в нём симлинк на файл репо, в выводе `Linked <путь> -> <файл репо>`

#### Scenario: симлинк уже есть
- **GIVEN** по пути лежит симлинк, ведущий в файл репо, — абсолютный или относительный
- **WHEN** запускается `install-linux.sh`
- **THEN** `WezTerm config already linked: <путь>`, ничего не меняется, бэкапов нет

#### Scenario: что угодно другое на месте
- **GIVEN** по пути чужой файл или симлинк в никуда
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
- **THEN** `WezTerm config already linked: <путь>`, ничего не меняется
- **AND** `wezterm.lua` репо остаётся обычным файлом, бэкапов внутри чекаута нет

#### Scenario: ~/.config/wezterm — битый симлинк
- **GIVEN** `~/.config/wezterm` — симлинк в никуда
- **WHEN** запускается `install-linux.sh`
- **THEN** он уходит в `<путь>.backup-<время>`, создаётся настоящий каталог и симлинк в нём, код 0

#### Scenario: ~/.config/wezterm — симлинк на другой существующий каталог
- **GIVEN** `~/.config/wezterm` — симлинк на каталог dotfiles, где лежит чужой `wezterm.lua`
- **WHEN** запускается `install-linux.sh`
- **THEN** `~/.config/wezterm` остаётся симлинком, чужой файл уходит в бэкап внутри каталога dotfiles, там же создаётся симлинк на файл репо

#### Scenario: запуск из терминала nvim_forge
- **GIVEN** `XDG_CONFIG_HOME` шелла — корень репо или другой каталог внутри чекаута
- **WHEN** запускается `install-linux.sh`
- **THEN** симлинк кладётся в `~/.config/wezterm/wezterm.lua`, внутри репо ничего не создаётся

#### Scenario: curl | bash
- **GIVEN** `install-linux.sh` читается со stdin
- **WHEN** выполняется шаг WezTerm
- **THEN** `wezterm.lua` от текущего каталога не ищется, симлинк не создаётся, в выводе `wezterm.lua not found near the config; skipping terminal config link`

#### Scenario: ручное подключение по шапке
- **GIVEN** чистый HOME без `~/.config/wezterm`, текущий каталог — корень репо
- **WHEN** выполняется команда для Linux из шапки `wezterm.lua`
- **THEN** создаётся каталог `~/.config/wezterm` и в нём симлинк на `wezterm.lua` репо
- **AND** шапка называет `./nvim_forge/scripts/install-linux.sh` как способ сделать то же автоматически
