-- Реальные окна/буферы: один сценарий для существующих language E2E.
local M={}
function M.code(e)
  e:input('<F7>')
  e:wait('Фокус в коде',function() return not e:current_ft():match('^dap') and e:current_ft()~='OverseerList' end)
end
function M.state(e,ft)
  return e:lua([[local ft=...;local out={};for _,b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].filetype==ft then
      out[#out+1]={buf=b,channel=vim.bo[b].channel,text=table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false),'\n')}
    end end;return out]],{ft})
end
function M.reopen(e,ft,keys)
  local before=M.state(e,ft)
  assert(#before==1,'Ожидается один Output buffer: '..vim.inspect(before))
  local session=e:lua([[local s=require('dap').session();return s and {id=s.id,thread=s.stopped_thread_id,frame=s.current_frame and s.current_frame.id} or false]])
  M.code(e)
  e:input(' wc')
  e:wait('Output focus перед hide',function() return e:current_ft()==ft end)
  e:input('q')
  e:wait('Output скрыт',function() return not e:has_window(ft) end)
  if keys==' du' then
    -- Toggle закрывает всю видимую Debug-группу, включая оставшийся sidebar.
    e:input(' du')
    e:wait('Debug-группа скрыта',function() return not e:has_window('dapui_scopes') end)
  end
  e:input(keys or ' md')
  e:wait('Тот же канал после manual reopen',function() return e:has_window(ft) end)
  local after=M.state(e,ft)
  assert(#after==1 and before[1].buf==after[1].buf and before[1].channel==after[1].channel,'Reopen заменил Output/PTY')
  assert(after[1].text:find(before[1].text,1,true),'Reopen потерял историю')
  local now=e:lua([[local s=require('dap').session();return s and {id=s.id,thread=s.stopped_thread_id,frame=s.current_frame and s.current_frame.id} or false]])
  assert(vim.deep_equal(session,now),'UI изменил сессию/паузу')
  local file=e.dir..'/output-policy.jsonl'
  vim.fn.writefile({vim.json.encode({keys=keys or ' md',session=session,before=before,after=after})},file,'a')
end
return M
