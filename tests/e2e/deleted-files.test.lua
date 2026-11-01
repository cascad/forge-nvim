-- Реальный Git/Neogit и native checktime, без подмены backend результатов.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local function norm(p) return vim.fs.normalize(p):gsub('\\','/') end
local function git(path,...)
  local argv={'git','-C',path};vim.list_extend(argv,{...})
  local r=vim.system(argv,{text=true,env={GIT_CONFIG_NOSYSTEM='1',GIT_CONFIG_GLOBAL=vim.fn.has('win32')==1 and 'NUL' or '/dev/null'}}):wait()
  assert(r.code==0,(r.stderr or '')..' '..table.concat(argv,' '));return vim.trim(r.stdout or '')
end
local function focus(e,keys,ft)
  e:input(keys);e:wait('фокус '..ft,function() return e:current_ft()==ft end,10000)
end
local function picker(e,text)
  e:wait('picker принимает ввод',function() return e:current_ft()=='TelescopePrompt' and e.rpc:request('nvim_get_mode',{}).mode=='i' end)
  e:input(text)
  e:wait('worktree выбран',function() return e:lua([[local text=...;local s=require('telescope.actions.state');local p=s.get_current_picker(vim.api.nvim_get_current_buf());local v=s.get_selected_entry();return v and p:_get_prompt()==text and tostring(v[1]):find(text,1,true)~=nil]],{text}) end)
  e:input('<CR>')
end
local function checktime(e,buf)
  e.checked=(e.checked or 0)+1
  e:input(':checktime '..(buf or '')..' | let g:forge_checked='..e.checked..'<CR>')
  e:wait('checktime завершён',function() return e:lua('return vim.g.forge_checked')==e.checked end)
end
local function responsive(e)
  local mode=e.rpc:request('nvim_get_mode',{})
  assert(not mode.blocking and mode.mode~='r?','неожиданный prompt: '..table.concat(e.rpc:screen_lines(),'\n'))
  local messages=e:lua([[return vim.fn.execute('messages')..'\n'..vim.v.errmsg]])
  assert(not messages:find('E211',1,true),messages)
  assert(not messages:find('stack traceback',1,true),messages)
  for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
end
local function check(name,fn)
  if vim.env.FORGE_DELETED_E2E_CASE and not name:find(vim.env.FORGE_DELETED_E2E_CASE,1,true) then return end
  T.check(name,function()
    local e,linked
    local ok,err=pcall(function()
      e=require('editor').start(root,{env={GIT_CONFIG_NOSYSTEM='1',GIT_CONFIG_GLOBAL=vim.fn.has('win32')==1 and 'NUL' or '/dev/null',GIT_TERMINAL_PROMPT='0'},prepare=function(project,_,runtime)
        for k,v in pairs({['user.name']='Fixture',['user.email']='fixture@example.invalid',['commit.gpgsign']='false',['core.autocrlf']='false'}) do git(project,'config',k,v) end
        git(project,'checkout','-b','main')
        for n=1,12 do vim.fn.writefile({'preserved '..n},project..'/gone'..n..'.txt') end
        git(project,'add','.');git(project,'commit','-m','deleted files baseline')
        linked=runtime..'/linked with space';git(project,'worktree','add','-b','linked',linked)
      end})
      e:wait('IDE готова',function() return e:lua('return _G.forge_e2e_observed') end,10000)
      e:input(':edit file_one.txt<CR>');e:wait('главный файл',function() return e:current_ft()=='text' end)
      fn(e,linked)
      responsive(e)
    end)
    if e then
      local good,list=pcall(git,e.project,'worktree','list','--porcelain')
      vim.fn.writefile({good and list or tostring(list)},e.dir..'/worktrees.txt')
      local history_ok,history=pcall(function() return e:lua([[return package.loaded.fidget and require('fidget').notification.get_history() or {}]]) end)
      vim.fn.writefile({vim.json.encode(history_ok and history or {error=tostring(history)})},e.dir..'/file-notifications.json')
      e:snapshot(name);io.stdout:write('  artifacts: '..e.dir..'\n');e:stop()
    end
    assert(ok,err)
  end)
end
local function remove(e)
  focus(e,'w','NeogitPopup');e:input('D');picker(e,'linked with space')
  e:wait('подтверждение удаления',function() return e.rpc:request('nvim_get_mode',{}).mode=='r?' and table.concat(e.rpc:screen_lines(),'\n'):find('Remove worktree',1,true) end)
  e:input('y')
