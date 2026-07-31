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

-- macOS: не отдавать Ctrl-комбинации системному IME.
-- macos_forward_to_ime_modifier_mask по умолчанию равен "SHIFT|CTRL", то
-- есть нажатия с Ctrl сначала уходят в IME. При не-латинском источнике
-- ввода (в системе включён RussianWin) IME может съесть такое событие, и
-- до сопоставления с config.keys оно не доходит. Под удар попадает в
-- первую очередь LEADER (Ctrl+Shift+Space) и весь слой Ctrl+Shift ниже.
-- Оставляем в маске только SHIFT: Ctrl идёт напрямую в WezTerm, а обычный
-- ввод и композиция через IME работают как раньше.
-- Это профилактика, а не лечение конкретного бага: сломанный Cmd+C
-- ломался по другой причине — см. disable_default_key_bindings ниже.
if not is_windows then
    config.macos_forward_to_ime_modifier_mask = "SHIFT"
end

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

-- Панель вкладок. Держим ВСЕГДА видимой (тонкую, без "fancy"): теперь это
-- не только вкладки, но и индикатор LEADER + имя воркспейса (см. секцию
-- мультиплексора внизу файла). Без неё не видно, взведён ли префикс.
-- Не нужна — верни `true`, всё остальное продолжит работать.
config.hide_tab_bar_if_only_one_tab = false
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.tab_max_width = 24

-- Неактивные панели слегка притушены, чтобы фокус читался с одного взгляда.
-- Значения мягкие: текст в фоновой панели остаётся читаемым.
config.inactive_pane_hsb = { saturation = 0.85, brightness = 0.75 }

-- =====================================================================
-- Copy / Paste
-- =====================================================================
local act = wezterm.action

-- ВСЕ ВСТРОЕННЫЕ ХОТКЕИ WEZTERM ОТКЛЮЧЕНЫ — это принципиально.
-- Дефолты WezTerm заданы ПО СИМВОЛУ, а не по позиции клавиши, поэтому они
-- срабатывают только на английской раскладке и молча пропадают на русской:
-- ровно та разница в поведении, которой тут быть не должно. Хуже того, часть
-- из них перехватывала клавиши у Neovim (и тоже только на англ.):
--   Ctrl+Shift+F  — забирал Search у панели поиска nvim (<C-S-f>)
--   Ctrl+Shift+P  — забирал палитру у Telescope (<C-S-p>)
--   Ctrl+PageUp/PageDown — забирали переключение буферов nvim
--   Alt+Enter     — забирал <A-CR>
-- Поэтому: дефолты выключены целиком, а всё нужное ниже переопределено
-- через phys: (позиция клавиши). Итог — один и тот же набор хоткеев на
-- Windows и macOS, на английской и русской раскладке, и ничего не
-- утекает мимо Neovim незаметно.
-- Мышь это не затрагивает: за неё отвечает отдельный
-- disable_default_mouse_bindings, он остаётся выключенным — выделение,
-- копирование по выделению и клик по ссылкам работают как раньше.
-- Режимы copy_mode и search_mode тоже сохраняются: они живут в отдельных
-- key_tables и этим флагом не сбрасываются.
config.disable_default_key_bindings = true

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

-- "Умный" Ctrl+C — ТОЛЬКО ДЛЯ WINDOWS (навешивается ниже под if is_windows).
-- Там нет Cmd, поэтому одна и та же клавиша обязана делать два дела: если
-- есть выделение мышью/клавиатурой → копируем и снимаем выделение; если
-- выделения нет → шлём Ctrl+C в программу как обычный SIGINT.
-- На macOS копирование системное (Cmd+C), и совмещать не нужно: там Ctrl+C
-- вообще не перехватывается и всегда работает как чистое прерывание.
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

