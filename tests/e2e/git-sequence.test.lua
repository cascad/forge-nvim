-- IDE-GIT-13/WF-08/09: native Neogit interactive todo в private fixture.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local env={GIT_CONFIG_NOSYSTEM='1',GIT_CONFIG_GLOBAL=vim.fn.has('win32')==1 and 'NUL' or '/dev/null',
  GIT_TERMINAL_PROMPT='0',LC_ALL='C',NEOGIT_LOG_FILE='1',NEOGIT_LOG_LEVEL='trace'}
local function git(project,...)
  local args={'git','-C',project};vim.list_extend(args,{...})
  local r=vim.system(args,{text=true,env=env}):wait()
  assert(r.code==0,table.concat(args,' ')..'\n'..(r.stderr or '')..(r.stdout or ''))
  return vim.trim(r.stdout or '')
end
local function in_rebase(project)
  return vim.fn.isdirectory(project..'/.git/rebase-merge')==1 or vim.fn.isdirectory(project..'/.git/rebase-apply')==1
end
local function check(action)
  T.check('IDE-GIT-13 native sequence '..action,function()
    local e,report,logfile
    local ok,err=xpcall(function()
      e=require('editor').start(root,{timeout=180000,env=env,prepare=function(project,_,runtime)
        local hooks=runtime..'/empty-hooks';vim.fn.mkdir(hooks,'p')
        for k,v in pairs({['user.name']='Forge E2E',['user.email']='forge-e2e@example.invalid',
            ['commit.gpgsign']='false',['tag.gpgsign']='false',['core.autocrlf']='false',['core.hooksPath']=hooks}) do
          git(project,'config',k,v)
        end
        git(project,'checkout','-b','main')
        if action=='conflict' then vim.fn.writefile({'BASE'},project..'/shared.txt') end
        git(project,'add','.');git(project,'commit','-m','sequence baseline')
        git(project,'checkout','-b','feature')
        for _,name in ipairs({'A','B','C'}) do
          vim.fn.writefile({'SEQUENCE_'..name},project..'/'..name:lower()..'.txt')
          if action=='conflict' and name~='C' then vim.fn.writefile({name},project..'/shared.txt') end
          git(project,'add','.');git(project,'commit','-m','SEQ_'..name)
        end
      end})
      assert(vim.uv.fs_copyfile(root..'/tests/e2e/git-sequence.test.lua',e.dir..'/git-sequence.test.lua'))
      logfile=e:lua([[return vim.fn.stdpath('cache')..'/neogit.log']])
      report={before={head=git(e.project,'rev-parse','HEAD'),tree=git(e.project,'rev-parse','HEAD^{tree}'),
        main=git(e.project,'rev-parse','main'),refs=git(e.project,'show-ref'),log=git(e.project,'log','--format=%s')}}
      local function todo()
        return e:lua([[local out={};for _,line in ipairs(vim.api.nvim_buf_get_lines(0,0,-1,false)) do
          if line:match('^pick ') or line:match('^fixup ') then
            local action,oid,subject=line:match('^(%w+) (%x+) (.+)$')
            out[#out+1]={action=action,oid=oid,subject=subject}
          end
        end;return out]])
      end
      local function subjects(rows)
        local out={};for _,r in ipairs(rows) do out[#out+1]=r.action..' '..r.subject end;return out
      end
      local function has_notice(message)
        for _,n in ipairs(e.rpc.notifications) do if n.message==message then return true end end
        return false
      end
      e:input(':edit a.txt<CR> wg')
      e:wait('native Git status',function() return e:current_ft()=='NeogitStatus'
        and e:lua([[return vim.fn.maparg('r','n',false,true).buffer==1]]) end)
      e:input('r');e:wait('Rebase popup',function() return e:current_ft()=='NeogitPopup' end)
      e:input('i')
      e:wait('native commit selector',function() return e:current_ft()=='NeogitCommitSelectView'
        and e:lua([[return vim.fn.maparg('<CR>','n',false,true).buffer==1
          and table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n'):find('SEQ_A',1,true)~=nil]]) end)
      e:input('gg/SEQ_A<CR><CR>')
      e:wait('native todo editor готов',function() return e:current_ft()=='gitrebase'
        and e:lua([[return vim.fn.maparg('f','n',false,true).buffer==1]]) end,20000)
      assert(in_rebase(e.project),'todo не принадлежит настоящему Git rebase')
      T.eq(git(e.project,'rev-parse','HEAD'),report.before.head)
      report.initial_todo=todo();T.eq(subjects(report.initial_todo),{'pick SEQ_A','pick SEQ_B','pick SEQ_C'})
      report.editor=e:lua([[return {file=vim.api.nvim_buf_get_name(0),cwd=vim.fn.getcwd(),
        modifiable=vim.bo.modifiable,readonly=vim.bo.readonly,ft=vim.bo.filetype} ]])
      T.eq(report.editor.modifiable,true);T.eq(report.editor.readonly,false)
      if action=='conflict' then
        e:input('ggjgk')
        e:wait('зависимый B перемещён перед A',function() return vim.deep_equal(subjects(todo()),{'pick SEQ_B','pick SEQ_A','pick SEQ_C'}) end)
      else
        e:input('ggjjgk')
        e:wait('C перемещён перед B',function() return vim.deep_equal(subjects(todo()),{'pick SEQ_A','pick SEQ_C','pick SEQ_B'}) end)
        e:input('f')
        e:wait('C стал fixup A',function() return vim.deep_equal(subjects(todo()),{'pick SEQ_A','fixup SEQ_C','pick SEQ_B'}) end)
      end
      report.edited_todo=todo();e:snapshot('sequence-edited')
      e:input(action=='abort' and '<C-c><C-k>' or '<C-c><C-c>')
      local conflict_message='Rebasing failed. Resolve conflicts before continuing'
      local notice=action=='conflict' and conflict_message or action=='submit' and 'Rebased successfully' or 'Rebase aborted'
      e:wait('Git завершился: '..notice,function()
        return has_notice(notice) and in_rebase(e.project)==(action=='conflict')
      end,20000)
      if action=='conflict' then
        report.conflict={unmerged=git(e.project,'ls-files','-u'),content=vim.fn.readfile(e.project..'/shared.txt')}
        assert(report.conflict.unmerged~='','false conflict не создал unmerged index')
        e:input(' wg');e:wait('status настоящего конфликта готов',function()
          return e:current_ft()=='NeogitStatus' and e:lua([[local text=table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n')
            return text:find('Rebasing',1,true)~=nil and text:find('unmerged',1,true)~=nil]])
        end)
        e:input('r');e:wait('Rebase actions с Abort',function()
          return e:current_ft()=='NeogitPopup' and e:lua([[return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n'):find('Abort',1,true)~=nil]])
        end)
        e:input('a');e:wait('native Abort confirm',function()
          return e.rpc:request('nvim_get_mode',{}).mode=='r?'
            and table.concat(e.rpc:screen_lines(),'\n'):find('Abort',1,true)~=nil
        end)
        vim.fn.writefile(e.rpc:screen_lines(),e.dir..'/native-abort-confirm.txt');e:input('y')
        e:wait('native rebase abort завершён',function() return not in_rebase(e.project) end,20000)
      end
      report.after={head=git(e.project,'rev-parse','HEAD'),tree=git(e.project,'rev-parse','HEAD^{tree}'),
        main=git(e.project,'rev-parse','main'),refs=git(e.project,'show-ref'),log=git(e.project,'log','--format=%s'),
        status=git(e.project,'status','--porcelain'),count=tonumber(git(e.project,'rev-list','--count','main..HEAD'))}
      T.eq(report.after.tree,report.before.tree);T.eq(report.after.main,report.before.main);T.eq(report.after.status,'')
      T.eq(git(e.project,'branch','--show-current'),'feature')
      if action=='submit' then
        assert(report.after.head~=report.before.head);T.eq(report.after.count,2)
        T.eq(report.after.log,'SEQ_B\nSEQ_A\nsequence baseline')
        T.eq(git(e.project,'show','HEAD^:c.txt'),'SEQUENCE_C')
        T.eq(git(e.project,'show','HEAD^:a.txt'),'SEQUENCE_A')
      else
        T.eq(report.after.head,report.before.head);T.eq(report.after.refs,report.before.refs)
        T.eq(report.after.log,report.before.log);T.eq(report.after.count,3)
      end
      for _,name in ipairs({'A','B','C'}) do T.eq(vim.fn.readfile(e.project..'/'..name:lower()..'.txt'),{'SEQUENCE_'..name}) end
      T.eq(e:lua([[return vim.fn.getcwd():gsub('\\','/')]]),e.project:gsub('\\','/'))
      T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
      for _,n in ipairs(e.rpc.notifications) do
        assert(n.level<vim.log.levels.ERROR or (action=='conflict' and n.message==conflict_message),n.message)
      end
    end,debug.traceback)
    if e then
      report=report or {};report.ok=ok;report.error=not ok and err or nil
      vim.fn.writefile({vim.json.encode(report)},e.dir..'/git-sequence.json')
      if logfile and vim.fn.filereadable(logfile)==1 then assert(vim.uv.fs_copyfile(logfile,e.dir..'/neogit.log')) end
      local snapped,why=pcall(e.snapshot,e,'sequence-'..action)
      if not snapped then ok=false;err=tostring(err or '')..'\nSnapshot: '..tostring(why) end
      io.stdout:write('  artifacts: '..e.dir..'\n')
      local stopped,cleanup=pcall(e.stop,e,not ok and err or nil)
      if not stopped then ok=false;err=tostring(err or '')..'\nCleanup: '..tostring(cleanup) end
    end
    assert(ok,err)
  end)
end
check('submit');check('abort');check('conflict')
T.finish()
