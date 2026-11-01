local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local function git(path,...)
  local argv={'git','-C',path};vim.list_extend(argv,{...})
  local r=vim.system(argv,{text=true,env={GIT_CONFIG_NOSYSTEM='1',GIT_CONFIG_GLOBAL=vim.fn.has('win32')==1 and 'NUL' or '/dev/null'}}):wait()
  assert(r.code==0,r.stderr);return vim.trim(r.stdout)
end
local function marks(e,kind) return vim.fn.glob(e.gate..'/'..kind..'-*.json',false,true) end
local function geometry(e)
  return e:lua([[local out={};for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    out[#out+1]={id=w,buf=vim.api.nvim_win_get_buf(w),pos=vim.api.nvim_win_get_position(w),width=vim.api.nvim_win_get_width(w),height=vim.api.nvim_win_get_height(w),diff=vim.wo[w].diff,scrollbind=vim.wo[w].scrollbind} end;return out]])
end
local function clean(e)
  for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
  local mode=e.rpc:request('nvim_get_mode',{})
  assert(not mode.blocking and mode.mode~='r?','неожиданный hit-enter/confirm: '..table.concat(e.rpc:screen_lines(),'\n'))
  assert(not e:lua("return vim.fn.execute('messages')"):find('stack traceback',1,true),'async traceback в messages')
end
local function release(e)
  vim.fn.writefile({},e.gate..'/release')
  e:wait('реальный git show завершён',function() return #marks(e,'done')==#marks(e,'started') and #marks(e,'done')>0 end,10000)
  for _,p in ipairs(marks(e,'done')) do T.eq(vim.json.decode(table.concat(vim.fn.readfile(p),'\n')).code,0) end
end
local function quiet(e)
  -- Проверка отсутствия ПОЗДНИХ ошибок после реального завершения процесса.
  -- Readiness Git/view проверяется отдельно, это не sleep вместо загрузки.
  local until_ns=vim.uv.hrtime()+400000000
  repeat clean(e);vim.wait(20) until vim.uv.hrtime()>=until_ns
end
local function history_loading(e)
  local count=#marks(e,'started')
  e:input(' gD')
  e:wait('real git show ожидает release',function() return #marks(e,'started')>count end,15000)
  T.eq(e:has_window('DiffviewFileHistory'),true)
  T.eq(e:lua([[local v=require('diffview.lib').get_current_view();return v and v.cur_entry and not v.cur_entry.opened]]),true)
end
local function check(name,fn,options)
  options=options or {}
  if vim.env.FORGE_DIFFVIEW_E2E_CASE and not name:find(vim.env.FORGE_DIFFVIEW_E2E_CASE,1,true) then return end
  T.check(name,function()
    local e
    local ok,err=pcall(function()
      local gate
      e=require('editor').start(root,{env={GIT_CONFIG_NOSYSTEM='1',GIT_CONFIG_GLOBAL=vim.fn.has('win32')==1 and 'NUL' or '/dev/null'},prepare=function(project,env,runtime)
        gate=runtime..'/git-gate';vim.fn.mkdir(gate,'p')
        git(project,'config','user.name','Forge E2E');git(project,'config','user.email','forge-e2e@example.invalid')
        git(project,'config','commit.gpgsign','false');git(project,'config','core.autocrlf','false')
        vim.fn.mkdir(runtime..'/empty-hooks','p');git(project,'config','core.hooksPath',runtime..'/empty-hooks')
        local lines={};for i=1,40 do lines[i]='line '..i end;vim.fn.writefile(lines,project..'/file_one.txt')
        git(project,'add','.');git(project,'commit','-m','history baseline')
        local python=vim.fn.exepath(vim.fn.has('win32')==1 and 'python' or 'python3')
        assert(python~='','Для Git gate нужен Python')
        local command={python,'-B',root..'/tests/e2e/git_gate.py',vim.fn.exepath('git'),gate}
        -- Дополняется только private конфиг через публичную опцию Diffview.
        if options.gate~=false then
          vim.fn.writefile(vim.split('return {{"sindrets/diffview.nvim", opts = {git_cmd = '..vim.inspect(command)..'}}}', '\n'),env.FORGE_E2E_CONFIG..'/lua/plugins/zz_e2e_git_gate.lua')
        end
      end})
      e.gate=gate
      e:wait('IDE готова',function() return e:lua('return _G.forge_e2e_observed') end,10000)
      e:input(':edit file_one.txt<CR>17G')
      e:wait('исходный файл и курсор',function() return e:current_file():find('file_one.txt',1,true) and e:lua('return vim.api.nvim_win_get_cursor(0)[1]')==17 end)
      e:lua([[vim.g.forge_diff_opened=0;vim.g.forge_diff_closed=0
        vim.api.nvim_create_autocmd('User',{pattern='DiffviewViewOpened',callback=function() vim.g.forge_diff_opened=vim.g.forge_diff_opened+1 end})
        vim.api.nvim_create_autocmd('User',{pattern='DiffviewViewClosed',callback=function() vim.g.forge_diff_closed=vim.g.forge_diff_closed+1 end})]])
      fn(e);clean(e)
      T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
    end)
    if e then
      if e.gate then
        vim.fn.writefile({},e.gate..'/release')
        for _,p in ipairs(vim.fn.glob(e.gate..'/*.json',false,true)) do vim.uv.fs_copyfile(p,e.dir..'/'..vim.fn.fnamemodify(p,':t')) end
      end
      e:snapshot(name);io.stdout:write('  artifacts: '..e.dir..'\n');e:stop()
    end
    assert(ok,err)
  end)
end

check('IDE-GIT-5 Space g q во время real git show и повторное открытие',function(e)
  e:input(':vsplit file_two.txt<CR>:vertical resize 42<CR>:wincmd h<CR>')
  e:wait('два неравных окна кода',function() return e:current_file():find('file_one.txt',1,true) and #geometry(e)==2 end)
  local source=e:lua('return vim.api.nvim_get_current_tabpage()')
  local before=geometry(e)
  history_loading(e)
  e:snapshot('loading-before-close')
  e:input(' gq')
  e:wait('возврат без release Git',function() return e:lua('return vim.api.nvim_get_current_tabpage()')==source end,2000)
  T.eq(geometry(e),before)
  e:input(':DiffviewClose<CR>') -- повтор из кода не закрывает его окно
  release(e)
  e:wait('просмотр очищен',function() clean(e);return e:lua('return #vim.api.nvim_list_tabpages()')==1 end)
  quiet(e);T.eq(geometry(e),before)
  T.eq(e:lua('return vim.api.nvim_win_get_cursor(0)[1]'),17)
  e:input(' gD')
  e:wait('история повторно загружена',function() return e:lua([[local v=require('diffview.lib').get_current_view();return v and v.cur_entry and v.cur_entry.opened]]) end,15000)
  e:input(' gq');e:wait('повтор закрыт',function() return e:lua('return #vim.api.nvim_list_tabpages()')==1 end)
end)

check('IDE-GIT-5 q F4 Alt-w и DiffviewClose во время загрузки',function(e)
  local source=e:lua('return vim.api.nvim_get_current_tabpage()')
  for _,key in ipairs({'q','<F4>','<A-w>',':DiffviewClose!<CR>'}) do
    if vim.fn.filereadable(e.gate..'/release')==1 then assert(vim.uv.fs_unlink(e.gate..'/release')) end
    history_loading(e)
    e:input(key)
    e:wait('возврат '..key,function() return e:lua('return vim.api.nvim_get_current_tabpage()')==source end,2000)
    release(e)
    e:wait('очищен '..key,function() clean(e);return e:lua('return #vim.api.nvim_list_tabpages()')==1 end)
    quiet(e)
  end
end)

check('IDE-GIT-5 поздняя очистка не закрывает другой diff',function(e)
  e:input(':edit file_two.txt<CR>gg0iOTHER_<Esc>:w<CR>:edit file_one.txt<CR>17G')
  e:wait('исходный файл',function() return e:current_file():find('file_one.txt',1,true) end)
  history_loading(e)
  local old=e:lua('return vim.api.nvim_get_current_tabpage()')
  e:input(' gq')
  e:wait('код до окончания Git',function() return e:current_ft()=='text' end,2000)
  e:input(':DiffviewOpen -- file_two.txt<CR>')
  e:wait('другой diff открыт',function() return e:lua([[local v=require('diffview.lib').get_current_view();return v~=nil]]) end,15000)
  local new=e:lua('return vim.api.nvim_get_current_tabpage()')
  assert(new~=old)
  release(e)
  e:wait('старый просмотр очищен',function() clean(e);return not e:lua('return vim.api.nvim_tabpage_is_valid(...)',{old}) end)
  e:wait('другой diff готов',function() return e:lua([[local v=require('diffview.lib').get_current_view();return v and v.cur_entry and v.cur_entry.opened]]) end,15000)
  quiet(e);T.eq(e:lua('return vim.api.nvim_get_current_tabpage()'),new)
  T.eq(e:lua('return #vim.api.nvim_list_tabpages()'),2)
  e:input(' gq');e:wait('другой diff закрыт пользователем',function() return e:lua('return #vim.api.nvim_list_tabpages()')==1 end)
end)

check('IDE-GIT-5 немедленное закрытие до первой версии и пустой diff',function(e)
  vim.fn.writefile({},e.gate..'/release')
  for _=1,3 do
    local opened=e:lua('return vim.g.forge_diff_opened')
    e:input(' gD gq')
    e:wait('раннее закрытие',function() clean(e);return e:lua([[local n=...;return vim.g.forge_diff_opened>n and vim.g.forge_diff_closed>n and #vim.api.nvim_list_tabpages()==1]],{opened}) end,15000)
    quiet(e)
  end
  local opened=e:lua('return vim.g.forge_diff_opened')
  e:input(' gd gq')
  e:wait('пустой diff закрыт',function() clean(e);return e:lua([[local n=...;return vim.g.forge_diff_opened>n and vim.g.forge_diff_closed>n and #vim.api.nvim_list_tabpages()==1]],{opened}) end)
  quiet(e)
  T.eq(e:lua([[return require('diffview.config').get_config().git_cmd]]),{'git'})
end,{gate=false})

check('IDE-GIT-5 повторная история того же файла до окончания старой загрузки',function(e)
  history_loading(e)
  local old=e:lua('return vim.api.nvim_get_current_tabpage()')
  e:input(' gq')
  e:wait('код после первого close',function() return e:current_ft()=='text' end,2000)
  e:input(' gD')
  e:wait('новая история открыта',function() return e:lua([[local old=...;local v=require('diffview.lib').get_current_view();return v and v.tabpage~=old]],{old}) end,15000)
  local new=e:lua('return vim.api.nvim_get_current_tabpage()')
  release(e)
  e:wait('старый view закрыт, данные нового сохранены',function()
    clean(e)
    return e:lua([[local old,new=...;if vim.api.nvim_tabpage_is_valid(old) or vim.api.nvim_get_current_tabpage()~=new then return false end
      for _,w in ipairs(vim.api.nvim_tabpage_list_wins(new)) do local b=vim.api.nvim_win_get_buf(w)
        if vim.wo[w].diff and vim.api.nvim_buf_get_lines(b,0,1,false)[1]=='line 1' then return true end end;return false]],{old,new})
  end,10000)
  quiet(e);T.eq(e:lua('return #vim.api.nvim_list_tabpages()'),2)
  e:input(' gq');e:wait('новая история закрыта пользователем',function() return e:lua('return #vim.api.nvim_list_tabpages()')==1 end)
end)

check('IDE-GIT-5 закрытие diff изменений во время загрузки версии',function(e)
  e:input('gg0iCHANGED_<Esc>:w<CR> gd')
  e:wait('diff ожидает настоящий git show',function() return #marks(e,'started')>0 end,15000)
  T.eq(e:has_window('DiffviewFiles'),true)
  e:input('q')
  e:wait('код до завершения Git',function() return e:current_ft()=='text' and e:current_file():find('file_one.txt',1,true) end,2000)
  release(e)
  e:wait('diff очищен',function() clean(e);return e:lua('return #vim.api.nvim_list_tabpages()')==1 end)
  quiet(e)
  T.eq(vim.fn.readfile(e.project..'/file_one.txt')[1],'CHANGED_line 1')
end)

check('IDE-GIT-5 Explorer открывается в исходном tab пока история загружается',function(e)
  local source=e:lua('return vim.api.nvim_get_current_tabpage()')
  history_loading(e);e:input(' e')
  e:wait('Explorer в исходном tab',function() return e:lua('return vim.api.nvim_get_current_tabpage()')==source and e:has_window('neo-tree') end)
  release(e)
  e:wait('закрытая история очищена',function() clean(e);return e:lua('return #vim.api.nvim_list_tabpages()')==1 end)
  quiet(e);T.eq(e:has_window('neo-tree'),true)
  T.eq(e:lua([[for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do if vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w)):find('file_one.txt',1,true) then return true end end;return false]]),true)
end)
T.finish()
