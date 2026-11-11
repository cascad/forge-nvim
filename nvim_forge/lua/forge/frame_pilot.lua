-- spec: IDE-PANEL-20. Явный ограниченный эксперимент; default layout прежний.
local M = {}
local s
local function valid(w) return w and vim.api.nvim_win_is_valid(w) end
function M.active() return s ~= nil end
function M.is_code(w) return s ~= nil and s.code == w end
function M.owns(w) return s ~= nil and (s.code == w or s.locals == w) end
function M.status()
    return s and { root=s.root,code=s.code,locals=s.locals,buf=s.scopes,zoom=s.zoom or false,
        layouts=s.layouts,open_ms=s.open_ms } or false
end
local function native_scopes()
    for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.bo[vim.api.nvim_win_get_buf(w)].filetype=='dapui_scopes' then return w end
    end
end
local function rectangle(w)
    local p=vim.api.nvim_win_get_position(w)
    return {row=p[1],col=p[2],width=vim.api.nvim_win_get_width(w),height=vim.api.nvim_win_get_height(w)}
end
local function enough(r) return r.width>=64 and r.height>=8 end
local function accent(w,title)
    local focused=vim.api.nvim_get_current_win()==w
    vim.api.nvim_win_set_config(w,{title={{' '..title..(focused and ' [focus] ' or ' '),focused and 'DiagnosticInfo' or 'Comment'}}})
    vim.wo[w].winhl='FloatBorder:'..(focused and 'DiagnosticInfo' or 'Comment')
    vim.wo[w].winbar=''
end
function M.refresh()
    if not s then return end
    if valid(s.code) then accent(s.code,'Code') end
    if valid(s.locals) then accent(s.locals,'Locals') end
end
function M.layout()
    if not s then return end
    if not valid(s.root) or not valid(s.code) then M.stop();return end
    local r=rectangle(s.root)
    if not enough(r) then
        M.stop();vim.notify('Frame pilot: мало места, рамки выключены',vim.log.levels.INFO);return
    end
    local left=valid(s.locals) and math.min(40,math.floor(r.width*0.3)) or 0
    vim.api.nvim_win_set_config(s.code,{relative='editor',row=r.row,col=r.col+left,width=r.width-left-2,height=r.height-2})
    if valid(s.locals) then
        vim.api.nvim_win_set_config(s.locals,{relative='editor',row=r.row,col=r.col,
            width=(s.zoom and r.width or left)-2,height=r.height-2,zindex=s.zoom and 55 or 50})
    end
    s.layouts=s.layouts+1
    M.refresh()
end
function M.focus_code()
    if not s then return false end
    s.zoom=false;M.layout();vim.api.nvim_set_current_win(s.code);return true
end
function M.show()
    if not s then return false end
    if not valid(s.locals) then
        s.locals=vim.api.nvim_open_win(s.scopes,false,{relative='editor',row=0,col=0,width=20,height=6,
            border='rounded',style='minimal',noautocmd=true})
        vim.w[s.locals].edgy_disable=true
    end
    M.layout();return true
end
function M.hide()
    if not s then return false end
    local w=s.locals;s.locals=nil;s.zoom=false
    vim.api.nvim_set_current_win(s.code)
    if valid(w) then vim.api.nvim_win_close(w,true) end
    M.layout();return true
end
function M.restore()
    if not s or not s.zoom then return false end
    s.zoom=false;M.layout();return true
end
function M.zoom()
    if not s or vim.api.nvim_get_current_win()~=s.locals then return false end
    s.zoom=not s.zoom;M.layout();return true
end
function M.direction(direction)
    if not s then return false end
    M.restore()
    -- Геометрия только этого пилота: левый Locals, правый Code, native bottom.
    local current=vim.api.nvim_get_current_win()
    if direction=='h' and current==s.code and valid(s.locals) then vim.api.nvim_set_current_win(s.locals)
    elseif direction=='l' and current==s.locals then vim.api.nvim_set_current_win(s.code)
    elseif direction=='k' and not M.owns(current) then vim.api.nvim_set_current_win(s.code)
    elseif direction=='j' and M.owns(current) then
        local r=rectangle(s.root)
        for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if w~=s.root and not M.owns(w) and vim.api.nvim_win_get_config(w).relative==''
                and vim.api.nvim_win_get_position(w)[1]>=r.row+r.height then
                vim.api.nvim_set_current_win(w);break
            end
        end
    end
    return true
