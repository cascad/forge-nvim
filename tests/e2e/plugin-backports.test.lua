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
      local missing=cli(dir,'--check');assert(missing.code~=0 and missing.stderr:find('Lazy build neogit',1,true),missing.stderr)
      T.eq(bytes(path),raw,'check не пишет исходный файл')
      local prepared=cli(dir);assert(prepared.code==0,prepared.stderr)
      T.eq(vim.json.decode(prepared.stdout).neogit.sha256,patch.after_sha256)
      local after=bytes(path);T.eq(vim.fn.sha256((after:gsub('\r\n','\n'))),patch.after_sha256)
      if eol=='\r\n' then assert(not after:gsub('\r\n',''):find('\n',1,true),'CRLF сохранён') end
      local stat=vim.uv.fs_stat(path)
      assert(cli(dir).code==0);assert(cli(dir,'--check').code==0)
      T.eq(vim.uv.fs_stat(path).mtime,stat.mtime,'повтор/check не пишет файл')
      T.eq(bytes(path),after)
      assert(cli(dir,'--revert').code==0);T.eq(bytes(path),raw)
      assert(cli(dir,'--revert').code==0);T.eq(bytes(path),raw)
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
  local e,path
  local ok,err=pcall(function()
    e=require('editor').start(root,{prepare=function(_,env)
      local data=env.XDG_DATA_HOME..'/nvim_forge'..(vim.fn.has('win32')==1 and '-data' or '')..'/lazy'
      -- Моделируем существующую установку без патча только в собственном профиле.
      dofile(root..'/nvim_forge/lua/ide/backports.lua').run('neogit',data..'/neogit','revert')
      path=data..'/neogit/'..patch.file
    end})
    e:wait('IDE готова',function() return e:lua('return _G.forge_e2e_observed') end,10000)
    T.eq(vim.fn.sha256((bytes(path):gsub('\r\n','\n'))),patch.before_sha256)
    e:input(':Lazy! build neogit<CR>')
    e:wait('Lazy build применил backport',function() return vim.fn.sha256((bytes(path):gsub('\r\n','\n')))==patch.after_sha256 end,15000)
    local stat=vim.uv.fs_stat(path)
    e:input(':Neogit<CR>')
    e:wait('Git открыт',function() return e:current_ft()=='NeogitStatus' end,15000)
    T.eq(vim.uv.fs_stat(path).mtime,stat.mtime,'config проверяет без записи')
    T.eq(vim.fn.sha256((bytes(path):gsub('\r\n','\n'))),patch.after_sha256)
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
      local missing=cli(dir,'--check','gitsigns.nvim');assert(missing.code~=0);T.eq(bytes(path),raw)
      local r=cli(dir,nil,'gitsigns.nvim');assert(r.code==0,r.stderr)
      T.eq(vim.json.decode(r.stdout)['gitsigns.nvim'].sha256,spec.after_sha256)
      T.eq(vim.fn.sha256((bytes(path):gsub('\r\n','\n'))),spec.after_sha256)
      if eol=='\r\n' then assert(not bytes(path):gsub('\r\n',''):find('\n',1,true)) end
      local stat=vim.uv.fs_stat(path);assert(cli(dir,nil,'gitsigns.nvim').code==0);assert(cli(dir,'--check','gitsigns.nvim').code==0)
      T.eq(vim.uv.fs_stat(path).mtime,stat.mtime)
      r=cli(dir,nil,'unknown');assert(r.code~=0 and r.stderr:find('Неизвестный backport',1,true),r.stderr)
      assert(cli(dir,'--revert','gitsigns.nvim').code==0);T.eq(bytes(path),raw);T.eq(bytes(sentinel),'UNCHANGED_SENTINEL')
      write(path,raw..'-- unknown change\n');r=cli(dir,nil,'gitsigns.nvim');assert(r.code~=0);T.eq(bytes(path),raw..'-- unknown change\n')
    end
  end)
end)
T.check('IDE-GIT-8 настоящий Lazy build готовит Gitsigns, открытие файла не пишет исходник',function()
  local spec=vim.json.decode(table.concat(vim.fn.readfile(root..'/nvim_forge/patches/plugins.json'),'\n'))['gitsigns.nvim']
  local e,path
  local ok,err=pcall(function()
    e=require('editor').start(root,{prepare=function(project,env,runtime)
      local dir=env.XDG_DATA_HOME..'/nvim_forge'..(vim.fn.has('win32')==1 and '-data' or '')..'/lazy/gitsigns.nvim'
      dofile(root..'/nvim_forge/lua/ide/backports.lua').run('gitsigns.nvim',dir,'revert');path=dir..'/'..spec.file
      -- Initial signs проверяем на tracked файле настоящего репозитория.
      for _,args in ipairs({{'config','user.name','Fixture'},{'config','user.email','fixture@example.invalid'},
        {'config','commit.gpgsign','false'},{'config','core.hooksPath',runtime..'/no-hooks'},
        {'add','.'},{'commit','-m','backport fixture'}}) do
        local argv={'git','-C',project};vim.list_extend(argv,args);local r=vim.system(argv,{text=true}):wait();assert(r.code==0,r.stderr)
      end
    end})
    e:wait('IDE готова',function() return e:lua('return _G.forge_e2e_observed') end,10000)
    T.eq(vim.fn.sha256((bytes(path):gsub('\r\n','\n'))),spec.before_sha256)
    e:input(':Lazy! build gitsigns.nvim<CR>')
    e:wait('Gitsigns build завершён',function() return vim.fn.sha256((bytes(path):gsub('\r\n','\n')))==spec.after_sha256 end,15000)
    local stat=vim.uv.fs_stat(path)
    if e:current_ft()=='lazy' then e:input('q');e:wait('Lazy закрыт',function() return e:current_ft()~='lazy' end) end
    e:input(':edit '..vim.fn.fnameescape(e.project..'/file_one.txt')..'<CR>')
    e:wait('initial signs готовы',function() return e:lua([[local d=vim.b.gitsigns_status_dict;return d and d.added~=nil]]) end,15000)
    T.eq(vim.uv.fs_stat(path).mtime,stat.mtime)
    for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
  end)
  if e then e:snapshot('gitsigns-build');io.stdout:write('  artifacts: '..e.dir..'\n');e:stop() end
  assert(ok,err)
end)
T.finish()
