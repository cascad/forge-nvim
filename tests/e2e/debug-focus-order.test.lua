-- spec: IDE-LOG-1. Реальный failed F5 и поздний native focus callback.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
for _,target in ipairs({{name='Problems',keys=' wx',ft='trouble'},{name='IDE Logs',keys=' wi',ft='forge-logs'}}) do
  if not vim.env.FORGE_DEBUG_FOCUS_CASE or target.name:find(vim.env.FORGE_DEBUG_FOCUS_CASE,1,true) then
    T.check('IDE-LOG-1 failed F5 late focus preserves '..target.name,function()
      local e,report
      local ok,err=xpcall(function()
        e=require('editor').start(root,{prepare=function(project)
          vim.fn.writefile({'console.log("not launched");'},project..'/focus.js')
        end})
        assert(vim.uv.fs_copyfile(root..'/tests/e2e/debug-focus-order.test.lua',e.dir..'/debug-focus-order.test.lua'))
        e:wait('Forge ready',function() return e:lua('return _G.forge_e2e_observed') end,10000)
        e:lua([[vim.g.forge_node_executable=vim.fn.getcwd()..'/missing-node']])
        e:input(':edit focus.js<CR>');e:wait('JS code',function() return e:current_ft()=='javascript' end)
        e:lua([[local a=require('ide.activities');local info=debug.getinfo(a.focus_code_later,'S')
          _G.focus_schedule=vim.schedule;_G.focus_held={};_G.focus_released={}
          vim.schedule=function(fn)
            local body=debug.getinfo(fn,'S')
            if body.source==info.source and body.linedefined>=info.linedefined and body.lastlinedefined<=info.lastlinedefined then
              _G.focus_held[#_G.focus_held+1]=fn;return
            end
            return _G.focus_schedule(fn)
          end]])
        e:input('<F5>');e:wait('failed F5 and native callback held',function()
          for _,n in ipairs(e.rpc.notifications) do if n.message:find('Node.js не найден',1,true) then
            return e:lua('return #_G.focus_held')>0 end end
        end)
        e:input(target.keys);e:wait('new panel selected',function() return e:current_ft()==target.ft end)
        report={case=target.name,before=e:current_ft(),held=e:lua('return #_G.focus_held')}
        e:lua([[vim.schedule=_G.focus_schedule
          for _,fn in ipairs(_G.focus_held) do vim.schedule(function()
            fn();_G.focus_released[#_G.focus_released+1]=vim.bo.filetype
          end) end]])
        e:wait('native callbacks released',function() return e:lua('return #_G.focus_released')==report.held end)
        report.after=e:current_ft();report.released=e:lua('return _G.focus_released')
        T.eq(report.after,target.ft,'Obsolete F5 focus stole explicit panel selection')
        T.eq(e:lua('return require("dap").session()==nil'),true)
        T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
      end,debug.traceback)
      if e then
        pcall(function() e:lua('if _G.focus_schedule then vim.schedule=_G.focus_schedule end') end)
        report=report or {case=target.name};report.ok=ok;report.error=not ok and tostring(err) or nil
        vim.fn.writefile({vim.json.encode(report)},e.dir..'/debug-focus-order.json');e:snapshot('debug-focus-order')
        io.stdout:write('  artifacts: '..e.dir..'\n')
        local stopped,issue=pcall(e.stop,e,not ok and err or nil);assert(stopped,issue)
        assert(e.rpc.exit_code==0 and e.rpc.exit_signal==0 and #e.rpc.api_errors==0,'Native root/API failure')
      end
      assert(ok,err)
    end)
  end
end
T.finish()