-- Ctrl+C вешаем только на Windows (см. smart_copy выше). На macOS клавиша
-- остаётся неперехваченной и уходит в программу как 0x03 → SIGINT.
if is_windows then
    table.insert(config.keys, { key = "phys:C", mods = "CTRL", action = smart_copy })
end

-- Шрифт: Cmd+=/− (мак) и Ctrl+=/− (вин/линукс) — крупнее/мельче,
-- Cmd/Ctrl+0 — сброс к сохранённому/дефолту. Перекрываем ВСЕ дефолтные
-- комбинации Increase/DecreaseFontSize (включая шифтованные «+»), иначе
-- часть из них меняла бы внутренний масштаб мимо overrides и Ctrl+Shift+S
-- сохранял бы не тот размер (см. change_font_size выше).
-- Клавиши заданы через phys: (позиция на клавиатуре), а не символом. По
-- символу «=» на русской раскладке ловилось бы не всегда, а вариант «+»
-- (Shift+=) вообще уехал бы: на RussianWin Shift над цифрами даёт другие
-- знаки. С phys:Equal + модификатором SHIFT комбинация одна и та же на
-- любой раскладке, поэтому отдельная строка на «+» больше не нужна.
for _, mods in ipairs({ "SUPER", "CTRL", "SHIFT|SUPER", "SHIFT|CTRL" }) do
    table.insert(config.keys, { key = "phys:Equal", mods = mods, action = change_font_size(1.1) })
    table.insert(config.keys, { key = "phys:Minus", mods = mods, action = change_font_size(1 / 1.1) })
    table.insert(config.keys, { key = "phys:0", mods = mods, action = change_font_size(nil) })
end

-- На macOS дублируем сохранение размера окна на привычный Cmd+Shift+S
-- (SUPER = Cmd). На Windows такой бинд не вешаем: Win+Shift+S занят
-- системным скриншотом.
if not is_windows then
    table.insert(config.keys,
        { key = "phys:S", mods = "SUPER|SHIFT", action = save_window_size })
end

-- =====================================================================
-- МУЛЬТИПЛЕКСОР: панели, вкладки, воркспейсы (вместо tmux)
-- =====================================================================
-- ПОЧЕМУ НЕ tmux/zellij: оба нативно живут только под Unix. На Windows
-- tmux работает лишь внутри WSL — а тогда nvim_forge.cmd, pwsh и нативные
-- тулзы остаются "снаружи", и хоткеи на маке и винде расходятся. У WezTerm
-- мультиплексор встроенный, и ЭТОТ файл — единственный источник хоткеев,
-- поэтому на обеих ОС они буквально одни и те же.
--
-- МОДЕЛЬ РОВНО КАК В tmux: есть LEADER (аналог Ctrl+B) — Ctrl+Shift+Space.
-- Нажал leader, отпустил, нажал команду. Пока префикс взведён, в панели
-- вкладок горит жёлтый "LEADER". Смысл в том, что у Neovim отбирается одна
-- комбинация, а не десяток.
--
-- Буквы команд — по логике vim, а не tmux: v = :vsplit, s = :split.
--
-- Прямые дубли (без leader) навешены только на то, что жмётся постоянно.
-- Они выбраны из комбинаций, которых НЕТ в nvim_forge: Ctrl+Shift+{B,D,E,
-- F,J,P} и Ctrl+Shift+F5 заняты Neovim, C/V/S — выше в этом файле.
-- Всё, что WezTerm перехватил, до Neovim уже не долетит — поэтому список
-- прямых биндингов держим коротким.
--
-- Про cwd: новая панель наследует каталог текущей только если шелл шлёт
-- OSC 7. У zsh/bash это даёт shell-integration WezTerm, у pwsh — строчка
-- в профиле. Без неё панель откроется в домашнем каталоге.

config.leader = {
    key = "phys:Space",
    mods = "CTRL|SHIFT",
    timeout_milliseconds = 2000,
}

local function map(key, mods, action)
    table.insert(config.keys, { key = key, mods = mods, action = action })
end

