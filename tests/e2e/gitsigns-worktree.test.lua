-- Настоящие Git/Neogit/Gitsigns; gate меняет только момент доставки результата.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local function norm(p) return vim.fs.normalize(p):gsub('\\','/') end
local function git(path,...)
  local args={'git','-C',path};vim.list_extend(args,{...})
  local r=vim.system(args,{text=true,env={GIT_CONFIG_NOSYSTEM='1',GIT_CONFIG_GLOBAL=vim.fn.has('win32')==1 and 'NUL' or '/dev/null'}}):wait()
  assert(r.code==0,(r.stderr or '')..table.concat(args,' '));return vim.trim(r.stdout or '')
end
local function records(gate,kind)
  local out={};for _,p in ipairs(vim.fn.glob(gate..'/'..kind..'-*.json',false,true)) do
    out[#out+1]=vim.json.decode(table.concat(vim.fn.readfile(p),'\n'))
  end;return out
end
local function release(gate,kind) vim.fn.writefile({'release'},gate..'/'..kind..'-release') end
local function focus(e,keys,ft)
  e:input(keys);e:wait('фокус '..ft,function() return e:current_ft()==ft and e:lua([[return vim.fn.maparg('q','n',false,true).buffer==1]]) end,10000)
end
local function responsive(e)
  local mode=e.rpc:request('nvim_get_mode',{})
  assert(not mode.blocking and mode.mode~='r?',table.concat(e.rpc:screen_lines(),'\n'))
  local messages=e:lua([[return vim.fn.execute('messages')..'\n'..vim.v.errmsg]])
  assert(not messages:find('stack traceback',1,true) and not messages:find('E211',1,true),messages)
  for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
end
local function confirm(e,text,key)
  e:wait('confirm '..text,function() return e.rpc:request('nvim_get_mode',{}).mode=='r?' and table.concat(e.rpc:screen_lines(),'\n'):find(text,1,true)~=nil end)
  e:input(key)
end
local function stage(e,path,needle)
  e:wait('signs загружены',function() return e:lua([[local d=vim.b.gitsigns_status_dict;return d and d.changed and d.changed>0]]) end,15000)
  e:input('gg0 ghs');e:wait('hunk staged в выбранном repo',function() return git(path,'diff','--cached'):find(needle,1,true)~=nil end)
  e:wait('signs завершили stage',function() return e:lua([[local d=vim.b.gitsigns_status_dict;return d and d.changed==0]]) end,10000)
  e:input(' ghu');e:wait('hunk unstaged',function() return git(path,'diff','--cached')=='' end)
end
local function check(name,dirty)
  if vim.env.FORGE_GITSIGNS_E2E_CASE and not name:find(vim.env.FORGE_GITSIGNS_E2E_CASE,1,true) then return end
  T.check(name,function()
    local e,gate,linked
    local ok,err=pcall(function()
      e=require('editor').start(root,{env={GIT_CONFIG_NOSYSTEM='1',GIT_CONFIG_GLOBAL=vim.fn.has('win32')==1 and 'NUL' or '/dev/null',GIT_TERMINAL_PROMPT='0'},prepare=function(project,env,runtime)
        for k,v in pairs({['user.name']='Fixture',['user.email']='fixture@example.invalid',['commit.gpgsign']='false',['core.autocrlf']='false',['core.hooksPath']=runtime..'/no-hooks'}) do git(project,'config',k,v) end
        git(project,'checkout','-b','main');git(project,'add','.');git(project,'commit','-m','fixture baseline')
        linked=runtime..'/linked with space';git(project,'worktree','add','-b','linked',linked)
        if dirty then vim.fn.writefile({'DIRTY_first file','NEEDLE_FORGE_E2E'},linked..'/file_one.txt') end
        gate=runtime..'/git-gate';vim.fn.mkdir(gate,'p');vim.fn.writefile({vim.json.encode(linked)},gate..'/target.json')
        local bin=runtime..'/git-proxy-bin';vim.fn.mkdir(bin,'p')
        local python=vim.fn.exepath(vim.fn.has('win32')==1 and 'python' or 'python3');assert(python~='','Нужен Python 3')
        local real=vim.fn.exepath('git');local script=root..'/tests/e2e/gitsigns_git_gate.py'
        local wrapper=bin..'/git'..(vim.fn.has('win32')==1 and '.exe' or '')
        if vim.fn.has('win32')==1 then
          local built=vim.system({'powershell.exe','-NoProfile','-File',root..'/tests/e2e/build_git_proxy.ps1','-Output',wrapper},{text=true}):wait()
          assert(built.code==0,(built.stdout or '')..(built.stderr or ''));vim.fn.writefile({python,'-B',script,real,gate},bin..'/git.args')
        else
          local args={python,'-B',script,real,gate};for i,v in ipairs(args) do args[i]=vim.fn.shellescape(v) end
          vim.fn.writefile({'#!/bin/sh','exec '..table.concat(args,' ')..' "$@"'},wrapper);assert(vim.uv.fs_chmod(wrapper,448))
        end
        env.PATH=bin..(vim.fn.has('win32')==1 and ';' or ':')..env.PATH;env.FORGE_GIT_PROXY_STABLE_CWD=project
        if vim.env.FORGE_GITSIGNS_SOURCE_VARIANT=='upstream' then
          assert(vim.env.FORGE_E2E_CONFIG_SOURCE,'Для red replay нужен старый config source без Gitsigns guard')
          local data=env.XDG_DATA_HOME..'/nvim_forge'..(vim.fn.has('win32')==1 and '-data' or '')..'/lazy'
          dofile(root..'/nvim_forge/lua/ide/backports.lua').run('gitsigns.nvim',data..'/gitsigns.nvim','revert')
        end
      end})
      vim.fn.writefile({vim.json.encode({gitsigns=vim.env.FORGE_GITSIGNS_SOURCE_VARIANT or 'prepared',source=vim.env.FORGE_E2E_CONFIG_SOURCE or root..'/nvim_forge'})},e.dir..'/source-variant.json')
      e:wait('IDE готова',function() return e:lua('return _G.forge_e2e_observed') end,10000)
      local main=git(e.project,'rev-parse','HEAD')
      e:input(':edit '..vim.fn.fnameescape(linked..'/file_one.txt')..'<CR>')
      e:wait('готовый real index show задержан',function() return #records(gate,'show')>0 end,15000)
      T.eq(records(gate,'show')[1].code,0);T.eq(records(gate,'show')[1].held,true)
      local buf=e:lua('return vim.api.nvim_get_current_buf()');local text=e:lua('return vim.api.nvim_buf_get_lines(0,0,-1,false)')
      focus(e,' wg','NeogitStatus');focus(e,'w','NeogitPopup');e:input('D')
      e:wait('picker принимает ввод',function() return e:current_ft()=='TelescopePrompt' and e.rpc:request('nvim_get_mode',{}).mode=='i' end)
      e:input('linked with space')
      e:wait('picker выбрал linked',function() return e:lua([[local s=require('telescope.actions.state');local v=s.get_selected_entry();return v and s.get_current_picker(vim.api.nvim_get_current_buf()):_get_prompt()=='linked with space' and tostring(v[1]):find('linked with space',1,true)~=nil]]) end)
      e:input('<CR>');confirm(e,'Remove worktree','y')
      e:wait('real remove завершён, его callback задержан',function() return #records(gate,'remove')>0 end,15000)
      if dirty then
        assert(records(gate,'remove')[1].code~=0);T.eq(vim.fn.isdirectory(linked),1)
        release(gate,'remove');confirm(e,'untracked or modified','n')
        e:wait('force отменён',function() return e.rpc:request('nvim_get_mode',{}).mode=='n' and e:current_ft()=='NeogitStatus' end)
        release(gate,'show');e:input(' w0')
        e:wait('linked код доступен',function() return e:current_file()==norm(linked..'/file_one.txt') end)
        stage(e,linked,'DIRTY_');T.eq(vim.fn.readfile(linked..'/file_one.txt'),text)
        assert(git(e.project,'worktree','list','--porcelain'):find('linked with space',1,true))
      else
        T.eq(records(gate,'remove')[1].code,0);T.eq(vim.fn.isdirectory(linked),0)
        release(gate,'show')
        e:wait('следующий real show вернул ошибку Git',function()
          responsive(e);for _,r in ipairs(records(gate,'show')) do if not r.held and r.code~=0 then return true end end
        end,10000)
        local until_ns=vim.uv.hrtime()+800000000;repeat responsive(e);vim.wait(25) until vim.uv.hrtime()>=until_ns
        release(gate,'remove')
        e:wait('Neogit завершил удаление',function() for _,n in ipairs(e.rpc.notifications) do if n.message=='Worktree removed' then return true end end end,10000)
        e:input(':checktime | let g:forge_gs_checked=1<CR>');e:wait('checktime завершён',function() return e:lua('return vim.g.forge_gs_checked')==1 end)
        T.eq(e:lua('return vim.api.nvim_buf_get_lines(...,0,-1,false)',{buf}),text)
        e:input(' w0');e:input(':edit '..vim.fn.fnameescape(e.project..'/file_two.txt')..'<CR>')
        e:wait('main код открыт',function() return e:current_file()==norm(e.project..'/file_two.txt') end)
        e:input('gg0iRECOVERED_<Esc>:write<CR>')
        e:wait('main изменение записано',function() return table.concat(vim.fn.readfile(e.project..'/file_two.txt'),'\n'):find('RECOVERED_',1,true)~=nil end)
        stage(e,e.project,'RECOVERED_')
        T.eq(e:lua('return vim.api.nvim_buf_get_lines(...,0,-1,false)',{buf}),text)
      end
      T.eq(git(e.project,'rev-parse','HEAD'),main);T.eq(git(e.project,'diff','--cached'),'');responsive(e)
    end)
    if e then
      if gate then
        release(gate,'show');release(gate,'remove');vim.fn.mkdir(e.dir..'/git-gate','p')
        for file,kind in vim.fs.dir(gate) do if kind=='file' then vim.uv.fs_copyfile(gate..'/'..file,e.dir..'/git-gate/'..file) end end
      end
      vim.fn.writefile({git(e.project,'worktree','list','--porcelain')},e.dir..'/worktrees.txt')
      e:snapshot(name);io.stdout:write('  artifacts: '..e.dir..'\n');e:stop()
    end
    assert(ok,err)
  end)
end
check('IDE-GIT-8 initial show и удаление worktree не блокируют код, main stage работает',false)
check('IDE-GIT-8 dirty force cancel сохраняет signs и stage правильного linked repo',true)
T.finish()
