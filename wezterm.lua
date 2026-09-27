-- WezTerm — терминал nvim_forge на Windows, macOS и Linux.
--
-- ПОДКЛЮЧЕНИЕ (файл остаётся в репо, в хомяк не копируется — WT-LOAD-1):
--   Windows — переменная уровня пользователя (её видят и GUI-запуски, WT-LOAD-3):
--       [Environment]::SetEnvironmentVariable("WEZTERM_CONFIG_FILE",
--           "F:\repo\forge-nvim\wezterm.lua", "User")
--   macOS — ./nvim_forge/scripts/install-macos.sh: симлинк
--   ~/.config/wezterm/wezterm.lua → этот файл, снимает то, что его перекрывает,
--   и проверяет, какой конфиг WezTerm реально загрузит (WT-LOAD-4…10).
--   Повторный запуск безопасен — им же и чинить.
--   Linux — mkdir -p ~/.config/wezterm && ln -sf "$PWD/wezterm.lua" ~/.config/wezterm/wezterm.lua (из корня репо)
--   или ./nvim_forge/scripts/install-linux.sh (то же самое автоматически, WT-LOAD-13).
--   Видимый признак этого конфига — панель вкладок ВНИЗУ с именем
--   воркспейса справа (WT-LOAD-15).
--
-- СЕКЦИИ (каждая использует только то, что определено выше):
--   1. Факты о платформе — единственное место, где читается внешний мир.
--   2. Файл состояния окна.
--   3. Настройки по capability: клавиатура, вид, шелл.
--   4. Действия и колбэки — именованные функции.
--   5. Привязки вне режимов — map(), по записи на строку.
--   6. Таблицы режимов — mode_map() и замены во встроенных mode_replace().
--   7. Сборка config.keys и config.key_tables.
--   8. События.
--
-- Как это должно работать — openspec/specs/wezterm-*/spec.md; код требования:
-- grep -n 'spec: WT-CLIP-2' wezterm.lua. История поломок — nvim_forge/FIXLOG.md.
-- Проверки — nvim -l tests/run.lua (эталоны конфига — tests/wezterm/golden/).
-- Код — в пересечении Lua 5.4 (WezTerm) и LuaJIT (тесты): без //, битовых
-- операторов, <const>/<close>.

local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder and wezterm.config_builder() or {}

-- =====================================================================
-- 1. ФАКТЫ О ПЛАТФОРМЕ
-- =====================================================================
-- Только здесь читаются target_triple, home_dir, os.getenv и PATH; ниже —
-- только platform.*.

-- Есть ли файл — БЕЗ открытия. PowerShell 7 из Microsoft Store лежит в
-- PATH псевдонимом (%LOCALAPPDATA%\Microsoft\WindowsApps\pwsh.exe): io.open
-- на нём падает, а wezterm.glob его видит (проба 2026-09-27, 20240203;
-- ~1 мс на все каталоги PATH). История: FIXLOG §52.
local function file_listed(full)
    local ok, found = pcall(wezterm.glob, (full:gsub("\\", "/")))
    return ok and type(found) == "table" and #found > 0
end

