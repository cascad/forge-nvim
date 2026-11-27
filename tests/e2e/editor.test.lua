local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
package.path = root .. '/tests/lib/?.lua;' .. package.path
local T = require('check')
local editor
local core_steps = {}

local function start_editor()
  editor = require('editor').start(root)
  T.eq(editor:lua('return package.loaded["ide"] ~= nil'), true)
  T.eq(editor:lua('return vim.v.errmsg'), '')
  -- Реальный RPC nil — vim.NIL: ожидание не должно принимать его за готовность.
  editor:lua('_G.forge_e2e_ready=nil')
  local ready
  editor:wait('RPC-состояние действительно готово', function()
    ready = editor:lua('return _G.forge_e2e_ready')
    if ready == vim.NIL then editor:lua('_G.forge_e2e_ready=true') end
    return ready
  end)
  T.eq(ready, true)
  local server=editor:lua('return vim.v.servername')
  assert(server~='', 'Native Neovim RPC address is empty; inspect nvim.log')
  local channel=vim.fn.sockconnect('pipe',server,{rpc=true})
  assert(channel>0, 'Cannot connect to native Neovim at '..server)
  local pid=vim.rpcrequest(channel,'nvim_exec_lua','return vim.uv.os_getpid()',{})
  vim.fn.chanclose(channel)
  T.eq(pid,editor:lua('return vim.uv.os_getpid()'))
end
T.check('SELF: EDITOR-STARTUP настоящий nvim_forge и pinned плагины', start_editor)

