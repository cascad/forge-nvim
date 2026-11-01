local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local function norm(p) return vim.fs.normalize(p):gsub('\\','/') end
local function git(path,...)
  local args={'git','-C',path};vim.list_extend(args,{...})
  local r=vim.system(args,{text=true,env={GIT_CONFIG_NOSYSTEM='1',GIT_CONFIG_GLOBAL=vim.fn.has('win32')==1 and 'NUL' or '/dev/null'}}):wait()
  assert(r.code==0,(r.stderr or '')..' '..table.concat(args,' '));return vim.trim(r.stdout)
end
local function clean(e)
  for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
  local mode=e.rpc:request('nvim_get_mode',{})
  assert(not mode.blocking and mode.mode~='r?','неожиданный prompt: '..table.concat(e.rpc:screen_lines(),'\n'))
  assert(not e:lua("return vim.fn.execute('messages')"):find('stack traceback',1,true),'async traceback')
end
local function quiet(e)
  -- Готовность/доставка Git проверяется отдельно; наблюдаем поздние ошибки.
  local until_ns=vim.uv.hrtime()+500000000
  repeat clean(e);vim.wait(25) until vim.uv.hrtime()>=until_ns
end
local function focus(e,keys,ft)
  e:input(keys);e:wait('фокус '..ft,function() return e:current_ft()==ft end,10000)
end
local function head(e,branch)
  return e:lua([[local branch=...;for _,line in ipairs(vim.api.nvim_buf_get_lines(0,0,-1,false)) do
    if line:match('^Head:%s+%x+%s+'..vim.pesc(branch)..'%s') then return true end end;return false]],{branch})
end
local function ready(e,branch,subject,other)
  e:wait('готовый Head/recent '..branch,function()
    local text=e:lua('return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),"\\n")')
    return e:current_ft()=='NeogitStatus' and head(e,branch) and text:find(subject,1,true) and not text:find(other,1,true)
  end,15000)
end
local function visit(e,label,path)
  focus(e,'w','NeogitPopup');e:input('g')
  e:wait('picker готов',function() return e:current_ft()=='TelescopePrompt' and e.rpc:request('nvim_get_mode',{}).mode=='i' end)
  e:input(label)
  e:wait('worktree выбран',function()
    return e:lua([[local text=...;local s=require('telescope.actions.state');local p=s.get_current_picker(vim.api.nvim_get_current_buf());local v=s.get_selected_entry();
      return v and p:_get_prompt()==text and tostring(v[1]):find(text,1,true)~=nil]],{label})
  end)
  e:input('<CR>')
  -- Перед следующим visit ждём только cwd/готовый ввод, не окончание Git.
  e:wait('cwd '..label,function() return e:current_ft()=='NeogitStatus' and norm(e:lua('return vim.fn.getcwd()'))==norm(path) end)
end
local function observed(path)
  return {head=git(path,'rev-parse','HEAD'),status=git(path,'status','--porcelain'),
    index=git(path,'diff','--cached'),one=vim.fn.readfile(path..'/file_one.txt'),two=vim.fn.readfile(path..'/file_two.txt')}
