-- Keyboard-layout aliases for shortcuts.
--
-- Goal: a shortcut typed on the same physical keys should work both on the
-- English QWERTY layout and on the Russian ЙЦУКЕН layout. For example:
--   <leader>md -> <leader>ьв
--   gd         -> пв
--   <C-S-d>    -> <C-S-в> when the terminal reports modified Cyrillic keys
--
-- This wraps vim.keymap.set early, so normal config maps and lazy.nvim key
-- trigger maps get aliases without duplicating every mapping by hand.

local M = {}

local en_to_ru = {
    ["`"] = "ё", ["~"] = "Ё",
    q = "й", w = "ц", e = "у", r = "к", t = "е", y = "н", u = "г", i = "ш", o = "щ", p = "з",
    Q = "Й", W = "Ц", E = "У", R = "К", T = "Е", Y = "Н", U = "Г", I = "Ш", O = "Щ", P = "З",
    ["["] = "х", ["]"] = "ъ", ["{"] = "Х", ["}"] = "Ъ",
    a = "ф", s = "ы", d = "в", f = "а", g = "п", h = "р", j = "о", k = "л", l = "д",
    A = "Ф", S = "Ы", D = "В", F = "А", G = "П", H = "Р", J = "О", K = "Л", L = "Д",
    [";"] = "ж", [":"] = "Ж", ["'"] = "э", ['"'] = "Э",
    z = "я", x = "ч", c = "с", v = "м", b = "и", n = "т", m = "ь",
    Z = "Я", X = "Ч", C = "С", V = "М", B = "И", N = "Т", M = "Ь",
    [","] = "б", ["."] = "ю", ["<"] = "Б", [">"] = "Ю", ["/"] = ".", ["?"] = ",",
}

local function translate_token(token)
    local body = token:sub(2, -2)
    local lower = body:lower()
    if lower == "leader" or lower == "localleader" or lower == "plug" then
        return token, false
    end

    local prefix, key = body:match("^(.*%-)([A-Za-z])$")
    if not prefix then
        return token, false
    end

    local mapped = en_to_ru[key]
    if not mapped then
        return token, false
    end
    return "<" .. prefix .. mapped .. ">", true
end

function M.translate_lhs(lhs)
    if type(lhs) ~= "string" or lhs == "" then return nil end
    if lhs:find("<Plug>", 1, true) or lhs:find("<plug>", 1, true) then return nil end

    local out = {}
    local changed = false
    local i = 1
    while i <= #lhs do
        local ch = lhs:sub(i, i)
        if ch == "<" then
            local close = lhs:find(">", i + 1, true)
            if close then
                local token = lhs:sub(i, close)
                local translated, token_changed = translate_token(token)
                out[#out + 1] = translated
                changed = changed or token_changed
                i = close + 1
            else
                local mapped = en_to_ru[ch] or ch
                out[#out + 1] = mapped
                changed = changed or mapped ~= ch
                i = i + 1
            end
        else
            local mapped = en_to_ru[ch] or ch
            out[#out + 1] = mapped
            changed = changed or mapped ~= ch
            i = i + 1
        end
    end

    if not changed then return nil end
    return table.concat(out)
end

function M.extend_mappings(mappings)
    for lhs, rhs in pairs(vim.deepcopy(mappings)) do
        local alias = M.translate_lhs(lhs)
        if alias and mappings[alias] == nil then
            mappings[alias] = rhs
        end
    end
    return mappings
end

local function langmap_escape(char)
    if char == "\\" or char == "," or char == ";" or char == '"' or char == "|" then
        return "\\" .. char
    end
    return char
end

function M.langmap()
    local items = {}
    for en, ru in pairs(en_to_ru) do
        -- Only non-ASCII Russian chars are safe here. ASCII chars produced by
        -- the Russian number row, like ":" for physical Shift+6, cannot be
        -- distinguished from the same char typed on the English layout.
        if #ru > 1 then
            items[#items + 1] = langmap_escape(ru) .. langmap_escape(en)
        end
    end
    table.sort(items)
    return table.concat(items, ",")
end

local installed = false

function M.setup()
    if installed then return end
    installed = true

    local original_set = vim.keymap.set
    local in_alias = false

    vim.keymap.set = function(mode, lhs, rhs, opts)
        local result = original_set(mode, lhs, rhs, opts)

        if in_alias then return result end
        local alias = M.translate_lhs(lhs)
        if not alias or alias == lhs then return result end

        local alias_opts = opts
        if type(opts) == "table" then
            alias_opts = vim.deepcopy(opts)
        end

        in_alias = true
        pcall(original_set, mode, alias, rhs, alias_opts)
        in_alias = false

        return result
    end
end

return M