-- --- Панели: создать / убить -----------------------------------------
map("phys:V", "LEADER", act.SplitPane({ direction = "Right" }))  -- :vsplit
map("phys:S", "LEADER", act.SplitPane({ direction = "Down" }))   -- :split
map("phys:X", "LEADER", act.CloseCurrentPane({ confirm = true }))
map("phys:Z", "LEADER", act.TogglePaneZoomState)

-- Самое частое — "дай вторую консоль рядом" — без leader, одной рукой.
map("Enter", "CTRL|SHIFT", act.SplitPane({ direction = "Right" }))
map("Enter", "CTRL|SHIFT|ALT", act.SplitPane({ direction = "Down" }))
map("phys:Z", "CTRL|SHIFT", act.TogglePaneZoomState)
map("phys:W", "CTRL|SHIFT", act.CloseCurrentPane({ confirm = true }))

-- --- Панели: переходы -------------------------------------------------
local dirs = {
    { "phys:H", "LeftArrow",  "Left" },
    { "phys:J", "DownArrow",  "Down" },
    { "phys:K", "UpArrow",    "Up" },
    { "phys:L", "RightArrow", "Right" },
}
for _, d in ipairs(dirs) do
    local letter, arrow, dir = d[1], d[2], d[3]
    map(letter, "LEADER", act.ActivatePaneDirection(dir))
    map(arrow, "LEADER", act.ActivatePaneDirection(dir))
    map(arrow, "CTRL|SHIFT", act.ActivatePaneDirection(dir))
end
-- o — по кругу (tmux); q — показать буквы на панелях и прыгнуть в любую.
map("phys:O", "LEADER", act.RotatePanes("Clockwise"))
map("phys:Q", "LEADER", act.PaneSelect({ alphabet = "asdfghjkl" }))

-- --- Панели: ресайз ---------------------------------------------------
-- LEADER r → залипающий режим: жми стрелки/hjkl сколько нужно, Esc — выход.
-- Это key_table с one_shot = false, аналог tmux resize-pane -Z … по нажатию.
map("phys:R", "LEADER", act.ActivateKeyTable({ name = "resize_pane", one_shot = false }))

-- ВСТРОЕННЫЕ ТАБЛИЦЫ copy_mode / search_mode — ТОЖЕ НА ПОЗИЦИИ КЛАВИШ.
-- WezTerm задаёт их по символам (h, j, k, l, y, G, $, /), поэтому на
-- русской раскладке внутри copy mode не работало бы вообще ничего.
-- Берём дефолтные таблицы и механически переписываем символьные клавиши
-- на phys:. Тонкость, из-за которой нельзя конвертировать «в лоб»:
-- заглавные записаны как key="G", mods="NONE" — то есть подразумевают
-- Shift. Если просто сделать phys:G, то сработает обычная «g», и G (в
-- конец буфера) перебьёт g (в начало). Поэтому заглавным явно дописываем
-- SHIFT. Знаки вроде $ и ^ — это Shift+4 и Shift+6, их разворачиваем так же.
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
    -- Уже привязано к позиции — не трогаем.
    if key:match("^phys:") then return b end

    -- Дефолтные таблицы приходят с префиксом "mapped:" — это и есть
    -- «сопоставлять по символу текущей раскладки», ровно то, что нам мешает.
    -- Снимаем префикс и смотрим на сам символ.
    local raw = key:match("^mapped:(.+)$") or key

    -- Одиночная латинская буква: a → phys:A, G → phys:G + SHIFT.
    if raw:match("^[A-Za-z]$") then
        if raw:match("^%u$") then mods = with_shift(mods) end
        return { key = "phys:" .. raw:upper(), mods = mods, action = b.action }
    end
    -- Цифра: позиция та же, но пусть будет единообразно.
    if raw:match("^%d$") then
        return { key = "phys:" .. raw, mods = mods, action = b.action }
    end
    -- Знаки препинания по таблице выше.
    local p = PUNCT_TO_PHYS[raw]
    if p then
        return {
            key = "phys:" .. p[1],
            mods = p[2] and with_shift(mods) or mods,
            action = b.action,
        }
    end
    -- Всё остальное — именованные клавиши (Escape, Enter, PageUp, стрелки,
    -- Space, F1…). Они и так не зависят от раскладки, не трогаем.
    return b
