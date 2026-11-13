local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local patch=vim.json.decode(table.concat(vim.fn.readfile(root..'/nvim_forge/patches/plugins.json'),'\n')).neogit
local function bytes(path) local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
local function write(path,text) vim.fn.mkdir(vim.fs.dirname(path),'p');local f=assert(io.open(path,'wb'));assert(f:write(text));assert(f:close()) end
local function runtime(fn)
  local p=require('editor_runtime').create(root)
  local ok,err=pcall(fn,p.path);require('editor_runtime').remove(p);assert(ok,err)
end
local function cli(dir,mode,plugin)
  local args={vim.v.progpath,'-l',root..'/nvim_forge/scripts/prepare-plugins.lua','--plugin-root',dir,'--plugin',plugin or 'neogit'}
  if mode then args[#args+1]=mode end
  return vim.system(args,{cwd=root,text=true,timeout=15000}):wait()
end
local deps=vim.env.FORGE_E2E_DEPS or root..'/.tests/editor-deps'
local function companions(base,spec,eol,prepared,plugin)
  plugin=plugin or 'gitsigns.nvim'
  local out={}
  for _,extra in ipairs(spec.extra or {}) do
    local text=bytes(deps..'/lazy/'..plugin..'/'..extra.file):gsub('\r\n','\n')
    if not prepared and vim.fn.sha256(text)==extra.after_sha256 then
      local a,b=assert(text:find(extra.after,1,true));text=text:sub(1,a-1)..extra.before..text:sub(b+1)
    end
    T.eq(vim.fn.sha256(text),prepared and extra.after_sha256 or extra.before_sha256)
    local path=base..'/'..plugin..'/'..extra.file;local raw=text:gsub('\n',eol or '\n')
    write(path,raw);out[#out+1]={path=path,raw=raw,spec=extra}
  end
  return out
end
local original=bytes(deps..'/lazy/neogit/'..patch.file):gsub('\r\n','\n')
if vim.fn.sha256(original)==patch.after_sha256 then
  local first,last=assert(original:find(patch.after,1,true));original=original:sub(1,first-1)..patch.before..original:sub(last+1)
end
assert(vim.fn.sha256(original)==patch.before_sha256,'Нужны pinned исходники Neogit')

T.check('IDE-GIT-7 CLI apply check repeat и revert сохраняют LF/CRLF',function()
  runtime(function(base)
    for _,eol in ipairs({'\n','\r\n'}) do
      local dir=base..(eol=='\n' and '/lf' or '/crlf');local path=dir..'/neogit/'..patch.file
      local raw=original:gsub('\n',eol);write(path,raw)
      local files=companions(dir,patch,eol,false,'neogit')
      local missing=cli(dir,'--check');assert(missing.code~=0 and missing.stderr:find('Lazy build neogit',1,true),missing.stderr)
      T.eq(bytes(path),raw,'check не пишет исходный файл')
      local prepared=cli(dir);assert(prepared.code==0,prepared.stderr)
      T.eq(vim.json.decode(prepared.stdout).neogit.sha256,patch.after_sha256)
      local after=bytes(path);T.eq(vim.fn.sha256((after:gsub('\r\n','\n'))),patch.after_sha256)
      for _,file in ipairs(files) do
        T.eq(vim.json.decode(prepared.stdout).neogit.files[file.spec.file],file.spec.after_sha256)
        T.eq(vim.fn.sha256((bytes(file.path):gsub('\r\n','\n'))),file.spec.after_sha256)
        file.stat=vim.uv.fs_stat(file.path)
        if eol=='\r\n' then assert(not bytes(file.path):gsub('\r\n',''):find('\n',1,true),'companion CRLF сохранён') end
      end
      if eol=='\r\n' then assert(not after:gsub('\r\n',''):find('\n',1,true),'CRLF сохранён') end
      local stat=vim.uv.fs_stat(path)
      assert(cli(dir).code==0);assert(cli(dir,'--check').code==0)
      T.eq(vim.uv.fs_stat(path).mtime,stat.mtime,'повтор/check не пишет файл')
      T.eq(bytes(path),after)
      for _,file in ipairs(files) do T.eq(vim.uv.fs_stat(file.path).mtime,file.stat.mtime) end
      assert(cli(dir,'--revert').code==0);T.eq(bytes(path),raw)
      for _,file in ipairs(files) do T.eq(bytes(file.path),file.raw) end
      assert(cli(dir,'--revert').code==0);T.eq(bytes(path),raw)
      for _,file in ipairs(files) do T.eq(bytes(file.path),file.raw) end
    end
  end)
end)
T.check('IDE-GIT-7 CLI сохраняет неизвестный payload и revision',function()
  runtime(function(base)
    local path=base..'/neogit/'..patch.file
    local unknown=original..'-- local change\n';write(path,unknown)
    local r=cli(base);assert(r.code~=0 and r.stderr:find('неизвестное содержимое',1,true),r.stderr)
    T.eq(bytes(path),unknown)
    write(path,original)
    local function git(...) local args={'git','-C',base..'/neogit'};vim.list_extend(args,{...});local x=vim.system(args,{text=true}):wait();assert(x.code==0,x.stderr) end
    git('init');git('-c','user.name=Fixture','-c','user.email=fixture@example.invalid','-c','commit.gpgsign=false','-c','core.hooksPath='..base..'/no-hooks','commit','--allow-empty','-m','unrelated revision')
    r=cli(base);assert(r.code~=0 and r.stderr:find('неизвестная ревизия',1,true),r.stderr)
    T.eq(bytes(path),original)
  end)
end)
T.check('IDE-GIT-7 editor отклоняет неподготовленный payload до запуска',function()
  runtime(function(base)
    local path=base..'/lazy/neogit/'..patch.file;write(path,original)
    local signs=vim.json.decode(table.concat(vim.fn.readfile(root..'/nvim_forge/patches/plugins.json'),'\n'))['gitsigns.nvim']
    write(base..'/lazy/gitsigns.nvim/'..signs.file,bytes(deps..'/lazy/gitsigns.nvim/'..signs.file))
    companions(base..'/lazy',signs,'\n',true)
    write(base..'/manifest.json',bytes(deps..'/manifest.json'))
    local before=vim.env.FORGE_E2E_DEPS;vim.env.FORGE_E2E_DEPS=base
    local ok,err=pcall(require('editor').start,root)
    vim.env.FORGE_E2E_DEPS=before
    assert(not ok and tostring(err):find('не подготовлен',1,true) and tostring(err):find('prepare_editor.py',1,true),tostring(err))
    T.eq(bytes(path),original)
  end)
end)
T.check('IDE-GIT-7 CLI Git воспроизводит системную границу cwd',function()
  local python=vim.fn.exepath(vim.fn.has('win32')==1 and 'python' or 'python3')
  assert(python~='','Нужен Python 3')
  local r=vim.system({python,'-B',root..'/tests/diagnostics/git-worktree-cwd.py'},
    {cwd=root,text=true,timeout=20000}):wait()
  assert(r.code==0,(r.stdout or '')..(r.stderr or ''))
  T.eq(#vim.json.decode(vim.trim(r.stdout)),3)
end)
T.check('IDE-GIT-7 настоящий Lazy build готовит private плагин, открытие Git его не пишет',function()
  local e,path,paths
  local ok,err=pcall(function()
    e=require('editor').start(root,{prepare=function(_,env)
      local data=env.XDG_DATA_HOME..'/nvim_forge'..(vim.fn.has('win32')==1 and '-data' or '')..'/lazy'
      -- Моделируем существующую установку без патча только в собственном профиле.
      dofile(root..'/nvim_forge/lua/ide/backports.lua').run('neogit',data..'/neogit','revert')
      path=data..'/neogit/'..patch.file
      -- Legacy IDE-034 уже подготовлен, новый util companion ещё исходный.
      write(path,bytes(deps..'/lazy/neogit/'..patch.file))
      paths={{path=path,spec=patch}}
      for _,extra in ipairs(patch.extra or {}) do paths[#paths+1]={path=data..'/neogit/'..extra.file,spec=extra} end
    end})
    e:wait('IDE готова',function() return e:lua('return _G.forge_e2e_observed') end,10000)
    T.eq(vim.fn.sha256((bytes(path):gsub('\r\n','\n'))),patch.after_sha256)
    for i,item in ipairs(paths) do if i>1 then T.eq(vim.fn.sha256((bytes(item.path):gsub('\r\n','\n'))),item.spec.before_sha256) end end
    e:input(':Lazy! build neogit<CR>')
    e:wait('Lazy build применил все файлы backport',function()
      for _,item in ipairs(paths) do if vim.fn.sha256((bytes(item.path):gsub('\r\n','\n')))~=item.spec.after_sha256 then return false end end
      return true
    end,15000)
    for _,item in ipairs(paths) do item.stat=vim.uv.fs_stat(item.path) end
    e:input(':Neogit<CR>')
    e:wait('Git открыт',function() return e:current_ft()=='NeogitStatus' end,15000)
    for _,item in ipairs(paths) do
      T.eq(vim.uv.fs_stat(item.path).mtime,item.stat.mtime,'config проверяет без записи')
      T.eq(vim.fn.sha256((bytes(item.path):gsub('\r\n','\n'))),item.spec.after_sha256)
    end
    for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
  end)
  if e then e:snapshot('lazy-build');io.stdout:write('  artifacts: '..e.dir..'\n');e:stop() end
  assert(ok,err)
end)
T.check('IDE-GIT-8 CLI выбирает только Gitsigns, repeat/revert и неизвестное имя безопасны',function()
  local spec=vim.json.decode(table.concat(vim.fn.readfile(root..'/nvim_forge/patches/plugins.json'),'\n'))['gitsigns.nvim']
  local source=bytes(deps..'/lazy/gitsigns.nvim/'..spec.file):gsub('\r\n','\n')
  local first,last=assert(source:find(spec.after,1,true));source=source:sub(1,first-1)..spec.before..source:sub(last+1)
  T.eq(vim.fn.sha256(source),spec.before_sha256)
  runtime(function(base)
    for _,eol in ipairs({'\n','\r\n'}) do
      local dir=base..(eol=='\n' and '/lf with space' or '/crlf with space')
      local path=dir..'/gitsigns.nvim/'..spec.file;local sentinel=dir..'/neogit/'..patch.file
      local raw=source:gsub('\n',eol);write(path,raw);write(sentinel,'UNCHANGED_SENTINEL')
      local files=companions(dir,spec,eol,false)
      local missing=cli(dir,'--check','gitsigns.nvim');assert(missing.code~=0);T.eq(bytes(path),raw)
      local r=cli(dir,nil,'gitsigns.nvim');assert(r.code==0,r.stderr)
      T.eq(vim.json.decode(r.stdout)['gitsigns.nvim'].sha256,spec.after_sha256)
      local hashes=vim.json.decode(r.stdout)['gitsigns.nvim'].files or {}
      for _,file in ipairs(files) do
        T.eq(hashes[file.spec.file],file.spec.after_sha256)
        T.eq(vim.fn.sha256((bytes(file.path):gsub('\r\n','\n'))),file.spec.after_sha256)
        file.stat=vim.uv.fs_stat(file.path)
      end
      T.eq(vim.fn.sha256((bytes(path):gsub('\r\n','\n'))),spec.after_sha256)
      if eol=='\r\n' then assert(not bytes(path):gsub('\r\n',''):find('\n',1,true)) end
      local stat=vim.uv.fs_stat(path);assert(cli(dir,nil,'gitsigns.nvim').code==0);assert(cli(dir,'--check','gitsigns.nvim').code==0)
      T.eq(vim.uv.fs_stat(path).mtime,stat.mtime)
      for _,file in ipairs(files) do T.eq(vim.uv.fs_stat(file.path).mtime,file.stat.mtime) end
      r=cli(dir,nil,'unknown');assert(r.code~=0 and r.stderr:find('Неизвестный backport',1,true),r.stderr)
      assert(cli(dir,'--revert','gitsigns.nvim').code==0);T.eq(bytes(path),raw);T.eq(bytes(sentinel),'UNCHANGED_SENTINEL')
      for _,file in ipairs(files) do T.eq(bytes(file.path),file.raw) end
      for _,previous in ipairs(spec.previous or {}) do
        local a,b=assert(source:find(spec.before,1,true))
        local old=source:sub(1,a-1)..previous.after..source:sub(b+1)
        T.eq(vim.fn.sha256(old),previous.sha256)
        old=old:gsub('\n',eol);write(path,old)
        local old_stat=vim.uv.fs_stat(path)
        r=cli(dir,'--check','gitsigns.nvim');assert(r.code~=0);T.eq(bytes(path),old)
        T.eq(vim.uv.fs_stat(path).mtime,old_stat.mtime)
        r=cli(dir,nil,'gitsigns.nvim');assert(r.code==0,r.stderr)
        T.eq(vim.fn.sha256((bytes(path):gsub('\r\n','\n'))),spec.after_sha256)
        assert(cli(dir,'--revert','gitsigns.nvim').code==0);T.eq(bytes(path),raw)
        write(path,old);assert(cli(dir,'--revert','gitsigns.nvim').code==0);T.eq(bytes(path),raw)
      end
      write(path,raw..'-- unknown change\n');r=cli(dir,nil,'gitsigns.nvim');assert(r.code~=0);T.eq(bytes(path),raw..'-- unknown change\n')
    end
  end)
end)
T.check('IDE-GIT-9 неизвестный companion не меняет ни один файл прежнего backport',function()
  local spec=vim.json.decode(table.concat(vim.fn.readfile(root..'/nvim_forge/patches/plugins.json'),'\n'))['gitsigns.nvim']
  runtime(function(base)
    for _,eol in ipairs({'\n','\r\n'}) do
      local files=companions(base,spec,eol,false);assert(#files>0 and #spec.previous>0)
      local path=base..'/gitsigns.nvim/'..spec.file
      local source=bytes(deps..'/lazy/gitsigns.nvim/'..spec.file):gsub('\r\n','\n')
      local a,b=assert(source:find(spec.after,1,true))
      source=source:sub(1,a-1)..spec.previous[1].after..source:sub(b+1)
      T.eq(vim.fn.sha256(source),spec.previous[1].sha256)
      local old=source:gsub('\n',eol);write(path,old)
      local unknown=files[1].raw..'-- unknown companion\n';write(files[1].path,unknown)
      local r=cli(base,nil,'gitsigns.nvim');assert(r.code~=0 and r.stderr:find('неизвестное содержимое',1,true),r.stderr)
      T.eq(bytes(path),old);T.eq(bytes(files[1].path),unknown)
    end
  end)
end)
T.check('IDE-GIT-8 настоящий Lazy build готовит Gitsigns, открытие файла не пишет исходник',function()
  local spec=vim.json.decode(table.concat(vim.fn.readfile(root..'/nvim_forge/patches/plugins.json'),'\n'))['gitsigns.nvim']
  local e,path,plugin_dir
  local ok,err=pcall(function()
    e=require('editor').start(root,{prepare=function(project,env,runtime)
      local dir=env.XDG_DATA_HOME..'/nvim_forge'..(vim.fn.has('win32')==1 and '-data' or '')..'/lazy/gitsigns.nvim'
      plugin_dir=dir
      dofile(root..'/nvim_forge/lua/ide/backports.lua').run('gitsigns.nvim',dir,'revert');path=dir..'/'..spec.file
      local previous=(spec.previous or {})[1]
      if previous then
        local source=bytes(path):gsub('\r\n','\n');local a,b=assert(source:find(spec.before,1,true))
        write(path,source:sub(1,a-1)..previous.after..source:sub(b+1))
      end
      -- Initial signs проверяем на tracked файле настоящего репозитория.
      for _,args in ipairs({{'config','user.name','Fixture'},{'config','user.email','fixture@example.invalid'},
        {'config','commit.gpgsign','false'},{'config','core.hooksPath',runtime..'/no-hooks'},
        {'add','.'},{'commit','-m','backport fixture'}}) do
        local argv={'git','-C',project};vim.list_extend(argv,args);local r=vim.system(argv,{text=true}):wait();assert(r.code==0,r.stderr)
      end
    end})
    e:wait('IDE готова',function() return e:lua('return _G.forge_e2e_observed') end,10000)
    T.eq(vim.fn.sha256((bytes(path):gsub('\r\n','\n'))),spec.previous and spec.previous[1].sha256 or spec.before_sha256)
    e:input(':Lazy! build gitsigns.nvim<CR>')
    local paths={{path=path,spec=spec}}
    for _,extra in ipairs(spec.extra or {}) do paths[#paths+1]={path=plugin_dir..'/'..extra.file,spec=extra} end
    e:wait('Gitsigns build завершён',function()
      for _,item in ipairs(paths) do if vim.fn.sha256((bytes(item.path):gsub('\r\n','\n')))~=item.spec.after_sha256 then return false end end
      return true
    end,15000)
    for _,item in ipairs(paths) do item.stat=vim.uv.fs_stat(item.path) end
    if e:current_ft()=='lazy' then e:input('q');e:wait('Lazy закрыт',function() return e:current_ft()~='lazy' end) end
    e:input(':edit '..vim.fn.fnameescape(e.project..'/file_one.txt')..'<CR>')
    e:wait('initial signs готовы',function() return e:lua([[local d=vim.b.gitsigns_status_dict;return d and d.added~=nil]]) end,15000)
    for _,item in ipairs(paths) do T.eq(vim.uv.fs_stat(item.path).mtime,item.stat.mtime) end
    for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
  end)
  if e then e:snapshot('gitsigns-build');io.stdout:write('  artifacts: '..e.dir..'\n');e:stop() end
  assert(ok,err)
end)
T.check('IDE-GIT-12 legacy Neogit companion обновляется явно, неизвестный сохраняет оба файла',function()
  runtime(function(base)
    for _,eol in ipairs({'\n','\r\n'}) do
      local dir=base..(eol=='\n' and '/lf legacy' or '/crlf legacy')
      local path=dir..'/neogit/'..patch.file
      local prepared=bytes(deps..'/lazy/neogit/'..patch.file):gsub('\r\n','\n'):gsub('\n',eol)
      write(path,prepared);local files=companions(dir,patch,eol,false,'neogit');assert(#files>0)
      local stat=vim.uv.fs_stat(path)
      local r=cli(dir,'--check');assert(r.code~=0 and r.stderr:find('Lazy build neogit',1,true),r.stderr)
      T.eq(bytes(path),prepared);T.eq(vim.uv.fs_stat(path).mtime,stat.mtime)
      for _,file in ipairs(files) do T.eq(bytes(file.path),file.raw) end
      r=cli(dir);assert(r.code==0,r.stderr)
      T.eq(bytes(path),prepared);T.eq(vim.uv.fs_stat(path).mtime,stat.mtime,'legacy primary не переписывается')
      for _,file in ipairs(files) do T.eq(vim.fn.sha256((bytes(file.path):gsub('\r\n','\n'))),file.spec.after_sha256) end
      assert(cli(dir,'--revert').code==0)
      local raw=original:gsub('\n',eol);T.eq(bytes(path),raw)
      local unknown=files[1].raw..'-- unknown util\n';write(files[1].path,unknown)
      r=cli(dir);assert(r.code~=0 and r.stderr:find('неизвестное содержимое',1,true),r.stderr)
      T.eq(bytes(path),raw,'primary не записывается до companion preflight')
      T.eq(bytes(files[1].path),unknown)
    end
  end)
end)
for _,eol in ipairs({'\n','\r\n'}) do
  T.check('IDE-TEST-6 Neotest CLI companion apply check repeat revert '..(eol=='\n' and 'LF' or 'CRLF'),function()
    runtime(function(base)
      local spec=vim.json.decode(bytes(root..'/nvim_forge/patches/plugins.json')).neotest
      local source=bytes(deps..'/lazy/neotest/'..spec.file):gsub('\r\n','\n')
      T.eq(vim.fn.sha256(source),spec.after_sha256)
      local a,b=assert(source:find(spec.after,1,true));source=source:sub(1,a-1)..spec.before..source:sub(b+1)
      T.eq(vim.fn.sha256(source),spec.before_sha256)
      local path=base..'/neotest/'..spec.file;local raw=source:gsub('\n',eol);write(path,raw)
      local files=companions(base,spec,eol,false,'neotest');T.eq(#files,3)
      assert(cli(base,'--check','neotest').code~=0);T.eq(bytes(path),raw)
      local result=cli(base,nil,'neotest');T.eq(result.code,0,result.stderr)
      local actual=vim.json.decode(result.stdout).neotest
      T.eq(actual.files[spec.file],spec.after_sha256)
      for _,item in ipairs(files) do T.eq(actual.files[item.spec.file],item.spec.after_sha256) end
      local all={{path=path,spec=spec,raw=raw}};vim.list_extend(all,files)
      for _,item in ipairs(all) do
        T.eq(vim.fn.sha256((bytes(item.path):gsub('\r\n','\n'))),item.spec.after_sha256)
        if eol=='\r\n' then assert(not bytes(item.path):gsub('\r\n',''):find('\n',1,true)) end
        item.stat=vim.uv.fs_stat(item.path)
      end
      T.eq(cli(base,nil,'neotest').code,0);T.eq(cli(base,'--check','neotest').code,0)
      for _,item in ipairs(all) do T.eq(vim.uv.fs_stat(item.path).mtime,item.stat.mtime) end
      T.eq(cli(base,'--revert','neotest').code,0)
      for _,item in ipairs(all) do T.eq(bytes(item.path),item.raw) end
    end)
  end)
end
T.check('IDE-TEST-6 unknown Neotest companion preserves all source files',function()
  runtime(function(base)
    local spec=vim.json.decode(bytes(root..'/nvim_forge/patches/plugins.json')).neotest
    local main=bytes(deps..'/lazy/neotest/'..spec.file):gsub('\r\n','\n')
    local a,b=assert(main:find(spec.after,1,true));main=main:sub(1,a-1)..spec.before..main:sub(b+1)
    local path=base..'/neotest/'..spec.file;write(path,main)
    local files=companions(base,spec,'\n',false,'neotest');local item=files[#files]
    local unknown=item.raw..'\n-- unknown private modification\n';write(item.path,unknown)
    local result=cli(base,nil,'neotest');assert(result.code~=0 and result.stderr:find('неизвестное содержимое',1,true),result.stderr)
    T.eq(bytes(path),main);T.eq(bytes(item.path),unknown)
    for i=1,#files-1 do T.eq(bytes(files[i].path),files[i].raw) end
  end)
end)
for _,eol in ipairs({'\n','\r\n'}) do
  T.check('IDE-FILE-5 Neo-tree CLI primary companion apply check repeat revert '..(eol=='\n' and 'LF' or 'CRLF'),function()
    runtime(function(base)
      local spec=vim.json.decode(bytes(root..'/nvim_forge/patches/plugins.json'))['neo-tree.nvim']
      local specs={spec};vim.list_extend(specs,spec.extra);local files={}
      for _,item in ipairs(specs) do
        local source=bytes(deps..'/lazy/neo-tree.nvim/'..item.file):gsub('\r\n','\n')
        if vim.fn.sha256(source)==item.after_sha256 then
          local a,b=assert(source:find(item.after,1,true));source=source:sub(1,a-1)..item.before..source:sub(b+1)
        end
        T.eq(vim.fn.sha256(source),item.before_sha256)
        local path=base..'/neo-tree.nvim/'..item.file;local raw=source:gsub('\n',eol);write(path,raw)
        files[#files+1]={path=path,raw=raw,spec=item}
      end
      assert(cli(base,'--check','neo-tree.nvim').code~=0)
      for _,item in ipairs(files) do T.eq(bytes(item.path),item.raw) end
      local result=cli(base,nil,'neo-tree.nvim');T.eq(result.code,0,result.stderr)
      local actual=vim.json.decode(result.stdout)['neo-tree.nvim'];T.eq(actual.sha256,spec.after_sha256)
      for _,item in ipairs(files) do
        T.eq(actual.files[item.spec.file],item.spec.after_sha256)
        T.eq(vim.fn.sha256((bytes(item.path):gsub('\r\n','\n'))),item.spec.after_sha256)
        if eol=='\r\n' then assert(not bytes(item.path):gsub('\r\n',''):find('\n',1,true)) end
        item.stat=vim.uv.fs_stat(item.path)
      end
      T.eq(cli(base,nil,'neo-tree.nvim').code,0);T.eq(cli(base,'--check','neo-tree.nvim').code,0)
      for _,item in ipairs(files) do T.eq(vim.uv.fs_stat(item.path).mtime,item.stat.mtime) end
      T.eq(cli(base,'--revert','neo-tree.nvim').code,0)
      for _,item in ipairs(files) do T.eq(bytes(item.path),item.raw) end
    end)
  end)
end
T.check('IDE-FILE-5 unknown Neo-tree companion preserves primary',function()
  runtime(function(base)
    local spec=vim.json.decode(bytes(root..'/nvim_forge/patches/plugins.json'))['neo-tree.nvim']
    local specs={spec};vim.list_extend(specs,spec.extra);local files={}
    for _,item in ipairs(specs) do
      local source=bytes(deps..'/lazy/neo-tree.nvim/'..item.file):gsub('\r\n','\n')
      local a,b=assert(source:find(item.after,1,true));source=source:sub(1,a-1)..item.before..source:sub(b+1)
      T.eq(vim.fn.sha256(source),item.before_sha256)
      local path=base..'/neo-tree.nvim/'..item.file;write(path,source);files[#files+1]={path=path,raw=source}
    end
    local last=files[#files];last.raw=last.raw..'\n-- unknown companion\n';write(last.path,last.raw)
    local result=cli(base,nil,'neo-tree.nvim');assert(result.code~=0 and result.stderr:find('неизвестное содержимое',1,true),result.stderr)
    for _,item in ipairs(files) do T.eq(bytes(item.path),item.raw) end
  end)
end)
T.check('IDE-BOOT-1 полный setup исходных plugins открывает Files Tests Locals без config ERROR',function()
  local e
  local started=vim.uv.hrtime()
  local prepared_files={}
  local setup=root..'/.tests/plugin-first-open-setup/'..tostring(vim.uv.hrtime())
  vim.fn.mkdir(setup,'p')
  local function stage(name,fields)
    local row={stage=name,ms=(vim.uv.hrtime()-started)/1e6,loop_ms=vim.uv.now(),fields=fields}
    local f=assert(io.open(setup..'/stages.jsonl','ab'));assert(f:write(vim.json.encode(row)..'\n'));assert(f:close())
  end
  stage('setup.begin')
  local commands={}
  local function prepare(applier,data,name)
    -- Тот же public applier, который вызывают CLI и Lazy build. Внешний CLI
    -- проверяется отдельно; здесь подготовка не создаёт вложенный SDK process.
    stage('apply.begin',{plugin=name or '*'})
    local result=name and {[name]=applier.run(name,data..'/'..name,'apply')} or applier.all(data,'apply')
    commands[#commands+1]={plugin=name or '*',result=result}
    vim.fn.writefile({vim.json.encode(commands)},setup..'/commands.json')
    stage('apply.end',{plugin=name or '*'})
    return result
  end
  local ok,err=xpcall(function()
    e=require('editor').start(root,{prepare=function(_,env)
      stage('profile.copied')
      local data=env.XDG_DATA_HOME..'/nvim_forge'..(vim.fn.has('win32')==1 and '-data' or '')..'/lazy'
      local applier=dofile(root..'/nvim_forge/lua/ide/backports.lua')
      local declarations=vim.json.decode(bytes(root..'/nvim_forge/patches/plugins.json'))
      applier.all(data,'revert')
      stage('payloads.reverted')
      for name,spec in pairs(declarations) do
        local list={spec};vim.list_extend(list,spec.extra or {})
        for _,item in ipairs(list) do
          T.eq(vim.fn.sha256((bytes(data..'/'..name..'/'..item.file):gsub('\r\n','\n'))),item.before_sha256)
        end
      end
      if vim.env.FORGE_PLUGIN_PREPARE_LEGACY=='1' then
        -- Прежняя неполная инструкция владельцу; source replay сохраняется RED.
        for _,name in ipairs({'neogit','gitsigns.nvim','nvim-dap'}) do
          prepare(applier,data,name)
        end
      else
        local applied=prepare(applier,data)
        T.eq(applier.all(data,'check'),applied)
        for name,spec in pairs(declarations) do
          assert(applied[name],'Общий setup пропустил '..name)
          local list={spec};vim.list_extend(list,spec.extra or {})
          for _,item in ipairs(list) do
            local path=data..'/'..name..'/'..item.file
            T.eq(vim.fn.sha256((bytes(path):gsub('\r\n','\n'))),item.after_sha256)
            prepared_files[#prepared_files+1]={path=path,raw=bytes(path),mtime=vim.uv.fs_stat(path).mtime}
          end
        end
      end
      stage('profile.prepared')
    end})
    stage('editor.started',{dir=e.dir,pid=e.rpc.process.pid})
    e:wait('IDE ready after explicit setup',function() return e:lua('return _G.forge_e2e_observed') end,10000)
    assert(vim.uv.fs_copyfile(root..'/tests/e2e/plugin-backports.test.lua',e.dir..'/plugin-backports.test.lua'))
    if vim.env.FORGE_PLUGIN_STAGE_TRACE=='1' then
      e:lua([[local path=...;local uv=vim.uv;local start=uv.hrtime()
      local function record(kind)
        local f=assert(io.open(path,'ab'));f:write(vim.json.encode({kind=kind,ms=(uv.hrtime()-start)/1e6,
          ft=vim.bo.filetype,mode=vim.api.nvim_get_mode()})..'\n');f:close()
      end
      vim.api.nvim_create_autocmd({'WinEnter','BufEnter','FileType'},{callback=function(ev) record(ev.event) end})
      local controls=require('ide.controls');local original=controls.locals
      controls.locals=function(...) record('locals.begin');original(...);record('locals.end') end
      record('observer.ready')]],{e.dir..'/startup-native.jsonl'})
    end
    local function no_errors()
      for _,notice in ipairs(e.rpc.notifications) do assert(notice.level<vim.log.levels.ERROR,notice.message) end
    end
    stage('files.begin');e:input(' we')
    e:wait('Files opens after explicit setup',function() no_errors();return e:current_ft()=='neo-tree' end)
    stage('files.end')
    e:input(' w0:edit file_one.txt<CR>')
    e:wait('plain file opens',function() no_errors();return e:current_file():find('file_one.txt',1,true)~=nil end)
    stage('plain.end')
    e:input(' wt')
    e:wait('Tests opens after explicit setup',function() no_errors();return e:current_ft()=='neotest-summary' end)
    stage('tests.end');e.rpc.trace.detail=vim.env.FORGE_PLUGIN_STAGE_TRACE=='1'
    stage('locals.begin')
    e:input(' wd')
    e:wait('Locals opens after explicit setup',function() no_errors();return e:current_ft()=='dapui_scopes' end)
    stage('locals.end')
    e:input(' w0')
    no_errors()
    T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
    T.eq(e:lua([[return require('dap').session()==nil]]),true,'Открытие Locals не запускает adapter')
    for _,item in ipairs(prepared_files) do
      T.eq(bytes(item.path),item.raw,'Открытие панели не меняет подготовленный plugin')
      T.eq(vim.uv.fs_stat(item.path).mtime,item.mtime,'Открытие панели не пишет patch')
    end
  end,debug.traceback)
  stage('case.end',{ok=ok,error=not ok and tostring(err) or nil})
  if e then
    assert(vim.uv.fs_copyfile(setup..'/stages.jsonl',e.dir..'/startup-stages.jsonl'))
    assert(vim.uv.fs_copyfile(setup..'/commands.json',e.dir..'/plugin-setup-commands.json'))
    e:snapshot('plugin-first-open');io.stdout:write('  artifacts: '..e.dir..'\n')
    local stopped,issue=pcall(e.stop,e,not ok and tostring(err) or nil)
    if not stopped then ok=false;err=tostring(err or '')..'\nCleanup: '..tostring(issue) end
  end
  assert(ok,err)
end)
T.finish()
