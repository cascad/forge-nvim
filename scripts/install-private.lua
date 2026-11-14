-- spec: IDE-BOOT-11. Общая граница файлов и процессов независимой установки.
local uv = vim.uv
local join = vim.fs.joinpath
local windows = uv.os_uname().sysname == 'Windows_NT'
local function fail(message) error(message, 0) end
local function read(path)
  local file = assert(io.open(path, 'rb'), path); local bytes = file:read('*a'); file:close(); return bytes
end
local function write(path, bytes)
  local file = assert(io.open(path, 'wb')); assert(file:write(bytes)); file:close()
end
local function normalize(path)
  local value = vim.fs.normalize(vim.fn.fnamemodify(path, ':p')):gsub('/+$', '')
  return windows and value:lower() or value
end
local function within(path, root)
  path, root = normalize(path), normalize(root)
  return path == root or path:sub(1, #root + 1) == root .. '/'
end
local function relative(path)
  if type(path) ~= 'string' or path == '' or path:find('[\r\n\t]') or path:find('[\\:]')
    or path:sub(1,1) == '/' then fail('Invalid relative runtime path: ' .. tostring(path)) end
  for part in path:gmatch('[^/]+') do
    if part == '.' or part == '..' then fail('Invalid relative runtime path: ' .. path) end
  end
  return path
end
local function mkdir(path) assert(vim.fn.mkdir(path, 'p') == 1 or uv.fs_stat(path), path) end
local function no_links(path)
  local current = vim.fn.fnamemodify(path, ':p')
  while current and current ~= '' do
    local stat = uv.fs_lstat(current)
    if stat and stat.type == 'link' then fail('Linked install target/parent: ' .. current) end
    local parent = vim.fs.dirname(current)
    if parent == current then break end
    current = parent
  end
end
local function copy_tree(source, target, root, active)
  root, active = root or source, active or {}
  local real = assert(uv.fs_realpath(source), source)
  if not within(real, root) or active[real] then fail('External/cyclic runtime link: ' .. source) end
  local stat = assert(uv.fs_stat(source), source)
  if stat.type == 'directory' then
    active[real] = true; mkdir(target)
    for name in vim.fs.dir(source) do copy_tree(join(source, name), join(target, name), root, active) end
    active[real] = nil
  elseif stat.type == 'file' then
    assert(uv.fs_copyfile(source, target)); assert(uv.fs_chmod(target, stat.mode))
  else fail('Unsupported runtime file: ' .. source) end
end
local function digest(path) return vim.fn.sha256(read(path)) end
local function environment(root, runtime, paths)
  local env = vim.fn.environ()
  env.XDG_CONFIG_HOME, env.XDG_DATA_HOME = join(root,'config'), join(root,'data')
  env.XDG_STATE_HOME, env.XDG_CACHE_HOME = join(root,'state'), join(root,'cache')
  env.NVIM_APPNAME, env.NVIM_LOG_FILE = 'forge', join(root,'log/nvim.log')
  env.TEMP, env.TMP, env.TMPDIR = join(root,'tmp'), join(root,'tmp'), join(root,'tmp')
  env.GOPATH, env.GOCACHE = join(root,'sdk-state/go'), join(root,'cache/go-build')
  env.npm_config_cache, env.PIP_CACHE_DIR = join(root,'cache/npm'), join(root,'cache/pip')
  local bins = {}; for _, path in ipairs(paths) do bins[#bins+1] = join(runtime, path) end
  env.PATH = table.concat(bins, windows and ';' or ':') .. (windows and ';' or ':') .. (env.PATH or '')
  for _, key in ipairs({'VIM','VIMRUNTIME','VIMINIT','EXINIT','LUA_INIT','LUA_PATH','LUA_CPATH'}) do env[key] = nil end
  return env
end
local function execute(argv, env, cwd, log)
  local result = vim.system(argv, {env=env, clear_env=true, cwd=cwd, text=true}):wait(600000)
  write(log, (result.stdout or '') .. (result.stderr or ''))
  if result.code ~= 0 then fail('Command failed (' .. result.code .. '): ' .. table.concat(argv,' ') .. '; log: ' .. log) end
end
local function install()
  local function absolute(value, label)
    return vim.fs.normalize(vim.fn.fnamemodify(assert(value,label), ':p'))
  end
  local source = absolute(vim.env.FORGE_INSTALL_SOURCE, 'Missing source')
  local target = absolute(vim.env.FORGE_INSTALL_TARGET, 'Missing target')
  local runtime = absolute(vim.env.FORGE_INSTALL_RUNTIME, 'Missing private runtime')
  no_links(target)
  if within(source, target) or within(runtime, target) or within(target, source) or within(target, runtime) then
    fail('Install target overlaps source/runtime')
  end
  for _, protected in ipairs({vim.env.HOME or '', vim.env.USERPROFILE or '', vim.env.LOCALAPPDATA or ''}) do
    if protected ~= '' and normalize(target) == normalize(protected) then fail('Protected install target') end
  end
  local owner_path = join(target, '.forge-install.json')
  local existing = uv.fs_stat(target)
  if existing then
    if existing.type ~= 'directory' then fail('Install target is not a directory') end
    local first = vim.fs.dir(target)()
    if first and not uv.fs_stat(owner_path) then fail('Install target contains files not owned by Forge: ' .. target) end
    if first then
      local owner = vim.json.decode(read(owner_path))
      if owner.schema ~= 1 or owner.product ~= 'forge-nvim' then fail('Invalid Forge ownership marker') end
    end
    -- Повтор не должен записывать через junction/symlink в чужой Neovim.
    local function check_owned(path)
      local stat = assert(uv.fs_lstat(path))
      if stat.type == 'link' then
        local real = uv.fs_realpath(path)
        if not real or not within(real,target) then fail('External link in Forge installation: ' .. path) end
      elseif stat.type == 'directory' then
        for name in vim.fs.dir(path) do check_owned(join(path,name)) end
      end
    end
    check_owned(target)
  end
  local manifest = vim.json.decode(read(join(runtime,'forge-runtime.json')))
  local sys = uv.os_uname()
  local osname = windows and 'windows' or (sys.sysname == 'Darwin' and 'macos' or 'linux')
  local arch = ({x86_64='x64', AMD64='x64', arm64='arm64', aarch64='arm64'})[sys.machine]
  if manifest.schema ~= 1 or manifest.platform ~= osname .. '-' .. tostring(arch) then fail('Unsupported runtime platform') end
  local version = vim.version()
  if version.major ~= 0 or version.minor ~= 12 or version.patch ~= 2 then fail('Runtime requires supported Neovim v0.12.2') end
  if windows then
    local expected = vim.json.decode(read(join(source,'scripts/sdk/windows.json')))
    local sdk = manifest.windows_sdk or {}
    for _, key in ipairs({'SourceRevision','PatchSHA256','ProcessPatchSHA256','ProcessSourceSHA256'}) do
      if sdk[key] ~= expected[key] then fail('Unsupported Windows SDK: ' .. key) end
    end
    if not (sdk.Ready and sdk.ConPTYProbe and sdk.ProcessProbe and sdk.ProcessLifecycleProbe)
      or (sdk.BinarySHA256 or ''):lower() ~= (manifest.files['bin/nvim.exe'] or ''):lower() then fail('Unverified Windows SDK') end
  end
  local nvim = windows and 'bin/nvim.exe' or 'bin/nvim'
  if manifest.nvim ~= nvim then fail('Unsupported runtime Neovim path') end
  if type(manifest.files) ~= 'table' or not manifest.files[nvim] then fail('Missing runtime file hashes') end
  for path, sha in pairs(manifest.files) do
    if digest(join(runtime,relative(path))) ~= sha:lower() then fail('Runtime SHA256 mismatch: ' .. path) end
  end
  local components = {}; for _, id in ipairs(manifest.components or {}) do components[id] = true end
  for id in (vim.env.FORGE_NVIM_COMPONENTS or 'core'):gmatch('[^,]+') do
    if not components[id] then fail('Runtime lacks selected component: ' .. id) end
  end
  if type(manifest.paths) ~= 'table' or #manifest.paths == 0 then fail('Runtime has no executable paths') end
  for _, path in ipairs(manifest.paths) do relative(path) end
  -- Проверка всего дерева до создания target (включая неучтённые manifest links).
  local function check_tree(path)
    local real = assert(uv.fs_realpath(path))
    if not within(real, runtime) then fail('External runtime link: ' .. path) end
    local stat = assert(uv.fs_lstat(path))
    if stat.type == 'link' then fail('Runtime bundle must materialize links: ' .. path) end
    if stat.type == 'directory' then
      for name in vim.fs.dir(path) do check_tree(join(path,name)) end
    elseif stat.type == 'file' and path ~= join(runtime,'forge-runtime.json') then
      local rel = vim.fs.relpath(runtime,path)
      if not manifest.files[rel] then fail('Untracked runtime file: ' .. rel) end
    end
  end
  check_tree(runtime)
  mkdir(target)
  if not existing or not uv.fs_stat(owner_path) then write(owner_path,vim.json.encode({schema=1,product='forge-nvim',ready=false})) end
  for _, dir in ipairs({'data','state','cache','tmp','log','sdk-state','backups'}) do mkdir(join(target,dir)) end
  local stamp = tostring(os.time()) .. '-' .. tostring(uv.hrtime())
  local stage = join(target,'.stage-' .. stamp); mkdir(stage)
  copy_tree(runtime,join(stage,'runtime'))
  mkdir(join(stage,'config')); copy_tree(join(source,'nvim_forge'),join(stage,'config/forge'))
  mkdir(join(stage,'bin'))
  for _, name in ipairs({'launch-managed.sh','launch-managed.ps1'}) do
    assert(uv.fs_copyfile(join(source,'scripts',name),join(stage,'bin',name == 'launch-managed.sh' and 'forge' or 'forge.ps1')))
  end
  assert(uv.fs_chmod(join(stage,'bin/forge'),493))
  write(join(stage,'bin/forge.cmd'),'@echo off\r\npowershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0forge.ps1" %*\r\nexit /b %errorlevel%\r\n')
  write(join(stage,'bin/runtime-paths.txt'),table.concat(manifest.paths,'\n') .. '\n')
  -- Setup использует staged config/runtime, а постоянные data/state принадлежат только Forge.
  local env = environment(target,join(stage,'runtime'),manifest.paths)
  env.XDG_CONFIG_HOME = join(stage,'config')
  local exe = join(stage,'runtime',nvim)
  for index, probe in ipairs(manifest.probes or {}) do
    local argv = {join(stage,'runtime',relative(probe[1]))}
    for i=2,#probe do argv[#argv+1]=probe[i] end
    execute(argv,env,target,join(target,'log','probe-' .. index .. '.log'))
  end
  for _, task in ipairs({'plugins','parsers','tools'}) do
    execute({exe,'--headless','-i','NONE','-u',join(stage,'config/forge/init.lua'),
      '-l',join(stage,'config/forge/scripts/setup-stage.lua'),task},env,target,join(target,'log','setup-' .. task .. '.log'))
  end
  local backup = join(target,'backups',stamp); mkdir(backup)
  local moved, committed = {}, {}
  local ok, err = pcall(function()
    for _, dir in ipairs({'runtime','config','bin'}) do
      if uv.fs_stat(join(target,dir)) then assert(uv.fs_rename(join(target,dir),join(backup,dir))); moved[#moved+1]=dir end
      assert(uv.fs_rename(join(stage,dir),join(target,dir))); committed[#committed+1]=dir
    end
    write(owner_path,vim.json.encode({schema=1,product='forge-nvim',ready=true,components=manifest.components,backup=backup}))
  end)
  if not ok then
    for _, dir in ipairs(committed) do assert(uv.fs_rename(join(target,dir),join(stage,dir))) end
    for _, dir in ipairs(moved) do assert(uv.fs_rename(join(backup,dir),join(target,dir))) end
    fail(err)
  end
  assert(uv.fs_rmdir(stage))
  io.stdout:write('Forge installed: ' .. target .. '\nLaunch: ' .. join(target,windows and 'bin/forge.cmd' or 'bin/forge') .. '\n')
end
local ok, err = xpcall(install,debug.traceback)
if not ok then io.stderr:write(tostring(err) .. '\n'); vim.cmd('cquit 1') end
