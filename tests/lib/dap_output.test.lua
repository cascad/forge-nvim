local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
package.path = root .. '/tests/lib/?.lua;' .. package.path
local T = require('check')
local M = dofile(root .. '/nvim_forge/lua/forge/dap_output.lua')

local function fixture(supported)
  local session = { stopped_thread_id = 1, capabilities = { supportsExceptionInfoRequest = supported } }
  local active, lines, callback = session, {}, nil
  function session:request(command, args, cb)
    T.eq(command, 'exceptionInfo'); T.eq(args.threadId, 1); callback = cb
  end
  local stopped = M.new(function() return active end, function(line) lines[#lines + 1] = line end)
  return { session = session, lines = lines, stopped = stopped,
    reply = function(err, info) assert(callback); callback(err, info) end,
    replace = function() active = {} end }
end

T.check('SELF: DAP exception без capability показывает event text и не требует запроса', function()
  local f = fixture(false)
  f.stopped(f.session, { reason = 'exception', description = 'panic', text = 'message' })
  T.eq(f.lines, { '[DAP exception] panic: message' })
end)
T.check('SELF: exceptionInfo добавляет stack и не дублирует event description', function()
  local f = fixture(true)
  f.stopped(f.session, { reason = 'exception', text = 'message' })
  f.reply(nil, { description = 'message', details = { stackTrace = 'stack', innerException = { { message = 'inner' } } } })
  T.eq(f.lines, { '[DAP exception] message', 'stack\ninner' })
end)
T.check('SELF: ошибка exceptionInfo сохраняет event text без дополнительной ошибки', function()
  local f = fixture(true)
  f.stopped(f.session, { reason = 'exception', text = 'message' })
  f.reply('adapter rejected', nil)
  T.eq(#f.lines, 1)
end)
T.check('SELF: ответ после continue не попадает в Output', function()
  local f = fixture(true)
  f.stopped(f.session, { reason = 'exception', text = 'message' })
  f.session.stopped_thread_id = nil
  f.reply(nil, { description = 'late' })
  T.eq(#f.lines, 1)
end)
T.check('SELF: ответ прежней сессии не попадает в новую', function()
  local f = fixture(true)
  f.stopped(f.session, { reason = 'exception', text = 'message' })
  f.replace()
  f.reply(nil, { description = 'late' })
  T.eq(#f.lines, 1)
end)
T.check('SELF: ответ прежней паузы не попадает в следующую того же потока', function()
  local f = fixture(true)
  f.stopped(f.session, { reason = 'exception', text = 'message' })
  f.stopped(f.session, { reason = 'breakpoint' })
  f.reply(nil, { description = 'late' })
  T.eq(#f.lines, 1)
end)
T.finish()