-- Первый по порядку PATH каталог (Windows: `;` и `\`), где есть name →
-- полный путь; нет → nil. exists — «есть ли файл».
local function find_in_path(path, name, exists)
    for dir in path:gmatch("[^;]+") do
        local full = (dir:gsub("[\\/]+$", "")) .. "\\" .. name
        if exists(full) then return full end
    end
    return nil
end

local platform = {}
do
    local triple = wezterm.target_triple
    platform.os = triple:find("windows") and "windows"
        or triple:find("darwin") and "macos"
        or "linux"
    platform.is_windows = platform.os == "windows"
    -- Хомяк: файлы состояния и выгрузки истории лежат в нём, не в репо.
    platform.home = wezterm.home_dir or os.getenv("USERPROFILE") or "."
    -- Шелл ищется только на Windows (вне Windows — $SHELL пользователя, WT-UI-2).
    -- Поиск — при каждом вычислении конфига; выбор виден в default_prog.
    if platform.is_windows then
        platform.pwsh = find_in_path(os.getenv("PATH") or "", "pwsh.exe", file_listed)
    end
end

-- =====================================================================
-- 2. ФАЙЛ СОСТОЯНИЯ ОКНА (WT-STATE-4)
-- =====================================================================
-- Размер окна и шрифт, сохранённые Ctrl/Cmd+Shift+S. История: FIXLOG §32, §48.
local window_state_file = platform.home .. "/.wezterm_forge_window.json"

-- Шрифт, если в файле состояния его нет (WT-STATE-5).
local DEFAULT_FONT_SIZE = 12.0

-- → { w, h, font_size } или nil (файла нет, он битый или без w/h).
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

-- → true, если записано.
local function write_window_state(t)
    local f = io.open(window_state_file, "w")
    if not f then return false end
    f:write(wezterm.json_encode(t))
    f:close()
    return true
end

-- =====================================================================
-- 3. НАСТРОЙКИ
-- =====================================================================

-- --- Клавиатура ------------------------------------------------------
-- Windows: kitty ВЫКЛЮЧЕН, протокол — win32-input-mode, который ConPTY сам
-- просит у терминала. Включённый kitty ломает набор на не-US раскладках
-- (кодировщик WezTerm знает только US) в программах, приславших CSI >Nu
-- через ConPTY, — например, Claude Code. История: FIXLOG §41.
-- macOS/Linux: kitty включён, Neovim 0.10+ сам его запрашивает.
config.enable_kitty_keyboard = not platform.is_windows  -- spec: WT-KBD-1, WT-KBD-2
config.allow_win32_input_mode = true                     -- spec: WT-KBD-1
config.enable_csi_u_key_encoding = false                 -- spec: WT-KBD-5

-- Alt — Meta (для <A-…> в nvim). Действуют только на macOS; на Windows
-- правый Alt на раскладке с AltGr остаётся AltGr. История: FIXLOG §51.
config.send_composed_key_when_left_alt_is_pressed = false   -- spec: WT-KBD-4
config.send_composed_key_when_right_alt_is_pressed = false  -- spec: WT-KBD-4

-- macOS: SHIFT в маске IME — ИНВАРИАНТ, не трогать. Shift+буква идёт через
-- IME и приходит готовым текстом без модификаторов; без SHIFT в маске на
-- русской раскладке в kitty-программах перестают набираться заглавные.
-- На привязки маска не влияет: phys: сопоставляется до IME. История: FIXLOG §41.
if not platform.is_windows then
    config.macos_forward_to_ime_modifier_mask = "SHIFT"  -- spec: WT-KBD-3
end

-- Встроенные привязки WezTerm заданы по символу и на русской раскладке
-- молча пропадают, часть перехватывала клавиши nvim. Выключены целиком,
-- нужное переопределено через phys: ниже. Мышь (свои дефолты) и встроенные
-- copy_mode/search_mode флаг не трогает.
config.disable_default_key_bindings = true  -- spec: WT-KEYS-1, WT-KEYS-2

-- --- Вид ---------------------------------------------------------------
config.color_scheme = "Catppuccin Mocha"  -- spec: WT-UI-3

-- CaskaydiaCove Nerd Font: winget install --id DEVCOM.CascadiaCodeNerdFont
-- (на macOS ставит install-macos.sh). Каждое отсутствующее имя из списка
-- WezTerm показывает окном ошибки, поэтому в списке только он; дальше —
-- встроенные запасные WezTerm. История: FIXLOG §52.
config.font = wezterm.font_with_fallback({  -- spec: WT-UI-4
    "CaskaydiaCove NF",          -- имя семейства в Nerd Fonts 3.x
    "CaskaydiaCove Nerd Font",   -- тот же шрифт под другим именем — страховка на иную сборку
})
config.warn_about_missing_glyphs = false  -- spec: WT-UI-4

-- Шрифт по умолчанию, перекрытый сохранённым. Файл читается при каждом
-- вычислении конфига: при перечитывании и для каждого нового окна.
config.font_size = DEFAULT_FONT_SIZE  -- spec: WT-STATE-5
local saved_state = read_saved_size()
if saved_state and saved_state.font_size then
    config.font_size = saved_state.font_size
end
config.adjust_window_size_when_changing_font_size = false  -- spec: WT-STATE-8
config.line_height = 1.05  -- spec: WT-UI-5

-- Правое поле шире: в нём рисуется полоса прокрутки.
config.window_padding = { left = 6, right = 14, top = 4, bottom = 4 }  -- spec: WT-UI-7, WT-SCROLL-3
config.window_decorations = "TITLE | RESIZE"  -- spec: WT-UI-6
config.scrollback_lines = 10000  -- spec: WT-SCROLL-1
config.enable_scroll_bar = true  -- spec: WT-SCROLL-3
config.audible_bell = "Disabled"  -- spec: WT-UI-8

-- Курсор шелла (форму в nvim задаёт guicursor). Constant/Constant —
-- дискретное мигание вместо плавного; animation_fps — прочие анимации.
config.default_cursor_style = "BlinkingBlock"  -- spec: WT-UI-9
config.cursor_blink_rate = 500
config.cursor_blink_ease_in = "Constant"
config.cursor_blink_ease_out = "Constant"
config.animation_fps = 1

-- Панель вкладок видна всегда: в ней бейдж режима и имя воркспейса.
config.hide_tab_bar_if_only_one_tab = false  -- spec: WT-UI-10
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.tab_max_width = 24
config.status_update_interval = 100  -- spec: WT-UI-14

config.inactive_pane_hsb = { saturation = 0.85, brightness = 0.75 }  -- spec: WT-UI-11

-- --- Шелл --------------------------------------------------------------
-- Windows: найденный PowerShell 7 полным путём (выбор и запуск не
-- расходятся), иначе встроенный powershell.exe. Вне Windows не задаём.
if platform.is_windows then
    config.default_prog = platform.pwsh and { platform.pwsh, "-NoLogo" }  -- spec: WT-UI-1, WT-UI-2
        or { "powershell.exe", "-NoLogo" }
end

-- =====================================================================
-- 4. ДЕЙСТВИЯ И КОЛБЭКИ
-- =====================================================================

-- --- Копирование (WT-CLIP-1) ---------------------------------------------
-- Один путь для всех клавиш копирования. Голого act.CopyTo нет нигде: при
-- пустом выделении он записывает в буфер пустую строку, а выделение WezTerm
-- гасит при любой перерисовке. Выделение читается ОДИН раз и в буфер идёт
-- прочитанный текст (CopyTextTo): между проверкой и записью оно могло бы
-- погаснуть. История: FIXLOG §42, §45.
-- after_copy — действие после копирования, on_empty — без выделения (nil — ничего).
local function copy_selection_with(after_copy, on_empty)
    return wezterm.action_callback(function(window, pane)
        local sel = window:get_selection_text_for_pane(pane)
        if sel and sel ~= "" then
            window:perform_action(act.CopyTextTo({
                text = sel, destination = "ClipboardAndPrimarySelection",
            }), pane)
            if after_copy then
                window:perform_action(after_copy, pane)
            end
        elseif on_empty then
            window:perform_action(on_empty, pane)
        end
    end)
end

local copy_selection = copy_selection_with(nil, nil)

-- Умный Ctrl+C (Windows): есть выделение — копируем и снимаем его; нет —
-- Ctrl+C уходит программе кодировщиком панели (WT-CLIP-2, WT-KBD-7).
local smart_copy = copy_selection_with(act.ClearSelection,
    act.SendKey({ key = "c", mods = "CTRL" }))

-- --- Шрифт (WT-STATE-6, WT-STATE-7) --------------------------------------
-- Через config overrides, а не IncreaseFontSize: внутренний масштаб из Lua
-- не прочитать, а overrides видны в effective_config() — только так
-- Ctrl+Shift+S сохраняет текущий шрифт. Шаг ×1.1, как у WezTerm.
-- factor = nil — сброс в два шага: overrides с шрифтом из файла (без файла —
-- DEFAULT_FONT_SIZE), затем те же overrides без font_size — значение всегда
-- другое, поэтому WezTerm каждый раз заново вычисляет конфиг окна, и окно
-- снова следует за файлом. nil в overrides не передаётся никогда — это
-- признак непринятого окна (accept_window). История: FIXLOG §48.
local function change_font_size(factor)
    return wezterm.action_callback(function(window, _pane)
        local overrides = window:get_config_overrides() or {}
        if factor then
            overrides.font_size = window:effective_config().font_size * factor
            window:set_config_overrides(overrides)
            return
        end
        local saved = read_saved_size()
        overrides.font_size = saved and saved.font_size or DEFAULT_FONT_SIZE
        window:set_config_overrides(overrides)
        overrides.font_size = nil
        window:set_config_overrides(overrides)
    end)
end

-- --- Окно: сохранить и принять новое (WT-STATE-1, WT-STATE-2, WT-STATE-3) --
-- Доли экрана — размер нового окна, пока ничего не сохранено.
local WINDOW_FRACTION_W = 0.62
local WINDOW_FRACTION_H = 0.72
-- Размер окна, если сведений об экране нет: крупный фикс без центрирования.
local FALLBACK_W, FALLBACK_H = 1500, 950

-- Запомнить ТЕКУЩИЕ размер окна и шрифт (effective_config учитывает overrides).
local save_window_size = wezterm.action_callback(function(window, _pane)
    local dims = window:get_dimensions()
    local t = {
        w = dims.pixel_width,
        h = dims.pixel_height,
        font_size = window:effective_config().font_size,
    }
    if write_window_state(t) then
        window:toast_notification("WezTerm",
            ("Сохранено: окно %d×%d, шрифт %.1f (так и откроется в след. раз)")
                :format(t.w, t.h, t.font_size),
            nil, 3000)
    else
        window:toast_notification("WezTerm", "Не удалось записать состояние окна", nil, 3000)
    end
end)

-- Размер и положение нового окна — чистая функция от сохранённого
-- состояния и активного экрана (nil — сведений об экране нет).
-- → { w, h, x, y, source }: source — saved / fraction / fallback; x, y = nil —
-- положение оставляем ОС.
local function new_window_geometry(saved, screen)
    if not screen then
        return { w = FALLBACK_W, h = FALLBACK_H, source = "fallback" }
    end
    local g
    if saved then
        g = { w = saved.w, h = saved.h, source = "saved" }
    else
        g = {
            w = math.floor(screen.width * WINDOW_FRACTION_W),
            h = math.floor(screen.height * WINDOW_FRACTION_H),
            source = "fraction",
        }
    end
    g.x = screen.x + math.floor((screen.width - g.w) / 2)
    g.y = screen.y + math.floor((screen.height - g.h) / 2)
    return g
end

-- Принять окно — один путь для каждого нового окна, откуда бы оно ни
-- взялось. WezTerm шлёт window-config-reloaded каждому новому окну сразу
-- после показа (termwindow new_window, 20240203) и потом при каждом
-- пересчёте конфига окна. Признак «не принято» — overrides окна равны nil:
-- новое окно начинает с Null, принятое получает {} и в nil не возвращается.
-- Признак живёт в окне и переживает перечитывание Lua. {} ставится и при
-- ошибке, иначе окно ставили бы на каждом событии; смена Null → {} заодно
-- пересчитывает конфиг, и шрифт берётся из файла на момент открытия.
-- История: FIXLOG §48.
local function accept_window(window)
    local id = window:window_id()
    local ok, err = pcall(function()
        local screens_ok, screens = pcall(wezterm.gui.screens)
        if not screens_ok then
            wezterm.log_warn(("принять окно %s: нет сведений об экране: %s"):format(id, tostring(screens)))
        end
        local g = new_window_geometry(read_saved_size(), screens_ok and screens.active or nil)
        window:set_inner_size(g.w, g.h)
        if g.x then window:set_position(g.x, g.y) end
        wezterm.log_info(("принять окно %s: %s %d×%d, %s"):format(id, g.source, g.w, g.h,
            g.x and ("в %d,%d"):format(g.x, g.y) or "положение — от ОС"))
    end)
    if not ok then
        wezterm.log_warn(("принять окно %s: %s"):format(id, tostring(err)))
    end
    window:set_config_overrides({})
end

local function on_window_config_reloaded(window, _pane)
    if window:get_config_overrides() == nil then
        accept_window(window)
    end
end

-- --- Панели, вкладки, воркспейсы ------------------------------------------
-- Готовый лэйаут: nvim слева широкий + 2 консоли справа столбиком (WT-PANE-9).
local ready_layout = wezterm.action_callback(function(_window, pane)
    local right = pane:split({ direction = "Right", size = 0.35 })
    right:split({ direction = "Bottom", size = 0.5 })
    pane:activate()
end)

local function rename_active_tab(window, _pane, line)
    if line and line ~= "" then
        window:active_tab():set_title(line)
    end
end
local rename_tab = act.PromptInputLine({  -- WT-PANE-11
    description = "Имя вкладки:",
    action = wezterm.action_callback(rename_active_tab),
})

local function switch_to_workspace(window, pane, line)
    if line and line ~= "" then
        window:perform_action(act.SwitchToWorkspace({ name = line }), pane)
    end
end
local new_workspace = act.PromptInputLine({  -- WT-PANE-10
    description = "Новый/существующий воркспейс:",
    action = wezterm.action_callback(switch_to_workspace),
})

-- --- Выгрузка истории в nvim (WT-SCROLL-13) --------------------------------
-- Приём штатный (docs/scrollback.md): get_lines_as_text + SpawnCommandInNewTab.
-- Что попадает в файл, решает get_lines_as_text (строки экранные, хвостовые
-- пробелы срезаны). nvim из PATH, не nvim_forge — мгновенный старт. Файл один,
-- перезаписывается, лежит в хомяке; в нём остаётся последний вывод.
local scrollback_file = platform.home .. "/.wezterm_scrollback.txt"
local scrollback_to_nvim = wezterm.action_callback(function(window, pane)
    local text = pane:get_lines_as_text(pane:get_dimensions().scrollback_rows)
    local f = io.open(scrollback_file, "w")
    if not f then
        window:toast_notification("WezTerm",
            "Не удалось записать " .. scrollback_file, nil, 3000)
        return
    end
    f:write(text)
    f:close()
    window:perform_action(
        act.SpawnCommandInNewTab({ args = { "nvim", "+", scrollback_file } }),
        pane)
end)

-- --- Режимы ------------------------------------------------------------
-- Выключить режим целиком (WINDOWS и RESIZE под ним), затем действие — для
-- всего, что открывает экран поверх панели (WT-WIN-19). ClearKeyTableStack,
-- а не PopKeyTable: WINDOWS поверх RESIZE после Pop оставил бы RESIZE,
-- глотающий ввод. copy/search mode живут на оверлее — их он не трогает.
-- История: FIXLOG §47.
local function leave_mode(action)
    return act.Multiple({ act.ClearKeyTableStack, action })
end

local close_copy_mode = act.CopyMode("Close")

-- --- Windows: подмена сочетаний nvim_forge (WT-KEYS-10, WT-KBD-9) ----------
-- Через ConPTY эти сочетания до nvim отдельной клавишей не доходят (WT-KBD-6).
-- Панель, объявленная nvim_forge (user var FORGE_NVIM = версия таблицы),
-- получает подменную клавишу — xterm F13–F20 с Ctrl, дальше с Ctrl+Shift (они
-- проходят, tests/wezterm/conpty/chords.fixture.json); nvim_forge переназначает
-- их обратно (nvim_forge/lua/config/wezterm_chords.lua — та же таблица и
-- версия). Прочие панели получают исходное нажатие записью win32-input-mode,
-- как её пишет WezTerm 20240203 (Ctrl — всегда левый). SendString: байты
-- точные и не зависят от режимов кодировщика панели. Сменил клавишу или
-- состав — подними версию здесь и в nvim_forge. История: FIXLOG §53.
local NVIM_CHORDS_VERSION = "1"
-- Модификаторы записи: LEFT_CTRL_PRESSED = 0x08, SHIFT_PRESSED = 0x10.
local LEFT_CTRL, CTRL_SHIFT = 0x08, 0x18
local NVIM_CHORDS = {
    -- сочетание, клавиша, модификаторы, подмена, исходное нажатие {vk, scan, символ, модификаторы}
    { "Ctrl+Shift+F",  "phys:F",      "CTRL|SHIFT", "\27[25;5~", { 70, 33, 6, CTRL_SHIFT } },
    { "Ctrl+Shift+P",  "phys:P",      "CTRL|SHIFT", "\27[26;5~", { 80, 25, 16, CTRL_SHIFT } },
    { "Ctrl+Shift+E",  "phys:E",      "CTRL|SHIFT", "\27[28;5~", { 69, 18, 5, CTRL_SHIFT } },
    { "Ctrl+Shift+D",  "phys:D",      "CTRL|SHIFT", "\27[29;5~", { 68, 32, 4, CTRL_SHIFT } },
    { "Ctrl+Shift+F5", "F5",          "CTRL|SHIFT", "\27[31;5~", { 116, 63, 0, CTRL_SHIFT } },
    { "Ctrl+.",        "phys:Period", "CTRL",       "\27[32;5~", { 190, 52, 0, LEFT_CTRL } },
    { "Ctrl+Enter",    "Enter",       "CTRL",       "\27[33;5~", { 13, 28, 10, LEFT_CTRL } },
    { "Ctrl+/",        "phys:Slash",  "CTRL",       "\27[34;5~", { 191, 53, 0, LEFT_CTRL } },
    { "Ctrl+Space",    "phys:Space",  "CTRL",       "\27[25;6~", { 32, 57, 32, LEFT_CTRL } },
}

-- Запись win32-input-mode: ESC [ Vk ; Sc ; Uc ; Kd ; Cs ; Rc _ — нажатие и отпускание.
local function win32_press_release(r)
    local rec = "\27[%d;%d;%d;%d;%d;1_"
    return rec:format(r[1], r[2], r[3], 1, r[4]) .. rec:format(r[1], r[2], r[3], 0, r[4])
end

-- Действие для строки NVIM_CHORDS.
local function nvim_chord(c)
    local subst, original = c[4], win32_press_release(c[5])
    return wezterm.action_callback(function(window, pane)
        local declared = pane:get_user_vars().FORGE_NVIM == NVIM_CHORDS_VERSION
        window:perform_action(act.SendString(declared and subst or original), pane)
    end)
end

-- Наблюдаемость: смена объявления видна в debug overlay (WINDOWS → d).
-- Зависшее объявление снимается командой из docs/WEZTERM.md.
local function on_user_var_changed(_window, pane, name, value)
    if name == "FORGE_NVIM" then
        wezterm.log_info(("forge: FORGE_NVIM pane=%s value=%q"):format(tostring(pane:pane_id()), value))
    end
end

-- --- Бейдж режима и ширина вкладок (WT-UI-12, WT-UI-13, WT-UI-15) ----------
-- Бейдж — только у таблиц клавиш; оверлеи (QuickSelect, лаунчер, палитра,
-- запросы, debug overlay) ввод перехватывают, но active_key_table их не видит.
-- Бейдж строится одной функцией из одной таблицы — и для показа, и для
-- расчёта резерва ширины. История: FIXLOG §52.
local MODE_BADGES = {
    windows     = { "WINDOWS", "#f9e2af" },  -- жёлтый
    resize_pane = { "RESIZE",  "#fab387" },  -- оранжевый
    copy_mode   = { "COPY",    "#89b4fa" },  -- синий
    search_mode = { "SEARCH",  "#a6e3a1" },  -- зелёный
}
local BADGE_GAP = "  "
local function badge_text(label) return "  ▶ " .. label .. "  ·  Esc выход  " end
local function workspace_text(name) return " " .. name .. " " end

local function update_right_status(window, _pane)
    -- pcall — на случай старого wezterm без active_key_table(): статус-бар
    -- не должен молча падать целиком.
    local ok, kt = pcall(function() return window:active_key_table() end)
    local m = (ok and kt) and MODE_BADGES[kt] or nil

    local elems = {}
    if m then
        table.insert(elems, { Background = { Color = m[2] } })
        table.insert(elems, { Foreground = { Color = "#1e1e2e" } })
        table.insert(elems, { Attribute = { Intense = true } })
        table.insert(elems, { Text = badge_text(m[1]) })
        table.insert(elems, "ResetAttributes")
        table.insert(elems, { Text = BADGE_GAP })
    end
    table.insert(elems, { Foreground = { Color = "#6c7086" } })
    table.insert(elems, { Text = workspace_text(window:active_workspace()) })
    window:set_right_status(wezterm.format(elems))
    window:set_left_status("")
end

-- Вкладки сужаются так, чтобы справа всегда оставалось место под самый
-- длинный бейдж (не текущий: здесь нет окна, и вкладки не прыгают при входе
-- в режим) и имя воркспейса. Ширина окна — по панелям активной вкладки,
-- поля окна не учтены (запас в пару знакомест). Только чистые вычисления.
local NEW_TAB_BUTTON_CELLS = 3  -- кнопка «+»
local MIN_TAB_TITLE_CELLS = 5   -- как у WezTerm по умолчанию

local function right_part_reserve(workspace)
    local widest = 0
    for _, m in pairs(MODE_BADGES) do
        widest = math.max(widest, wezterm.column_width(badge_text(m[1])))
    end
    return widest + wezterm.column_width(BADGE_GAP) + wezterm.column_width(workspace_text(workspace))
end

local function format_tab_title(tab, tabs, panes, _config, _hover, max_width)
    local title = tab.tab_title
    if not title or title == "" then title = tab.active_pane.title end
    local text = (" %d: %s "):format(tab.tab_index + 1, title)
    local pad = MIN_TAB_TITLE_CELLS - wezterm.column_width(text)
    if pad > 0 then text = text .. string.rep(" ", pad) end

    local cols = 0
    for _, p in ipairs(panes) do cols = math.max(cols, p.left + p.width) end
    local width = max_width
    if cols > 0 then
        local room = cols - NEW_TAB_BUTTON_CELLS - right_part_reserve(wezterm.mux.get_active_workspace())
        width = math.min(max_width, math.max(1, math.floor(room / #tabs)))
    end
    return wezterm.truncate_right(text, width)
end

-- =====================================================================
-- 5. ПРИВЯЗКИ ВНЕ РЕЖИМОВ — всё, что терминал перехватывает (WT-KEYS-3)
-- =====================================================================
-- Одна запись — одна строка map(key, mods, action, opts) с тегом spec.
-- Клавиши — через phys: (позиция на ANSI-US), поэтому одинаковы на любой
-- раскладке (WT-KEYS-2). Ctrl+<буква>, которых здесь нет, уходят в nvim как
-- есть; сочетания, оставленные nvim, не перехватываются (WT-KEYS-4).
-- opts.os — "windows" или "not_windows" (macOS и Linux), без него — везде.
-- opts.leaves_mode — сочетание открывает экран поверх панели: его копия в
-- таблицах режимов сначала выключает режим (WT-WIN-19).
local bindings = {}
local function map(key, mods, action, opts)
    opts = opts or {}
    table.insert(bindings, {
        key = key, mods = mods, action = action,
        os = opts.os, leaves_mode = opts.leaves_mode,
    })
end

-- --- Буфер обмена -------------------------------------------------------
map("phys:C", "CTRL", smart_copy, { os = "windows" })  -- spec: WT-CLIP-2
map("phys:C", "CTRL|SHIFT", copy_selection)  -- spec: WT-CLIP-4
map("Insert", "CTRL", copy_selection)  -- spec: WT-CLIP-4
map("phys:C", "SUPER", copy_selection, { os = "not_windows" })  -- spec: WT-CLIP-5
map("phys:V", "CTRL", act.PasteFrom("Clipboard"))  -- spec: WT-CLIP-6
map("phys:V", "CTRL|SHIFT", act.PasteFrom("Clipboard"))  -- spec: WT-CLIP-6
map("Insert", "SHIFT", act.PasteFrom("Clipboard"))  -- spec: WT-CLIP-6
map("phys:V", "SUPER", act.PasteFrom("Clipboard"), { os = "not_windows" })  -- spec: WT-CLIP-6

-- --- Клавиши для программы ------------------------------------------------
-- Ctrl+[ неотличим от Esc; шлём F13 — nvim вешает на него «сдвиг влево».
map("phys:LeftBracket", "CTRL", act.SendKey({ key = "F13" }))  -- spec: WT-KEYS-6
for _, c in ipairs(NVIM_CHORDS) do
    map(c[2], c[3], nvim_chord(c), { os = "windows" })  -- spec: WT-KEYS-10, WT-KBD-9
end

-- --- Окно и шрифт -----------------------------------------------------------
map("phys:S", "CTRL|SHIFT", save_window_size)  -- spec: WT-STATE-3
map("phys:S", "SUPER|SHIFT", save_window_size, { os = "not_windows" })  -- spec: WT-STATE-3
-- На Windows только Ctrl: Win+= — экранная лупа, Win+Shift+S — скриншот.
-- Перекрыты все дефолтные Increase/DecreaseFontSize, включая с Shift, иначе
-- они меняли бы масштаб мимо overrides. История: FIXLOG §50.
for _, f in ipairs({
    { "CTRL" }, { "SHIFT|CTRL" },
    { "SUPER", "not_windows" }, { "SHIFT|SUPER", "not_windows" },
}) do
    map("phys:Equal", f[1], change_font_size(1.1), { os = f[2] })  -- spec: WT-STATE-6
    map("phys:Minus", f[1], change_font_size(1 / 1.1), { os = f[2] })  -- spec: WT-STATE-6
    map("phys:0", f[1], change_font_size(nil), { os = f[2] })  -- spec: WT-STATE-7
end
map("phys:N", "CTRL|SHIFT", act.SpawnWindow)  -- spec: WT-PANE-7
map("phys:R", "CTRL|SHIFT", act.ReloadConfiguration)  -- spec: WT-LOAD-14

-- --- Панели и вкладки -------------------------------------------------------
map("phys:Space", "CTRL|SHIFT", act.ActivateKeyTable({  -- spec: WT-WIN-1, WT-WIN-3, WT-WIN-4
    name = "windows", one_shot = false, prevent_fallback = true,
    timeout_milliseconds = 5000,
}))
map("Enter", "CTRL|SHIFT", act.SplitPane({ direction = "Right" }))  -- spec: WT-PANE-1
map("Enter", "CTRL|SHIFT|ALT", act.SplitPane({ direction = "Down" }))  -- spec: WT-PANE-1
map("phys:Z", "CTRL|SHIFT", act.TogglePaneZoomState)  -- spec: WT-PANE-3
map("phys:W", "CTRL|SHIFT", act.CloseCurrentPane({ confirm = true }), { leaves_mode = true })  -- spec: WT-PANE-4
for _, d in ipairs({
    { "phys:H", "Left" }, { "phys:J", "Down" },
    { "phys:K", "Up" },   { "phys:L", "Right" },
    { "LeftArrow", "Left" }, { "DownArrow", "Down" },
    { "UpArrow", "Up" }, { "RightArrow", "Right" },
}) do
    map(d[1], "CTRL|SHIFT", act.ActivatePaneDirection(d[2]))  -- spec: WT-PANE-2
end
map("phys:T", "CTRL|SHIFT", act.SpawnTab("CurrentPaneDomain"))  -- spec: WT-PANE-5
map("PageDown", "CTRL|SHIFT", act.ActivateTabRelative(1))  -- spec: WT-PANE-6
map("PageUp", "CTRL|SHIFT", act.ActivateTabRelative(-1))  -- spec: WT-PANE-6
map("Tab", "CTRL", act.ActivateTabRelative(1))  -- spec: WT-KEYS-5, WT-PANE-6
map("Tab", "CTRL|SHIFT", act.ActivateTabRelative(-1))  -- spec: WT-KEYS-5, WT-PANE-6
for i = 1, 9 do
    map("phys:" .. i, "CTRL|SHIFT", act.ActivateTab(i - 1))  -- spec: WT-PANE-6
end

-- --- История -----------------------------------------------------------------
map("PageUp", "SHIFT", act.ScrollByPage(-1))  -- spec: WT-SCROLL-2
map("PageDown", "SHIFT", act.ScrollByPage(1))  -- spec: WT-SCROLL-2
map("phys:Delete", "CTRL|SHIFT", act.ClearScrollback("ScrollbackOnly"))  -- spec: WT-SCROLL-4
map("phys:X", "CTRL|SHIFT", act.ActivateCopyMode, { leaves_mode = true })  -- spec: WT-SCROLL-5
map("phys:U", "CTRL|SHIFT", act.QuickSelect, { leaves_mode = true })  -- spec: WT-SCROLL-12

-- --- macOS: системные Cmd-сочетания -----------------------------------------
map("phys:N", "SUPER", act.SpawnWindow, { os = "not_windows" })  -- spec: WT-PANE-8, WT-PANE-7
map("phys:T", "SUPER", act.SpawnTab("CurrentPaneDomain"), { os = "not_windows" })  -- spec: WT-PANE-8
map("phys:H", "SUPER", act.HideApplication, { os = "not_windows" })  -- spec: WT-PANE-8
map("phys:M", "SUPER", act.Hide, { os = "not_windows" })  -- spec: WT-PANE-8
map("phys:Q", "SUPER", act.QuitApplication, { os = "not_windows", leaves_mode = true })  -- spec: WT-PANE-8

-- =====================================================================
-- 6. ТАБЛИЦЫ РЕЖИМОВ
-- =====================================================================

-- --- WINDOWS и RESIZE: свои таблицы -----------------------------------------
-- Липкий модальный режим вместо tmux-леадера: вход Ctrl+Shift+Space (секция
-- 5), команды сериями на голых клавишах, Esc — выход. Клавиша без команды
-- проглатывается; сочетания терминала работают и в режиме — их копии
-- добавляет сборка (секция 7). Буквы — по логике vim: v = :vsplit, s = :split.
-- История: FIXLOG §47.
local mode_bindings = { windows = {}, resize_pane = {} }
local function mode_map(mode, key, mods, action)
    table.insert(mode_bindings[mode], { key = key, mods = mods, action = action })
end

-- Панели: переходы (остаёмся в режиме).
for _, d in ipairs({
    { "phys:H", "Left" }, { "phys:J", "Down" },
    { "phys:K", "Up" },   { "phys:L", "Right" },
    { "LeftArrow", "Left" }, { "DownArrow", "Down" },
    { "UpArrow", "Up" }, { "RightArrow", "Right" },
}) do
    mode_map("windows", d[1], "NONE", act.ActivatePaneDirection(d[2]))  -- spec: WT-WIN-5
end
mode_map("windows", "phys:O", "NONE", act.ActivatePaneDirection("Next"))  -- spec: WT-WIN-6
mode_map("windows", "phys:Q", "NONE", leave_mode(act.PaneSelect({ alphabet = "asdfghjkl" })))  -- spec: WT-WIN-7

-- Панели: сплиты, зум, закрытие.
mode_map("windows", "phys:V", "NONE", act.SplitPane({ direction = "Right" }))  -- spec: WT-WIN-8
mode_map("windows", "phys:S", "NONE", act.SplitPane({ direction = "Down" }))  -- spec: WT-WIN-8
mode_map("windows", "phys:Z", "NONE", act.TogglePaneZoomState)  -- spec: WT-WIN-9
mode_map("windows", "phys:X", "NONE", leave_mode(act.CloseCurrentPane({ confirm = true })))  -- spec: WT-WIN-10

-- Ресайз — подрежим, заменяющий WINDOWS: Esc и Enter из него ведут сразу к вводу.
mode_map("windows", "phys:R", "NONE", act.ActivateKeyTable({  -- spec: WT-WIN-11
    name = "resize_pane", one_shot = false, prevent_fallback = true,
    replace_current = true, timeout_milliseconds = 5000,
}))
mode_map("windows", "phys:A", "NONE", leave_mode(ready_layout))  -- spec: WT-WIN-12

-- Вкладки (остаёмся — листать и создавать сериями).
mode_map("windows", "phys:C", "NONE", act.SpawnTab("CurrentPaneDomain"))  -- spec: WT-WIN-13
mode_map("windows", "phys:N", "NONE", act.ActivateTabRelative(1))  -- spec: WT-WIN-13
mode_map("windows", "phys:P", "NONE", act.ActivateTabRelative(-1))  -- spec: WT-WIN-13
for i = 1, 9 do
    mode_map("windows", "phys:" .. i, "NONE", act.ActivateTab(i - 1))  -- spec: WT-WIN-13
end
mode_map("windows", "phys:Comma", "NONE", leave_mode(rename_tab))  -- spec: WT-WIN-14

-- Воркспейсы.
mode_map("windows", "phys:W", "NONE", leave_mode(act.ShowLauncherArgs({ flags = "FUZZY|TABS|WORKSPACES" })))  -- spec: WT-WIN-15
mode_map("windows", "phys:S", "SHIFT", leave_mode(new_workspace))  -- spec: WT-WIN-15

-- История и служебное.
mode_map("windows", "phys:LeftBracket", "NONE", leave_mode(act.ActivateCopyMode))  -- spec: WT-WIN-16
mode_map("windows", "phys:F", "NONE", leave_mode(act.Search({ CaseInSensitiveString = "" })))  -- spec: WT-WIN-16
mode_map("windows", "phys:Space", "NONE", leave_mode(act.QuickSelect))  -- spec: WT-WIN-16
mode_map("windows", "phys:B", "NONE", leave_mode(scrollback_to_nvim))  -- spec: WT-WIN-17
mode_map("windows", "phys:E", "NONE", leave_mode(act.CharSelect({ copy_on_select = true })))  -- spec: WT-WIN-18
mode_map("windows", "phys:Semicolon", "NONE", leave_mode(act.ActivateCommandPalette))  -- spec: WT-WIN-18
mode_map("windows", "phys:M", "NONE", leave_mode(act.ToggleFullScreen))  -- spec: WT-WIN-18
mode_map("windows", "phys:D", "NONE", leave_mode(act.ShowDebugOverlay))  -- spec: WT-WIN-18

-- Выход — только верхний слой; вход повторно — тумблер.
mode_map("windows", "Escape", "NONE", act.PopKeyTable)  -- spec: WT-WIN-2
mode_map("windows", "Enter", "NONE", act.PopKeyTable)  -- spec: WT-WIN-2
mode_map("windows", "phys:Space", "CTRL|SHIFT", act.PopKeyTable)  -- spec: WT-WIN-2

-- RESIZE.
for _, d in ipairs({
    { "phys:H", "Left" }, { "phys:J", "Down" },
    { "phys:K", "Up" },   { "phys:L", "Right" },
    { "LeftArrow", "Left" }, { "DownArrow", "Down" },
    { "UpArrow", "Up" }, { "RightArrow", "Right" },
}) do
    mode_map("resize_pane", d[1], "NONE", act.AdjustPaneSize({ d[2], 3 }))  -- spec: WT-WIN-11
end
mode_map("resize_pane", "Escape", "NONE", act.PopKeyTable)  -- spec: WT-WIN-11
mode_map("resize_pane", "Enter", "NONE", act.PopKeyTable)  -- spec: WT-WIN-11

-- --- copy_mode и search_mode: встроенные таблицы плюс замены -----------------
-- Встроенные таблицы берутся у WezTerm и переводятся на phys: (сборка).
-- Замена — пара (клавиша, модификаторы): есть в таблице — меняется её
-- действие (не дописывается вторая запись: при повторе WezTerm молча берёт
-- последнюю), нет — добавляется. История: FIXLOG §45, §46.
local mode_replacements = {}
local function mode_replace(mode, key, mods, action)
    table.insert(mode_replacements, { mode = mode, key = key, mods = mods, action = action })
end

-- В 20240203 из copy mode нет поиска — возвращаем vim-тройку.
mode_replace("copy_mode", "phys:Slash", "NONE", act.Search({ CaseInSensitiveString = "" }))  -- spec: WT-SCROLL-8
mode_replace("copy_mode", "phys:N", "NONE", act.CopyMode("NextMatch"))  -- spec: WT-SCROLL-8
mode_replace("copy_mode", "phys:N", "SHIFT", act.CopyMode("PriorMatch"))  -- spec: WT-SCROLL-8
-- Встроенный `y` — голый CopyTo: без выделения стёр бы буфер.
mode_replace("copy_mode", "phys:Y", "NONE", copy_selection_with(close_copy_mode, close_copy_mode))  -- spec: WT-SCROLL-7, WT-CLIP-1
-- Встроенный Enter — PriorMatch; Enter принимает шаблон, как после `/` в vim.
mode_replace("search_mode", "Enter", "NONE", act.CopyMode("AcceptPattern"))  -- spec: WT-SCROLL-10

-- =====================================================================
-- 7. СБОРКА
-- =====================================================================

-- Запись привязки для этой ОС?
local function for_platform(b, p)
    if b.os == nil then return true end
    if b.os == "windows" then return p.is_windows end
    if b.os == "not_windows" then return not p.is_windows end
    error(("map %s %s: неизвестное os = %s"):format(b.key, tostring(b.mods), tostring(b.os)))
end

-- WezTerm получает только key, mods и action: лишних полей в записи нет.
local function build_keys(list, p)
    local keys = {}
    for _, b in ipairs(list) do
        if for_platform(b, p) then
            table.insert(keys, { key = b.key, mods = b.mods, action = b.action })
        end
    end
    return keys
end

-- Пара (клавиша, модификаторы) — для сравнения записей: модификаторы как
-- множество, у Enter — синонимы встроенных таблиц.
local KEY_SYNONYMS = {
    Return = "Enter", ["mapped:\r"] = "Enter", ["mapped:Enter"] = "Enter", ["mapped:Return"] = "Enter",
}
local function binding_id(key, mods)
    local parts = {}
    for m in tostring(mods or "NONE"):gmatch("[^|]+") do
        if m ~= "NONE" then table.insert(parts, m) end
    end
    table.sort(parts)
    return (KEY_SYNONYMS[key] or key) .. " " .. table.concat(parts, "|")
end

-- --- Перевод встроенных таблиц на phys: (WT-SCROLL-6) -----------------------
-- WezTerm задаёт copy_mode/search_mode по символам, и на русской раскладке в
-- copy mode не работало бы ничего. Тонкость: заглавные записаны как key="G",
-- mods="NONE" (Shift подразумевается) — им явно дописывается SHIFT, иначе
-- phys:G перебил бы g. Знаки вроде $ и ^ — Shift+4 и Shift+6 — так же.
local PUNCT_TO_PHYS = {
    [","] = { "Comma" },       [";"] = { "Semicolon" },
    ["."] = { "Period" },      ["/"] = { "Slash" },
    ["?"] = { "Slash", true }, ["'"] = { "Quote" },
    ['"'] = { "Quote", true }, ["`"] = { "Grave" },
    ["-"] = { "Minus" },       ["="] = { "Equal" },
    ["["] = { "LeftBracket" }, ["]"] = { "RightBracket" },
    ["{"] = { "LeftBracket", true }, ["}"] = { "RightBracket", true },
    ["$"] = { "4", true },     ["^"] = { "6", true },
    ["%"] = { "5", true },     ["*"] = { "8", true },
    ["("] = { "9", true },     [")"] = { "0", true },
    ["<"] = { "Comma", true }, [">"] = { "Period", true },
    [":"] = { "Semicolon", true },
}

