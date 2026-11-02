-- Реальные окна Neogit/Telescope и процессы Git, без подмены backend.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local function norm(p) return vim.fs.normalize(p):gsub('\\','/') end
local function git(path,...)
  local args={'git','-C',path};vim.list_extend(args,{...})
  local r=vim.system(args,{text=true,env={GIT_CONFIG_NOSYSTEM='1',GIT_CONFIG_GLOBAL=vim.fn.has('win32')==1 and 'NUL' or '/dev/null'}}):wait()
  assert(r.code==0,(r.stderr or '')..table.concat(args,' '));return vim.trim(r.stdout or '')
end
local function focus(e,keys,ft)
  e:input(keys);e:wait('фокус '..ft,function() return e:current_ft()==ft and e:lua([[return vim.fn.maparg('q','n',false,true).buffer==1]]) end,10000)
end
local function picker(e,text)
  e:wait('picker принимает ввод',function() return e:current_ft()=='TelescopePrompt' and e.rpc:request('nvim_get_mode',{}).mode=='i' end)
  e:input(text);e:wait('выбран '..text,function() return e:lua([[local text=...;local s=require('telescope.actions.state');local v=s.get_selected_entry();return v and s.get_current_picker(vim.api.nvim_get_current_buf()):_get_prompt()==text and tostring(v[1]):find(text,1,true)~=nil]],{text}) end)
  e:input('<CR>')
end
local function status(e,path,branch)
  e:wait('status '..branch,function() return norm(e:lua('return vim.fn.getcwd()'))==norm(path) and e:current_ft()=='NeogitStatus' and e:lua([[local branch=...;return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n'):find(' '..branch..' ',1,true)~=nil]],{branch}) end,15000)
end
local function visit(e,path,text,branch)
  focus(e,'w','NeogitPopup');e:input('g');picker(e,text);status(e,path,branch)
end
local function confirm(e,text,key)
  e:wait('confirm '..text,function() return e.rpc:request('nvim_get_mode',{}).mode=='r?' and table.concat(e.rpc:screen_lines(),'\n'):find(text,1,true)~=nil end)
  e:input(key)
end
local function remove(e,linked)
  focus(e,'w','NeogitPopup');e:input('D');picker(e,'linked with space');confirm(e,'Remove worktree','y')
end
local function responsive(e)
  assert(not e.rpc:request('nvim_get_mode',{}).blocking,table.concat(e.rpc:screen_lines(),'\n'))
  local messages=e:lua([[return vim.fn.execute('messages')..'\n'..vim.v.errmsg]])
  assert(not messages:find('stack traceback',1,true) and not messages:find('E211',1,true),messages)
  for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
end
local function check(name,dirty)
  T.check(name,function()
    local e,linked,next_path
    local ok,err=xpcall(function()
      e=require('editor').start(root,{env={GIT_CONFIG_NOSYSTEM='1',GIT_CONFIG_GLOBAL=vim.fn.has('win32')==1 and 'NUL' or '/dev/null',GIT_TERMINAL_PROMPT='0',NEOGIT_LOG_FILE='1',NEOGIT_LOG_LEVEL='trace'},prepare=function(project,_,runtime)
        for k,v in pairs({['user.name']='Fixture',['user.email']='fixture@example.invalid',['commit.gpgsign']='false',['core.autocrlf']='false',['core.hooksPath']=runtime..'/no-hooks'}) do git(project,'config',k,v) end
        git(project,'checkout','-b','main');git(project,'add','.');git(project,'commit','-m','fixture baseline')
        linked=runtime..'/linked with space';next_path=runtime..'/next worktree'
        git(project,'worktree','add','-b','linked',linked);git(project,'worktree','add','-b','next',next_path)
      end})
      e:wait('IDE готова',function() return e:lua('return _G.forge_e2e_observed') end,10000)
      e:input(':edit '..vim.fn.fnameescape(linked..'/file_one.txt')..'<CR>')
      e:wait('linked signs готовы',function() return e:current_file()==norm(linked..'/file_one.txt') and e:lua([[local d=vim.b.gitsigns_status_dict;return d and d.added~=nil]]) end)
      local buf=e:lua('return vim.api.nvim_get_current_buf()');local main=git(e.project,'rev-parse','HEAD')
      if dirty then e:input('gg0iDIRTY_<Esc>:write<CR>');e:wait('dirty сохранён',function() return git(linked,'diff'):find('DIRTY_',1,true)~=nil end) end
      local text=e:lua('return vim.api.nvim_buf_get_lines(0,0,-1,false)')
      focus(e,' wg','NeogitStatus');visit(e,linked,'linked with space','linked')
      remove(e,linked)
      if dirty then
        confirm(e,'untracked or modified','n');status(e,e.project,'main');responsive(e)
        T.eq(vim.fn.readfile(linked..'/file_one.txt'),text)
        assert(git(e.project,'worktree','list','--porcelain'):find('linked with space',1,true))
        -- Реальный внешний commit переводит fixture в чистое состояние.
        -- UI stage/commit editor отдельно покрыты git-workflow.test.lua.
        git(linked,'add','file_one.txt');git(linked,'commit','-m','forge active worktree commit')
        T.eq(git(linked,'status','--porcelain'),'')
        visit(e,linked,'linked with space','linked')
        status(e,linked,'linked');remove(e,linked)
      end
      e:wait('каталог удалён',function() return vim.fn.isdirectory(linked)==0 end,15000)
      status(e,e.project,'main');responsive(e)
      T.eq(e:lua('return vim.api.nvim_buf_get_lines(...,0,-1,false)',{buf}),text)
      T.eq(git(e.project,'rev-parse','HEAD'),main)
      assert(not git(e.project,'worktree','list','--porcelain'):find('linked with space',1,true))
      visit(e,next_path,'next worktree','next');visit(e,e.project,'project','main');responsive(e)
      e:input(' w0');e:input(':edit '..vim.fn.fnameescape(e.project..'/file_two.txt')..'<CR>')
      e:wait('код доступен',function() return e:current_file()==norm(e.project..'/file_two.txt') end)
      e:input('A_EDITABLE<Esc>');e:wait('редактор принимает ввод',function() return e:lua('return vim.api.nvim_get_current_line()'):find('_EDITABLE',1,true)~=nil end)
      responsive(e)
    end,debug.traceback)
    if e then
      for _,path in ipairs(vim.fn.glob(e.runtime..'/cache/**/neogit.log',false,true)) do vim.uv.fs_copyfile(path,e.dir..'/neogit.log') end
      -- Даже на hit-enter сохранить исходную ошибку/экран и убрать свой runtime.
      local cwd_ok,cwd=pcall(e.lua,e,'return vim.fn.getcwd()')
      local observed={cwd=cwd_ok and cwd or tostring(cwd),worktrees=git(e.project,'worktree','list','--porcelain')}
      vim.fn.writefile({vim.json.encode(observed)},e.dir..'/worktree-observed.json')
      e:snapshot(name);io.stdout:write('  artifacts: '..e.dir..'\n');e:stop()
    end
    assert(ok,err)
  end)
end
check('IDE-GIT-7 чистый текущий worktree удаляется без force и следующий visit работает',false)
check('IDE-GIT-7 dirty cancel сохраняет файл, commit и повторное удаление работают',true)
T.finish()