local function scenario(name, fn)
  local requirement = name:match('^IDE%-BOOT%-') ~= nil
  if not requirement then core_steps[#core_steps + 1] = fn end
  T.check((requirement and '' or 'SELF: ') .. name, function()
    local ok, err = pcall(function()
      -- --id пропускает SELF-случаи. Для выбранного требования те же
      -- пользовательские действия нужны как Given, без ложных отдельных PASS.
      if requirement and T.filter and not editor then
        start_editor()
        for _, step in ipairs(core_steps) do step() end
      end
      assert(editor, 'Предыдущий запуск редактора не удался')
      fn()
    end)
    if not ok then
      if editor then
        editor:snapshot(name)
        editor:input('<Esc><Esc><F7>')
      end
      error(err)
    end
  end)
end

scenario('EDITOR-FILE открыть, изменить и сохранить через ввод', function()
  editor:input(':edit file_one.txt<CR>')
  editor:wait('file_one открыт', function() return editor:current_file():match('/file_one.txt$') end)
  editor:input('Goadded from e2e<Esc><C-s>')
  editor:wait('изменение записано на диск', function()
    return table.concat(vim.fn.readfile(editor.project .. '/file_one.txt'), '\n'):find('added from e2e', 1, true) ~= nil
  end)
end)

scenario('EDITOR-TREE открыть дерево и выбрать файл', function()
  editor:input(' e')
  editor:wait('Neo-tree виден', function() return editor:has_window('neo-tree') end)
  editor:wait('Фокус в Neo-tree', function() return editor:current_ft() == 'neo-tree' end)
  local line
  editor:wait('дерево закончило чтение каталога', function()
    line = editor:lua([[for i,s in ipairs(vim.api.nvim_buf_get_lines(0,0,-1,false)) do if s:find('file_two.txt',1,true) then return i end end; return 0]])
    return line > 0
  end)
  editor:input('gg' .. string.rep('j', line - 1) .. '<CR>')
  editor:wait('выбранный файл открыт в коде', function() return editor:current_file():match('/file_two.txt$') end)
end)

scenario('EDITOR-FIND поиск имени через Telescope', function()
  editor:input('<C-p>')
  editor:wait('Telescope prompt готов к вводу', function() return editor:current_ft() == 'TelescopePrompt' and editor:lua('return vim.api.nvim_get_mode().mode') == 'i' end)
  editor:input('file_one.txt')
  editor:wait('результат поиска имени', function()
    return editor:lua([[for _,b in ipairs(vim.api.nvim_list_bufs()) do if vim.bo[b].filetype=='TelescopeResults' then for _,s in ipairs(vim.api.nvim_buf_get_lines(b,0,-1,false)) do if s:find('file_one.txt',1,true) then return true end end end end; return false]])
  end)
  editor:wait('выбран результат имени', function()
    return editor:lua("return require('telescope.actions.state').get_selected_entry() ~= nil")
  end)
  editor:input('<CR>')
  editor:wait('переход к найденному файлу', function() return editor:current_file():match('/file_one.txt$') end)
end)

scenario('EDITOR-GREP поиск содержимого через настоящий rg', function()
  editor:input(' fg')
  editor:wait('live_grep prompt готов к вводу', function() return editor:current_ft() == 'TelescopePrompt' and editor:lua('return vim.api.nvim_get_mode().mode') == 'i' end)
  editor:input('NEEDLE_FORGE_E2E')
  editor:wait('результат поиска содержимого', function()
    return editor:lua([[for _,b in ipairs(vim.api.nvim_list_bufs()) do if vim.bo[b].filetype=='TelescopeResults' then for _,s in ipairs(vim.api.nvim_buf_get_lines(b,0,-1,false)) do if s:find('NEEDLE_FORGE_E2E',1,true) then return true end end end end; return false]])
  end)
  editor:wait('выбран результат содержимого', function()
    return editor:lua("return require('telescope.actions.state').get_selected_entry() ~= nil")
  end)
  editor:input('<CR>')
  editor:wait('переход к найденной строке', function() return editor:current_file():match('/file_one.txt$') and editor:current_ft() ~= 'TelescopePrompt' end)
  T.eq(editor:lua('return vim.api.nvim_win_get_cursor(0)[1]'), 2)
end)

scenario('EDITOR-BUFFERS следующий файл и закрытие буфера', function()
  editor:input(' bn')
  editor:wait('следующий файл', function() return editor:current_file():match('/file_two.txt$') end)
  editor:input(' bd')
  editor:wait('возврат к оставшемуся файлу', function() return editor:current_file():match('/file_one.txt$') end)
end)

scenario('EDITOR-FOCUS панель и возврат в код через F6/F7', function()
  if not editor:has_window('neo-tree') then
    editor:input(' e')
    editor:wait('открытая панель получила фокус', function() return editor:current_ft() == 'neo-tree' end)
    editor:input('<F7>')
  end
  editor:wait('фокус в коде', function() return editor:current_file():match('/file_one.txt$') end)
  editor:input('<F6>')
  editor:wait('фокус в панели', function() return editor:current_ft() == 'neo-tree' end)
  editor:input('<F7>')
  editor:wait('фокус вернулся в код', function() return editor:current_file():match('/file_one.txt$') end)
end)

scenario('IDE-BOOT-1 обычная работа не запускает скачивание инструментов', function()
  editor:wait('окно наблюдения после VeryLazy (старый таймер 3000 мс)', function() return editor:lua('return _G.forge_e2e_observed == true') end, 6000)
  T.eq(editor:lua('return vim.g.forge_e2e_installs'), 0)
  local spawns = editor:lua('return _G.forge_e2e_spawns')
  for _, process in ipairs(spawns) do
    local cmd = process.cmd:gsub('\\', '/'):lower():match('([^/]+)$')
    assert(not cmd:match('^curl') and not cmd:match('^wget'),
      'Неявная загрузка при работе редактора: ' .. vim.inspect(process))
  end
  assert(not editor:lua("return vim.fn.execute('messages')"):find('Downloading tree%-sitter'), 'Treesitter скачивает парсеры при запуске')
  T.eq(editor:lua("return vim.fn.exists(':ForgeTreesitterInstall')"), 2)
  T.eq(editor:lua("return vim.fn.exists(':MasonToolsInstall')"), 2)
  T.eq(editor:lua("return vim.fn.exists(':MasonToolsInstallSync')"), 2)
end)

scenario('IDE-BOOT-2 обычные файлы не вызывают предупреждение чужого LSP', function()
  for _, item in ipairs(editor:lua('return vim.g.forge_e2e_notifications')) do
    assert(not item.message:find('gopls не найден', 1, true), 'Go LSP предупреждает при работе с .txt')
  end
end)

scenario('EDITOR-COMMENT Cmd+/ comments and uncomments lines through the editor mapping', function()
  local first, second = 'local first = 1', 'local second = 2'
  assert(vim.fn.writefile({first, second, 'return first + second'}, editor.project .. '/comment.lua') == 0)
  editor:input(':edit comment.lua<CR>')
  editor:wait('Lua file opened', function() return editor:current_file():match('/comment.lua$') end)
  local function lines_are(a, b)
    return function()
      local lines = editor:lua('return vim.api.nvim_buf_get_lines(0,0,2,false)')
      return lines[1] == a and lines[2] == b
    end
  end
  editor:input('gg<D-/>')
  editor:wait('Cmd+/ comments the current line', lines_are('-- ' .. first, second))
  editor:input('<D-/>')
  editor:wait('Cmd+/ uncomments the current line', lines_are(first, second))
  editor:input('ggVj<D-/>')
  editor:wait('Cmd+/ comments the selection', lines_are('-- ' .. first, '-- ' .. second))
  editor:input('gg0i<D-/>')
  editor:wait('Cmd+/ uncomments while staying in Insert mode', function()
    return lines_are(first, '-- ' .. second)() and editor:lua('return vim.api.nvim_get_mode().mode') == 'i'
  end)
  editor:input('<Esc>:edit! file_one.txt<CR>')
  editor:wait('comment test returned to the original file', function()
    return editor:current_file():match('/file_one.txt$')
  end)
end)

scenario('EDITOR-ERRORS нет ошибок конфигурации после UIEnter и действий', function()
  for _, item in ipairs(editor:lua('return vim.g.forge_e2e_notifications')) do
    assert(item.level < vim.log.levels.ERROR, item.message)
  end
  local messages = editor:lua("return vim.fn.execute('messages')")
  assert(not messages:find('Failed to run `config`', 1, true), messages)
  assert(not messages:find('E5113', 1, true), messages)
end)

if vim.fn.has('macunix') == 1 then
  scenario('MAC-INPUT Cyrillic and US keyboard layouts drive Normal motions, Ex and Insert', function()
    editor:input(':enew<CR>')
    editor:wait('empty document for keyboard motions', function()
      return editor:lua('return vim.api.nvim_buf_get_name(0) == ""')
    end)
    local result = editor:lua([=[
      local ffi = require('ffi')
      ffi.cdef[[
        const void *TISCreateInputSourceList(const void *, unsigned char);
        extern const void *kTISPropertyInputSourceID;
        long CFArrayGetCount(const void *);
        const void *CFArrayGetValueAtIndex(const void *, long);
        const void *CFRetain(const void *);
        unsigned char CFStringGetCString(const void *, char *, long, uint32_t);
      ]]
      local carbon = ffi.load('/System/Library/Frameworks/Carbon.framework/Carbon')
      local cf = ffi.load('/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation')
      local selected
      local layout = require('config.macos_layout')
      layout.reader()()  -- exercise the active system source without selecting one
      local reader = layout.reader(function()
        return ffi.cast('void *', cf.CFRetain(selected))
      end)
      local sources = ffi.gc(carbon.TISCreateInputSourceList(nil, 1), cf.CFRelease)
      local by_id = {}
      for i = 0, tonumber(cf.CFArrayGetCount(sources)) - 1 do
        local source = ffi.cast('void *', cf.CFArrayGetValueAtIndex(sources, i))
        local id = carbon.TISGetInputSourceProperty(source, carbon.kTISPropertyInputSourceID)
        local buf = ffi.new('char[256]')
        if id ~= nil and cf.CFStringGetCString(id, buf, 256, 0x08000100) ~= 0 then
          by_id[ffi.string(buf)] = source
        end
      end
      -- Borrowed sources are retained by the captured array throughout the test.
      _G.forge_layout_for_test = function(id)
        assert(sources ~= nil)
        selected = assert(by_id['com.apple.keylayout.' .. id], id)
      end
      _G.forge_layout_for_test('RussianWin')
      local symbols = reader()
      require('config.ru_keys').follow_layout(reader)
      return {symbols[':'], symbols[';']}
    ]=])
    T.eq(result, {'^', '$'})
    editor:input('i   first line<Esc>0:')
    editor:wait('Russian Shift+6 moves to first nonblank', function()
      return editor:lua('return vim.fn.col(".")') == 4
    end)
    editor:input(';')
    editor:wait('Russian Shift+4 moves to line end', function()
      return editor:lua('return vim.fn.col(".") == vim.fn.col("$") - 1')
    end)
    editor:input('Aтекст:;<Esc>')
    editor:wait('Russian punctuation stays literal in Insert', function()
      return editor:lua('return vim.api.nvim_get_current_line():sub(-#"текст:;") == "текст:;"')
    end)
    editor:lua([[_G.forge_layout_for_test('US')]])
    editor:input(':let g:forge_english_colon = 1<CR>')
    editor:wait('English colon opens Ex after layout switch', function()
      return editor:lua('return vim.g.forge_english_colon') == 1
    end)
  end)
end

if editor then
  io.stdout:write('  artifacts: ' .. editor.dir .. '\n')
  editor:stop()
end

local function real(path)
  return assert(vim.uv.fs_realpath(path), path):gsub('\\', '/')
end

local function check_launcher(contract)
  local tui
  local ok, issue = xpcall(function()
    tui = require('session_tui').start(root, { launcher = contract.launcher, prepare = function(project)
      for _, name in ipairs({ 'Project A ü', 'Project B ü' }) do
        local nested = project .. '/' .. name .. '/nested'
        vim.fn.mkdir(nested, 'p')
        assert(vim.fn.writefile({ 'Nested project file | ' .. name }, nested .. '/nested.txt') == 0)
      end
    end })
    if not contract.revision then
      -- An existing checkout may have current plugin revisions with old or
      -- missing backports. Exercise the launcher against that private cache.
      local namespace = vim.fn.has('win32') == 1 and 'nvim_forge-data' or 'nvim_forge'
      local lazy_root = tui.host.runtime .. '/data/' .. namespace .. '/lazy'
      local backports = dofile(root .. '/nvim_forge/lua/ide/backports.lua')
      for _, plugin in ipairs({ 'neo-tree.nvim', 'gitsigns.nvim', 'neotest' }) do
        local dir = lazy_root .. '/' .. plugin
        backports.run(plugin, dir, 'revert')
        local prepared, issue = pcall(backports.run, plugin, dir, 'check')
        assert(not prepared and tostring(issue):find('не подготовлен', 1, true), tostring(issue))
      end
    end
    local host = tui.host
    host:lua([[
      vim.api.nvim_create_autocmd('TermRequest', { callback = function(ev)
        local flag = ev.data.sequence:match('1337;SetUserVar=FORGE_NVIM=([%w+/=]*)')
        if flag then vim.g.forge_test_pane_flag = flag end
      end })
    ]])
    tui:launch()
    local launch = tui:lua([[local expected=vim.uv.fs_realpath(...)
      local config
      for _,script in ipairs(vim.fn.getscriptinfo()) do
        if vim.uv.fs_realpath(script.name)==expected then config=script.name;break end
      end
      return { config=config, executable=vim.v.progpath, version=tostring(vim.version()),
        namespace=vim.env.NVIM_APPNAME, cwd=vim.fn.getcwd(), data=vim.fn.stdpath('data') }]], { contract.config })
    launch.revision = contract.revision
    vim.fn.writefile({ vim.json.encode(launch) }, host.dir .. '/public-launch.json')
    T.eq(real(assert(launch.config, 'Expected init.lua was not sourced')), real(contract.config))
    T.eq(real(launch.executable), real(contract.runtime))
    T.eq(launch.namespace, contract.namespace)
    T.eq(real(launch.cwd), real(tui.a))
    local data_home = contract.data_home or host.runtime .. '/data'
    local namespace = contract.namespace .. (vim.fn.has('win32') == 1 and '-data' or '')
    T.eq(real(launch.data), real(data_home .. '/' .. namespace))
    local backports = tui:lua([[return require('ide.backports').all(vim.fn.stdpath('data')..'/lazy','check')]])
    vim.fn.writefile({ vim.json.encode(backports) }, host.dir .. '/public-launch-backports.json')

    local function row_for(name)
      return tui:lua([[if vim.bo.filetype~='neo-tree' then return false end
      for i,line in ipairs(vim.api.nvim_buf_get_lines(0,0,-1,false)) do
        if line:find(...,1,true) then return i end
      end; return false]], { name })
    end
    local function check_ui()
      local state = tui:state()
      T.eq(state.installs, 0)
      assert(#state.ui > 0 and not state.mode.blocking, 'Real TUI is not ready')
      assert(not state.messages:match('E%d%d%d+:') and not state.messages:find('Failed to run ',1,true),
        state.messages)
      for _, notice in ipairs(state.notices) do
        assert(notice.level < vim.log.levels.ERROR, notice.message)
      end
    end

    local function open_from_files(project, context)
      local row
      host:wait(context .. ': Files has focus and shows the nested folder', function()
        row = row_for('nested')
        return row
      end)
      tui:send(tostring(row) .. 'G')
      -- Session restore may already have expanded the directory.
      if row_for('nested.txt') then
        tui:send('h')
        host:wait(context .. ': h collapses the restored branch', function()
          return row_for('nested') and not row_for('nested.txt')
        end)
      end
      for _, keys in ipairs({ { 'l', 'h' }, { 'д', 'р' } }) do
        tui:send(keys[1])
        host:wait(context .. ': ' .. keys[1] .. ' expands the branch', function()
          return row_for('nested.txt')
        end)
        tui:send(keys[2])
        host:wait(context .. ': ' .. keys[2] .. ' collapses the branch', function()
          return row_for('nested') and not row_for('nested.txt')
        end)
      end
      tui:send('l')
      host:wait(context .. ': nested file is visible', function()
        row = row_for('nested.txt')
        return row
      end)
      tui:send(tostring(row) .. 'Gl')
      host:wait(context .. ': l opens the selected project file in code', function()
        return tui:state().file == project .. '/nested/nested.txt'
      end)
      T.eq(tui:lua('return vim.api.nvim_get_current_line()'), 'Nested project file | ' .. vim.fs.basename(project))
      check_ui()
    end

    open_from_files(tui.a, 'Directory launch')

    if not contract.revision then
      -- Use the bytes sent by the macOS terminal profile, including a filetype
      -- whose optional parser has never been installed.
      tui:command('edit comment.sh')
      tui:send('iecho ok\27')
      host:wait('shell buffer ready', function()
        return tui:lua('return vim.bo.filetype') == 'sh' and tui:mode().mode == 'n'
      end)
      tui:lua([[vim.treesitter.language.register('forge_missing_shell_parser', 'sh')
        assert(vim.treesitter.get_parser(0) == nil)]])
      tui:send('\27[47;9u')
      host:wait('physical Cmd+/ comments a shell line', function()
        return tui:lua('return vim.api.nvim_get_current_line()') == '# echo ok'
      end)
      tui:send('\27[47;5u')
      host:wait('physical Ctrl+/ uncomments the same line', function()
        return tui:lua('return vim.api.nvim_get_current_line()') == 'echo ok'
      end)
      host:wait('fride advertised its keyboard transport to the terminal', function()
        return host:lua('return vim.g.forge_test_pane_flag') == vim.base64.encode('1')
      end)
      require('bootstrap')
      local wez = require('fake_wezterm')
      local function press(os, physical, mods)
        local keys = wez.load_config({triple = wez.TRIPLES[os]}).config.keys
        local binding = assert(wez.find_binding(keys, physical, mods))
        local window = wez.window()
        local version = vim.base64.decode(host:lua('return vim.g.forge_test_pane_flag'))
        wez.run_callback(binding.action, window, wez.pane({user_vars={FORGE_NVIM=version}}))
        local action = assert(window.performed[1])
        T.eq(action.name, 'SendString')
        tui:send(action.args[1])
      end
      tui:command('edit! comment.py')
      tui:send('iprint(1)\rprint(2)\27')
      host:wait('Python buffer ready', function()
        return tui:lua('return vim.bo.filetype') == 'python' and tui:mode().mode == 'n'
      end)
      tui:send('gg')
      press('macos', 'phys:Slash', 'SUPER')
      host:wait('Cmd+/ comments only the current Python line', function()
        return vim.deep_equal(tui:lua('return vim.api.nvim_buf_get_lines(0,0,-1,false)'), {'# print(1)', 'print(2)'})
      end)
      press('windows', 'phys:Slash', 'CTRL')
      host:wait('Ctrl+/ restores the current Python line via the Windows profile', function()
        return tui:lua('return vim.api.nvim_get_current_line()') == 'print(1)'
      end)
      tui:send('ggVj')
      press('macos', 'phys:Slash', 'SUPER')
      host:wait('Cmd+/ comments both selected Python lines', function()
        return vim.deep_equal(tui:lua('return vim.api.nvim_buf_get_lines(0,0,-1,false)'), {'# print(1)', '# print(2)'})
      end)
      tui:send('ggVj')
      press('macos', 'phys:Slash', 'SUPER')
      host:wait('Cmd+/ restores both Python lines', function()
        return vim.deep_equal(tui:lua('return vim.api.nvim_buf_get_lines(0,0,-1,false)'), {'print(1)', 'print(2)'})
      end)
      tui:command('write')
      press('macos', 'phys:W', 'SUPER')
      host:wait('Cmd+W closes the Python tab', function() return not tui:state().file:match('comment%.py$') end)
      tui:send(' wt')
      host:wait('lowercase wt opens Tests from checkout', function() return tui:lua('return vim.bo.filetype') == 'neotest-summary' end)
      tui:send('q')
      host:wait('q returns to the editor', function() return tui:lua('return vim.bo.buftype') == '' end)
      tui:command('edit nested/nested.txt')
      host:wait('restorable project document selected', function() return tui:state().file == tui.a .. '/nested/nested.txt' end)
      check_ui()
      -- Prepare only on-disk recent entries in this test's private profile.
      -- The dashboard, picker, project switch, and restore all run through input.
      tui:quit()
      local history = launch.data .. '/project_nvim'
      vim.fn.mkdir(history, 'p')
      assert(vim.fn.writefile({ tui.a, tui.b }, history .. '/project_history') == 0)

      local function select_recent(keys, query, project)
        local pid = tui:state().pid
        tui:send(keys)
        host:wait('Recent Projects picker from ' .. keys, function()
          return tui:mode().mode == 'i' and tui:lua('return vim.bo.filetype') == 'TelescopePrompt'
        end)
        tui:send(query)
        host:wait('Named project selected: ' .. query, function()
          local path = tui:lua([[local entry=require('telescope.actions.state').get_selected_entry()
            return entry and entry.value or false]])
          return path and real(path) == real(project)
        end)
        tui:send('\r')
        tui:connect(pid)
        host:wait('Requested project has opened: ' .. query, function()
          return real(tui:state().cwd) == real(project)
        end)
      end

      tui:launch(true)
      host:wait('fride without arguments opens the start screen', function()
        return tui:lua('return vim.bo.filetype') == 'alpha'
      end)
      select_recent('p', 'Project B', tui.b)
      open_from_files(tui.b, 'Start screen project picker')
      select_recent(' op', 'Project A', tui.a)
      host:wait('Project A returns to its saved file with code focus', function()
        return tui:lua('return _G.forge_session_views_restored > 0')
          and tui:state().file == tui.a .. '/nested/nested.txt'
      end)
      tui:send(' we')
      open_from_files(tui.a, 'Restored project')

      tui:command('ForgeLogs')
      host:wait('ForgeLogs opens the central log from the public launcher', function()
        return tui:lua('return vim.bo.filetype') == 'forge-logs'
      end)
      check_ui()
    end
    host:snapshot('public-launch')
  end, debug.traceback)
  if tui then
    io.stdout:write('  artifacts: ' .. tui.host.dir .. '\n')
    tui:stop(not ok and issue or nil)
  end
  assert(ok, issue)
end

T.check('IDE-BOOT-12 checkout fride opens projects and navigates Files through real input', function()
  check_launcher({
    launcher = { directory = root },
    config = root .. '/nvim_forge/init.lua',
    runtime = vim.fn.has('win32') == 1 and vim.env.FORGE_NVIM ~= 'system'
      and (root .. '/.tools/neovim/windows-x64/bin/nvim.exe') or vim.fn.exepath('nvim'),
    namespace = 'nvim_forge',
  })
end)

if vim.env.FORGE_E2E_INSTALLED_KIT then
  T.check('IDE-BOOT-54 installed fride opens the project with the packaged revision', function()
    local function owned_directory(path)
      local directory = real(assert(path, 'Укажи путь к установленному комплекту и профилю'))
      local owned = real(root .. '/.tests') .. '/'
      assert(directory:sub(1, #owned) == owned, 'Профиль и комплект должны быть на отдельном стенде в .tests')
      return directory
    end
    local function json(path)
      return vim.json.decode(table.concat(vim.fn.readfile(path), '\n'))
    end
    local kit = owned_directory(vim.env.FORGE_E2E_INSTALLED_KIT)
    local profile = owned_directory(vim.env.FORGE_E2E_INSTALLED_PROFILE)
    local bundle = real(assert(vim.env.FORGE_E2E_INSTALLER_BUNDLE, 'Укажи проверяемый комплект установщика'))
    local marker = json(kit .. '/.forge-install.json')
    assert(marker.ready and marker.product == 'forge-nvim', 'Комплект ещё не готов')
    local build = json(bundle .. '/build.json')
    assert(build.source_commit and build.source_worktree_dirty == false, 'Требуется комплект из commit')
    for _, source in ipairs(build.source_files) do
      local relative = source:match('^nvim_forge/(.+)$')
      if relative then
        T.eq(vim.fn.readfile(kit .. '/config/forge/' .. relative, 'b'),
          vim.fn.readfile(bundle .. '/payload/source/' .. source, 'b'), relative)
      end
    end
    check_launcher({
      launcher = { directory = kit .. '/bin', environment = {
        HOME = profile .. '/home', USERPROFILE = profile .. '/home',
        LOCALAPPDATA = profile .. '/local', APPDATA = profile .. '/roaming',
        XDG_CONFIG_HOME = profile .. '/config', XDG_DATA_HOME = profile .. '/data',
        XDG_STATE_HOME = profile .. '/state', XDG_CACHE_HOME = profile .. '/cache',
      } },
      config = kit .. '/config/forge/init.lua',
      runtime = kit .. '/runtime/bin/' .. (vim.fn.has('win32') == 1 and 'nvim.exe' or 'nvim'),
      namespace = 'fride',
      data_home = profile .. '/data',
      revision = build.source_commit,
    })
  end)
end

T.finish()