local function with_shift(mods)
    if mods == nil or mods == "" or mods == "NONE" then return "SHIFT" end
    if mods:find("SHIFT") then return mods end
    return mods .. "|SHIFT"
end

local function to_phys_binding(b)
    local key, mods = b.key, b.mods or "NONE"
    if type(key) ~= "string" then return b end
    if key:match("^phys:") then return b end
    -- Префикс "mapped:" — «по символу текущей раскладки»: снимаем.
    local raw = key:match("^mapped:(.+)$") or key
    if raw:match("^[A-Za-z]$") then
        if raw:match("^%u$") then mods = with_shift(mods) end
        return { key = "phys:" .. raw:upper(), mods = mods, action = b.action }
    end
    if raw:match("^%d$") then
        return { key = "phys:" .. raw, mods = mods, action = b.action }
    end
    local p = PUNCT_TO_PHYS[raw]
    if p then
        return {
            key = "phys:" .. p[1],
            mods = p[2] and with_shift(mods) or mods,
            action = b.action,
        }
    end
    -- Именованные клавиши (Escape, Enter, стрелки, F1…) от раскладки не зависят.
    return b
end

-- Замена в таблице режима (см. mode_replace).
local function apply_replacement(tbl, r)
    local id, found = binding_id(r.key, r.mods), 0
    for _, b in ipairs(tbl) do
        if binding_id(b.key, b.mods) == id then
            b.action = r.action
            found = found + 1
        end
    end
    if found == 0 then
        table.insert(tbl, { key = r.key, mods = r.mods, action = r.action })
    elseif found > 1 then
        wezterm.log_error(("%s: ожидалась одна запись %s, найдено %d"):format(r.mode, id, found))
    end
