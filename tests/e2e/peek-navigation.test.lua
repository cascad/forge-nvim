-- spec: IDE-PANEL-9. Настоящие gopls, ввод и окна; ответы LSP не подменяются.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local deps=vim.env.FORGE_E2E_LSP_DEPS or root..'/.tests/lsp-deps'
local manifest=vim.json.decode(table.concat(vim.fn.readfile(deps..'/manifest.json'),'\n'))
T.eq(manifest.tools.gopls.version,'v0.23.0')
local files={'go.mod','library.go','use.go','types.go'}
local function windows(e)
  return e:lua([[local out={};for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local b=vim.api.nvim_win_get_buf(w);local c=vim.api.nvim_win_get_config(w)
    out[#out+1]={id=w,name=vim.api.nvim_buf_get_name(b),ft=vim.bo[b].filetype,
      floating=c.relative~='',pos=vim.api.nvim_win_get_position(w),cursor=vim.api.nvim_win_get_cursor(w),
      line=vim.api.nvim_buf_get_lines(b,vim.api.nvim_win_get_cursor(w)[1]-1,vim.api.nvim_win_get_cursor(w)[1],false)[1]}
    end;return out]])
end
local function has_list(e)
  for _,w in ipairs(windows(e)) do if w.ft=='Glance' then return true end end
  return false
