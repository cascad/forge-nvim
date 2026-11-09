-- Private native Bash workspace; tools устанавливаются отдельной командой.
local M={}
local function read(path) return vim.json.decode(table.concat(vim.fn.readfile(path),'\n')) end
local function copy(from,to)
  vim.fn.mkdir(to,'p')
  for name,kind in vim.fs.dir(from) do
    if kind=='directory' then copy(from..'/'..name,to..'/'..name)
    elseif kind=='file' then assert(vim.uv.fs_copyfile(from..'/'..name,to..'/'..name))
    else error('Неожиданный тип Bash fixture '..name) end
  end
end
function M.start(root,on_create,missing)
  local deps=vim.env.FORGE_E2E_BASH_DEPS or root..'/.tests/bash-deps'
  local manifest=read(deps..'/manifest.json')
  for path,hash in pairs(manifest.files) do
    local f=assert(io.open(deps..'/'..path,'rb'));local raw=f:read('*a');f:close()
    assert(vim.fn.sha256(raw)==hash,'Изменены Bash deps: '..path)
  end
  for path,hash in pairs(manifest.host_files) do
    local f=assert(io.open(path,'rb'));local raw=f:read('*a');f:close();assert(vim.fn.sha256(raw)==hash,'Изменён host tool '..path)
  end
  local win=vim.fn.has('win32')==1;local sep=win and ';' or ':'
  local path={vim.fs.dirname(manifest.node),deps..'/bin',vim.fs.dirname(manifest.bash)}
  for _,dir in ipairs(vim.split(vim.env.PATH or '',sep,{plain=true,trimempty=true})) do
    local foreign=false
    for _,name in ipairs({'bash-language-server','shfmt','shellcheck','bats'}) do
      for _,suffix in ipairs(win and {'','.exe','.cmd','.bat'} or {''}) do if vim.fn.filereadable(dir..'/'..name..suffix)==1 then foreign=true end end
    end
    if not foreign then path[#path+1]=dir end
  end
  local e=require('editor').start(root,{timeout=45000,site=deps..'/site',
    env={PATH=table.concat(path,sep),FORGE_NODE_EXECUTABLE=manifest.node,FORGE_NODE_TOOLS=deps..'/tools',
      FORGE_BASH_EXECUTABLE=manifest.bash,FORGE_BATS_EXECUTABLE=deps..'/bats/bats-core-1.14.0/bin/bats'},
    prepare=function(project,env,runtime)
      local dir=project..'/Bash workspace ü';copy(root..'/tests/e2e/fixtures/bash-language',dir)
      local r=vim.system({'git','init',dir},{text=true,env=env,clear_env=true}):wait();assert(r.code==0,r.stderr)
      env.TMPDIR=(runtime..'/tmp'):gsub('\\','/')
      env.BATS_TMPDIR=env.TMPDIR..'/bats';vim.fn.mkdir(env.BATS_TMPDIR,'p')
      local startup=runtime..'/bash-env.sh'
      env.FORGE_BASH_STARTUP_MARKER=dir..'/startup-ran.txt'
      env.BASH_ENV=startup;env.ENV=startup
      vim.fn.writefile({'printf yes >"$FORGE_BASH_STARTUP_MARKER"'},startup)
      -- Положительный контроль: fixture действительно запускается обычным
      -- non-interactive Bash. Forge обязан убрать этот startup hook у child.
      local probe=vim.system({manifest.bash,'--noprofile','--norc','-c',':'},{text=true,env=env,clear_env=true}):wait()
      assert(probe.code==0,probe.stderr);assert(vim.fn.filereadable(env.FORGE_BASH_STARTUP_MARKER)==1)
      assert(vim.fn.delete(env.FORGE_BASH_STARTUP_MARKER)==0)
      if missing then
        env.FORGE_BASH_EXECUTABLE=runtime..'/not-installed-bash';env.FORGE_NODE_TOOLS=runtime..'/no-tools'
        local system=(vim.env.WINDIR or 'C:/Windows')..'/System32'
        if win and vim.fn.filereadable(system..'/bash.exe')==1 then
          -- Проверяем и alias: override "bash" не должен обходить WSL guard.
          env.FORGE_BASH_EXECUTABLE='bash';env.PATH=system..';'..env.PATH
        end
      end
      vim.fn.writefile({'neighbor-ran.txt','literal-neighbor-ran.txt','run-cwd.txt','startup-ran.txt'},dir..'/.gitignore')
    end})
  if on_create then on_create(e) end
  e.bash_project=(e.project..'/Bash workspace ü'):gsub('\\','/')
  e.bash_manifest=manifest
  e.log_lsp=e:lua([[return vim.lsp.log.get_filename()]])
  e.log_state=e:lua([[return vim.fn.stdpath('log')]])
  vim.fn.writefile({vim.json.encode(manifest)},e.dir..'/bash-dependencies.json')
  assert(vim.uv.fs_copyfile(root..'/tests/e2e/bash-tools/package-lock.json',e.dir..'/package-lock.json'))
  assert(vim.uv.fs_copyfile(root..'/tests/e2e/bash-tools/sources.json',e.dir..'/bash-sources.json'))
  e:input(':cd '..vim.fn.fnameescape(e.bash_project)..'<CR>')
  e:lua([[vim.lsp.log.set_level('debug');_G.forge_bash_diagnostics={};local original=vim.lsp.handlers['textDocument/publishDiagnostics'];
    vim.lsp.handlers['textDocument/publishDiagnostics']=function(err,result,ctx,config)
      if result then _G.forge_bash_diagnostics[result.uri]=true end
      if original then return original(err,result,ctx,config) end
    end]])
  return e
end
return M