end

config.key_tables = {}
-- pcall: wezterm.gui доступен не во всех контекстах (например, в
-- mux-сервере). Если API нет — просто остаёмся на дефолтных таблицах,
-- конфиг от этого не падает.
local ok_tables, default_tables = pcall(function()
    return wezterm.gui.default_key_tables()
end)
if ok_tables and type(default_tables) == "table" then
    for name, binds in pairs(default_tables) do
        local converted = {}
        for _, b in ipairs(binds) do
            table.insert(converted, to_phys_binding(b))
        end
        config.key_tables[name] = converted
    end
end

-- В ЭТОЙ ВЕРСИИ WezTerm В copy_mode НЕТ ПОИСКА — он вынесен в отдельный
-- режим (search_mode) и из copy mode никак не вызывается. Для vim-навигации
-- по выводу это дыра: без «/» половина смысла теряется. Добавляем привычную
-- тройку. act.Search открывает search_mode: набрал шаблон → Enter вернёт в
-- copy mode на совпадении, дальше n/N прыгают по ним.
if config.key_tables.copy_mode then
    local cm = config.key_tables.copy_mode
    table.insert(cm, {
        key = "phys:Slash", mods = "NONE",
        action = act.Search({ CaseInSensitiveString = "" }),
    })
    table.insert(cm, { key = "phys:N", mods = "NONE", action = act.CopyMode("NextMatch") })
    table.insert(cm, { key = "phys:N", mods = "SHIFT", action = act.CopyMode("PriorMatch") })
end

config.key_tables.resize_pane = {
        { key = "phys:H",     action = act.AdjustPaneSize({ "Left", 3 }) },
        { key = "phys:J",     action = act.AdjustPaneSize({ "Down", 3 }) },
        { key = "phys:K",     action = act.AdjustPaneSize({ "Up", 3 }) },
        { key = "phys:L",     action = act.AdjustPaneSize({ "Right", 3 }) },
        { key = "LeftArrow",  action = act.AdjustPaneSize({ "Left", 3 }) },
        { key = "DownArrow",  action = act.AdjustPaneSize({ "Down", 3 }) },
        { key = "UpArrow",    action = act.AdjustPaneSize({ "Up", 3 }) },
        { key = "RightArrow", action = act.AdjustPaneSize({ "Right", 3 }) },
    { key = "Escape",     action = "PopKeyTable" },
    { key = "Enter",      action = "PopKeyTable" },
}

-- --- Готовая раскладка под задачу «nvim + тестовые консоли» ------------
-- LEADER a: текущая панель (там forge-nvim) остаётся слева и широкой,
-- справа появляются две консоли столбиком. Фокус возвращается в nvim.
map("phys:A", "LEADER", wezterm.action_callback(function(_window, pane)
    local right = pane:split({ direction = "Right", size = 0.35 })
    right:split({ direction = "Bottom", size = 0.5 })
    pane:activate()
end))

