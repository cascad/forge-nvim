-- Настоящий дочерний Neovim: RPC только транспорт ввода и наблюдения.
local M = {}
local uv = vim.uv

local function copy_tree(source, target)
  vim.fn.mkdir(target, 'p')
  for name, kind in vim.fs.dir(source) do
    local from, to = source .. '/' .. name, target .. '/' .. name
    if kind == 'directory' then copy_tree(from, to)
    elseif kind == 'file' then assert(uv.fs_copyfile(from, to))
    else error('Неожиданный тип в подготовленных исходниках: ' .. from) end
  end
end

local function stop_process(rpc)
  if not rpc or rpc.exited then return end
  -- Уведомление без ожидания RPC-ответа: qa! завершает сам transport.
  pcall(function() rpc.process:write(vim.mpack.encode({2,'nvim_command',{'qa!'}})) end)
  if not vim.wait(2000,function() return rpc.exited end,10) then
    rpc.process:kill(15)
    assert(vim.wait(2000,function() return rpc.exited end,10), 'Дочерний Neovim не завершился')
  end
end

local function start(root, options, holder)
  options = options or {}
  local deps = vim.env.FORGE_E2E_DEPS or (root .. '/.tests/editor-deps')
  local manifest_path = deps .. '/manifest.json'
  assert(vim.fn.filereadable(manifest_path) == 1,
    'Не подготовлены плагины. Выполни python[3] tests/e2e/prepare_editor.py --download')
  local manifest = vim.json.decode(table.concat(vim.fn.readfile(manifest_path), '\n'))
  local lock = vim.json.decode(table.concat(vim.fn.readfile(root .. '/nvim_forge/lazy-lock.json'), '\n'))
  local expected = {}
  for name, spec in pairs(lock) do expected[name] = spec.commit end
  assert(vim.deep_equal(expected, manifest.plugins), 'Подготовленные плагины не соответствуют lazy-lock.json; повтори prepare_editor.py')

  local dir = root .. '/.tests/editor-e2e/' .. tostring(uv.hrtime())
  vim.fn.mkdir(dir, 'p')
  holder.dir=dir
  -- Большой private runtime живёт на файловой системе гостя, а не на
  -- Windows bind mount. В .tests остаются только воспроизводимые артефакты.
  local profile = require('editor_runtime').create(root)
  holder.profile=profile
  local runtime = profile.path
  local project = runtime .. '/project'
  vim.fn.mkdir(project, 'p')
  vim.fn.mkdir(project .. '/nested', 'p')
  vim.fn.writefile({ 'first file', 'NEEDLE_FORGE_E2E' }, project .. '/file_one.txt')
  vim.fn.writefile({ 'second file' }, project .. '/file_two.txt')
  vim.fn.writefile({ 'nested file' }, project .. '/nested/file_three.txt')
  local init = vim.system({ 'git', 'init', project }, { text = true }):wait()
  assert(init.code == 0, init.stderr)

  local env = vim.fn.environ()
  for key, value in pairs(options.env or {}) do env[key] = value end
  env.NVIM_APPNAME = 'nvim_forge'
  env.HOME, env.USERPROFILE = runtime .. '/home', runtime .. '/home'
  env.LOCALAPPDATA, env.APPDATA = runtime .. '/local', runtime .. '/roaming'
  for _, name in ipairs({ 'HOME', 'LOCALAPPDATA', 'APPDATA' }) do vim.fn.mkdir(env[name], 'p') end
  for _, part in ipairs({ 'CONFIG', 'DATA', 'STATE', 'CACHE' }) do
    env['XDG_' .. part .. '_HOME'] = runtime .. '/' .. part:lower()
    vim.fn.mkdir(env['XDG_' .. part .. '_HOME'], 'p')
  end
  env.NVIM_LOG_FILE = runtime .. '/nvim.log'
  env.TMP, env.TEMP, env.TMPDIR = runtime .. '/tmp', runtime .. '/tmp', runtime .. '/tmp'
  vim.fn.mkdir(env.TMP, 'p')
  env.FORGE_E2E_CONFIG = root .. '/nvim_forge'
  env.VIMINIT, env.EXINIT, env.GVIMINIT = nil, nil, nil
  -- Приложения берут суффикс -data на Windows по native stdpath Neovim.
  local data = env.XDG_DATA_HOME .. '/nvim_forge' .. (vim.fn.has('win32') == 1 and '-data' or '')
  for name in pairs(expected) do copy_tree(deps .. '/lazy/' .. name, data .. '/lazy/' .. name) end
  if options.site then copy_tree(options.site, data .. '/site') end
  local config = env.XDG_CONFIG_HOME .. '/nvim_forge'
  -- Полная неизменённая копия сборки в реальном stdpath: lazy сбрасывает rtp
  -- к stdpath(config), поэтому одного -u на внешний init недостаточно.
  local config_source = options.config or vim.env.FORGE_E2E_CONFIG_SOURCE or root .. '/nvim_forge'
  local source_lock = vim.json.decode(table.concat(vim.fn.readfile(config_source .. '/lazy-lock.json'), '\n'))
  assert(vim.deep_equal(source_lock, lock), 'Config source и подготовленный lock различаются')
  copy_tree(config_source, config)
  vim.fn.writefile({ config_source }, dir .. '/config-origin.txt')
  env.FORGE_E2E_CONFIG = config

  -- Подготовка частного проекта до старта backend (реальные Git fixtures и т.п.).
  if options.prepare then options.prepare(project, env, runtime) end

  local observer = runtime .. '/observe.lua'
  vim.fn.writefile({
    'vim.opt.rtp:prepend(vim.env.FORGE_E2E_CONFIG)',
    'vim.o.columns=140; vim.o.lines=45; vim.o.more=false',
    'vim.g.forge_e2e_installs=0; vim.g.forge_e2e_notifications={}',
    'vim.api.nvim_create_autocmd("User", {pattern="VeryLazy", callback=function() vim.defer_fn(function() _G.forge_e2e_observed=true end,3500) end})',
    '_G.forge_e2e_spawns={}; local spawn=vim.uv.spawn; vim.uv.spawn=function(cmd,opts,...) _G.forge_e2e_spawns[#_G.forge_e2e_spawns+1]={cmd=cmd,args=(opts or {}).args}; return spawn(cmd,opts,...) end',
    'vim.api.nvim_create_autocmd("User", {pattern="MasonToolsStartingInstall", callback=function() vim.g.forge_e2e_installs=vim.g.forge_e2e_installs+1 end})',
    'local notify=vim.notify; vim.notify=function(msg,level,opts) local all=vim.g.forge_e2e_notifications; all[#all+1]={message=tostring(msg),level=level or 2}; vim.g.forge_e2e_notifications=all; vim.rpcnotify(1,"forge_e2e_notify",tostring(msg),level or 2); return notify(msg,level,opts) end',
  }, observer)
  local rpc = require('editor_rpc').start({ vim.v.progpath, '--headless', '--embed', '-i', 'NONE',
    '--cmd', 'lua dofile(' .. vim.inspect(observer) .. ')', '-u', config .. '/init.lua' }, {
    cwd = project, env = env, clear_env = true, timeout = options.timeout,
  })
  holder.rpc=rpc
  local self = { rpc = rpc, dir = dir, project = project, runtime = runtime }
  function self:lua(code, args)
    local mode = self.rpc:request('nvim_get_mode', {})
    assert(not mode.blocking and mode.mode ~= 'r?', 'Neovim ожидает ввода; смотри screen snapshot (hit-enter/confirm)')
    return self.rpc:request('nvim_exec_lua', { code, args or {} })
  end
  function self:input(keys)
    self.rpc:request('nvim_input', { keys })
  end
  -- Явно разрешённый WARN может открыть hit-enter. Caller задаёт точный
  -- текст; ERROR/другое сообщение не принимаются автоматически.
  function self:ack_warning(pattern)
    if not self.rpc:request('nvim_get_mode', {}).blocking then return false end
    for _, n in ipairs(self.rpc.notifications) do assert(n.level < vim.log.levels.ERROR, n.message) end
    local last = self.rpc.notifications[#self.rpc.notifications]
    assert(last and last.level == vim.log.levels.WARN and last.message:find(pattern, 1, true),
      'Неожиданный prompt: ' .. (last and last.message or 'нет notify'))
    vim.fn.writefile(self.rpc:screen_lines(), self.dir .. '/accepted-warning-prompt.txt')
    self:input('<CR>')
    return true
  end
  function self:wait(description, predicate, timeout)
    local last_error
    local deadline = uv.hrtime() + (timeout or 5000) * 1000000
    repeat
      local ok, answer = pcall(predicate)
      if not ok then last_error = tostring(answer) end
      if ok and answer and answer ~= vim.NIL then return end
      -- Predicate выполняет RPC. Его нельзя вызывать из callback vim.wait:
      -- вложенный event loop повторно запускает тот же predicate.
      vim.wait(25)
    until uv.hrtime() >= deadline
    error(description .. (last_error and (': ' .. last_error) or ''))
  end
  function self:current_file()
    return self:lua('return vim.api.nvim_buf_get_name(0)'):gsub('\\', '/')
  end
  function self:has_window(ft)
    return self:lua([[local ft=...; for _,w in ipairs(vim.api.nvim_list_wins()) do if vim.bo[vim.api.nvim_win_get_buf(w)].filetype==ft then return true end end; return false]], { ft })
  end
  function self:current_ft() return self:lua('return vim.bo.filetype') end
  function self:snapshot(label)
    local ok, state = pcall(function()
      return self:lua([[local wins={}; for _,w in ipairs(vim.api.nvim_list_wins()) do local b=vim.api.nvim_win_get_buf(w); wins[#wins+1]={id=w,buf=b,file=vim.api.nvim_buf_get_name(b),ft=vim.bo[b].filetype,lines=vim.api.nvim_buf_get_lines(b,0,math.min(80,vim.api.nvim_buf_line_count(b)),false)} end; return {windows=wins,mode=vim.api.nvim_get_mode(),messages=vim.fn.execute('messages'),errmsg=vim.v.errmsg,notifications=vim.g.forge_e2e_notifications,installs=vim.g.forge_e2e_installs,spawns=_G.forge_e2e_spawns,config=vim.fn.stdpath('config'),data=vim.fn.stdpath('data')} ]])
    end)
    local suffix = label and ('-' .. label:gsub('[^%w_-]', '_')) or ''
    vim.fn.writefile({ vim.json.encode(ok and state or { error = tostring(state), child_exit = self.rpc.exit_code }) }, self.dir .. '/snapshot' .. suffix .. '.json')
    vim.fn.writefile(vim.split(table.concat(self.rpc.stderr), '\n'), self.dir .. '/stderr.log')
    vim.fn.writefile({ vim.json.encode(self.rpc.notifications) }, self.dir .. '/notifications.json')
    vim.fn.writefile(self.rpc:screen_lines(), self.dir .. '/screen' .. suffix .. '.txt')
  end
  function self:stop()
    if self.stopped then return end
    pcall(function() self:snapshot() end)
    local ok,err=pcall(function()
      copy_tree(self.project, self.dir .. '/project')
      copy_tree(config, self.dir .. '/config-source')
      assert(uv.fs_copyfile(manifest_path, self.dir .. '/dependency-manifest.json'))
      if vim.fn.filereadable(env.NVIM_LOG_FILE) == 1 then assert(uv.fs_copyfile(env.NVIM_LOG_FILE, self.dir .. '/nvim.log')) end
    end)
    stop_process(self.rpc)
    if not ok then holder.keep_runtime=true;error(tostring(err)..'; runtime сохранён: '..runtime) end
    require('editor_runtime').remove(profile)
    self.stopped=true
  end
  -- Подключение настоящего UI запускает UIEnter и VeryLazy.
  local ok, failure = pcall(function()
    self.rpc:request('nvim_ui_attach', { 140, 45, { rgb = true, ext_linegrid = true } })
    -- nvim_get_mode и nvim_input — fast API: доступны даже на hit-enter.
    -- В restricted Windows-среде core logger может показать warning о своём
    -- исходном C:/.../nvim.log. Не пытаемся выполнить blocking Lua API за ним.
    local mode = self.rpc:request('nvim_get_mode', {})
    if mode.blocking then
      self:wait('hit-enter отображён UI', function()
        return table.concat(self.rpc:screen_lines(), '\n'):find('Press ENTER', 1, true) ~= nil
      end)
      vim.fn.writefile(self.rpc:screen_lines(), dir .. '/startup-prompt.txt')
      self:input('<CR>')
    end
    self:wait('VimEnter настоящей сборки', function() return self:lua('return vim.v.vim_did_enter') == 1 end, 10000)
  end)
  if not ok then
    self:stop()
    error(tostring(failure) .. '; artifacts: ' .. dir)
  end
  return self
end

function M.start(root, options)
  local holder={}
  local ok,result=xpcall(function() return start(root,options,holder) end,debug.traceback)
  if ok then return result end
  stop_process(holder.rpc)
  if holder.dir then pcall(vim.fn.writefile,vim.split(tostring(result),'\n'),holder.dir..'/start-error.txt') end
  if holder.profile and not holder.keep_runtime then require('editor_runtime').remove(holder.profile) end
  error(result)
end

return M
