-- Real nested controller, CodeLLDB, private editor and a public UI resize.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
T.check('SELF: OUTPUT-RESIZE native terminal padding preserves semantic history',function()
  local dir=root..'/.tests/output-resize/'..tostring(vim.uv.hrtime());vim.fn.mkdir(dir,'p')
  local result=vim.system({vim.v.progpath,'-l',root..'/tests/diagnostics/output-toggle.lua','--trace','--resize'},
    {cwd=root,text=true,timeout=180000,env={NVIM_LOG_FILE=dir..'/controller.log'}}):wait()
  vim.fn.writefile(vim.split((result.stdout or '')..(result.stderr or ''),'\n'),dir..'/child.log')
  local artifact=(result.stdout or ''):match('artifacts: ([^\r\n]+)')
  assert(artifact,'Missing child artifact: '..(result.stderr or ''))
  artifact=artifact:gsub('\\','/'):gsub('%s+$','')
  local prefix=root..'/.tests/editor-e2e/'
  assert(artifact:sub(1,#prefix)==prefix and artifact:sub(#prefix+1):match('^%d+$'),'Unexpected child artifact')
  local function read(name) return vim.json.decode(table.concat(vim.fn.readfile(artifact..'/'..name),'\n')) end
  local attempt,shutdown,capture=read('output-attempt-01.json'),read('shutdown.json'),read('output-capture.json')
  vim.fn.writefile({vim.json.encode({artifact=artifact,child_exit=result.code,child_signal=result.signal,
    first=attempt,shutdown=shutdown})},dir..'/result.json')
  assert(result.code==0 and result.signal==0,'Native resize failed; artifacts: '..dir..'\n'..(result.stdout or '')..(result.stderr or ''))
  assert(attempt.ok and #attempt.before==1 and #attempt.after==1)
  local before,after=attempt.before[1],attempt.after[1]
  T.eq(before.buf,after.buf);T.eq(before.channel,after.channel)
  assert(not after.text:find(before.text,1,true),'Fixture did not exercise raw padding mismatch')
  for _,marker in ipairs({'POLICY_BEFORE 42','POLICY_STDERR'}) do
    assert(before.text:find(marker,1,true) and after.text:find(marker,1,true),'Meaningful stdout lost')
  end
  assert(shutdown.ok and shutdown.exit_code==0 and shutdown.exit_signal==0 and shutdown.scope.ok)
  T.eq(shutdown.api_errors,{})
  assert(capture.native.total>0 and capture.native.dropped==0 and not capture.error)
  io.stdout:write('  artifacts: '..artifact..'; resize: '..dir..'\n')
end)
T.finish()
