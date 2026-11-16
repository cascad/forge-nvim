-- spec: IDE-BOOT-28. Installed wrapper; shared config/keymap stays in wezterm.lua.
local wezterm = require('wezterm')
local directory = wezterm.config_dir
local config = assert(loadfile(directory .. '/wezterm.lua'))({
    window_state_file = directory .. '/../state/wezterm-window.json',
})
config.font_dirs = { directory .. '/../runtime/terminal/fonts' }
config.font_locator = 'ConfigDirsOnly'
config.font = wezterm.font('CaskaydiaCove NF')
return config
