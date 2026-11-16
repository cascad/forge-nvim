# Proposal

## Why

IDE-138/141 требуют необязательный Terminal внутри отдельного fride kit. Сейчас
галочка есть, но native WezTerm/font artifact и launcher отсутствуют; legacy
installers меняют пользовательское подключение конфига. Следующий срез после
Git prerequisite — воспроизводимая private доставка без этих изменений.

## What Changes

- Pinned официальный WezTerm20240203 и CaskaydiaCove Nerd Font3.4.0, publisher
  preparation/package через прежний component catalog, SHA/source/license metadata.
- `fride-terminal` запускает собственный WezTerm с явным config-file и обычным
  fride внутри; обычный `fride` продолжает работать в текущем терминале.
- Тот же общий wezterm.lua, частный font_dirs/ConfigDirsOnly и state file.
  Пользовательские WezTerm config/font registration/environment не меняются.
- Delivery E2E на Windows/Ubuntu: version/config/font, HTTP/launcher/repeat/
  invalid payload и сохранение kit; настоящий GUI/editor roundtrip Windows.
  Ubuntu GUI/native Mac отдельно, console container не считается GUI acceptance.

## Capabilities

### New Capabilities

- `managed-terminal-delivery`: private Terminal component и явный launcher.

### Modified Capabilities

- `wezterm-config-loading`: WT-LOAD-1 допускает отдельный installed snapshot
  с явным --config-file, legacy подключение файла репозитория сохраняется.
- `wezterm-window-state`: WT-STATE-4 отдельный state для managed Terminal.

## Impact

Publisher scripts/platform policy, install-private staging и новые launchers;
маленький context parameter общего wezterm.lua только для state path. SDK/Neovim/
plugin locks/legacy installers/production catalog не меняются. Linux Desktop
должен иметь обычные GUI libraries; AppImage не означает отсутствие host GUI.
