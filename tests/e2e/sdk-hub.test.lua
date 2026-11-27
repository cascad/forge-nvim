-- Выбор реального компилятора или интерпретатора через меню в изолированном проекте.
local root = vim.fs.normalize(vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h'))
package.path = root .. '/tests/lib/?.lua;' .. package.path
local T = require('check')

local function prompt(e)
  e:wait('next SDK picker', function()
    return e:current_ft() == 'TelescopePrompt'
      and e.rpc:request('nvim_get_mode', {}).mode == 'i'
      and e:lua('return vim.api.nvim_get_current_buf()') ~= e.last_sdk_prompt
  end, 30000)
end

local function select_item(e, label)
  prompt(e)
  e:input(label)
  e:wait('selected ' .. label, function()
    return e:lua([[local entry = require('telescope.actions.state').get_selected_entry()
      return entry and entry.ordinal:find(..., 1, true) ~= nil]], {label})
  end)
  e.last_sdk_prompt = e:lua('return vim.api.nvim_get_current_buf()')
  e:input('<CR>')
end

local function open_sdk(e, kind, title)
  e:input(' lS')
  select_item(e, title)
  select_item(e, 'Выбрать SDK')
  if kind == 'python' then select_item(e, 'python') end
  select_item(e, 'project')
  prompt(e)
end

local function read(path)
  return vim.json.decode(table.concat(vim.fn.readfile(path), '\n'))
end

local function sdk_environment(kind)
  local bin
  if kind == 'rust' then
    local deps = vim.env.FORGE_E2E_RUST_DEPS or root .. '/.tests/rust-deps'
    bin = read(deps .. '/manifest.json').sysroot .. '/bin'
  elseif kind == 'node' then
    local deps = vim.env.FORGE_E2E_NODE_DEPS or root .. '/.tests/node-deps'
    bin = vim.fs.dirname(vim.fs.joinpath(deps, read(deps .. '/manifest.json').node))
  elseif kind == 'python' then
    local deps = vim.env.FORGE_E2E_PYTHON_DEPS or root .. '/.tests/python-deps'
    bin = vim.fs.dirname(vim.fs.joinpath(deps, read(deps .. '/manifest.json').tools_python))
  else
    local deps = vim.env.FORGE_E2E_DAP_TOOLS or root .. '/.tests/dap-tools'
    bin = deps .. '/go/bin'
  end
  return {PATH=bin .. (vim.fn.has('win32') == 1 and ';' or ':') .. vim.env.PATH,
    RUSTUP_AUTO_INSTALL='0', GOTOOLCHAIN='local'}
end

for _, spec in ipairs({{'go','Go'}, {'rust','Rust'}, {'python','Python'}, {'node','JS / Node'}}) do
  local kind, title = unpack(spec)
  local runtime = kind == 'python' or kind == 'node'
  local id = runtime and 'IDE-BOOT-38' or 'IDE-BOOT-37'
  T.check(id .. ' SDK hub: select installed ' .. title .. ' for project and cancel on reopen', function()
    local e
    local ok, err = xpcall(function()
      e = require('editor').start(root, {env=sdk_environment(kind)})
      e:input(':edit sdk-note.txt<CR>iunsaved note<Esc>')
      e:wait('unsaved document', function() return e:lua('return vim.bo.modified') end)
      local code = e:lua('return vim.api.nvim_get_current_win()')
      open_sdk(e, kind, title)
      local sdk
      e:wait('discovered executable in ' .. title .. ' picker', function()
        sdk = e:lua([[local picker = require('telescope.actions.state').get_current_picker(vim.api.nvim_get_current_buf())
          for entry in picker.manager:iter() do
            local item = entry.value.text
            local exe = item.label:match(' | (.-) | ')
            if exe and vim.fn.executable(exe) == 1 then return {path=item.value, exe=exe} end
          end]])
        return type(sdk) == 'table'
      end, 30000)
      select_item(e, sdk.exe)
      select_item(e, 'Сохранить для следующ')
      local file = e.project .. (runtime and '/.fride/tools.json' or '/.fride/sdk.json')
      local field = runtime and 'tools' or 'sdks'
      e:wait('project choice saved', function() return read(file)[field][kind] == sdk.path end)
      local saved = read(file)
      open_sdk(e, kind, title)
      e:input('<Esc><Esc>')
      e:wait('back to unsaved document', function()
        return e:lua('return vim.api.nvim_get_current_win()') == code and e:lua('return vim.bo.modified')
      end)
      T.eq(e:lua('return vim.api.nvim_get_current_line()'), 'unsaved note')
      T.eq(read(file), saved)
    end, debug.traceback)
    if e then e:stop(not ok and err or nil) end
    assert(ok, err)
  end)
end
T.finish()
