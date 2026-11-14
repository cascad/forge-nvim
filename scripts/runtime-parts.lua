-- spec: IDE-BOOT-14. Verify optional parts before touching the install target.
local M = {}
function M.plan(core, original, plan_file)
  local uv, join = vim.uv, vim.fs.joinpath
  local manifest = vim.deepcopy(original)
  if not plan_file or plan_file == '' then return manifest, {} end
  local windows = uv.os_uname().sysname == 'Windows_NT'
  local function fail(message) error(message, 0) end
  local function read(path)
    local file = assert(io.open(path,'rb'),path);local text=file:read('*a');file:close();return text
  end
  local function relative(path)
    if type(path)~='string' or path=='' or path:find('[\\:\r\n\t]') or path:sub(1,1)=='/'
      or path:find('//',1,true) or path:sub(-1)=='/' then fail('Invalid component path: '..tostring(path)) end
    for part in path:gmatch('[^/]+') do if part=='.' or part=='..' then fail('Invalid component path: '..path) end end
    return path
  end
  local function key(path) return windows and path:lower() or path end
  local occupied,directories={},{}
  local function reserve(path,owner)
    local name=key(path)
    if occupied[name] or directories[name] then fail('Runtime file conflict: '..path) end
    local parent=name:match('^(.*)/[^/]+$')
    while parent do
      if occupied[parent] then fail('Runtime file conflict: '..path) end
      directories[parent]=true;parent=parent:match('^(.*)/[^/]+$')
    end
    occupied[name]=owner
  end
  for path in pairs(manifest.files) do
    reserve(path,'core')
  end
  for _,path in ipairs({'forge-runtime.json','forge-component.json'}) do reserve(path,'metadata') end
  local roots,seen={},{}
  for line in (read(plan_file)..'\n'):gmatch('([^\n]+)\n') do
    line=line:gsub('\r$','')
    local platform,id,url,sha=line:match('^([^\t]+)\t([a-z-]+)\t([^\t]+)\t([a-f0-9]+)$')
    if not id or #sha~=64 or platform~=manifest.platform or seen[id] then fail('Invalid runtime composition plan') end
    seen[id]=true
    local root=join(vim.fs.dirname(core),sha)
    if id=='core' then
      if next(roots) or vim.fs.normalize(root)~=vim.fs.normalize(core) then fail('Core plan/cache mismatch') end
      if #manifest.components~=1 or manifest.components[1]~='core' then fail('Modular Core must contain only core') end
    else
      if not seen.core then fail('Core must be first') end
      local part=vim.json.decode(read(join(root,'forge-component.json')))
      if part.schema~=1 or part.kind~='component' or part.platform~=manifest.platform
        or type(part.components)~='table' or #part.components~=1 or part.components[1]~=id
        or part.nvim or part.windows_sdk then fail('Invalid component manifest: '..id) end
      if type(part.files)~='table' or not next(part.files) or type(part.paths)~='table'
        or type(part.probes)~='table' then fail('Incomplete component manifest: '..id) end
      for path,expected in pairs(part.files) do
        relative(path)
        reserve(path,id)
        if type(expected)~='string' or #expected~=64 or expected:find('[^a-f0-9]')
          or vim.fn.sha256(read(join(root,path)))~=expected then fail('Component SHA256 mismatch: '..id..'/'..path) end
        manifest.files[path]=expected
      end
      local function tree(path,rel)
        local stat=assert(uv.fs_lstat(path),path)
        if stat.type=='link' then fail('Linked component file: '..path)
        elseif stat.type=='directory' then
          for name in vim.fs.dir(path) do tree(join(path,name),rel=='' and name or rel..'/'..name) end
        elseif stat.type~='file' or (rel~='forge-component.json' and not part.files[rel]) then
          fail('Untracked component file: '..id..'/'..rel)
        end
      end
      -- Also reject a linked root/parent, rather than reading through it.
      local parent=root
      while parent and parent~='' do
        local stat=uv.fs_lstat(parent);if stat and stat.type=='link' then fail('Linked component root: '..root) end
        local next_parent=vim.fs.dirname(parent);if parent==next_parent then break end;parent=next_parent
      end
      tree(root,'')
      for _,path in ipairs(part.paths) do
        relative(path)
        local stat=uv.fs_stat(join(root,path))
        if not stat or stat.type~='directory' then fail('Missing component executable directory: '..id..'/'..path) end
        if not vim.tbl_contains(manifest.paths,path) then manifest.paths[#manifest.paths+1]=path end
      end
      manifest.probes=manifest.probes or {}
      for _,probe in ipairs(part.probes) do
        if type(probe)~='table' or #probe==0 or not part.files[relative(probe[1])] then fail('Invalid component probe: '..id) end
        for _,arg in ipairs(probe) do if type(arg)~='string' then fail('Invalid component probe argument') end end
        manifest.probes[#manifest.probes+1]=probe
      end
      manifest.components[#manifest.components+1]=id
      roots[#roots+1]={root=root,files=part.files}
    end
  end
  if not seen.core then fail('Missing Core in runtime plan') end
  return manifest,roots
end
return M