end
local function worktree(e,linked,count,active)
  local main=git(e.project,'rev-parse','HEAD')
  local buffers={}
  for n=1,count do
    e:input(':edit '..vim.fn.fnameescape(linked..'/gone'..n..'.txt')..'<CR>')
    e:wait('linked файл '..n,function() return e:current_file()==norm(linked..'/gone'..n..'.txt') end)
    if vim.env.FORGE_DELETED_PENDING_ATTACH~='1' then
      -- Gitsigns намеренно не считает diff скрытого буфера: готовность
      -- наблюдаем, пока каждый файл ещё виден, а не после его hide.
      e:wait('signs видимого файла готовы',function() return e:lua([[local d=vim.b.gitsigns_status_dict;return d and d.added~=nil]]) end)
    end
    buffers[#buffers+1]=e:lua('return vim.api.nvim_get_current_buf()')
  end
  if vim.env.FORGE_DELETED_PENDING_ATTACH~='1' then
    -- Исходный IDE-032 произошёл после commit/push, когда signs уже готовы.
    -- Rapid initial attach → удаление cwd сохранён отдельной диагностикой.
    e:wait('Gitsigns обработал открытые файлы',function()
      local states=e:lua([[local out={};for _,buf in ipairs(...) do out[#out+1]={buf=buf,status=vim.b[buf].gitsigns_status_dict} end;return out]],{buffers})
      vim.fn.writefile({vim.json.encode(states)},e.dir..'/signs-readiness.json')
      for _,s in ipairs(states) do if not s.status or s.status==vim.NIL or s.status.added==nil then return false end end
      return true
    end)
  end
  local code=e:lua('return vim.api.nvim_get_current_win()')
  focus(e,' wg','NeogitStatus')
  if active then
    focus(e,'w','NeogitPopup');e:input('g');picker(e,'linked with space')
    e:wait('cwd linked',function() return norm(e:lua('return vim.fn.getcwd()'))==norm(linked) end)
    if vim.env.FORGE_DELETED_CURRENT_WORKTREE~='1' then
      -- Активный cwd отдельно покрыт active-worktree.test.lua (IDE-034).
      -- Здесь проверяем IDE-BUF-4 после успешного удаления из main.
      focus(e,'w','NeogitPopup');e:input('g');picker(e,'project')
      e:wait('cwd main перед удалением',function() return norm(e:lua('return vim.fn.getcwd()'))==norm(e.project) end)
    end
  end
  remove(e)
  e:wait('Git удалил worktree',function() return vim.fn.isdirectory(linked)==0 end,15000)
  e:wait('Status вернул фокус',function() return e:current_ft()=='NeogitStatus' end)
  -- Реальная пользовательская команда воспроизводит проверку Neogit refresh.
  checktime(e);responsive(e)
  for n,buf in ipairs(buffers) do
    T.eq(e:lua('return vim.api.nvim_buf_is_loaded(...)',{buf}),true)
    T.eq(e:lua('return vim.api.nvim_buf_get_lines(...,0,-1,false)',{buf}),{'preserved '..n})
    T.eq(e:lua('return vim.bo[...].modified',{buf}),false)
  end
  focus(e,'<Esc>','text')
  T.eq(e:lua('return vim.api.nvim_get_current_win()'),code)
  e:input('GoSTILL_EDITABLE<Esc>')
  e:wait('ввод после удаления',function() return e:lua('return vim.api.nvim_get_current_line()')=='STILL_EDITABLE' end)
  e:input(':edit '..vim.fn.fnameescape(e.project..'/file_two.txt')..'<CR>')
  -- Другой буфер открываем явно без потери несохранённого текста (hidden=true).
  e:wait('основной файл доступен',function() return e:current_file()==norm(e.project..'/file_two.txt') end)
  T.eq(git(e.project,'rev-parse','HEAD'),main)
  assert(not git(e.project,'worktree','list','--porcelain'):find('linked with space',1,true))
  T.eq(vim.fn.readfile(e.project..'/file_one.txt'),{'first file','NEEDLE_FORGE_E2E'})
end
check('IDE-BUF-4 много открытых файлов удалённого worktree',function(e,linked) worktree(e,linked,12,false) end)
check('IDE-BUF-4 удаление после посещения worktree сохраняет код',function(e,linked) worktree(e,linked,1,true) end)

local function opened(e,name)
  e:input(':edit '..name..'<CR>')
  e:wait('открыт '..name,function() return e:current_file()==norm(e.project..'/'..name) end)
  return e:lua('return vim.api.nvim_get_current_buf()')
end
local function quiet(e,predicate)
  local until_ns=vim.uv.hrtime()+800000000 -- больше штатного autosave debounce 500ms
  repeat responsive(e);predicate();vim.wait(25) until vim.uv.hrtime()>=until_ns
end
local function warnings(e)
  return e:lua([[local out={};for _,v in ipairs(require('fidget').notification.get_history()) do
    if (v.message or ''):find('File no longer available on disk:',1,true) then
      out[#out+1]={message=v.message,updated=v.last_updated} end end;return out]])
end
check('IDE-BUF-4 скрытый pending autosave отменяется, write возвращает autosave',function(e)
  local other=opened(e,'file_two.txt')
  local buf=opened(e,'file_one.txt')
  local path=e.project..'/file_one.txt'
  e:input('A_READY<Esc>:w<CR>')
  e:wait('autosave загружен',function() return e:lua([[return package.loaded['auto-save'] and require('auto-save').enabled() and not vim.bo.modified]]) end)
  e:input('A_PENDING<Esc>')
  e:wait('изменение ждёт запись',function() return e:lua('return vim.bo.modified and vim.api.nvim_get_current_line():find("_PENDING",1,true)~=nil') end)
  -- Пользовательский :noautocmd сохраняет уже поставленный timer при hide.
  e:input(':noautocmd buffer '..other..'<CR>')
  e:wait('pending буфер скрыт',function() return e:lua('return vim.api.nvim_get_current_buf()')==other end)
  local text=e:lua('return vim.api.nvim_buf_get_lines(...,0,-1,false)',{buf})
  assert(vim.uv.fs_unlink(path));checktime(e,buf)
  quiet(e,function() T.eq(vim.fn.filereadable(path),0,'autosave не создаёт удалённый файл') end)
  T.eq(e:lua('return vim.bo[...].modified',{buf}),true)
  T.eq(e:lua('return vim.api.nvim_buf_get_lines(...,0,-1,false)',{buf}),text)
  local first=warnings(e);T.eq(#first,1)
  checktime(e);checktime(e)
  focus(e,' bp','text');e:input(':buffer '..buf..'<CR>')
  e:wait('файл снова в коде',function() return e:lua('return vim.api.nvim_get_current_buf()')==buf end)
  T.eq(warnings(e),first,'повторный checktime/show не обновляет предупреждение')
  e:input('A_AFTER_DELETE<Esc>')
  e:input(':buffer '..other..'<CR>')
  e:wait('смена фокуса',function() return e:lua('return vim.api.nvim_get_current_buf()')==other end)
  quiet(e,function() T.eq(vim.fn.filereadable(path),0) end)
  e:input(':buffer '..buf..'<CR>:write<CR>')
  e:wait('явная запись восстановила файл',function() return vim.fn.filereadable(path)==1 and not e:lua('return vim.bo.modified') end)
  e:input('A_AUTOSAVE_BACK<Esc>')
  e:wait('autosave снова работает',function() return table.concat(vim.fn.readfile(path),'\n'):find('_AUTOSAVE_BACK',1,true)~=nil end)
  assert(vim.uv.fs_unlink(path));checktime(e)
  e:wait('новый эпизод удаления',function() return #warnings(e)>=1 and warnings(e)[1].updated~=first[1].updated end)
end)

check('IDE-BUF-4 Save As сохраняет текст, новый файл получает autosave',function(e)
  local buf=opened(e,'gone1.txt');local path=e.project..'/gone1.txt'
  assert(vim.uv.fs_unlink(path));checktime(e)
  e:input('A_RECOVERED<Esc>')
  e:wait('изменение в буфере',function() return e:lua('return vim.bo.modified') end)
  e:input(':saveas recovered.txt<CR>')
  e:wait('Save As готов',function() return e:current_file()==norm(e.project..'/recovered.txt') and not e:lua('return vim.bo.modified') end)
  T.eq(e:lua('return vim.api.nvim_get_current_buf()'),buf)
  T.eq(vim.fn.readfile(e.project..'/recovered.txt'),{'preserved 1_RECOVERED'})
  e:input('A_NEXT<Esc>')
  e:wait('новое имя сохраняется автоматически',function() return vim.fn.readfile(e.project..'/recovered.txt')[1]=='preserved 1_RECOVERED_NEXT' end)
  T.eq(vim.fn.filereadable(path),0)
end)

check('IDE-BUF-4 существующий файл сохраняет autoread и native conflict',function(e)
  opened(e,'gone1.txt');local path=e.project..'/gone1.txt'
  T.eq(e:lua('return vim.o.autoread'),true)
  vim.fn.writefile({'EXTERNAL_RELOAD','another line'},path);checktime(e)
  T.eq(e:lua('return vim.api.nvim_buf_get_lines(0,0,-1,false)'),{'EXTERNAL_RELOAD','another line'})
  e:input(':ASToggle<CR>')
  e:wait('autosave выключен пользователем',function() return e:lua([[return package.loaded['auto-save'] and not require('auto-save').enabled()]]) end)
  e:input('gg0iLOCAL_<Esc>')
  e:wait('несохранённый локальный текст',function() return e:lua('return vim.bo.modified') end)
  vim.fn.writefile({'EXTERNAL_CONFLICT_KEEP'},path)
  e:input(':checktime<CR>')
  e:wait('штатный выбор конфликта',function()
    local mode=e.rpc:request('nvim_get_mode',{})
    return mode.mode=='r?' and table.concat(e.rpc:screen_lines(),'\n'):find('W12',1,true)~=nil
  end)
  vim.fn.writefile(e.rpc:screen_lines(),e.dir..'/native-conflict.txt')
  e:input('o') -- OK: сохраняем локальный текст, не выбираем Load File.
  e:wait('конфликт подтверждён',function() return not e.rpc:request('nvim_get_mode',{}).blocking end)
  T.eq(e:lua('return vim.api.nvim_buf_get_lines(0,0,-1,false)'),{'LOCAL_EXTERNAL_RELOAD','another line'})
  T.eq(vim.fn.readfile(path),{'EXTERNAL_CONFLICT_KEEP'})
  T.eq(e:lua('return vim.bo.modified'),true)
end)
T.finish()
