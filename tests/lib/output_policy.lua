-- Реальные окна/буферы: один сценарий для существующих language E2E.
local M={}
function M.code(e)
  e:input('<F7>')
  e:wait('Фокус в коде',function() return not e:current_ft():match('^dap') and e:current_ft()~='OverseerList' end)
end
function M.state(e,ft)
  return e:lua([[local ft=...;local out={};for _,b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].filetype==ft then
      out[#out+1]={buf=b,channel=vim.bo[b].channel,buftype=vim.bo[b].buftype,text=table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false),'\n')}
    end end;return out]],{ft})
end
function M.history_preserved(before,after)
  local previous,current=before.text,after.text
  if before.buftype=='terminal' and after.buftype=='terminal' then
    -- Empty terminal rows reflect the viewport height, including after resize.
    previous=previous:gsub('\n+$','');current=current:gsub('\n+$','')
  end
  return current:find(previous,1,true)~=nil
end
function M.reopen(e,ft,keys)
  e.output_attempt=(e.output_attempt or 0)+1
  local attempt={ft=ft,keys=keys or ' md',timeline={}}
  local function stage(name) attempt.stage=name;attempt.timeline[#attempt.timeline+1]={stage=name,ns=vim.uv.hrtime()} end
  local ok,err=xpcall(function()
  stage('before')
  local before=M.state(e,ft);attempt.before=before
  assert(#before==1,'Ожидается один Output buffer: '..vim.inspect(before))
  local session=e:lua([[local s=require('dap').session();return s and {id=s.id,thread=s.stopped_thread_id,frame=s.current_frame and s.current_frame.id} or false]])
  attempt.session=session;stage('code-focus')
  M.code(e)
  e:input(' wc')
  e:wait('Output focus перед hide',function() return e:current_ft()==ft end)
  stage('hide-output')
  e:input('q')
  e:wait('Output скрыт',function() return not e:has_window(ft) end)
  if keys==' du' then
    -- Toggle закрывает всю видимую Debug-группу, включая оставшийся sidebar.
    stage('toggle-close')
    e:input(' du')
    e:wait('Debug-группа скрыта',function() return not e:has_window('dapui_scopes') end)
  end
  stage('reopen')
  e:input(keys or ' md')
  e:wait('Тот же канал после manual reopen',function() return e:has_window(ft) end)
  local after=M.state(e,ft);attempt.after=after;stage('history-check')
  assert(#after==1 and before[1].buf==after[1].buf and before[1].channel==after[1].channel,'Reopen заменил Output/PTY')
  assert(M.history_preserved(before[1],after[1]),'Reopen потерял историю')
  local now=e:lua([[local s=require('dap').session();return s and {id=s.id,thread=s.stopped_thread_id,frame=s.current_frame and s.current_frame.id} or false]])
  attempt.now=now;stage('session-check')
  assert(vim.deep_equal(session,now),'UI изменил сессию/паузу')
  local file=e.dir..'/output-policy.jsonl'
  vim.fn.writefile({vim.json.encode({keys=keys or ' md',session=session,before=before,after=after})},file,'a')
  end,debug.traceback)
  attempt.ok=ok;attempt.error=not ok and tostring(err) or nil
  attempt.capture=require('output_capture').snapshot(e)
  local saved,save_error=pcall(function()
    assert(vim.fn.writefile({vim.json.encode(attempt)},e.dir..('/output-attempt-%02d.json'):format(e.output_attempt))==0,'Output capture write failed')
  end)
  if not ok then error(tostring(err)..(not saved and ('\nCapture: '..tostring(save_error)) or ''),0) end
  assert(saved,tostring(save_error))
end
return M