-- --- Вкладки ----------------------------------------------------------
map("phys:C", "LEADER", act.SpawnTab("CurrentPaneDomain"))
map("phys:N", "LEADER", act.ActivateTabRelative(1))
map("phys:P", "LEADER", act.ActivateTabRelative(-1))
map("phys:T", "CTRL|SHIFT", act.SpawnTab("CurrentPaneDomain"))
map("PageDown", "CTRL|SHIFT", act.ActivateTabRelative(1))
map("PageUp", "CTRL|SHIFT", act.ActivateTabRelative(-1))
-- Ctrl+Tab / Ctrl+Shift+Tab — привычное «как везде» переключение вкладок.
-- Отдаём терминалу осознанно: Neovim крутит буферы на <Tab>/<S-Tab> БЕЗ
-- Ctrl, а <C-Tab> в nvim_forge не занят ничем. Голый <Tab> мы не трогаем,
-- он уходит в nvim как раньше. Клавиша именованная, а не символьная,
-- поэтому от раскладки не зависит.
-- Захочешь вернуть <C-Tab> в Neovim — удали эти две строки.
map("Tab", "CTRL", act.ActivateTabRelative(1))
map("Tab", "CTRL|SHIFT", act.ActivateTabRelative(-1))
-- phys:1..9 — по позиции клавиши. Через символ Ctrl+Shift+2 на русской
-- раскладке пришёл бы как «"», а на английской как «@» — и биндинг
-- разъехался бы между раскладками.
for i = 1, 9 do
    map("phys:" .. i, "LEADER", act.ActivateTab(i - 1))
    map("phys:" .. i, "CTRL|SHIFT", act.ActivateTab(i - 1))
end
-- Переименовать вкладку. phys:Comma, потому что на русской раскладке эта
-- клавиша печатает «б» — по символу биндинг бы не поймался.
map("phys:Comma", "LEADER", act.PromptInputLine({
    description = "Имя вкладки:",
    action = wezterm.action_callback(function(window, _pane, line)
        if line and line ~= "" then
            window:active_tab():set_title(line)
        end
    end),
}))

-- --- Воркспейсы (аналог сессий tmux) ----------------------------------
-- Набор вкладок/панелей под задачу; переключение мгновенное, состояние
-- каждого воркспейса живёт своей жизнью.
map("phys:W", "LEADER", act.ShowLauncherArgs({ flags = "FUZZY|TABS|WORKSPACES" }))
map("phys:S", "LEADER|SHIFT", act.PromptInputLine({
    description = "Новый/существующий воркспейс:",
    action = wezterm.action_callback(function(window, pane, line)
        if line and line ~= "" then
            window:perform_action(act.SwitchToWorkspace({ name = line }), pane)
        end
    end),
}))

