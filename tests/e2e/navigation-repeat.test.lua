local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
package.path = root .. '/tests/lib/?.lua;' .. package.path
local T = require('check')

T.check('Held j and h scroll code in both layouts without per-key layout queries or breadcrumb updates', function()
  local e
  local ok, problem = xpcall(function()
    e = require('editor').start(root)
    vim.fn.writefile(vim.fn['repeat']({string.rep('x', 80)}, 180), e.project .. '/motion.txt')
    e:input(':edit motion.txt<CR>')
    e:wait('motion fixture ready', function() return e:current_file():match('/motion.txt$') end)
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
    for i = 1, 64 do
      local tick = vim.uv.hrtime()
      e:input(i % 2 == 0 and 'о' or 'j')
      e:lua("vim.cmd('redraw')")
      samples[#samples + 1] = (vim.uv.hrtime() - tick) / 1e6
    end
    for i = 1, 48 do
      e:input(i % 2 == 0 and 'р' or 'h')
      e:lua("vim.cmd('redraw')")
    end
    local cursor = e:lua('return vim.api.nvim_win_get_cursor(0)')
    T.eq(cursor, {65, 31})
    table.sort(samples)
    local metrics = e:lua('return repeat_metrics')
    metrics.p95_ms = samples[math.ceil(#samples * .95)]
    metrics.max_ms = samples[#samples]
    io.stdout:write('  motion: ' .. vim.json.encode(metrics) .. '\n')
    T.eq(metrics.layout_reads, 0)
    assert(metrics.updates < 8, 'breadcrumb redraws during continuous motion: ' .. metrics.updates)
  end, debug.traceback)
  if e then e:stop(not ok and problem or nil) end
  assert(ok, problem)
end)

T.finish()
