local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local env={GIT_CONFIG_NOSYSTEM='1',GIT_CONFIG_GLOBAL=vim.fn.has('win32')==1 and 'NUL' or '/dev/null',GIT_TERMINAL_PROMPT='0',LC_ALL='C'}
local function git(path,...)
  local args={'git','-C',path};vim.list_extend(args,{...})
  local r=vim.system(args,{text=true,env=env}):wait()
  assert(r.code==0,table.concat(args,' ')..'\n'..(r.stderr or '')..(r.stdout or ''))
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
local function picker(e,text)
  e:wait('picker готов',function() return e:current_ft()=='TelescopePrompt' and e.rpc:request('nvim_get_mode',{}).mode=='i' end)
  e:input(text)
  e:wait('picker выбрал '..text,function() return e:lua([[local s=require('telescope.actions.state');local v=s.get_selected_entry();return v and tostring(v[1]):find(...,1,true)~=nil]],{text}) end)
  e:input('<CR>')
end
local function errors(e)
  for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR or n.message==e.expected_error,n.message) end
end
local function acknowledge(e)
  local m=e.rpc:request('nvim_get_mode',{})
  if not m.blocking then return false end
  errors(e)
  assert(m.mode~='r?','Неожиданный confirm')
  local last=e.rpc.notifications[#e.rpc.notifications]
  assert(last and (last.message==e.expected_error or last.message=='Committed'),'Неожиданный hit-enter')
  local screen=e.rpc:screen_lines();assert(not table.concat(screen,'\n'):match('%f[%w]E%d+:'),'Нативная ошибка Neovim')
  e.evidence.prompts=e.evidence.prompts or {};e.evidence.prompts[#e.evidence.prompts+1]=screen;e:input('<CR>')
  return true
end
local function in_progress(e,kind)
  if kind=='merge' then return vim.fn.filereadable(e.project..'/.git/MERGE_HEAD')==1 end
  return vim.fn.isdirectory(e.project..'/.git/rebase-merge')==1 or vim.fn.isdirectory(e.project..'/.git/rebase-apply')==1
end
local function conflict(e,kind)
  focus(e,' wg','NeogitStatus')
  popup(e,kind=='merge' and 'm' or 'r',kind=='merge' and 'Merge' or 'Rebase')
  e:input(kind=='merge' and 'm' or 'e');picker(e,kind=='merge' and 'feature' or 'main')
  e:wait('настоящий Git конфликт',function() return in_progress(e,kind) and git(e.project,'ls-files','-u')~='' end,20000)
  e:wait('уведомление конфликта',function()
    e.rpc:request('nvim_get_mode',{});errors(e)
    if acknowledge(e) then return false end
    for _,n in ipairs(e.rpc.notifications) do if n.message==e.expected_error then return true end end
  end,15000)
  e:wait('status конфликта',function()
    if acknowledge(e) then return false end
    if e:current_ft()=='NeogitConsole' then e:input('q');return false end
    return e:current_ft()=='NeogitStatus' and e:lua([[return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n')]]):lower():find('unmerged',1,true)
  end,15000)
  e.evidence.conflicted={index=git(e.project,'ls-files','-u'),content=vim.fn.readfile(e.project..'/file_one.txt')}
  e:snapshot('conflict-status')
end
local function resolve(e,kind)
  e:input(' gd')
  e:wait('три diff окна загружены',function()
    return e:lua([[local view=require('diffview.lib').get_current_view();local count=0;local main,feature=false,false
      for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do if vim.wo[w].diff then
        count=count+1;local text=table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w),0,-1,false),'\n')
        main=main or text:find('MAIN_CONFLICT',1,true)~=nil;feature=feature or text:find('FEATURE_CONFLICT',1,true)~=nil
      end end;return view and view.cur_entry and view.cur_entry.opened and count==3 and main and feature]])
  end,15000)
  e.evidence.diff_windows=e:lua([[local out={};for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local b=vim.api.nvim_win_get_buf(w);out[#out+1]={win=w,file=vim.api.nvim_buf_get_name(b),pos=vim.api.nvim_win_get_position(w),diff=vim.wo[w].diff,
      readonly=vim.bo[b].readonly,modifiable=vim.bo[b].modifiable,buftype=vim.bo[b].buftype}
    end;return out]])
  local function editable()
    local state=e:lua([[return {file=vim.api.nvim_buf_get_name(0),buftype=vim.bo.buftype,modifiable=vim.bo.modifiable,readonly=vim.bo.readonly}]])
    e.evidence.after_alt_e=state
    return state.file:gsub('\\','/')==(e.project..'/file_one.txt'):gsub('\\','/') and state.buftype=='' and state.modifiable and not state.readonly
  end
  focus(e,' gF','DiffviewFiles');e:input('<A-e>')
  e:wait('Alt+e фокусирует writable результат',editable,5000)
  e.evidence.alt_e_from_panel=e.evidence.after_alt_e
  e:input('<A-l>');e:wait('правая версия',function() return e:lua([[return vim.bo.buftype=='nowrite' and not vim.bo.modifiable]]) end)
  e:input('<A-e>');e:wait('Alt+e возвращает результат из версии',editable,5000)
  e:input(']x'..(kind=='merge' and ' ct' or ' co'))
  local expected=kind=='merge' and 'FEATURE_CONFLICT' or 'MAIN_CONFLICT'
  e:wait('выбрана версия без markers',function()
    return e:lua([[local lines=vim.api.nvim_buf_get_lines(0,0,-1,false);return #lines==3 and lines[2]==...]],{expected})
  end)
  e:input(':w<CR>');e:wait('результат на диске',function() return vim.fn.readfile(e.project..'/file_one.txt')[2]==expected end)
  e:input(' gq');e:wait('diff закрыт',function() return e:lua([[return require('diffview.lib').get_current_view()==nil]]) end,10000)
  focus(e,' wg','NeogitStatus')
  e:wait('конфликтный файл в status',function() return e:lua([[return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n')]]):find('file_one.txt',1,true) end)
  e:input('gg/file_one.txt<CR>s')
  e:wait('stage удалил unmerged index',function() return git(e.project,'ls-files','-u')=='' end)
  popup(e,kind=='merge' and 'm' or 'r',kind=='merge' and 'Merge' or 'Rebase');e:input(kind=='merge' and 'm' or 'r')
  e:wait('continue открыл commit editor',function() return e:current_ft()=='gitcommit' and e:lua([[return vim.fn.maparg('ZZ','n',false,true).buffer==1]]) end,15000)
  e:input('<Esc>');e:wait('normal commit',function() return e.rpc:request('nvim_get_mode',{}).mode=='n' end);e:input('ZZ')
  e:wait('операция завершена',function() if acknowledge(e) then return false end;return not in_progress(e,kind) and git(e.project,'status','--porcelain')=='' end,20000)
  T.eq(vim.fn.readfile(e.project..'/file_one.txt'),{'header',expected,'tail'})
  T.eq(vim.fn.readfile(e.project..'/file_two.txt'),{'FEATURE_TWO_KEEP'})
  T.eq(git(e.project,'rev-parse','feature'),kind=='merge' and e.evidence.before.feature or git(e.project,'rev-parse','HEAD'))
  if kind=='merge' then
    T.eq(vim.split(git(e.project,'rev-list','--parents','-n','1','HEAD'),' '),{git(e.project,'rev-parse','HEAD'),e.evidence.before.main,e.evidence.before.feature})
  else
    T.eq(git(e.project,'rev-parse','HEAD^'),e.evidence.before.main);T.eq(git(e.project,'rev-parse','main'),e.evidence.before.main)
    T.eq(git(e.project,'log','-1','--format=%s'),'feature conflict commit')
  end
end
local function abort(e,kind)
  popup(e,kind=='merge' and 'm' or 'r',kind=='merge' and 'Merge' or 'Rebase');e:input('a')
  e:wait('confirm Abort',function() return e.rpc:request('nvim_get_mode',{}).mode=='r?' and table.concat(e.rpc:screen_lines(),'\n'):find('Abort',1,true) end)
  vim.fn.writefile(e.rpc:screen_lines(),e.dir..'/abort-confirm.txt');e:input('y')
  e:wait('abort завершён',function() if acknowledge(e) then return false end;return not in_progress(e,kind) end,15000)
  T.eq(git(e.project,'rev-parse','HEAD'),e.evidence.before.head);T.eq(git(e.project,'write-tree'),e.evidence.before.index)
  T.eq(git(e.project,'rev-parse','main'),e.evidence.before.main);T.eq(git(e.project,'rev-parse','feature'),e.evidence.before.feature)
  T.eq(vim.fn.readfile(e.project..'/file_one.txt'),e.evidence.before.one);T.eq(vim.fn.readfile(e.project..'/file_two.txt'),e.evidence.before.two)
  T.eq(git(e.project,'branch','--show-current'),kind=='merge' and 'main' or 'feature');T.eq(git(e.project,'status','--porcelain'),'')
end
local function check(kind,action)
  local name='IDE-GIT-11 '..kind..' '..action
  if vim.env.FORGE_GIT_CONFLICT_CASE and not name:find(vim.env.FORGE_GIT_CONFLICT_CASE,1,true) then return end
  T.check(name,function()
    local e
    local ok,err=pcall(function()
      e=require('editor').start(root,{timeout=180000,env=vim.tbl_extend('force',env,{NEOGIT_LOG_FILE='1',NEOGIT_LOG_LEVEL='trace'}),prepare=function(project,_,runtime)
        local hooks=runtime..'/empty-hooks';vim.fn.mkdir(hooks,'p')
        for k,v in pairs({['user.name']='Forge E2E',['user.email']='forge-e2e@example.invalid',['commit.gpgsign']='false',['tag.gpgsign']='false',['core.autocrlf']='false',['core.hooksPath']=hooks}) do git(project,'config',k,v) end
        git(project,'checkout','-b','main');vim.fn.writefile({'header','BASE_CONFLICT','tail'},project..'/file_one.txt')
        git(project,'add','.');git(project,'commit','-m','fixture baseline')
        git(project,'checkout','-b','feature');vim.fn.writefile({'header','FEATURE_CONFLICT','tail'},project..'/file_one.txt');vim.fn.writefile({'FEATURE_TWO_KEEP'},project..'/file_two.txt')
        git(project,'add','.');git(project,'commit','-m','feature conflict commit')
        git(project,'checkout','main');vim.fn.writefile({'header','MAIN_CONFLICT','tail'},project..'/file_one.txt');git(project,'add','.');git(project,'commit','-m','main conflict commit')
        if kind=='rebase' then git(project,'checkout','feature') end
      end})
      e.expected_error=kind=='merge' and 'Merging failed. Resolve conflicts before continuing' or 'Rebasing failed. Resolve conflicts before continuing'
      e.evidence={before={head=git(e.project,'rev-parse','HEAD'),main=git(e.project,'rev-parse','main'),feature=git(e.project,'rev-parse','feature'),index=git(e.project,'write-tree'),one=vim.fn.readfile(e.project..'/file_one.txt'),two=vim.fn.readfile(e.project..'/file_two.txt')}}
      e:wait('IDE готова',function() return e:lua('return _G.forge_e2e_observed') end,10000)
      e:input(':edit file_one.txt<CR>');e:wait('файл открыт',function() return e:current_file():sub(-12)=='file_one.txt' end)
      conflict(e,kind)
      if action=='resolve' then resolve(e,kind) else abort(e,kind) end
      focus(e,'<Esc>','text');T.eq(e:current_file():sub(-12),'file_one.txt');T.eq(e:lua('return vim.g.forge_e2e_installs'),0);errors(e)
    end)
    if e then
      e.evidence=e.evidence or {};e.evidence.after={head=git(e.project,'rev-parse','HEAD'),status=git(e.project,'status','--porcelain'),refs=git(e.project,'show-ref'),unmerged=git(e.project,'ls-files','-u')}
      vim.fn.writefile({vim.json.encode(e.evidence)},e.dir..'/git-conflict-observed.json')
      for _,path in ipairs(vim.fn.glob(e.runtime..'/cache/**/neogit.log',false,true)) do vim.uv.fs_copyfile(path,e.dir..'/neogit.log') end
      e:snapshot(name);io.stdout:write('  artifacts: '..e.dir..'\n');e:stop()
    end
    assert(ok,err)
  end)
end
for _,kind in ipairs({'merge','rebase'}) do for _,action in ipairs({'resolve','abort'}) do check(kind,action) end end
T.finish()
