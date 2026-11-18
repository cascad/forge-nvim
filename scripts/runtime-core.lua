-- spec: IDE-BOOT-11 IDE-BOOT-40. Shared read-only Core validation.
local M={}
local uv,join=vim.uv,vim.fs.joinpath
local windows=uv.os_uname().sysname=='Windows_NT'
local function fail(message) error(message, 0) end
local function read(path)
  local file = assert(io.open(path, 'rb'), path); local bytes = file:read('*a'); file:close(); return bytes
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
local function digest(path) return vim.fn.sha256(read(path)) end
function M.validate(source,runtime)
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
  return manifest
end
return M
