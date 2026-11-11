-- spec: IDE-LOG-2/4. Настоящий readonly view на границе64KiB.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
for _,source in ipairs({'format','messages'}) do
  T.check('IDE-LOG-2 bounded Unicode tail '..source,function()
    local e,report
    local ok,err=xpcall(function()
      e=require('editor').start(root)
      assert(vim.uv.fs_copyfile(root..'/tests/e2e/ide-log-tail.test.lua',e.dir..'/ide-log-tail.test.lua'))
      e:wait('Forge ready',function() return e:lua('return _G.forge_e2e_observed') end,10000)
      local path=e:lua([[local source=...;local raw=string.rep('Я',40000)..'SOURCE_TAIL_X'
        if source=='messages' then return false end
        for _,item in ipairs(require('forge.log_sources').list()) do if item.id==source then
          vim.fn.mkdir(vim.fs.dirname(item.path),'p');local f=assert(io.open(item.path,'wb'));assert(f:write(raw));assert(f:close());return item.path
        end end;error('Source missing')]],{source})
      if source=='messages' then
        e:input(':lua _G.log_tail_native_done=false;vim.api.nvim_echo({{string.rep("Я",40000).."SOURCE_TAIL_X"}},true,{});_G.log_tail_native_done=true<CR>')
        e:wait('native message recorded',function()
          if e.rpc:request('nvim_get_mode',{}).blocking then
            local screen=table.concat(e.rpc:screen_lines(),'\n')
            assert(screen:find('Я',1,true) or screen:find('SOURCE_TAIL_X',1,true),'Unexpected native prompt')
            e:input('<CR>');return false
          end
          return e:lua('return _G.log_tail_native_done')
        end)
      end
      e:input(':ForgeLogs '..source..'<CR>');e:wait('tail source selected',function()
        return e:current_ft()=='forge-logs' and e:lua('return require("forge.logs").source')==source
      end)
      local data=e:lua([[local b=require('forge.logs').buf;local lines=vim.api.nvim_buf_get_lines(b,0,-1,false)
        local invalid=false;for _,line in ipairs(lines) do local byte=line:byte(1)
          if byte and byte>=128 and byte<192 then invalid=true end end
        local all=table.concat(lines,'\n');return {tail=all:find('SOURCE_TAIL_X',1,true)~=nil,
          invalid_start=invalid,truncated=all:find('[truncated]',1,true)~=nil,
          false_empty=all:find('доступен; пусто',1,true)~=nil,bytes=#all} ]])
      report={source=source,path=path,view=data}
      assert(data.tail,'Bounded source lost the only long line instead of showing its tail')
      assert(not data.invalid_start,'Bounded source begins with an orphan UTF-8 continuation byte')
      assert(data.truncated and not data.false_empty,'Truncated source falsely classified as empty')
      assert(data.bytes<68000,'Unbounded source view')
      if path then assert(vim.uv.fs_copyfile(path,e.dir..'/native-tail.log')) end
      T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
    end,debug.traceback)
    if e then
      report=report or {source=source};report.ok=ok;report.error=not ok and tostring(err) or nil
      vim.fn.writefile({vim.json.encode(report)},e.dir..'/ide-log-tail.json')
      pcall(e.snapshot,e,'ide-log-tail');io.stdout:write('  artifacts: '..e.dir..'\n')
      local stopped,issue=pcall(e.stop,e,not ok and err or nil);assert(stopped,issue)
      assert(e.rpc.exit_code==0 and e.rpc.exit_signal==0 and #e.rpc.api_errors==0,'Native root/API failure')
    end
    assert(ok,err)
  end)
end
T.finish()