end
local function check(name,options,fn)
  if vim.env.FORGE_WORKTREE_E2E_CASE and not name:find(vim.env.FORGE_WORKTREE_E2E_CASE,1,true) then return end
  T.check(name,function()
    local e,linked,gate,before
    local ok,err=pcall(function()
      e=require('editor').start(root,{env={GIT_CONFIG_NOSYSTEM='1',GIT_CONFIG_GLOBAL=vim.fn.has('win32')==1 and 'NUL' or '/dev/null',NEOGIT_LOG_FILE='1',NEOGIT_LOG_LEVEL='trace'},prepare=function(project,env,runtime)
        for k,v in pairs({['user.name']='Forge E2E',['user.email']='forge-e2e@example.invalid',['commit.gpgsign']='false',['core.autocrlf']='false'}) do git(project,'config',k,v) end
        vim.fn.mkdir(runtime..'/empty-hooks','p');git(project,'config','core.hooksPath',runtime..'/empty-hooks')
        git(project,'checkout','-b','main');git(project,'add','.');git(project,'commit','-m','COMMON_BASELINE')
        linked=runtime..'/linked worktree';git(project,'worktree','add','-b','forge-refresh-linked',linked)
        vim.fn.writefile({'LINKED_COMMIT_FILE'},linked..'/file_one.txt');git(linked,'add','.');git(linked,'commit','-m','LINKED_UNIQUE_HEAD')
        vim.fn.writefile({'MAIN_COMMIT_FILE'},project..'/file_one.txt');git(project,'add','.');git(project,'commit','-m','MAIN_UNIQUE_HEAD')
        for path,content in pairs({[project]='MAIN_STAGED_KEEP',[linked]='LINKED_STAGED_KEEP'}) do
          vim.fn.writefile({content},path..'/file_two.txt');git(path,'add','file_two.txt')
        end
        before={main=observed(project),linked=observed(linked)}
        if options.gate then
          gate=runtime..'/git-gate';vim.fn.mkdir(gate,'p');vim.fn.writefile({vim.json.encode(linked)},gate..'/target.json')
          local py=vim.fn.exepath(vim.fn.has('win32')==1 and 'python' or 'python3');assert(py~='','Нужен Python для real Git gate')
          local real=vim.fn.exepath('git');local script=root..'/tests/e2e/neogit_git_gate.py'
          local wrapper=runtime..'/git-proxy'..(vim.fn.has('win32')==1 and '.exe' or '')
          if vim.fn.has('win32')==1 then
            local built=vim.system({'powershell.exe','-NoProfile','-File',root..'/tests/e2e/build_git_proxy.ps1','-Output',wrapper},{text=true}):wait()
            assert(built.code==0,built.stderr)
            vim.fn.writefile({py,'-B',script,real,gate},runtime..'/git-proxy.args')
          else
            local args={py,'-B',script,real,gate};for i,v in ipairs(args) do args[i]=vim.fn.shellescape(v) end
            vim.fn.writefile({'#!/bin/sh','exec '..table.concat(args,' ')..' "$@"'},wrapper);assert(vim.uv.fs_chmod(wrapper,448))
          end
          vim.fn.writefile({'return {{"NeogitOrg/neogit",opts={git_executable='..vim.inspect(wrapper)..'}}}'},env.FORGE_E2E_CONFIG..'/lua/plugins/zz_e2e_neogit_gate.lua')
        end
      end})
      e.linked,e.gate=linked,gate
      e:wait('IDE готова',function() return e:lua('return _G.forge_e2e_observed') end,10000)
      e:input(':edit file_one.txt<CR>')
      e:wait('файл открыт',function() return norm(e:current_file())==norm(e.project..'/file_one.txt') end)
      focus(e,options.tab and ' gg' or ' wg','NeogitStatus')
      ready(e,'main','MAIN_UNIQUE_HEAD','LINKED_UNIQUE_HEAD')
      e:lua([[vim.g.forge_worktree_refreshed=0;vim.api.nvim_create_autocmd('User',{pattern='NeogitStatusRefreshed',callback=function() vim.g.forge_worktree_refreshed=vim.g.forge_worktree_refreshed+1 end})]])
      fn(e);clean(e)
      T.eq(observed(e.project),before.main,'main не изменён');T.eq(observed(linked),before.linked,'linked не изменён')
      T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
    end)
    if e then
      local saved,after=pcall(function() return {main=observed(e.project),linked=observed(linked)} end)
      vim.fn.writefile({vim.json.encode({before=before,after=saved and after or tostring(after)})},e.dir..'/git-observed.json')
      if gate then
        vim.fn.writefile({},gate..'/release')
        for _,p in ipairs(vim.fn.glob(gate..'/*',false,true)) do if vim.fn.filereadable(p)==1 then vim.uv.fs_copyfile(p,e.dir..'/'..vim.fn.fnamemodify(p,':t')) end end
      end
      for _,p in ipairs(vim.fn.glob(e.runtime..'/cache/**/neogit.log',false,true)) do vim.uv.fs_copyfile(p,e.dir..'/neogit.log') end
      e:snapshot(name);io.stdout:write('  artifacts: '..e.dir..'\n');e:stop()
    end
    assert(ok,err)
  end)
