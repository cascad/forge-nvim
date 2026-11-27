local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
package.path = root .. '/tests/lib/?.lua;' .. package.path
local T = require('check')

T.check('F5 offers only launch.json on Cargo.toml and adds current-file actions on Rust source', function()
  local editor
  local ok, err = xpcall(function()
    editor = require('rust_project').start(root, function(e) editor = e end)
    local function open(path)
      editor:input(':edit ' .. path .. '<CR>')
      editor:wait(path .. ' active', function() return editor:current_file() == editor.rust_project .. '/' .. path end)
    end
    local function check_choices(expected)
      editor:input('<F5>')
      editor:wait('F5 picker ready', function()
        return editor:current_ft() == 'TelescopePrompt' and editor:lua([[local p=require('telescope.actions.state').get_current_picker(vim.api.nvim_get_current_buf())
          return p.manager and p.manager:num_results() > 0 and vim.api.nvim_get_mode().mode == 'i']])
      end)
      local rows = editor:lua([[local p=require('telescope.actions.state').get_current_picker(vim.api.nvim_get_current_buf())
        local rows={}; for entry in p.manager:iter() do rows[#rows+1]=entry.ordinal end; return rows]])
      table.sort(rows)
      table.sort(expected)
      T.eq(rows, expected, 'all choices shown by F5')
    end
    local function no_targets()
      local before = #editor.rpc.notifications
      editor:input('<F5>')
      editor:wait('empty launcher explains how to add a target', function()
        for i = before + 1, #editor.rpc.notifications do
          if editor.rpc.notifications[i].message:find('.vscode/launch.json', 1, true) then return true end
        end
      end)
      T.eq(editor:current_ft(), 'toml')
      T.eq(editor:lua("return require('dap').session()==nil"), true)
    end

    open('Cargo.toml')
    local launch_json = editor.rust_project .. '/.vscode/launch.json'
    assert(vim.fn.filereadable(launch_json) == 0)
    no_targets()
    local config = {
      name = 'Configured alternate', type = 'codelldb', request = 'launch',
      cwd = editor.rust_project .. '/app', program = editor.rust_target .. '/debug/alternate' .. editor.rust_suffix,
      preLaunchTask = 'cargo build (debug)', args = { 'from-config' }, console = 'integratedTerminal',
    }
    vim.fn.writefile({vim.json.encode({version='0.2.0', configurations={config}})}, launch_json)
    local configured = 'Configured alternate  [codelldb]  <launch.json>'
    open('app/src/main.rs')
    check_choices({configured, 'Current Rust file bin  [codelldb]  <current file>',
      'Current Rust file bin (args)  [codelldb]  <current file>'})
    editor:input('<Esc>')
    editor:wait('cancel returns to Rust', function() return editor:current_ft() == 'rust' end)

    open('Cargo.toml')
    check_choices({configured})
    editor:input('<CR>')
    editor:wait('explicit launch runs the configured program with its argument', function()
      for _, line in ipairs(editor.rpc:screen_lines()) do
        if line:find('RUST_ALTERNATE 42 from-config', 1, true) then return true end
      end
    end, 60000)
    editor:wait('the configured program exited', function()
      return editor:lua("return require('dap').session()==nil")
    end)
    editor:input('<F7>:edit Cargo.toml<CR>')
    editor:wait('manifest active with previous output', function()
      return editor:current_file() == editor.rust_project .. '/Cargo.toml'
    end)
    vim.fn.writefile({'{"configurations":[]}'}, launch_json)
    no_targets()
  end, debug.traceback)
  if editor then
    editor:snapshot('cargo-launch')
    io.stdout:write('  artifacts: ' .. editor.dir .. '\n')
    editor:stop(not ok and err or nil)
  end
  assert(ok, err)
end)

T.finish()
