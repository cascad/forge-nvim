-- WF-09: native Git credentials/retry через настоящий loopback HTTP remote.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local user,secret='forge-fixture','fixture-password-42' -- Только synthetic fixture данные.
local git_env={GIT_CONFIG_NOSYSTEM='1',GIT_CONFIG_GLOBAL=vim.fn.has('win32')==1 and 'NUL' or '/dev/null',
  GIT_TERMINAL_PROMPT='0',LC_ALL='C'}
local function git(project,...)
  local args={'git','-C',project};vim.list_extend(args,{...})
  local r=vim.system(args,{text=true,env=git_env}):wait();assert(r.code==0,r.stderr or r.stdout)
  return vim.trim(r.stdout or '')
end
local function check(action)
  T.check('SELF: GIT-AUTH '..action..' и повтор push с тем же commit',function()
    local e,report,job,logfile,auditfile
    local ok,err=xpcall(function()
      local python=vim.fn.exepath(vim.fn.has('win32')==1 and 'python' or 'python3');assert(python~='','Нужен host Python')
      e=require('editor').start(root,{timeout=180000,env=vim.tbl_extend('force',git_env,{
        GIT_TERMINAL_PROMPT='1',GCM_INTERACTIVE='never',NEOGIT_LOG_FILE='1',NEOGIT_LOG_LEVEL='trace',
        NO_PROXY='127.0.0.1,localhost',no_proxy='127.0.0.1,localhost'}),prepare=function(project,env,runtime)
          for _,key in ipairs({'GIT_ASKPASS','SSH_ASKPASS','SSH_ASKPASS_REQUIRE'}) do env[key]=nil end
          local hooks=project..'/.git/hooks';vim.fn.mkdir(hooks,'p')
          for k,v in pairs({['user.name']='Forge E2E',['user.email']='forge-e2e@example.invalid',
              ['commit.gpgsign']='false',['tag.gpgsign']='false',['core.autocrlf']='false',
              ['core.hooksPath']=hooks,['credential.helper']='',['http.proxy']=''}) do git(project,'config',k,v) end
          git(project,'checkout','-b','main');git(project,'add','.');git(project,'commit','-m','auth baseline')
          git(runtime,'init','--bare','origin.git');git(runtime..'/origin.git','symbolic-ref','HEAD','refs/heads/main')
          git(project,'remote','add','origin',runtime..'/origin.git');git(project,'push','-u','origin','main')
          vim.fn.writefile({'AUTH_LOCAL_COMMIT'},project..'/auth-change.txt')
          git(project,'add','.');git(project,'commit','-m','auth local change')
          vim.fn.writefile({'#!/bin/sh',[[printf 'FORGE_PRE_PUSH\n' >> "$(git rev-parse --git-path forge-pre-push-ran)"]]},hooks..'/pre-push')
          assert(vim.uv.fs_chmod(hooks..'/pre-push',493))
        end})
      assert(vim.uv.fs_copyfile(root..'/tests/e2e/git-auth.test.lua',e.dir..'/git-auth.test.lua'))
      assert(vim.uv.fs_copyfile(root..'/tests/e2e/fixtures/git-auth/server.py',e.dir..'/server.py'))
      logfile=e:lua([[return vim.fn.stdpath('cache')..'/neogit.log']])
      local ready,audit=e.runtime..'/http-ready.json',e.runtime..'/http-audit.jsonl'
      auditfile=audit
      job=e:lua([[local py,script,base,ready,audit,log=...
        return vim.fn.jobstart({py,'-B',script,'--base',base,'--ready',ready,'--audit',audit},
          {cwd=base,detach=false,stderr_buffered=true,on_stderr=function(_,lines)
            if #lines>0 then vim.fn.writefile(lines,log,'a') end end})]],
        {python,root..'/tests/e2e/fixtures/git-auth/server.py',e.runtime,ready,audit,e.dir..'/server-stderr.txt'})
      assert(job>0,'HTTP fixture job не запущен')
      e:wait('HTTP fixture готова',function() return vim.fn.filereadable(ready)==1 end,10000)
      local endpoint=vim.json.decode(table.concat(vim.fn.readfile(ready),'\n'))
      git(e.project,'remote','set-url','origin',endpoint.url)
      report={endpoint=endpoint,before={head=git(e.project,'rev-parse','HEAD'),remote=git(e.runtime..'/origin.git','rev-parse','HEAD')}}
      local function screen() return table.concat(e.rpc:screen_lines(),'\n') end
      local function history()
        return e:lua([[local out={};local n=package.loaded['neogit.lib.git'];if n then
          for _,r in ipairs(n.cli.history) do if r.cmd:match('%spush%s') then
            out[#out+1]={cmd=r.cmd,code=r.code,stdout=r.stdout,stderr=r.stderr}
          end end end;return out]])
      end
      local function status()
        e:input(' wg');e:wait('Git status готов',function() return e:current_ft()=='NeogitStatus'
          and e:lua([[return vim.fn.maparg('P','n',false,true).buffer==1]]) end)
      end
      local function push()
        status();e:input('P');e:wait('Push popup',function() return e:current_ft()=='NeogitPopup' and screen():find('Push',1,true) end)
        e:input('u')
      end
      local function prompt(word)
        e:wait('native '..word..' prompt',function()
          return e.rpc:request('nvim_get_mode',{}).mode=='c' and screen():find(word,1,true)~=nil
        end,20000)
      end
      local function credentials(password,retry)
        if not retry then prompt('Username');e:input(user..'<CR>') end
        prompt('Password');e:input(password)
        e:wait('native secret mask отрисована',function() return screen():find(string.rep('*',#password),1,true)~=nil end)
        assert(not screen():find(password,1,true),'Secret виден в native prompt')
        report.masked=true;e:input('<CR>')
      end
      local function finished(count,success)
        e:wait('Git push завершён',function()
          local mode=e.rpc:request('nvim_get_mode',{})
          if mode.mode=='r?' and screen():lower():find('force',1,true) then e:input('n');return false end
          if mode.blocking and mode.mode~='c' and mode.mode~='r?' then
            assert(not screen():match('%f[%w]E%d+:'),'Native Neovim error вместо Git result')
            e:input('<CR>');return false
          end
          if mode.mode~='n' then return false end
          local rows=history();report.pending_history=rows
          return #rows>=count and rows[#rows].code~=nil and mode.mode=='n'
            and (not success or rows[#rows].code==0)
        end,30000)
      end
      push()
      if action=='cancel' then
        prompt('Username');e:input('<Esc>');finished(1)
      else
        credentials('fixture-wrong-password')
        e:wait('Native auth отказ и новый Password prompt',function()
          local rejected=false
          if vim.fn.filereadable(audit)==1 then
            for _,line in ipairs(vim.fn.readfile(audit)) do local r=vim.json.decode(line)
              rejected=rejected or (r.has_auth and not r.authorized) end
          end
          local mode=e.rpc:request('nvim_get_mode',{})
          report.retry_observed={mode=mode,rejected=rejected,screen=screen()}
          if mode.blocking and screen():lower():find('authentication failed',1,true) then
            assert(not screen():match('%f[%w]E%d+:'),'Native Neovim error вместо auth failure')
            report.failure_visible=true;e:input('<CR>');return false
          end
          return rejected and mode.mode=='c' and screen():find('Password',1,true)~=nil
        end,20000)
        vim.fn.writefile(e.rpc:screen_lines(),e.dir..'/retry-screen.txt')
      end
      T.eq(git(e.project,'rev-parse','HEAD'),report.before.head)
      T.eq(git(e.runtime..'/origin.git','rev-parse','HEAD'),report.before.remote)
      if action=='cancel' then report.failed=history();assert(report.failed[#report.failed].code~=0,'Отказ неожиданно успешен') end
      if action=='cancel' then push() end
      credentials(secret,action=='reject');finished(2,true)
      e:wait('Remote получил тот же commit',function() return git(e.runtime..'/origin.git','rev-parse','HEAD')==report.before.head end,10000)
      report.after={head=git(e.project,'rev-parse','HEAD'),remote=git(e.runtime..'/origin.git','rev-parse','HEAD'),status=git(e.project,'status','--porcelain')}
      T.eq(report.after.head,report.before.head);T.eq(report.after.remote,report.before.head);T.eq(report.after.status,'')
      report.history=history();T.eq(report.history[#report.history].code,0)
      if action=='reject' then
        report.failed={};for _,r in ipairs(report.history) do if r.code~=0 then report.failed[#report.failed+1]=r end end
        assert(#report.failed>0,'Нет native Git отказа')
        e:wait('Native authentication failure доступен пользователю',function()
          for _,n in ipairs(e.rpc.notifications) do if n.message:lower():find('authentication failed',1,true) then return true end end
        end)
        report.failure_visible=true
      end
      report.hooks=vim.fn.readfile(e.project..'/.git/forge-pre-push-ran')
      assert(#report.hooks>0 and report.hooks[1]=='FORGE_PRE_PUSH','Настоящий pre-push hook не исполнился')
      for _,r in ipairs(report.history) do assert(not r.cmd:find('--no-verify',1,true),'Git hook обойдён') end
      report.requests={};for _,line in ipairs(vim.fn.readfile(audit)) do report.requests[#report.requests+1]=vim.json.decode(line) end
      local posted,rejected=false,false
      for _,r in ipairs(report.requests) do
        posted=posted or (r.method=='POST' and r.authorized and r.status==200)
        rejected=rejected or (r.has_auth and not r.authorized)
      end
      assert(posted,'Нет настоящего authenticated Git POST');if action=='reject' then assert(rejected,'Нет настоящего отказа credentials') end
      local rendered=vim.inspect(report.history);assert(not rendered:find(secret,1,true),'Secret попал в Git output')
      T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
    end,debug.traceback)
    if e then
      report=report or {};report.ok=ok;report.error=not ok and err or nil
      if not ok then
        vim.fn.writefile(e.rpc:screen_lines(),e.dir..'/failure-screen.txt')
        -- Только завершение fixture: native retry может ждать inputsecret/hit-enter.
        pcall(function() e:wait('Отмена оставшихся native prompts',function()
          local mode=e.rpc:request('nvim_get_mode',{})
          if mode.mode=='c' then e:input('<Esc>');return false end
          if mode.blocking or mode.mode=='r?' then e:input('<CR>');return false end
          return mode.mode=='n'
        end,4000) end)
      end
      if auditfile and vim.fn.filereadable(auditfile)==1 then
        assert(vim.uv.fs_copyfile(auditfile,e.dir..'/http-audit.jsonl'))
      end
      local observed,diagnostic=pcall(function() return e:lua([[local g=package.loaded['neogit.lib.git'];return {
        history=g and g.cli.history or {},mode=vim.api.nvim_get_mode(),
        messages=vim.fn.execute('messages'),terminal_prompt=vim.env.GIT_TERMINAL_PROMPT} ]]) end)
      if observed then report.diagnostic=diagnostic end
      if job and job>0 then
        local stopped,result=pcall(function() return e:lua([[local id=...;local before=vim.fn.jobwait({id},0)[1]
          vim.fn.jobstop(id);return {before=before,after=vim.fn.jobwait({id},3000)[1]} ]],{job}) end)
        report.server_stop=stopped and result or tostring(result)
        if not stopped or result.after==-1 then ok=false;err=tostring(err or '')..'\nHTTP fixture stop failed' end
      end
      vim.fn.writefile({vim.json.encode(report)},e.dir..'/git-auth.json')
      if logfile and vim.fn.filereadable(logfile)==1 then assert(vim.uv.fs_copyfile(logfile,e.dir..'/neogit.log')) end
      local snapped,why=pcall(e.snapshot,e,'git-auth-'..action)
      if not snapped then ok=false;err=tostring(err or '')..'\nSnapshot: '..tostring(why) end
      io.stdout:write('  artifacts: '..e.dir..'\n')
      local stopped,cleanup=pcall(e.stop,e,not ok and err or nil)
      if not stopped then ok=false;err=tostring(err or '')..'\nCleanup: '..tostring(cleanup) end
    end
    assert(ok,err)
  end)
end
check('cancel');check('reject')
T.finish()