end
local function log_check(e,subject,other)
  focus(e,'l','NeogitPopup');focus(e,'l','NeogitLogView')
  e:wait('история последнего worktree',function()
    local text=e:lua('return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),"\\n")')
    return text:find(subject,1,true) and text:find('COMMON_BASELINE',1,true) and not text:find(other,1,true)
  end)
  e:snapshot('history-'..subject)
  focus(e,'q','NeogitStatus')
end
local function held_visit(e)
  visit(e,'linked worktree',e.linked)
  e:wait('реальный linked log захвачен и удерживается',function() return #vim.fn.glob(e.gate..'/started-*.json',false,true)>0 end,15000)
  for _,p in ipairs(vim.fn.glob(e.gate..'/started-*.json',false,true)) do
    T.eq(vim.json.decode(table.concat(vim.fn.readfile(p),'\n')).code,0,'gate захватил успешный настоящий Git')
  end
  T.eq(head(e,'forge-refresh-linked'),false,'не ждём завершения linked history')
  T.eq(e:lua([[-- Только наблюдение за конкретным старым refresh, без вызова действий.
    _G.forge_worktree_pending=require('neogit.lib.git').repo._refresh_task
    return _G.forge_worktree_pending~=nil and not _G.forge_worktree_pending:done()]]),true)
  e:snapshot('linked-history-held')
  visit(e,'project',e.project)
  ready(e,'main','MAIN_UNIQUE_HEAD','LINKED_UNIQUE_HEAD')
  vim.fn.writefile({},e.gate..'/release')
  e:wait('захваченный Git output выдан после release',function()
    return #vim.fn.glob(e.gate..'/done-*.json',false,true)>0
  end,10000)
  for _,p in ipairs(vim.fn.glob(e.gate..'/done-*.json',false,true)) do
    T.eq(vim.json.decode(table.concat(vim.fn.readfile(p),'\n')).code,0)
  end
  e:wait('старый refresh завершился без ошибки',function()
    clean(e);return e:lua('return _G.forge_worktree_pending:done()')
  end,15000)
  local completion=e:lua([[return {done=_G.forge_worktree_pending:done(),cancelled=_G.forge_worktree_pending:cancelled(),refreshed=vim.g.forge_worktree_refreshed}]])
  vim.fn.writefile({vim.json.encode(completion)},e.dir..'/refresh-completion.json')
  ready(e,'main','MAIN_UNIQUE_HEAD','LINKED_UNIQUE_HEAD')
  T.eq(norm(e:lua('return vim.fn.getcwd()')),norm(e.project))
  log_check(e,'MAIN_UNIQUE_HEAD','LINKED_UNIQUE_HEAD')
  visit(e,'linked worktree',e.linked);ready(e,'forge-refresh-linked','LINKED_UNIQUE_HEAD','MAIN_UNIQUE_HEAD')
  log_check(e,'LINKED_UNIQUE_HEAD','MAIN_UNIQUE_HEAD')
  quiet(e)
end
check('IDE-GIT-6 pending log и быстрый visit в боковой панели',{gate=true},held_visit)
check('IDE-GIT-6 pending log и быстрый visit в полном tab',{gate=true,tab=true},held_visit)
check('IDE-GIT-6 серия visit без gate и повторное открытие',{gate=false},function(e)
  T.eq(e:lua('return require("neogit.config").values.git_executable'),'git','настоящий Git без proxy')
  for _=1,4 do visit(e,'linked worktree',e.linked);visit(e,'project',e.project) end
  ready(e,'main','MAIN_UNIQUE_HEAD','LINKED_UNIQUE_HEAD')
  log_check(e,'MAIN_UNIQUE_HEAD','LINKED_UNIQUE_HEAD')
  focus(e,' wq','text');focus(e,' wg','NeogitStatus')
  ready(e,'main','MAIN_UNIQUE_HEAD','LINKED_UNIQUE_HEAD')
  quiet(e)
end)
T.finish()
