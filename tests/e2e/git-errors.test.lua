local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local git_env={GIT_CONFIG_NOSYSTEM='1',GIT_CONFIG_GLOBAL=vim.fn.has('win32')==1 and 'NUL' or '/dev/null',GIT_TERMINAL_PROMPT='0',LC_ALL='C'}
local function run_git(path,...)
  local args={'git','-C',path};vim.list_extend(args,{...})
  return vim.system(args,{text=true,env=git_env}):wait()
end
local function git(path,...)
  local r=run_git(path,...);assert(r.code==0,r.stderr or r.stdout)
  return vim.trim(r.stdout or '')
end
local function focus(e,keys,ft)
  e:input(keys);e:wait('фокус '..ft,function()
    return e:current_ft()==ft and (not ft:match('^Neogit') or e:lua([[return vim.fn.maparg('q','n',false,true).buffer==1]]))
  end,10000)
end
local function popup(e,key,title)
  focus(e,key,'NeogitPopup')
  e:wait(title,function() return table.concat(e.rpc:screen_lines(),'\n'):find(title,1,true) end)
end
local function expected_error(e,message)
    local known=message==e.expected_error
    if e.expected_git_error and message:match('^fatal:') then
      -- PTY может склеить fatal и hint. Допускается только фрагмент настоящего
      -- независимого Git stderr этой fixture, а не произвольный fatal/ERROR.
      local normalized=message:gsub('%s','')
      known=known or ((normalized:find('doesnotappeartobeagitrepository',1,true) or normalized:find('Couldnotreadfromremoterepository.',1,true))
        and e.expected_git_error:find(normalized,1,true))
    end
    return known
end
local function errors(e)
  for _,n in ipairs(e.rpc.notifications) do
    assert(n.level<vim.log.levels.ERROR or expected_error(e,n.message),'Неожиданный ERROR: '..n.message)
  end
