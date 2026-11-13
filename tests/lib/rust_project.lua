-- Реальный offline Cargo workspace; SDK и tools подготовлены отдельно.
local M={}
local uv=vim.uv
local function read(path) return vim.json.decode(table.concat(vim.fn.readfile(path),'\n')) end
local function copy(from,to)
  vim.fn.mkdir(to,'p')
  for name,kind in vim.fs.dir(from) do
    if kind=='directory' then copy(from..'/'..name,to..'/'..name)
    elseif kind=='file' then assert(uv.fs_copyfile(from..'/'..name,to..'/'..name))
    else error('Неожиданный тип Rust fixture '..name) end
  end
end
function M.start(root,on_create,before_enter)
  if vim.env.FORGE_RUST_LEGACY then
    assert(vim.env.FORGE_RUST_CASE=='nextest' or vim.env.FORGE_RUST_CASE=='debug nearest','Legacy replay только для Rust test regressions')
  end
  if vim.env.FORGE_RUST_OUTPUT_LEGACY then
    assert(not vim.env.FORGE_RUST_LEGACY and vim.env.FORGE_RUST_CASE=='debug nearest','Output replay только для debug nearest после path fix')
  end
  local deps=vim.env.FORGE_E2E_RUST_DEPS or root..'/.tests/rust-deps'
  local manifest=read(deps..'/manifest.json')
  for path,hash in pairs(manifest.files) do
    local f=assert(io.open(deps..'/'..path,'rb'));local raw=f:read('*a');f:close()
    assert(vim.fn.sha256(raw)==hash,'Изменены Rust deps: '..path)
  end
  for path,hash in pairs(manifest.host_files) do
    local f=assert(io.open(path,'rb'));local raw=f:read('*a');f:close()
    assert(vim.fn.sha256(raw)==hash,'Изменён host Rust SDK: '..path)
  end
  local win=vim.fn.has('win32')==1
  local sep=win and ';' or ':'
  local suffix=win and '.exe' or ''
  local sysroot=manifest.sysroot:gsub('\\','/')
  local path={sysroot..'/bin',deps..'/nextest',deps..'/codelldb/extension/adapter'}
  for _,dir in ipairs(vim.split(vim.env.PATH or '',sep,{plain=true,trimempty=true})) do
    local foreign=false
    for _,name in ipairs({'rustc','cargo','rust-analyzer','rustfmt','cargo-nextest','codelldb'}) do
      if vim.fn.filereadable(dir..'/'..name..suffix)==1 then foreign=true end
    end
    if not foreign then path[#path+1]=dir end
  end
  local prepare_output
  local e=require('editor').start(root,{timeout=60000,site=deps..'/site',snapshot_ignore={target=true},
    env={PATH=table.concat(path,sep),RUSTUP_AUTO_INSTALL='0',CARGO_NET_OFFLINE='true',CARGO_BUILD_JOBS='2',
      RUSTC=sysroot..'/bin/rustc'..suffix,RUSTDOC=sysroot..'/bin/rustdoc'..suffix,RAYON_NUM_THREADS='2'},
    prepare=function(project,env,runtime)
      if vim.env.FORGE_RUST_LEGACY then
        local patch=read(root..'/nvim_forge/patches/plugins.json')['neotest-rust']
        local plugin=env.XDG_DATA_HOME..'/nvim_forge'..(win and '-data' or '')..'/lazy/neotest-rust'
        local patches={patch};vim.list_extend(patches,patch.extra or {})
        for _,item in ipairs(patches) do
          local file=plugin..'/'..item.file
          local f=assert(io.open(file,'rb'));local raw=f:read('*a');f:close();assert(vim.fn.sha256(raw)==item.after_sha256)
          local a,b=assert(raw:find(item.after,1,true));raw=raw:sub(1,a-1)..item.before..raw:sub(b+1)
          assert(vim.fn.sha256(raw)==item.before_sha256);f=assert(io.open(file,'wb'));f:write(raw);f:close()
        end
      end
      if vim.env.FORGE_RUST_OUTPUT_LEGACY then
        local patch=read(root..'/nvim_forge/patches/plugins.json')['neotest-rust'].extra[1]
        local file=env.XDG_DATA_HOME..'/nvim_forge'..(win and '-data' or '')..'/lazy/neotest-rust/'..patch.file
        local f=assert(io.open(file,'rb'));local raw=f:read('*a');f:close();assert(vim.fn.sha256(raw)==patch.after_sha256)
        local a,b=assert(raw:find(patch.after,1,true));raw=raw:sub(1,a-1)..patch.previous[1].after..raw:sub(b+1)
        assert(vim.fn.sha256(raw)==patch.previous[1].sha256);f=assert(io.open(file,'wb'));f:write(raw);f:close()
      end
      local dir=project..'/Rust workspace ü';copy(root..'/tests/e2e/fixtures/rust-language',dir)
      for _,key in ipairs({'RUSTC_WRAPPER','RUSTC_WORKSPACE_WRAPPER','RUSTFLAGS','CARGO_ENCODED_RUSTFLAGS'}) do env[key]=nil end
      env.CARGO_HOME=runtime..'/cargo-home'
      env.CARGO_TARGET_DIR=runtime..'/target'
      env.RUSTUP_HOME=vim.env.RUSTUP_HOME or vim.fn.fnamemodify(sysroot,':h:h')
      vim.fn.mkdir(env.CARGO_HOME,'p');vim.fn.mkdir(dir..'/.vscode','p')
      vim.fn.writefile({'target/','rust-cwd.txt','neighbor-ran.txt'},dir..'/.gitignore')
      local r=vim.system({sysroot..'/bin/cargo'..suffix,'metadata','--offline','--format-version','1','--no-deps'},
        {cwd=dir,env=env,clear_env=true,text=true}):wait()
      assert(r.code==0,r.stderr);prepare_output=r.stdout
      assert(vim.fn.filereadable(env.CARGO_TARGET_DIR..'/debug/forge_app'..suffix)==0,'Fixture не должна заранее собирать binary')
    end})
  if on_create then on_create(e) end
  e.rust_project=(e.project..'/Rust workspace ü'):gsub('\\','/')
  e.rust_target=e.runtime..'/target'
  e.rust_suffix=suffix
  e.rust_deps=deps
  e.rustc=sysroot..'/bin/rustc'..suffix
  e.log_cache=e:lua([[return vim.fn.stdpath('cache')]])
  e.log_state=e:lua([[return vim.fn.stdpath('log')]])
  e.log_lsp=e:lua([[return vim.lsp.log.get_filename()]])
  local plugin=e:lua([[return vim.fn.stdpath('data')..'/lazy/neotest-rust']])
  for _,name in ipairs({'init','dap'}) do assert(uv.fs_copyfile(plugin..'/lua/neotest-rust/'..name..'.lua',e.dir..'/neotest-rust-'..name..'.lua')) end
  vim.fn.writefile(vim.split(prepare_output,'\n',{plain=true}),e.dir..'/cargo-metadata.json')
  vim.fn.writefile({vim.json.encode(manifest)},e.dir..'/rust-dependencies.json')
  assert(uv.fs_copyfile(root..'/tests/e2e/rust-tools/sources.json',e.dir..'/rust-sources.json'))
  e:lua([[vim.lsp.log.set_level('debug')]])
  e:lua([[local original=vim.lsp.handlers['experimental/serverStatus'];
    vim.lsp.handlers['experimental/serverStatus']=function(err,result,ctx,config)
      _G.forge_rust_server_status=result
      if original then return original(err,result,ctx,config) end
    end]])
  if before_enter then before_enter(e) end
  e:input(':cd '..vim.fn.fnameescape(e.rust_project)..'<CR>')
  return e
end
return M
