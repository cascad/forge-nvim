local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
package.path = root .. '/tests/lib/?.lua;' .. package.path
local T = require('check')

local function observe_input(e)
  e:lua([[vim.on_key(function(_, typed)
    if typed ~= '' then _G.forge_motion_key_ns = vim.uv.hrtime() end
  end, vim.api.nvim_create_namespace('forge_motion_probe'))]])
end

local function measure_key(e, key, row, col)
  local started = vim.uv.hrtime()
  e:input(key)
  -- nvim_input подтверждает постановку в очередь. Ждём сам курсор и ответ UI.
  local cursor
  repeat
    local state = e:lua('return {vim.api.nvim_win_get_cursor(0), _G.forge_motion_key_ns}')
    cursor = state[1]
    if state[2] and state[2] >= started and (e.rpc.last_flush_ns or 0) >= state[2]
        and cursor[1] == row and (not col or cursor[2] == col) then
      local input_to_flush_ms = (e.rpc.last_flush_ns - started) / 1e6
      if not e.slowest or input_to_flush_ms > e.slowest.total_ms then
        e.slowest = {key=key, row=row, total_ms=input_to_flush_ms, to_on_key_ms=(state[2] - started) / 1e6}
      end
      -- При автоповторе около 30 Гц между событиями успевают отработать таймеры.
      local elapsed = (vim.uv.hrtime() - started) / 1e6
      if elapsed < 33 then vim.wait(math.floor(33 - elapsed)) end
      return input_to_flush_ms
    end
    vim.wait(1)
  until vim.uv.hrtime() - started > 1000000000
  error(('key %s expected row %d col %s, got %s; UI flushed: %s'):format(
    key, row, tostring(col), vim.inspect(cursor), tostring((e.rpc.last_flush_ns or 0) >= started)))
end

T.check('Held j and h scroll Go code with gopls in both layouts without per-key layout queries or breadcrumb updates', function()
  local e
  local ok, problem = xpcall(function()
    local lsp = vim.env.FORGE_E2E_LSP_DEPS or root .. '/.tests/lsp-deps'
    local dap = vim.env.FORGE_E2E_DAP_TOOLS or root .. '/.tests/dap-tools'
    e = require('editor').start(root, {env={
      PATH=table.concat({lsp .. '/bin', dap .. '/go/bin', vim.env.PATH}, vim.fn.has('win32') == 1 and ';' or ':'),
      GOTOOLCHAIN='local', GOENV='off', GOPROXY='off', GOSUMDB='off', GOWORK='off',
      GOCACHE=require('go_cache').path(root),
    }, prepare=function(project)
      local lines = {'package motion //' .. string.rep('x', 63)}
      for i = 2, 180 do
        local prefix = ('const value%d = "'):format(i)
        lines[i] = prefix .. string.rep('x', 79 - #prefix) .. '"'
      end
      vim.fn.writefile({'module example.org/motion', 'go 1.22'}, project .. '/go.mod')
      vim.fn.writefile(lines, project .. '/motion.go')
    end})
    e:input(':edit motion.go<CR>')
    e:wait('motion fixture attached to gopls', function()
      return e:lua([[local client=vim.lsp.get_clients({name='gopls',bufnr=0})[1]
        return client and client.initialized]])
    end, 30000)
    e:input('gg$')
    e:lua([[local ui=require('barbecue.ui')
      local update=ui.update
      _G.repeat_metrics={updates=0, layout_reads=0}
      ui.update=function(...)
        repeat_metrics.updates=repeat_metrics.updates+1
        return update(...)
      end
      require('config.ru_keys').follow_layout(function()
        repeat_metrics.layout_reads=repeat_metrics.layout_reads+1
      end)]])
    local samples = {}
    observe_input(e)
    for i = 1, 64 do
      samples[#samples + 1] = measure_key(e, i <= 32 and 'j' or 'о', 1 + i, 79)
    end
    for i = 1, 48 do
      samples[#samples + 1] = measure_key(e, i <= 24 and 'h' or 'р', 65, 79 - i)
    end
    local cursor = e:lua('return vim.api.nvim_win_get_cursor(0)')
    T.eq(cursor, {65, 31})
    table.sort(samples)
    local metrics = e:lua('return repeat_metrics')
    metrics.p95_ms = samples[math.ceil(#samples * .95)]
    metrics.max_ms = samples[#samples]
    metrics.slowest = e.slowest
    io.stdout:write('  motion: ' .. vim.json.encode(metrics) .. '\n')
    T.eq(metrics.layout_reads, 0)
    assert(metrics.updates < 8, 'breadcrumb redraws during continuous motion: ' .. metrics.updates)
    assert(metrics.p95_ms < 100, 'sustained input latency above 100 ms in code')
  end, debug.traceback)
  if e then e:stop(not ok and problem or nil) end
  assert(ok, problem)
end)

T.check('Files repeat scrolls both ways and returns focus to the same code split', function()
  local e
  local ok, problem = xpcall(function()
    e = require('editor').start(root, {prepare=function(project)
      for i = 1, 96 do vim.fn.writefile({'fixture'}, project .. ('/motion-%03d.txt'):format(i)) end
    end})
    e:input(':edit file_one.txt<CR>')
    e:wait('code active', function() return e:current_file():match('/file_one.txt$') end)
    local code = e:lua('return vim.api.nvim_get_current_win()')
    e:input(' we')
    e:wait('Files shows all rows', function()
      return e:current_ft() == 'neo-tree' and e:lua('return vim.api.nvim_buf_line_count(0) > 96')
    end)
    local first=e:lua([[for row,line in ipairs(vim.api.nvim_buf_get_lines(0,0,-1,false)) do
      if line:find('motion-001.txt',1,true) then return row end end]])
    e:input(tostring(first)..'G')
    e:wait('first file selected', function() return e:lua('return vim.api.nvim_get_current_line()'):find('motion-001.txt',1,true) end)
    local panel = e:lua('return vim.api.nvim_get_current_win()')
    e:lua([[local fs=require('neo-tree.sources.filesystem.lib.fs_scan')
      local scan=fs.get_items; _G.forge_repeat_scans=0
      fs.get_items=function(...) forge_repeat_scans=forge_repeat_scans+1; return scan(...) end]])
    local samples = {}
    observe_input(e)
    local row = first
    for _, direction in ipairs({
      {en='j', ru='о', count=64, step=1, target='motion-065.txt'},
      {en='k', ru='л', count=48, step=-1, target='motion-017.txt'},
    }) do
      for i = 1, direction.count do
        row = row + direction.step
        samples[#samples + 1] = measure_key(e, i <= direction.count / 2 and direction.en or direction.ru, row)
      end
      T.ok(e:lua('return vim.api.nvim_get_current_line()'):find(direction.target,1,true))
    end
    table.sort(samples)
    local scans=e:lua('return forge_repeat_scans')
    io.stdout:write(('  Files motion: p95_ms=%.2f max_ms=%.2f scans=%d slowest=%s\n'):format(
      samples[math.ceil(#samples*.95)], samples[#samples], scans, vim.json.encode(e.slowest)))
    assert(scans < 8, 'repeated directory scans while moving through Files')
    assert(samples[math.ceil(#samples*.95)] < 100, 'sustained input latency above 100 ms in Files')
    e:input('<F7>')
    e:wait('same code window', function() return e:lua('return vim.api.nvim_get_current_win()') == code end)
    e:input(' we')
    e:wait('same Files window', function() return e:lua('return vim.api.nvim_get_current_win()') == panel end)
  end,debug.traceback)
  if e then e:stop(not ok and problem or nil) end
  assert(ok,problem)
end)

T.finish()
