-- Сочетания WezTerm в записи nvim и каноническая запись nvim (add-wezterm-spec-checks,
-- design, решение 6; межслойная проверка WT-KEYS-4, WT-KEYS-6, WT-KEYS-7).
--
--   local KN = require('keynames')
--   KN.wezterm_lhs('phys:F', 'CTRL|SHIFT')   --> '<C-S-f>'
--   KN.canon('<C-S-f>')                      --> '<C-S-F>'  (как nvim хранит lhs привязки)
--   KN.from_wezterm('phys:LeftBracket', 'CTRL')  --> '<C-[>'
--   KN.split('<Space>f<C-V>')                --> { '<Space>', 'f', '<C-V>' }
--
-- Перевод WezTerm → nvim — таблица имён:
--   * `phys:` — по раскладке US-ANSI (позиция клавиши = символ английской
--     раскладки); имена PhysKeyCode WezTerm 20240203 (wezterm-input-types/src/lib.rs);
--   * именованные клавиши — имена nvim (`Enter` → `<CR>`, `LeftArrow` → `<Left>`, …);
--   * модификаторы: CTRL → C, SHIFT → S, ALT → A, SUPER → D (синонимы WezTerm
--     CMD/WIN = SUPER, OPT/META = ALT — как F.norm_mods подделки).
--
-- Каноническая запись — lhs, под которым nvim хранит привязку (поле `lhs` у
-- nvim_get_keymap, это keytrans НЕупрощённых кодов `lhsraw`). Отклонение от
-- design, решение 6 (там `keytrans(keycode(lhs))`): vim.keycode упрощает
-- сочетания до другой клавиши, и разные сочетания сливаются. Проба на
-- Neovim 0.12.2, 2026-09-27:
--   keytrans(keycode('<C-[>'))   = '<Esc>'   а lhs привязки '<C-[>'   = '<C-[>'
--   keytrans(keycode('<C-S-j>')) = '<S-NL>'  а lhs привязки '<C-S-j>' = '<C-S-J>'
--   keytrans(keycode('<C-j>'))   = '<NL>'    а lhs привязки '<C-j>'   = '<C-J>'
-- С упрощением Ctrl+[ из WezTerm совпал бы с привязкой nvim_forge на клавишу
-- Esc, хотя это разные клавиши (WT-KEYS-6: Esc WezTerm не трогает). Таблица
-- привязок nvim их различает, её запись и берётся.
--
-- Нужен запущенный nvim (API привязок): модуль работает под `nvim -l`.

local M = {}

-- Позиции US-ANSI, у которых символ не совпадает с именем PhysKeyCode.
-- Значение — символ английской раскладки или имя клавиши nvim.
M.PHYS = {
  Equal = '=', Minus = '-', LeftBracket = '[', RightBracket = ']', Backslash = '\\',
  Semicolon = ';', Quote = "'", Grave = '`', Comma = ',', Period = '.', Slash = '/',
  Space = '<Space>', Return = '<CR>', Enter = '<CR>', Tab = '<Tab>', Escape = '<Esc>',
  Backspace = '<BS>', Delete = '<Del>', Insert = '<Insert>', Home = '<Home>', End = '<End>',
  PageUp = '<PageUp>', PageDown = '<PageDown>', LeftArrow = '<Left>', RightArrow = '<Right>',
  UpArrow = '<Up>', DownArrow = '<Down>',
}

-- Именованные клавиши WezTerm без префикса (KeyCode: Enter|Return, Tab, Escape,
-- Backspace, Delete, Insert, Home, End, PageUp, PageDown, стрелки; F1…F24 — ниже).
M.NAMED = {
  Enter = '<CR>', Return = '<CR>', Tab = '<Tab>', Escape = '<Esc>', Backspace = '<BS>',
  Delete = '<Del>', Insert = '<Insert>', Home = '<Home>', End = '<End>',
  PageUp = '<PageUp>', PageDown = '<PageDown>', LeftArrow = '<Left>', RightArrow = '<Right>',
  UpArrow = '<Up>', DownArrow = '<Down>', Space = '<Space>',
}

-- Модификатор WezTerm → буква nvim. Порядок в записи — C, S, A, D (nvim
-- канонизирует порядок сам, см. canon).
M.MODS = { CTRL = 'C', SHIFT = 'S', ALT = 'A', SUPER = 'D' }
local MOD_ALIAS = { CMD = 'SUPER', WIN = 'SUPER', OPT = 'ALT', META = 'ALT' }
local MOD_ORDER = { 'CTRL', 'SHIFT', 'ALT', 'SUPER' }

-- Символы, которые внутри <…> или отдельно пишутся именем.
local CHAR_NAME = { ['<'] = 'lt', ['\\'] = 'Bslash', ['|'] = 'Bar', [' '] = 'Space' }

--- Клавиша WezTerm → основа записи nvim: один символ ('f', '[', '2') или имя в
--- скобках ('<CR>', '<F5>'). Неизвестное имя — nil и причина.
local function base_key(key)
  if type(key) ~= 'string' or key == '' then return nil, 'клавиша не строка: ' .. tostring(key) end
  local phys = key:match('^phys:(.+)$')
  local name = phys or key:match('^mapped:(.+)$') or key
  if name:match('^F%d%d?$') then return '<' .. name .. '>' end
  if phys then
    if name:match('^%a$') then return name:lower() end
    if name:match('^%d$') then return name end
    local v = M.PHYS[name]
    if v then return v end
    return nil, 'неизвестная физическая клавиша ' .. key
  end
  if M.NAMED[name] then return M.NAMED[name] end
  if vim.fn.strchars(name) == 1 then
    if name == ' ' then return '<Space>' end
    return name
  end
  return nil, 'неизвестная клавиша ' .. key
end

--- Модификаторы WezTerm ('CTRL|SHIFT', nil, 'NONE') → список букв nvim по порядку C, S, A, D.
local function mod_letters(mods)
  local set = {}
  for part in tostring(mods or ''):gmatch('[^|]+') do
    part = vim.trim(part)
    part = MOD_ALIAS[part] or part
    if part ~= '' and part ~= 'NONE' then
      if not M.MODS[part] then return nil, 'неизвестный модификатор ' .. part end
      set[part] = true
    end
  end
  local out = {}
  for _, m in ipairs(MOD_ORDER) do
    if set[m] then out[#out + 1] = M.MODS[m] end
  end
  return out
end

--- Запись nvim для сочетания WezTerm (без канонизации): ('phys:F', 'CTRL|SHIFT') → '<C-S-f>'.
--- Неизвестная клавиша или модификатор — nil и причина.
function M.wezterm_lhs(key, mods)
  local base, err = base_key(key)
  if not base then return nil, err end
  local letters, merr = mod_letters(mods)
  if not letters then return nil, merr end
  if #letters == 0 then
    if #base == 1 and CHAR_NAME[base] then return '<' .. CHAR_NAME[base] .. '>' end
    return base
  end
  local inner = base:match('^<(.+)>$') or CHAR_NAME[base] or base
  return '<' .. table.concat(letters, '-') .. '-' .. inner .. '>'
end

-- Буфер-черновик для канонизации: одна временная привязка за раз.
local scratch

--- Каноническая запись lhs — как её хранит таблица привязок nvim (см. шапку).
--- `<leader>` раскрывается по текущему g:mapleader. Ошибка разбора — error.
function M.canon(lhs)
  if type(lhs) ~= 'string' or lhs == '' then error('keynames.canon: пустой lhs', 2) end
  if not (scratch and vim.api.nvim_buf_is_valid(scratch)) then
    scratch = vim.api.nvim_create_buf(false, true)
  end
  vim.api.nvim_buf_set_keymap(scratch, 'n', lhs, '', {})
  local maps = vim.api.nvim_buf_get_keymap(scratch, 'n')
  local out = maps[1] and maps[1].lhs
  pcall(vim.api.nvim_buf_del_keymap, scratch, 'n', lhs)
  if #maps ~= 1 or not out then
    error(('keynames.canon: для %q ожидалась одна привязка, получено %d'):format(lhs, #maps), 2)
  end
  return out
end

--- Каноническая запись nvim для сочетания WezTerm. Неизвестная клавиша — nil и причина.
function M.from_wezterm(key, mods)
  local lhs, err = M.wezterm_lhs(key, mods)
  if not lhs then return nil, err end
  return M.canon(lhs)
end

--- Каноническую запись — на клавиши: '<Space>f<C-V>' → { '<Space>', 'f', '<C-V>' }.
--- В канонической записи символ '<' всегда '<lt>', поэтому '<' открывает имя.
function M.split(lhs)
  local out, i, n = {}, 1, #lhs
  while i <= n do
    local c = lhs:sub(i, i)
    local close = c == '<' and lhs:find('>', i + 1, true)
    if close then
      out[#out + 1] = lhs:sub(i, close)
      i = close + 1
    else
      local len = vim.str_utf_end(lhs, i) + 1
      out[#out + 1] = lhs:sub(i, i + len - 1)
      i = i + len
    end
  end
  return out
end

return M