-- --- Скроллбэк: чтение и поиск ---------------------------------------
-- QuickSelect (подсветить на экране пути/URL/хеши буквами и скопировать
-- одной клавишей) по умолчанию висел на Ctrl+Shift+Space — а эту комбинацию
-- забрал LEADER. Возвращаем на свободный Ctrl+Shift+U и дублируем в leader.
map("phys:U", "CTRL|SHIFT", act.QuickSelect)
map("phys:Space", "LEADER", act.QuickSelect)
-- LEADER [ — copy mode: hjkl/стрелки для навигации по истории, v — выделить,
-- y — скопировать, Esc — выход. Ровно как copy-mode-vi в tmux.
map("phys:LeftBracket", "LEADER", act.ActivateCopyMode)
map("phys:F", "LEADER", act.Search({ CaseInSensitiveString = "" }))

-- LEADER b — ВЕСЬ вывод панели уходит в файл и открывается в nvim новой
-- вкладкой, курсор в конце. Дальше это обычный Neovim: /поиск, n/N, gg/G,
-- визуальный режим, y в системный буфер, :w для сохранения куска.
-- Возврат к вводу — просто :q, вкладка закроется и ты снова в консоли.
-- Приём штатный, описан в документации WezTerm (docs/scrollback.md):
-- get_lines_as_text + SpawnCommandInNewTab.
--
-- Запускаем ГОЛЫЙ nvim, а не nvim_forge.sh/.cmd: для чтения вывода нужен
-- мгновенный старт, а не полная IDE с LSP и плагинами. Захочешь форж —
-- поменяй args на путь до nvim_forge.sh (мак) / nvim_forge.cmd (винда).
--
-- Файл один и тот же, каждый раз перезаписывается. Лежит в хомяке рядом
-- с .wezterm_forge_window.json — в репо ничего не попадает. Учти, что в
-- нём остаётся последний вывод консоли: если там мелькали токены/пароли,
-- удали файл руками.
local scrollback_file = (wezterm.home_dir or os.getenv("USERPROFILE") or ".")
    .. "/.wezterm_scrollback.txt"

map("phys:B", "LEADER", wezterm.action_callback(function(window, pane)
    local text = pane:get_lines_as_text(pane:get_dimensions().scrollback_rows)
    -- get_lines_as_text отдаёт и незанятую часть экрана — это хвост из
    -- пустых строк, из-за него курсор в конце файла оказывается в пустоте.
    text = text:gsub("%s+$", "\n")
    local f = io.open(scrollback_file, "w")
    if not f then
        window:toast_notification("WezTerm",
            "Не удалось записать " .. scrollback_file, nil, 3000)
        return
    end
    f:write(text)
    f:close()
    -- «+» без числа — открыть на последней строке, т.е. на свежем выводе.
    window:perform_action(
        act.SpawnCommandInNewTab({ args = { "nvim", "+", scrollback_file } }),
        pane)
end))

-- --- Возврат полезных дефолтов, теперь через phys: ---------------------
-- Всё, что WezTerm давал «из коробки» и что стоит сохранить. Переписано на
-- позиции клавиш, поэтому одинаково работает на любой раскладке.
-- НЕ возвращены намеренно (их забирает Neovim, см. комментарий выше):
-- Ctrl+Shift+F, Ctrl+Shift+P, Ctrl+PageUp/PageDown, Ctrl+Tab, Alt+Enter.
map("phys:K", "CTRL|SHIFT", act.ClearScrollback("ScrollbackOnly"))
map("phys:L", "CTRL|SHIFT", act.ShowDebugOverlay)
map("phys:R", "CTRL|SHIFT", act.ReloadConfiguration)
map("phys:N", "CTRL|SHIFT", act.SpawnWindow)
map("phys:X", "CTRL|SHIFT", act.ActivateCopyMode)
map("PageUp", "SHIFT", act.ScrollByPage(-1))
map("PageDown", "SHIFT", act.ScrollByPage(1))

-- Дефолты, которые висели на Alt+Enter / Ctrl+Shift+P / Ctrl+Shift+U —
-- переехали под LEADER, чтобы не отнимать комбинации у Neovim.
map("phys:M", "LEADER", act.ToggleFullScreen)
map("phys:Semicolon", "LEADER", act.ActivateCommandPalette)  -- аналог prefix+: в tmux
map("phys:E", "LEADER", act.CharSelect({ copy_on_select = true }))

-- macOS: системные Cmd-комбинации, которые там ожидаются на уровне ОС.
-- На Windows их нет — кросс-платформенный набор целиком живёт на Ctrl/LEADER,
-- так что это только удобство мака, а не отдельная «маковая раскладка».
if not is_windows then
    map("phys:C", "SUPER", act.CopyTo("Clipboard"))
    map("phys:V", "SUPER", act.PasteFrom("Clipboard"))
    map("phys:N", "SUPER", act.SpawnWindow)
    map("phys:T", "SUPER", act.SpawnTab("CurrentPaneDomain"))
    map("phys:H", "SUPER", act.HideApplication)
    map("phys:M", "SUPER", act.Hide)
    map("phys:Q", "SUPER", act.QuitApplication)
end

-- --- Индикатор LEADER + воркспейс в панели вкладок --------------------
wezterm.on("update-right-status", function(window, _pane)
    local leader = window:leader_is_active()
    local text = " " .. window:active_workspace() .. " "
    if leader then
        text = " LEADER  " .. text
    end
    window:set_right_status(wezterm.format({
        { Foreground = { Color = leader and "#f9e2af" or "#6c7086" } },
        { Text = text },
    }))
end)

return config
