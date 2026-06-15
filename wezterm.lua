-- WezTerm — кросс-платформенный терминал с одинаковым поведением на
-- Windows / macOS / Linux. Главная причина выбора для этого репо:
-- поддержка kitty keyboard protocol, благодаря которой Neovim получает
-- "хитрые" комбо как отдельные клавиши — Ctrl+. (code action), Cmd+.,
-- Ctrl+Enter, Shift+Enter, Ctrl+; и т.п. Обычные терминалы их глотают.
--
-- ИСПОЛЬЗОВАНИЕ (без копирования в хомяк, в духе остального репо):
--   Вариант 1 (env-переменная — рекомендуется):
--     задай WEZTERM_CONFIG_FILE = путь до этого файла, и WezTerm возьмёт
--     именно его. Пример (Windows, PowerShell-профиль):
--       $env:WEZTERM_CONFIG_FILE = "F:\repo\forge-nvim\wezterm.lua"
--     macOS/Linux (~/.zshrc или ~/.bashrc):
--       export WEZTERM_CONFIG_FILE="$HOME/path/to/forge-nvim/wezterm.lua"
--   Вариант 2 (стандартное место):
--     скопируй/симлинкни этот файл в:
--       Windows: %USERPROFILE%\.wezterm.lua
--       Unix:    ~/.config/wezterm/wezterm.lua

local wezterm = require("wezterm")
local config = wezterm.config_builder and wezterm.config_builder() or {}

local is_windows = wezterm.target_triple:find("windows") ~= nil

-- =====================================================================
-- Шелл по умолчанию
-- =====================================================================
-- Ищем exe в %PATH% вручную (WezTerm-Lua не имеет встроенного "which").
local function exe_in_path(name)
    local path = os.getenv("PATH") or ""
    local sep = is_windows and ";" or ":"
    for dir in path:gmatch("([^" .. sep .. "]+)") do
        local full = dir .. (is_windows and "\\" or "/") .. name
        local f = io.open(full, "r")
        if f then
            f:close()
            return full
        end
    end
    return nil
end

if is_windows then
    -- Предпочитаем pwsh (PowerShell 7), если он реально есть в PATH.
    -- Иначе — встроенный powershell.exe (есть на любой Windows), чтобы
    -- терминал гарантированно стартовал, а не падал на отсутствующем pwsh.
    if exe_in_path("pwsh.exe") then
        config.default_prog = { "pwsh.exe", "-NoLogo" }
    else
        config.default_prog = { "powershell.exe", "-NoLogo" }
    end
end
-- На macOS/Linux default_prog не задаём — берётся $SHELL пользователя.

-- =====================================================================
-- Клавиатура: kitty keyboard protocol → Ctrl+. и компания долетают в nvim
-- =====================================================================
-- WezTerm объявляет поддержку расширенного протокола, а Neovim 0.10+ сам
-- его запрашивает. Дополнительно НИЧЕГО включать не надо — Ctrl+. начнёт
-- работать как code action. Оставляем стандартные wezterm-хоткеи, но
-- НЕ перехватываем то, что нужно Neovim.
config.enable_kitty_keyboard = true
config.enable_csi_u_key_encoding = false  -- kitty protocol предпочтительнее

-- Чтобы Alt работал как Meta (нужно для <A-...> биндингов nvim), а не
-- вводил спец-символы (актуально для macOS).
config.send_composed_key_when_left_alt_is_pressed = false
config.send_composed_key_when_right_alt_is_pressed = false

-- =====================================================================
-- Внешний вид
-- =====================================================================
config.color_scheme = "Catppuccin Mocha"
-- Основной — CaskaydiaCove Nerd Font (Cascadia с иконками, красивый).
-- Должен быть установлен: winget install --id DEVCOM.CascadiaCodeNerdFont
-- Фолбэки — на случай чужой машины без него: сначала другой установленный
-- Nerd Font (иконки сохранятся), затем обычные моноширинные.
config.font = wezterm.font_with_fallback({
    "CaskaydiaCove NF",          -- имя семейства в Nerd Fonts 3.x
    "CaskaydiaCove Nerd Font",   -- старое имя (Nerd Fonts 2.x), для совместимости
    "Inconsolata Nerd Font Mono",
    "Cascadia Mono",
    "Consolas",
})
-- Не сыпать предупреждениями, если в строке нет глифа в основном шрифте —
-- молча берём из fallback.
config.warn_about_missing_glyphs = false
config.font_size = 12.0
config.line_height = 1.05

