local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local function check(name,options,fn)
  T.check('SELF: UI-CAPTURE '..name,function()
    local e
    local ok,err=xpcall(function()
      e=require('editor').start(root,options)
      for _,file in ipairs({'tests/e2e/ui-capture.test.lua','tests/diagnostics/render-ui.py','tests/lib/ui_grid.py'}) do
        assert(vim.uv.fs_copyfile(root..'/'..file,e.dir..'/'..vim.fn.fnamemodify(file,':t')))
      end
      e:wait('editor ready',function() return e:lua('return _G.forge_e2e_observed') end,10000)
      fn(e)
      T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
    end,debug.traceback)
    if e then
      e:snapshot(name);io.stdout:write('  artifacts: '..e.dir..'\n')
      local stopped,cleanup=pcall(e.stop,e,not ok and err or nil)
      if not stopped then ok=false;err=tostring(err or '')..'\nCleanup: '..tostring(cleanup) end
      if e.rpc.shutdown_result then
        T.eq(e.rpc.exit_code,0);T.eq(e.rpc.exit_signal,0);T.eq(e.rpc.api_errors,{})
        assert(e.rpc.shutdown_result.ok,vim.inspect(e.rpc.shutdown_result))
      end
    end
    assert(ok,err)
  end)
end
local function checkpoint(e,label)
  local capture=e.rpc.ui_capture;assert(capture,'UI capture was not enabled')
  local previous=capture.flushes
  local info=e:lua([[vim.cmd('redraw!');local w=vim.api.nvim_get_current_win();local b=vim.api.nvim_get_current_buf()
    local top=vim.api.nvim_win_call(w,function() return vim.fn.line('w0') end)
    local pos=vim.fn.screenpos(w,top,1)
    return {row=pos.row-1,col=pos.col-1,text=vim.api.nvim_buf_get_lines(b,top-1,top,false)[1]}]])
  e:wait('actual redraw flush',function() return capture.flushes>previous end)
  capture:checkpoint(label,info);assert(not capture.error,capture.error)
end
check('RGB UTF8 scroll resize export',{capture_ui=true},function(e)
  assert(e.rpc.ui_capture,'UI capture was not enabled')
  e:lua([[vim.cmd('enew');vim.bo.buftype='nofile';vim.bo.bufhidden='wipe';vim.bo.filetype=''
    local lines={'RGB_CAPTURE Ω界 & <tag>'};for i=2,90 do lines[i]=('UI_ROW_%03d'):format(i) end
    vim.api.nvim_buf_set_lines(0,0,-1,false,lines);vim.wo.number=false;vim.wo.relativenumber=false
    vim.wo.signcolumn='no';vim.wo.foldcolumn='0';vim.wo.statuscolumn='';vim.wo.wrap=false
    vim.api.nvim_set_hl(0,'ForgeCaptureVector',{fg=0xff5733,bg=0x112233})
    vim.api.nvim_buf_set_extmark(0,vim.api.nvim_create_namespace('capture-vector'),0,0,{end_row=1,hl_group='ForgeCaptureVector'})
    vim.api.nvim_win_set_cursor(0,{1,0})]])
  checkpoint(e,'utf8-rgb')
  e:lua([[vim.cmd('normal! '..vim.api.nvim_replace_termcodes('7<C-e>',true,false,true))]])
  checkpoint(e,'scrolled')
  e.rpc:request('nvim_ui_try_resize',{100,35});checkpoint(e,'resized')
  local python=vim.fn.exepath(vim.fn.has('win32')==1 and 'python' or 'python3');assert(python~='','Python 3 required')
  local converted=vim.system({python,'-B',root..'/tests/diagnostics/render-ui.py',e.rpc.ui_capture.path,'--output',e.dir..'/ui'},
    {text=true,timeout=20000}):wait()
  T.eq(converted.code,0,(converted.stdout or '')..(converted.stderr or ''))
  local frames=vim.json.decode(table.concat(vim.fn.readfile(e.dir..'/ui/frames.json'),'\n'))
  T.eq(#frames,3);T.eq(frames[3].width,100);T.eq(frames[3].height,35)
  assert((frames[2].events.grid_scroll or 0)>0,'Native scroll was not exercised')
  local first=frames[1];local meta=first.metadata;local cells=first.cells[meta.row+1]
  T.eq(cells[meta.col+1][1],'R');local attr=first.highlights[tostring(cells[meta.col+1][2])]
  T.eq(attr.foreground,0xff5733);T.eq(attr.background,0x112233)
  assert(table.concat(vim.tbl_map(function(cell) return cell[1] end,cells),''):find(meta.text,1,true))
  local wide=false;for i,cell in ipairs(cells) do if cell[1]=='界' then T.eq(cells[i+1][1],'');wide=true end end;assert(wide)
  local output=table.concat(vim.fn.readfile(e.dir..'/ui/00-utf8-rgb.svg'),'\n')
  assert(output:find('&amp;',1,true) and output:find('&lt;',1,true),'SVG escaping missing')
end)
check('capture byte limit preserves live RPC',{capture_ui=true,capture_ui_limit=512},function(e)
  assert(e.rpc.ui_capture,'UI capture was not enabled')
  assert(e.rpc.ui_capture.error and e.rpc.ui_capture.error:find('limit',1,true))
  assert(vim.uv.fs_stat(e.rpc.ui_capture.path).size<=512)
  assert(e:lua('return vim.api.nvim_get_current_buf()')>0)
end)
check('capture remains explicitly disabled by default',{},function(e)
  T.eq(e.rpc.ui_capture,nil);T.eq(vim.fn.filereadable(e.dir..'/ui-redraw.jsonl'),0)
end)
T.finish()