end
local function acknowledge(e)
  local mode=e.rpc:request('nvim_get_mode',{})
  if not mode.blocking then return false end
  assert(mode.mode~='r?','Неожиданный confirm')
  errors(e)
  local last=e.rpc.notifications[#e.rpc.notifications]
  assert(last and (expected_error(e,last.message) or last.message=='Committed'
    or last.message=='Pushing to origin/main' or last.message=='Pushed to origin/main'
    -- Neogit также публикует полный stdout как INFO. Он начинается с точной
    -- fatal строки этой fixture; все ERROR отдельно сверены с CLI stderr.
    or (last.level==vim.log.levels.INFO and e.expected_primary_fatal
      and last.message:sub(1,#e.expected_primary_fatal)==e.expected_primary_fatal)),
    'Блокировка без ожидаемого уведомления Git')
  local screen=e.rpc:screen_lines()
  assert(not table.concat(screen,'\n'):match('%f[%w]E%d+:'),'Нативная ошибка Neovim вместо ожидаемого Git notify')
  e.evidence.prompts=e.evidence.prompts or {}
  e.evidence.prompts[#e.evidence.prompts+1]=screen
  e:input('<CR>')
  return true
end
local function notice(e,predicate)
  e:wait('ожидаемое уведомление Git',function()
    e.rpc:request('nvim_get_mode',{})
    errors(e)
    if acknowledge(e) then return false end
    for _,n in ipairs(e.rpc.notifications) do if predicate(n.message) then return true end end
  end,20000)
  e:wait('настоящий push завершился',function()
    errors(e)
    if acknowledge(e) then return false end
    return e:lua([[for _,item in ipairs(require('neogit.lib.git').cli.history) do if item.cmd:match('%spush%s') and item.code~=nil then return true end end;return false]])
  end,10000)
end
local function status(e)
  e:wait('возврат в Git status',function()
    if acknowledge(e) then return false end
    if e:current_ft()=='NeogitConsole' then e:input('q');return false end
    return e:current_ft()=='NeogitStatus'
  end,10000)
end
local function commit(e,message)
  e:input(':edit file_one.txt<CR>')
  e:wait('исходный файл',function() return e:current_file():sub(-12)=='file_one.txt' end)
  e:input('gg0iLOCAL_PUSH_<Esc>:w<CR>')
  focus(e,' wg','NeogitStatus')
  e:wait('изменение в status',function() return e:lua([[return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n')]]):find('file_one.txt',1,true) end)
  e:input('gg/file_one.txt<CR>s')
  e:wait('staged',function() return git(e.project,'diff','--cached','--name-only')=='file_one.txt' end)
  popup(e,'c','Commit');e:input('c')
  e:wait('commit editor',function() return e:current_ft()=='gitcommit' and e:lua([[return vim.fn.maparg('ZZ','n',false,true).buffer==1]]) end,15000)
  e:input('<Esc>');e:wait('normal',function() return e.rpc:request('nvim_get_mode',{}).mode=='n' end)
  e:input('gg0i'..message..'<Esc>')
  e:wait('сообщение commit',function() return e:lua('return vim.api.nvim_buf_get_lines(0,0,1,false)[1]')==message end)
  e:input('ZZ')
  e:wait('настоящий commit',function() return git(e.project,'log','-1','--format=%s')==message end,20000)
  status(e)
  return git(e.project,'rev-parse','HEAD')
end
local function history(e,cause)
  status(e);focus(e,'$','NeogitGitCommandHistory')
  e:input('gg/push.*origin.*main<CR><Tab>')
  e:wait('причина видима в истории',function() return table.concat(e.rpc:screen_lines(),'\n'):find(cause,1,true) end,10000)
  e:snapshot('git-error-history')
  e.evidence.history=e:lua([[return vim.api.nvim_buf_get_lines(0,0,-1,false)]])
  focus(e,'q','NeogitStatus')
end
local function push(e)
  popup(e,'P','Push');e:input('u')
end
local function pushed(e,head)
  notice(e,function(s) return s=='Pushed to origin/main' end)
  e:wait('remote получил commit',function() return git(e.runtime..'/origin.git','rev-parse','refs/heads/main')==head end,20000)
  status(e)
  local commands=e:lua([[local out={};for _,item in ipairs(require('neogit.lib.git').cli.history) do
    if item.cmd:match('%spush%s') then out[#out+1]={cmd=item.cmd,code=item.code,stdout=item.stdout,stderr=item.stderr} end
  end;return out]])
  T.eq(#commands,2,'Ожидается один отказ и один явный retry')
  assert(commands[1].code~=0 and commands[2].code==0,'Не сохранены настоящий отказ и успешный retry')
  for _,item in ipairs(commands) do assert(not item.cmd:find('--force',1,true),'Обычный retry оказался force') end
  e.evidence.pushes=commands
end
local function check(name,fn)
  if vim.env.FORGE_GIT_ERRORS_CASE and not name:find(vim.env.FORGE_GIT_ERRORS_CASE,1,true) then return end
  T.check(name,function()
    local e
    local ok,err=pcall(function()
      e=require('editor').start(root,{timeout=150000,env=vim.tbl_extend('force',git_env,{NEOGIT_LOG_FILE='1',NEOGIT_LOG_LEVEL='trace'}),prepare=function(project,env,runtime)
        local hooks=runtime..'/empty-hooks';vim.fn.mkdir(hooks,'p')
        for k,v in pairs({['user.name']='Forge E2E',['user.email']='forge-e2e@example.invalid',['commit.gpgsign']='false',['tag.gpgsign']='false',['core.autocrlf']='false',['core.hooksPath']=hooks,['pull.rebase']='false'}) do git(project,'config',k,v) end
        git(project,'checkout','-b','main');git(project,'add','.');git(project,'commit','-m','fixture baseline')
        git(runtime,'init','--bare',runtime..'/origin.git');git(project,'remote','add','origin',runtime..'/origin.git');git(project,'push','-u','origin','main')
      end})
      e.evidence={}
      e:wait('IDE готова',function() return e:lua('return _G.forge_e2e_observed') end,10000)
      fn(e)
      T.eq(e:lua('return vim.g.forge_e2e_installs'),0);errors(e)
    end)
    if e then
      e.evidence=e.evidence or {}
      for label,args in pairs({status={'status','--porcelain'},log={'log','--all','--oneline'},refs={'show-ref'},remote={'ls-remote','origin'}}) do
        local r=run_git(e.project,unpack(args));e.evidence[label]={code=r.code,stdout=r.stdout,stderr=r.stderr}
      end
      vim.fn.writefile({vim.json.encode(e.evidence)},e.dir..'/git-error-observed.json')
      for _,path in ipairs(vim.fn.glob(e.runtime..'/cache/**/neogit.log',false,true)) do vim.uv.fs_copyfile(path,e.dir..'/neogit.log') end
      e:snapshot(name);io.stdout:write('  artifacts: '..e.dir..'\n');e:stop()
    end
    assert(ok,err)
  end)
end

check('IDE-GIT-10 rejected push сохраняет обе истории и принимает обычный retry',function(e)
  local local_head=commit(e,'local rejected commit')
  local peer=e.runtime..'/peer clone'
  git(e.runtime,'clone','--branch','main',e.runtime..'/origin.git',peer)
  git(peer,'config','user.name','Forge Peer');git(peer,'config','user.email','peer@example.invalid');git(peer,'config','commit.gpgsign','false')
  vim.fn.writefile({'REMOTE_PEER_KEEP'},peer..'/file_two.txt');git(peer,'add','file_two.txt');git(peer,'commit','-m','independent peer commit');git(peer,'push','origin','main')
  local remote_head=git(peer,'rev-parse','HEAD')
  local content=vim.fn.readfile(e.project..'/file_one.txt')
  local index=git(e.project,'write-tree')
  e.evidence.before={local_head=local_head,remote_head=remote_head,index=index,content=content}
  e.expected_error='Failed to push to origin/main'
  push(e)
  e:wait('предложение force',function() return e.rpc:request('nvim_get_mode',{}).mode=='r?' and table.concat(e.rpc:screen_lines(),'\n'):find('force push with lease',1,true) end,20000)
  vim.fn.writefile(e.rpc:screen_lines(),e.dir..'/declined-force-prompt.txt');e:input('n')
  notice(e,function(s) return s==e.expected_error end)
  T.eq(git(e.project,'rev-parse','HEAD'),local_head);T.eq(git(e.runtime..'/origin.git','rev-parse','refs/heads/main'),remote_head)
  T.eq(git(e.project,'write-tree'),index);T.eq(vim.fn.readfile(e.project..'/file_one.txt'),content);T.eq(git(e.project,'status','--porcelain'),'')
  history(e,'[rejected]')
  -- Подготовка retry согласует fixture явно. UI merge/conflicts — отдельный этап.
  git(e.project,'fetch','origin');git(e.project,'merge','--no-edit','origin/main')
  local merged=git(e.project,'rev-parse','HEAD')
  git(e.project,'merge-base','--is-ancestor',local_head,merged);git(e.project,'merge-base','--is-ancestor',remote_head,merged)
  e:input('<C-r>');e:wait('status увидел merge',function() return e:lua([[return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n')]]):find(merged:sub(1,7),1,true) end,15000)
  push(e);pushed(e,merged)
  T.eq(git(e.project,'status','--porcelain'),'');T.eq(vim.fn.readfile(e.project..'/file_two.txt'),{'REMOTE_PEER_KEEP'})
  focus(e,'<Esc>','text');T.eq(e:current_file():sub(-12),'file_one.txt')
end)

check('IDE-GIT-10 недоступный remote сохраняет commit и повторяет push после исправления',function(e)
  local head=commit(e,'local unavailable remote commit')
  local remote_head=git(e.runtime..'/origin.git','rev-parse','refs/heads/main')
  local content=vim.fn.readfile(e.project..'/file_one.txt')
  git(e.project,'remote','set-url','origin',e.runtime..'/missing remote.git')
  local oracle=run_git(e.project,'push','origin','main')
  assert(oracle.code==128 and oracle.stderr:find('does not appear to be a git repository',1,true))
  e.expected_error='Failed to push to origin/main'
  e.expected_git_error=(oracle.stdout..oracle.stderr):gsub('%s','');e.evidence.cli_error=oracle
  e.expected_primary_fatal=oracle.stderr:match('([^\r\n]+)')
  push(e)
  notice(e,function(s) return s:find('does not appear to be a git repository',1,true) end)
  T.eq(git(e.project,'rev-parse','HEAD'),head);T.eq(git(e.runtime..'/origin.git','rev-parse','refs/heads/main'),remote_head)
  T.eq(vim.fn.readfile(e.project..'/file_one.txt'),content);T.eq(git(e.project,'status','--porcelain'),'')
  history(e,'does not appear to be a git repository')
  focus(e,'<Esc>','text');T.eq(e:current_file():sub(-12),'file_one.txt')
  git(e.project,'remote','set-url','origin',e.runtime..'/origin.git')
  focus(e,' wg','NeogitStatus');push(e);pushed(e,head)
  T.eq(git(e.project,'rev-parse','HEAD'),head);T.eq(git(e.project,'status','--porcelain'),'')
  focus(e,'<Esc>','text')
end)
T.finish()