-- right чуть шире — там рисуется полоса прокрутки (enable_scroll_bar),
-- иначе она наезжает на последний столбец текста.
config.window_padding = { left = 6, right = 14, top = 4, bottom = 4 }
-- TITLE|RESIZE — нативный заголовок окна (за него можно таскать + кнопки
-- свернуть/развернуть/закрыть) и рамки для ресайза. Было "RESIZE" — без
-- заголовка окно невозможно было перетащить.
config.window_decorations = "TITLE | RESIZE"
config.adjust_window_size_when_changing_font_size = false
config.scrollback_lines = 10000
-- Полоса прокрутки справа: видно, где мы в истории, и можно тащить мышью.
-- Появляется только когда есть scrollback (т.е. в шелле; внутри nvim,
-- который держит альтернативный экран, её нет — там скроллит сам nvim).
-- min_content_width в padding учитывает её ширину, чтобы не наезжала на текст.
config.enable_scroll_bar = true
config.audible_bell = "Disabled"

-- Курсор. Neovim сам управляет формой через guicursor, тут дефолт для
-- шелл-промпта. BlinkingBlock + быстрый rate + Constant-ease убирают
-- "ленивое" плавное затухание (по умолчанию WezTerm делает Ease-анимацию
-- на 800мс, из-за чего мигание кажется вялым).
config.default_cursor_style = "BlinkingBlock"
config.cursor_blink_rate = 500          -- мс на фазу (меньше = быстрее)
config.cursor_blink_ease_in = "Constant"  -- без плавного появления
config.cursor_blink_ease_out = "Constant" -- без плавного затухания
config.animation_fps = 1                -- дискретное вкл/выкл, не fade

-- Табы WezTerm не нужны (вкладки/сплиты ведёт Neovim). Прячем панель,
-- если открыт один таб.
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false

-- =====================================================================
-- Copy / Paste
-- =====================================================================
local act = wezterm.action

-- РАСКЛАДКО-НЕЗАВИСИМОСТЬ. Привязки заданы через `phys:` — это ФИЗИЧЕСКАЯ
-- позиция клавиши на ANSI-US клавиатуре, а не символ, который она печатает.
-- Без этого на русской раскладке Ctrl+C нажимает физическую клавишу "C",
-- но ОС отдаёт символ "с" (кириллица) → wezterm не узнаёт биндинг → Ctrl+C
-- не копирует и (главное) не шлёт SIGINT в программу. С `phys:C` биндинг
-- ловится на любой раскладке (рус/eng/любой), а SendKey ниже отправляет
-- в pane уже «чистый» Ctrl+C, который conpty превращает в 0x03 → SIGINT.
--
-- Прочие Ctrl+<буква>, которые wezterm НЕ перехватывает, уходят как есть в
-- nvim — там раскладку разруливает config/ru_keys.lua (langmap + алиасы).

-- Ctrl+C — "умный": если есть выделение мышью/клавиатурой → копируем и
-- снимаем выделение; если выделения нет → шлём Ctrl+C в программу как
-- обычный SIGINT/прерывание (нужно шеллу и nvim).
local smart_copy = wezterm.action_callback(function(window, pane)
    local sel = window:get_selection_text_for_pane(pane)
    if sel and sel ~= "" then
        window:perform_action(act.CopyTo("ClipboardAndPrimarySelection"), pane)
        window:perform_action(act.ClearSelection, pane)
    else
        window:perform_action(act.SendKey({ key = "c", mods = "CTRL" }), pane)
    end
end)

config.keys = {
    { key = "phys:C", mods = "CTRL", action = smart_copy },
    { key = "phys:V", mods = "CTRL", action = act.PasteFrom("Clipboard") },
    -- Дубли на Ctrl+Shift+C/V — привычный терминальный вариант, всегда
    -- copy/paste без "умной" логики.
    { key = "phys:C", mods = "CTRL|SHIFT", action = act.CopyTo("Clipboard") },
    { key = "phys:V", mods = "CTRL|SHIFT", action = act.PasteFrom("Clipboard") },
}

return config
