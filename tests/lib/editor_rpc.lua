-- Msgpack-RPC клиент на встроенных vim.system и vim.mpack. Принимает redraw
-- как UI-клиент, а не отправляет эти уведомления API-серверу родительского nvim.
local M = {}

function M.start(argv, options)
  local self = { replies = {}, serial = 0, redraw = 0, screen = {}, stderr = {}, notifications = {}, api_errors = {}, exited = false }
  if options.capture_ui then
    assert(options.artifacts,'UI capture requires owned artifacts')
    self.ui_capture=require('ui_capture').new(options.artifacts..'/ui-redraw.jsonl',options.capture_ui_limit)
  end
  self.trace=require('editor_trace').new(options)
  local function trace(kind,fields,detail) if self.trace then self.trace:emit(kind,fields,detail) end end
  local unpacker = vim.mpack.Unpacker()
  local function notification(message)
    if message[2] == 'nvim_error_event' then
      local observed={type=message[3][1],message=tostring(message[3][2])}
      self.api_errors[#self.api_errors+1]=observed
      trace('nvim_error_event',observed)
      return
    end
    if message[2] == 'forge_e2e_notify' then
      self.notifications[#self.notifications + 1] = { message = message[3][1], level = message[3][2] }
      return
    end
    if message[2] ~= 'redraw' then return end
    if self.ui_capture then self.ui_capture:redraw(message[3]) end
    self.redraw = self.redraw + 1
    for _, batch in ipairs(message[3]) do
      if batch[1] == 'grid_line' then
        for i = 2, #batch do
          local event = batch[i]
          if event[1] == 1 then
            local row, col = event[2] + 1, event[3] + 1
            self.screen[row] = self.screen[row] or {}
            for _, cell in ipairs(event[4]) do
              for _ = 1, cell[3] or 1 do self.screen[row][col] = cell[1]; col = col + 1 end
            end
          end
        end
      elseif batch[1] == 'grid_clear' then self.screen = {} end
    end
  end
  self.scope=require('process_scope').new()
  local spawned,failure=pcall(function()
    local command=self.scope:command(self.trace and self.trace:prepare(argv) or argv,options)
    self.process = vim.system(command, vim.tbl_extend('force',self.scope.spawn_options,{
      cwd = options.cwd, env = options.env, clear_env = true, stdin = true, timeout = options.timeout or 60000,
      stdout = function(err, chunk)
        if err then self.error = err end
        if not chunk then trace('stdout_eof',{error=err});return end
        trace('stdout_chunk',{bytes=#chunk},true)
        local ok, failure = pcall(function()
          local pos = 1
          while pos <= #chunk do
            local message
            message, pos = unpacker(chunk, pos)
            if message then
              if message[1] == 1 then
                trace('reply',{id=message[2],error=message[3]~=vim.NIL},true)
                self.replies[message[2]] = message
              elseif message[1] == 2 then notification(message) end
            end
          end
        end)
        if not ok then self.error = tostring(failure) end
      end,
      stderr = function(err, chunk)
        if chunk then self.stderr[#self.stderr + 1] = chunk
        else trace('stderr_eof',{error=err}) end
      end,
    }), function(result)
      trace('process_complete',{code=result.code,signal=result.signal})
      self.exited = true; self.exit_code = result.code; self.exit_signal=result.signal
      if self.ui_capture then self.ui_capture:close() end
    end)
    self.scope:attach(self.process.pid)
    trace('process_started',{pid=self.process.pid})
  end)
  if not spawned then
    if self.ui_capture then self.ui_capture:close() end
    if self.process then
      pcall(function() self.process:kill('sigkill') end)
      vim.wait(2000,function() return self.exited end,10)
    end
    local closed,cleanup=pcall(self.scope.close,self.scope)
    if not closed then cleanup={ok=false,error=tostring(cleanup)} end
    if options.artifacts then
      pcall(vim.fn.writefile,{vim.json.encode({error=tostring(failure),pid=self.process and self.process.pid,
        exited=self.exited,scope=cleanup})},options.artifacts..'/process-scope-start.json')
    end
    error(tostring(failure)..(not cleanup.ok and ('; Scope cleanup: '..tostring(cleanup.error)) or ''))
  end

  function self:request(method, args)
    assert(not self.error and not self.exited, self.error or 'Дочерний редактор завершился')
    self.serial = self.serial + 1
    local id = self.serial
    trace('request',{id=id,method=method},true)
    self.process:write(vim.mpack.encode({ 0, id, method, args or {} }))
    local ready = vim.wait(10000, function() return self.replies[id] or self.exited or self.error end, 5)
    if not ready then
      local message='RPC timeout: '..method
      self.failure=self.failure or {message=message,method=method,id=id,timeout_ms=10000,pid=self.process.pid}
      if options.artifacts then
        local ok,err=pcall(vim.fn.writefile,{vim.json.encode(self.failure)},options.artifacts..'/rpc-error.json')
        if not ok then self.failure.artifact_error=tostring(err) end
      end
      self.process:kill(15)
      error(message)
    end
    assert(self.replies[id], self.error or ('Редактор завершился во время ' .. method))
    local response = self.replies[id]
    self.replies[id] = nil
    assert(response[3] == vim.NIL, vim.inspect(response[3]))
    return response[4]
  end
  function self:screen_lines()
    local rows = {}
    for i = 1, 45 do
      local cells = {}
      for col = 1, 140 do cells[col] = (self.screen[i] or {})[col] or ' ' end
      rows[i] = table.concat(cells)
    end
    return rows
  end
  return self
end

return M