end
function M.stop(reopen)
    if not s then return end
    local old=s;s=nil
    vim.api.nvim_del_augroup_by_id(old.group)
    local buf=valid(old.code) and vim.api.nvim_win_get_buf(old.code) or old.buf
    local view=valid(old.code) and vim.api.nvim_win_call(old.code,vim.fn.winsaveview) or old.view
    if valid(old.root) then
        vim.api.nvim_win_set_buf(old.root,buf);vim.wo[old.root].winbar=old.winbar
        vim.api.nvim_win_call(old.root,function() vim.fn.winrestview(view) end)
    end
    for _,w in ipairs({old.locals or false,old.code or false}) do if valid(w) then vim.api.nvim_win_close(w,true) end end
    if vim.api.nvim_buf_is_valid(old.base) then vim.api.nvim_buf_delete(old.base,{force=true}) end
    if reopen~=false and vim.api.nvim_get_current_tabpage()==old.tab then
        require('dapui').open({layout=1})
    end
    if valid(old.root) and vim.api.nvim_get_current_tabpage()==old.tab then vim.api.nvim_set_current_win(old.root) end
end
function M.start()
    if s then M.stop();return end
    local dap=package.loaded.dap
    if not dap or not dap.session() or not dap.session().stopped_thread_id then
        vim.notify('Frame pilot: сначала остановитесь на breakpoint',vim.log.levels.INFO);return
    end
    local main=require('ide.state').find_main_window()
    local count=0
    for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do if require('ide.state').is_main_window(w) then count=count+1 end end
    if count~=1 or not enough(rectangle(main)) then
        vim.notify('Frame pilot: нужны одна группа кода и область от 64×8',vim.log.levels.INFO);return
    end
    local started=vim.uv.hrtime()
    local buf=vim.api.nvim_win_get_buf(main)
    local view=vim.api.nvim_win_call(main,vim.fn.winsaveview)
    local winbar=vim.wo[main].winbar
    require('dapui').open({layout=1})
    local source=assert(native_scopes(),'native Locals не открылись')
    local scopes=vim.api.nvim_win_get_buf(source)
    local cursor=vim.api.nvim_win_get_cursor(source)
    require('dapui').close({layout=1})
    local base=vim.api.nvim_create_buf(false,true)
    vim.bo[base].bufhidden='wipe';vim.bo[base].filetype='forge-frame-root'
    vim.api.nvim_win_set_buf(main,base);vim.wo[main].winbar=''
    local code=vim.api.nvim_open_win(buf,false,{relative='editor',row=0,col=0,width=40,height=8,border='rounded',noautocmd=true})
    vim.w[code].edgy_disable=true
    vim.api.nvim_win_call(code,function() vim.fn.winrestview(view) end)
    s={root=main,code=code,buf=buf,base=base,scopes=scopes,tab=vim.api.nvim_get_current_tabpage(),view=view,winbar=winbar,layouts=0}
    s.group=vim.api.nvim_create_augroup('ForgeFramePilot',{clear=true})
    M.show();vim.api.nvim_win_set_cursor(s.locals,cursor);vim.api.nvim_set_current_win(s.locals)
    s.open_ms=(vim.uv.hrtime()-started)/1e6
    local group=s.group
    vim.api.nvim_create_autocmd({'WinResized','VimResized'},{group=group,callback=function() vim.schedule(M.layout) end})
    vim.api.nvim_create_autocmd('WinEnter',{group=group,callback=function() vim.schedule(M.refresh) end})
    vim.api.nvim_create_autocmd({'TabLeave','VimLeavePre'},{group=group,callback=function() M.stop(false) end})
    vim.api.nvim_create_autocmd('WinClosed',{group=group,callback=function(ev)
        if s and (tonumber(ev.match)==s.root or tonumber(ev.match)==s.code) then vim.schedule(function() M.stop(false) end) end
    end})
    vim.api.nvim_create_autocmd('BufWinEnter',{group=group,callback=function()
        if not s then return end
        -- Native sidebar-команды выходят из эксперимента вместо второго layout.
        for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if w~=s.root and not M.owns(w) and vim.api.nvim_win_get_config(w).relative==''
                and vim.api.nvim_win_get_position(w)[2]==0
                and vim.api.nvim_win_get_position(w)[1]==vim.api.nvim_win_get_position(s.root)[1] then
                vim.schedule(function() M.stop(false) end);return
            end
        end
    end})
    M.refresh()
end
return M