end

-- Таблица режима плюс копии сочетаний терминала (WT-WIN-4, WT-WIN-11): копия
-- выполняет то же действие и продлевает режим, помеченная leaves_mode сперва
-- выключает режим (WT-WIN-19). Пара, занятая командой режима, пропускается —
-- команда важнее (Ctrl+Shift+Space в WINDOWS — выход). Одна запись на пару
-- (WT-KEYS-8) — по построению.
local function with_terminal_bindings(mode, list, p)
    local out, taken = {}, {}
    for _, b in ipairs(mode) do
        table.insert(out, b)
        taken[binding_id(b.key, b.mods)] = true
    end
    for _, b in ipairs(list) do
        local id = binding_id(b.key, b.mods)
        if for_platform(b, p) and not taken[id] then
            taken[id] = true
            table.insert(out, {
                key = b.key, mods = b.mods,
                action = b.leaves_mode and leave_mode(b.action) or b.action,
            })
        end
    end
    return out
end

config.keys = build_keys(bindings, platform)

local key_tables = {}
-- pcall: wezterm.gui есть не во всех контекстах (mux-сервер). Без него
-- остаются встроенные таблицы WezTerm как есть, конфиг не падает.
local ok_tables, default_tables = pcall(function()
    return wezterm.gui.default_key_tables()
end)
if ok_tables and type(default_tables) == "table" then
    for name, binds in pairs(default_tables) do
        local converted = {}
        for _, b in ipairs(binds) do
            table.insert(converted, to_phys_binding(b))
        end
        key_tables[name] = converted
    end
end
local warned = {}
for _, r in ipairs(mode_replacements) do
    if key_tables[r.mode] then
        apply_replacement(key_tables[r.mode], r)
    elseif not warned[r.mode] then
        warned[r.mode] = true
        wezterm.log_warn(r.mode .. ": встроенной таблицы нет — остаётся таблица WezTerm")
    end
end
for _, name in ipairs({ "windows", "resize_pane" }) do
    key_tables[name] = with_terminal_bindings(mode_bindings[name], bindings, platform)
end
config.key_tables = key_tables

-- =====================================================================
-- 8. СОБЫТИЯ
-- =====================================================================
wezterm.on("window-config-reloaded", on_window_config_reloaded)  -- spec: WT-STATE-1, WT-STATE-2
wezterm.on("user-var-changed", on_user_var_changed)  -- spec: WT-KBD-9
wezterm.on("update-right-status", update_right_status)  -- spec: WT-UI-12, WT-UI-13
wezterm.on("format-tab-title", format_tab_title)  -- spec: WT-UI-15

return config
