local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
for _,variant in ipairs({'winfix','hidden','winfix-direct','hidden-direct'}) do
  T.check('IDE-PANEL-15 native legacy '..variant..' restore keeps file focus',function()
    local dir=root..'/.tests/session-legacy/'..tostring(vim.uv.hrtime());vim.fn.mkdir(dir,'p')
    assert(vim.uv.fs_copyfile(root..'/tests/e2e/session-legacy.test.lua',dir..'/session-legacy.test.lua'))
    local result=vim.system({vim.v.progpath,'-l',root..'/tests/diagnostics/session-legacy.lua',variant},
      {cwd=root,text=true,timeout=180000,env={NVIM_LOG_FILE=dir..'/controller.log'}}):wait()
    assert(vim.fn.writefile(vim.split((result.stdout or '')..(result.stderr or ''),'\n'),dir..'/child.log')==0)
    local artifact=assert((result.stdout or ''):match('artifacts: ([^\r\n]+)'),result.stderr):gsub('\\','/'):gsub('%s+$','')
    local prefix=root..'/.tests/editor-e2e/'
    assert(artifact:sub(1,#prefix)==prefix and artifact:sub(#prefix+1):match('^%d+$'))
    io.stdout:write('  artifacts: '..artifact..'; controller: '..dir..'\n')
    local function read(name) return vim.json.decode(table.concat(vim.fn.readfile(artifact..'/'..name),'\n')) end
    local report=read('session-legacy.json')
    assert(vim.fn.writefile({vim.json.encode({artifact=artifact,child_exit=result.code,child_signal=result.signal})},dir..'/result.json')==0)
    assert(result.code==0 and result.signal==0 and report.ok,report.error or 'Native legacy failed; see child.log')
    if variant:match('%-direct$') then T.eq(report.initial.pid,report.returned.pid)
    else assert(report.initial.pid~=report.switched.pid and report.switched.pid~=report.returned.pid) end
    local s=report.after
    T.eq(s.cwd,report.before.cwd);T.eq(#s.buffers,variant:match('^hidden') and 1 or 2)
    assert(#s.ui>0 and not s.mode.blocking);T.eq(s.installs,0)
    assert(not s.messages:match('E%d%d%d+:'),s.messages)
    for _,notice in ipairs(s.notices) do assert(notice.level<vim.log.levels.ERROR,notice.message) end
    local focused,explorer,files=nil,false,0
    for _,tab in ipairs(s.tabs) do for _,w in ipairs(tab.windows) do
      if w.win==s.current then focused=w end
      if w.ft=='neo-tree' then explorer=true end
      if w.bt=='' and w.file~='' and not w.floating then
        assert(not w.fixed and not w.marker,'Legacy file still trapped in panel');files=files+1
      end
    end end
    assert(explorer,'Explorer missing after legacy restore')
    T.eq(report.tree_path,s.cwd,'Explorer must keep the restored project root')
    local shutdown=read('shutdown.json')
    assert(shutdown.ok and shutdown.exit_code==0 and shutdown.exit_signal==0 and not shutdown.hard_kill)
    T.eq(shutdown.api_errors,{})
    assert(shutdown.scope.ok and (shutdown.scope.active_after==0 or shutdown.scope.active_after==false) and not shutdown.scope.terminated)
    T.eq(shutdown.scope.stages or {},{})
    for _,stage in ipairs(shutdown.stages) do assert(stage.stage~='sigterm' and stage.stage~='sigkill') end
    assert(files>0,'Listed legacy file was not restored to a code window')
    assert(focused and focused.bt=='' and focused.ft=='text' and not focused.floating and not focused.marker,
      'Legacy focus '..variant..': '..vim.inspect(focused))
    assert(focused.file==s.cwd..'/first.txt' or focused.file==s.cwd..'/second.txt','Wrong legacy file')
  end)
end
T.finish()