end
local function preview(e,file,text,row)
  for _,w in ipairs(windows(e)) do
    if w.floating and w.ft=='go' and w.name:sub(-#file)==file
      and (not text or w.line:find(text,1,true)) and (not row or w.cursor[1]==row) then return true end
  end
  return false
end
local function seek(e,word)
  e:input('gg/'..word..'<CR>')
  e:wait('символ '..word,function() return e:lua([[return vim.fn.expand('<cword>')]])==word end)
end
local function peek(e,keys,file,text,row)
  e:input(keys)
  e:wait(keys..' показал настоящий preview',function()
    return e:current_ft()=='Glance' and preview(e,file,text,row)
  end,20000)
end
local function closed(e,original)
  e:wait('Peek закрыт и исходное место восстановлено',function()
    return not has_list(e) and e:lua('return vim.api.nvim_get_current_win()')==original.win
      and e:current_file():sub(-6)=='use.go'
      and vim.deep_equal(e:lua('return vim.api.nvim_win_get_cursor(0)'),original.cursor)
  end,5000)
  for _,w in ipairs(windows(e)) do assert(not (w.floating and w.ft=='go'),'остался preview') end
end
local function state(e)
  return e:lua([[return {requests=_G.forge_peek_requests,notifications=vim.g.forge_e2e_notifications,
    mode=vim.api.nvim_get_mode(),messages=vim.fn.execute('messages'),
    spawns=_G.forge_e2e_spawns,installs=vim.g.forge_e2e_installs,
    cursor=vim.api.nvim_win_get_cursor(0),file=vim.api.nvim_buf_get_name(0)}]])
end
local function check(name,fn)
  if vim.env.FORGE_PEEK_CASE and not name:find(vim.env.FORGE_PEEK_CASE,1,true) then return end
  T.check('IDE-PANEL-9 '..name,function()
    local e
    local ok,err=pcall(function()
      local suffix=vim.fn.has('win32')==1 and '.exe' or ''
      local sdk=vim.env.FORGE_E2E_DAP_TOOLS or root..'/.tests/dap-tools'
      local go=sdk..'/go/bin'
      if vim.fn.filereadable(go..'/go'..suffix)==0 then go=vim.fn.fnamemodify(vim.fn.exepath('go'),':h') end
      assert(go~='','явно подготовь Go SDK')
      local path={go,deps..'/bin'}
      for _,exe in ipairs({'git','rg'}) do
        local found=vim.fn.exepath(exe);assert(found~='',exe..' отсутствует')
        path[#path+1]=vim.fn.fnamemodify(found,':h')
      end
      if vim.fn.has('win32')==1 then
        path[#path+1]=vim.env.SystemRoot..'/System32';path[#path+1]=vim.env.SystemRoot
      else path[#path+1]='/usr/bin';path[#path+1]='/bin' end
      e=require('editor').start(root,{timeout=180000,env={
        PATH=table.concat(path,vim.fn.has('win32')==1 and ';' or ':'),
        GOENV='off',GOTOOLCHAIN='local',GOPROXY='off',GOSUMDB='off',GOTELEMETRY='off',
        GOMAXPROCS='2',GOFLAGS='-p=2',CGO_ENABLED='0'},prepare=function(project,env,runtime)
          env.GOPATH=runtime..'/go';env.GOMODCACHE=deps..'/gopath/pkg/mod'
          env.GOCACHE=require('go_cache').path(root)
          local dir=project..'/Peek workspace ü';vim.fn.mkdir(dir,'p')
          for _,file in ipairs(files) do
            assert(vim.uv.fs_copyfile(root..'/tests/e2e/fixtures/peek-navigation/'..file,dir..'/'..file))
          end
        end})
      e.go=(e.project..'/Peek workspace ü'):gsub('\\','/')
      vim.fn.writefile(vim.fn.readfile(root..'/tests/e2e/peek-navigation.test.lua'),e.dir..'/peek-navigation.test.lua')
      vim.fn.writefile({vim.json.encode(manifest)},e.dir..'/lsp-dependencies.json')
      e:lua([[vim.lsp.log.set_level('debug');_G.forge_peek_requests={};
        vim.api.nvim_create_autocmd('LspRequest',{callback=function(ev)
          local r=ev.data.request;table.insert(_G.forge_peek_requests,{method=r.method,type=r.type}) end})]])
      e:input(':cd '..vim.fn.fnameescape(e.go)..'<CR>:edit '..vim.fn.fnameescape(e.go..'/use.go')..'<CR>')
      e:wait('gopls прикреплён к настоящему Go проекту',function()
        return e:current_file():sub(-6)=='use.go' and e:lua([[for _,c in ipairs(vim.lsp.get_clients({bufnr=0,name='gopls'})) do
          if c.initialized and not c:is_stopped() then return true end end;return false]])
      end,20000)
      seek(e,'Double')
      e.original={win=e:lua('return vim.api.nvim_get_current_win()'),cursor=e:lua('return vim.api.nvim_win_get_cursor(0)')}
      fn(e)
      local observed=state(e)
      T.eq(observed.installs,0);assert(not observed.mode.blocking,'неожиданный prompt')
      assert(not observed.messages:match('E%d+:'),observed.messages)
      for _,n in ipairs(observed.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
      for _,file in ipairs(files) do
        T.eq(vim.fn.readfile(e.go..'/'..file),vim.fn.readfile(root..'/tests/e2e/fixtures/peek-navigation/'..file))
      end
    end)
    if e then
      pcall(function()
        local observed=state(e);observed.windows=windows(e)
        vim.fn.writefile({vim.json.encode(observed)},e.dir..'/peek-state.json')
        local log=e:lua('return vim.lsp.log.get_filename()')
        if vim.fn.filereadable(log)==1 then assert(vim.uv.fs_copyfile(log,e.dir..'/lsp.log')) end
      end)
      e:snapshot(name);io.stdout:write('  artifacts: '..e.dir..'\n');e:stop(not ok and tostring(err) or nil)
    end
    assert(ok,err)
  end)
end
for _,key in ipairs({'q','<Esc>'}) do
  check(key..' закрывает definition и возвращает курсор',function(e)
    peek(e,'gpd','library.go','func Double',3)
    e:input(key);closed(e,e.original)
  end)
end
check('references j/k обновляют preview и Enter открывает выбранный usage',function(e)
  e:input('gpr')
  e:wait('references list',function() return e:current_ft()=='Glance' end,20000)
  local function row(text)
    return e:lua([[local text=...;for i,s in ipairs(vim.api.nvim_buf_get_lines(0,0,-1,false)) do
      if s:find(text,1,true) then return i end end;return 0]],{text})
  end
  local group=row('use.go');assert(group>0,'нет группы use.go')
  e:input(group..'Gl')
  e:wait('раскрыта группа references',function() return row('Double(21)')>0 and row('Double(2)')>0 end)
  e:input(group..'Gh')
  e:wait('h свернул группу references',function() return row('Double(21)')==0 and row('Double(2)')==0 end)
  e:input('l')
  e:wait('l снова раскрыл references',function() return row('Double(21)')>0 and row('Double(2)')>0 end)
  local first=row('Double(21)');local second=row('Double(2)');T.eq(second,first+1)
  -- Позиционирование только клавиатурой; mapped j/k должны обновить preview.
  e:input(first..'Gj')
  e:wait('j выбрал второй usage',function() return preview(e,'use.go','Double(2)',8) end)
  T.eq(e:lua('return vim.api.nvim_win_get_cursor(0)[1]'),second)
  e:input('k')
  e:wait('k вернул первый usage',function() return preview(e,'use.go','Double(21)',4) end)
  e:input('j<CR>')
  e:wait('Enter открыл выбранный usage',function()
    return not has_list(e) and e:current_file():sub(-6)=='use.go'
      and e:lua([[return vim.api.nvim_win_get_cursor(0)[1]==8 and vim.fn.expand('<cword>')=='Double']])
  end)
end)
for _,item in ipairs({{'v','вертикальный'},{'s','горизонтальный'}}) do
  check(item[1]..' открывает '..item[2]..' split',function(e)
    peek(e,'gpd','library.go','func Double',3)
    e:input(item[1])
    e:wait('целевая позиция открыта в split',function()
      return not has_list(e) and e:current_file():sub(-10)=='library.go'
        and e:lua([[return vim.api.nvim_win_get_cursor(0)[1]==3 and vim.fn.expand('<cword>')=='Double']])
    end)
    local code={};for _,w in ipairs(windows(e)) do if not w.floating and w.ft=='go' then code[#code+1]=w end end
    T.eq(#code,2)
    if item[1]=='v' then T.eq(code[1].pos[1],code[2].pos[1]);assert(code[1].pos[2]~=code[2].pos[2])
    else T.eq(code[1].pos[2],code[2].pos[2]);assert(code[1].pos[1]~=code[2].pos[1]) end
  end)
end
check('gpt/gpi показывают настоящий тип и реализацию',function(e)
  seek(e,'item');peek(e,'gpt','types.go','type Widget',7);e:input('q')
  e:wait('type Peek закрыт',function() return not has_list(e) and e:current_ft()=='go' end)
  seek(e,'Named');peek(e,'gpi','types.go','type Widget',7);e:input('q')
  e:wait('implementation Peek закрыт',function() return not has_list(e) and e:current_ft()=='go' end)
  local methods={};for _,r in ipairs(state(e).requests) do methods[r.method]=true end
  assert(methods['textDocument/typeDefinition'] and methods['textDocument/implementation'])
end)
check('Space l переключает list/preview, Q закрывает из обоих окон',function(e)
  peek(e,'gpd','library.go','func Double',3)
  e:input(' l')
  e:wait('фокус в preview',function() return e:current_file():sub(-10)=='library.go' and e:lua([[return vim.api.nvim_win_get_config(0).relative~='']]) end)
  e:input(' l');e:wait('фокус в списке',function() return e:current_ft()=='Glance' end)
  e:input('Q');closed(e,e.original)
  peek(e,'gpd','library.go','func Double',3);e:input(' l')
  e:wait('фокус в preview повторно',function() return e:current_file():sub(-10)=='library.go' end)
  e:input('Q');closed(e,e.original)
end)
T.finish()
