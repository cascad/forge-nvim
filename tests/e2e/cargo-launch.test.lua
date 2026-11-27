local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
package.path = root .. '/tests/lib/?.lua;' .. package.path
local T = require('check')

T.check('F5 on Cargo.toml builds and launches a selected workspace example', function()
  local editor
  local ok, err = xpcall(function()
    editor = require('rust_project').start(root, function(e) editor = e end)
    editor:input(':edit Cargo.toml<CR>')
    editor:wait('workspace manifest active', function() return editor:current_file() == editor.rust_project .. '/Cargo.toml' end)
    editor:input('<F5>')
    editor:wait('workspace binaries and examples appear together', function()
      local screen = table.concat(editor.rpc:screen_lines(), '\n')
      return screen:find('forge_app / example', 1, true) and screen:find('forge_app / alternate', 1, true)
        and not screen:find('Current Rust file', 1, true) and editor:current_ft() == 'TelescopePrompt'
    end)
    editor:input('example')
    editor:wait('example selected', function()
      return editor:lua([[local e=require('telescope.actions.state').get_selected_entry()
        return e and e.ordinal:find('forge_app / example',1,true) ~= nil]])
    end)
    editor:input('<CR>')
    editor:wait('selected example actually printed its result', function()
      for _, line in ipairs(editor.rpc:screen_lines()) do
        if line:find('RUST_EXAMPLE 42', 1, true) then return true end
      end
    end, 60000)
    editor:wait('the launched example exited', function()
      return editor:lua("return require('dap').session()==nil")
    end)
    editor:input('<F7>:edit Cargo.toml<CR>')
    editor:wait('manifest active with previous output', function()
      return editor:current_file() == editor.rust_project .. '/Cargo.toml'
    end)
    editor:input('<F5>')
    editor:wait('F5 reopens target selection with previous output visible', function()
      return editor:current_ft() == 'TelescopePrompt'
    end)
    editor:input('<Esc>')
    editor:wait('cancelling leaves the manifest active and debugger idle', function()
      return editor:current_ft() == 'toml' and editor:lua("return require('dap').session()==nil")
    end)
  end, debug.traceback)
  if editor then
    editor:snapshot('cargo-launch')
    io.stdout:write('  artifacts: ' .. editor.dir .. '\n')
    editor:stop(not ok and err or nil)
  end
  assert(ok, err)
end)

T.finish()
