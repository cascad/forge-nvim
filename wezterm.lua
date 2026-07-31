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
-- Размер окна при старте + запоминание размера.
-- =====================================================================
-- Логика, как просил юзер: растяни окно мышью как удобно, подбери шрифт
-- (Cmd/Ctrl +/−) → нажми Ctrl+Shift+S (см. config.keys ниже) — размер окна
-- И размер шрифта сохранятся, и ВСЕ новые окна открываются ровно такими,
-- пока не сохранишь снова. Если сохранённого ещё нет — открываем крупным
-- в долю экрана (как VS Code/IDEA), не на весь экран.
-- Сохранённое состояние лежит в хомяке (не в репо).
local window_state_file = (wezterm.home_dir or os.getenv("USERPROFILE") or ".")
    .. "/.wezterm_forge_window.json"

-- Доли экрана ТОЛЬКО для первого запуска (пока размер не сохранён). Основной
-- способ задать размер — Ctrl+Shift+S; эти числа лишь дефолт «из коробки».
local WINDOW_FRACTION_W = 0.62
local WINDOW_FRACTION_H = 0.72

local function read_saved_size()
    local f = io.open(window_state_file, "r")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    local ok, t = pcall(wezterm.json_parse, data)
    if ok and type(t) == "table" and tonumber(t.w) and tonumber(t.h) then
        return {
            w = math.floor(t.w),
            h = math.floor(t.h),
            -- В файлах, сохранённых до добавления шрифта, поля нет — nil.
            font_size = tonumber(t.font_size),
        }
    end
    return nil
end

local function center_on_active_screen(gui, w, h)
    local screen = wezterm.gui.screens().active
    gui:set_inner_size(w, h)
    gui:set_position(
        screen.x + math.floor((screen.width - w) / 2),
        screen.y + math.floor((screen.height - h) / 2)
    )
end

-- Ctrl+Shift+S → запомнить ТЕКУЩИЕ размер окна и размер шрифта.
local save_window_size = wezterm.action_callback(function(window, _pane)
    local dims = window:get_dimensions()
    -- effective_config() учитывает set_config_overrides, т.е. отдаёт шрифт
    -- после Cmd/Ctrl +/− (font-биндинги ниже работают через overrides).
    local t = {
        w = dims.pixel_width,
        h = dims.pixel_height,
        font_size = window:effective_config().font_size,
    }
    local f = io.open(window_state_file, "w")
    if f then
        f:write(wezterm.json_encode(t))
        f:close()
        window:toast_notification("WezTerm",
            ("Сохранено: окно %d×%d, шрифт %.1f (так и откроется в след. раз)")
                :format(t.w, t.h, t.font_size),
            nil, 3000)
    else
        window:toast_notification("WezTerm", "Не удалось записать состояние окна", nil, 3000)
    end
end)

wezterm.on("gui-startup", function(cmd)
    local _, _, window = wezterm.mux.spawn_window(cmd or {})
    local gui = window:gui_window()
    local ok = pcall(function()
        local saved = read_saved_size()
        if saved then
            center_on_active_screen(gui, saved.w, saved.h)
        else
            local screen = wezterm.gui.screens().active
            center_on_active_screen(gui,
                math.floor(screen.width * WINDOW_FRACTION_W),
                math.floor(screen.height * WINDOW_FRACTION_H))
        end
    end)
    -- Фоллбэк, если API экрана недоступен — просто крупный фикс-размер.
    if not ok then pcall(function() gui:set_inner_size(1500, 950) end) end
end)

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
-- Если шрифт был сохранён через Ctrl/Cmd+Shift+S — восстанавливаем его,
-- перекрывая дефолт выше. Хранится в одном файле с размером окна.
local saved_state = read_saved_size()
if saved_state and saved_state.font_size then
    config.font_size = saved_state.font_size
end
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

-- Смена размера шрифта ЧЕРЕЗ config overrides, а не дефолтные
-- IncreaseFontSize/DecreaseFontSize: внутренний font-scale wezterm нельзя
-- прочитать из Lua, а overrides видны в effective_config() — только так
-- Ctrl/Cmd+Shift+S может сохранить текущий шрифт. Шаг тот же, что у
-- дефолта (×1.1). factor = nil — сброс к config.font_size (т.е. к
-- сохранённому, а без сохранённого — к 12).
local function change_font_size(factor)
    return wezterm.action_callback(function(window, _pane)
        local overrides = window:get_config_overrides() or {}
        if factor then
            overrides.font_size = window:effective_config().font_size * factor
        else
            overrides.font_size = nil
        end
        window:set_config_overrides(overrides)
    end)
end

config.keys = {
    { key = "phys:C", mods = "CTRL", action = smart_copy },
    { key = "phys:V", mods = "CTRL", action = act.PasteFrom("Clipboard") },
    -- Дубли на Ctrl+Shift+C/V — привычный терминальный вариант, всегда
    -- copy/paste без "умной" логики.
    { key = "phys:C", mods = "CTRL|SHIFT", action = act.CopyTo("Clipboard") },
    { key = "phys:V", mods = "CTRL|SHIFT", action = act.PasteFrom("Clipboard") },

    -- Ctrl+Shift+S — запомнить текущий размер окна (см. gui-startup выше).
    -- nvim это не использует, так что перехват тут безопасен.
    { key = "phys:S", mods = "CTRL|SHIFT", action = save_window_size },

    -- Ctrl+[ → outdent в Neovim (сдвиг строки влево, как Ctrl+] = вправо).
    -- Физически Ctrl+[ == Esc (0x1b), и nvim не может их различить, поэтому
    -- перехватываем здесь и шлём <F13> — на него nvim вешает «сдвиг влево»
    -- (см. nvim_forge/lua/config/keymaps.lua). Esc остаётся на самой
    -- клавише Esc. phys:LeftBracket — физическая позиция «[», не зависит
    -- от раскладки (на русской это та же клавиша, что печатает «х»).
    { key = "phys:LeftBracket", mods = "CTRL", action = act.SendKey({ key = "F13" }) },
}

-- Шрифт: Cmd+=/− (мак) и Ctrl+=/− (вин/линукс) — крупнее/мельче,
-- Cmd/Ctrl+0 — сброс к сохранённому/дефолту. Перекрываем ВСЕ дефолтные
-- комбинации Increase/DecreaseFontSize (включая шифтованные «+»), иначе
-- часть из них меняла бы внутренний масштаб мимо overrides и Ctrl+Shift+S
-- сохранял бы не тот размер (см. change_font_size выше).
for _, mods in ipairs({ "SUPER", "CTRL", "SHIFT|SUPER", "SHIFT|CTRL" }) do
    table.insert(config.keys, { key = "=", mods = mods, action = change_font_size(1.1) })
    table.insert(config.keys, { key = "+", mods = mods, action = change_font_size(1.1) })
    table.insert(config.keys, { key = "-", mods = mods, action = change_font_size(1 / 1.1) })
    table.insert(config.keys, { key = "0", mods = mods, action = change_font_size(nil) })
end

-- На macOS дублируем сохранение размера окна на привычный Cmd+Shift+S
-- (SUPER = Cmd). На Windows такой бинд не вешаем: Win+Shift+S занят
-- системным скриншотом.
if not is_windows then
    table.insert(config.keys,
        { key = "phys:S", mods = "SUPER|SHIFT", action = save_window_size })
end

return config
