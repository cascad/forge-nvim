local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local deps=vim.env.FORGE_E2E_LSP_DEPS or root..'/.tests/lsp-deps'
assert(vim.fn.filereadable(deps..'/manifest.json')==1,'Явно выполни python[3] -B tests/e2e/prepare_lsp.py --download')
local manifest=vim.json.decode(table.concat(vim.fn.readfile(deps..'/manifest.json'),'\n'))
T.eq(manifest.tools.gopls.version,'v0.23.0');T.eq(manifest.tools.gofumpt.version,'v0.9.2')
local function lines(e) return e:lua([[return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n')]]) end
local function open(e,file)
  e:input(':edit '..vim.fn.fnameescape(e.go..'/'..file)..'<CR>')
  e:wait('Go файл '..file,function() return e:current_file():sub(-#file)==file and e:current_ft()=='go' end,10000)
  e:wait('настоящий gopls прикреплён',function()
    return e:lua([[for _,c in ipairs(vim.lsp.get_clients({bufnr=0,name='gopls'})) do
      if c.initialized and not c:is_stopped() and vim.fn.maparg('gd','n',false,true).buffer==1 then return true end end;return false]])
  end,20000)
end
local function seek(e,word)
  e:input('gg/'..word..'<CR>')
  e:wait('выбран '..word,function() return e:lua([[return vim.fn.expand('<cword>')]])==word end)
end
local function check(name,fallback,fn)
  if vim.env.FORGE_GO_LANGUAGE_CASE and not name:find(vim.env.FORGE_GO_LANGUAGE_CASE,1,true) then return end
  T.check((name:match('^IDE%-') and '' or 'SELF: GO-LANGUAGE ')..name,function()
    local e
    local ok,err=pcall(function()
      local sep=vim.fn.has('win32')==1 and ';' or ':'
      local suffix=vim.fn.has('win32')==1 and '.exe' or ''
      local sdk=vim.env.FORGE_E2E_DAP_TOOLS or root..'/.tests/dap-tools'
      local go=vim.fn.filereadable(sdk..'/go/bin/go'..suffix)==1 and sdk..'/go/bin' or vim.fn.fnamemodify(vim.fn.exepath('go'),':h')
      local path={go}
      if fallback~='no-lsp' then path[#path+1]=deps..'/bin' end
      if not fallback then path[#path+1]=deps..'/format-bin' end
      for _,exe in ipairs({'git','rg'}) do
        local found=vim.fn.exepath(exe);assert(found~='',exe..' отсутствует')
        path[#path+1]=vim.fn.fnamemodify(found,':h')
      end
      if vim.fn.has('win32')==1 then
        path[#path+1]=vim.env.SystemRoot..'/System32';path[#path+1]=vim.env.SystemRoot
      else path[#path+1]='/usr/bin';path[#path+1]='/bin' end
      e=require('editor').start(root,{timeout=180000,env={PATH=table.concat(path,sep),
        GOTOOLCHAIN='local',GOENV='off',GOPROXY='off',GOSUMDB='off',GOTELEMETRY='off',CGO_ENABLED='0',
        GOMAXPROCS='2',GOCACHE=require('go_cache').path(root),GOPATH=root..'/.tests/tmp/go-language-gopath',
        GOMODCACHE=deps..'/gopath/pkg/mod'},prepare=function(project)
          local dir=project..'/Go workspace ü';vim.fn.mkdir(dir,'p')
          for _,file in ipairs({'go.mod','library.go','use.go','completion.go','format.go'}) do
            assert(vim.uv.fs_copyfile(root..'/tests/e2e/fixtures/go-language/'..file,dir..'/'..file))
          end
          for _,item in ipairs({{'command.go','CommandFormat'},{'shortcut.go','KeyFormat'},{'save.go','AutoFormat'}}) do
            local source=table.concat(vim.fn.readfile(root..'/tests/e2e/fixtures/go-language/format.go'),'\n'):gsub('Unformatted',item[2])
            vim.fn.writefile(vim.split(source,'\n',{plain=true}),dir..'/'..item[1])
          end
          vim.fn.writefile({'package sample   ','','func Cleanup() int { return 1 }   ','',''},dir..'/cleanup.go')
          vim.fn.writefile({'plain text   ','',''},dir..'/cleanup.txt')
        end})
      e.go=(e.project..'/Go workspace ü'):gsub('\\','/')
      vim.fn.writefile(vim.fn.readfile(root..'/tests/e2e/go-language.test.lua'),e.dir..'/go-language.test.lua')
      vim.fn.writefile({vim.json.encode(manifest)},e.dir..'/lsp-dependencies.json')
      e:lua([[vim.lsp.log.set_level('debug');_G.forge_language_requests={};
        vim.api.nvim_create_autocmd('LspRequest',{callback=function(ev)
          local r=ev.data.request;table.insert(_G.forge_language_requests,{method=r.method,type=r.type,client=ev.data.client_id}) end})]])
      e:input(':cd '..vim.fn.fnameescape(e.go)..'<CR>')
      fn(e)
      local state=e:lua([[return {requests=_G.forge_language_requests,clients=vim.tbl_map(function(c)
        return {name=c.name,cmd=c.config.cmd,root=c.root_dir} end,vim.lsp.get_clients()),
        notifications=vim.g.forge_e2e_notifications,mode=vim.api.nvim_get_mode(),messages=vim.fn.execute('messages'),
        spawns=_G.forge_e2e_spawns,installs=vim.g.forge_e2e_installs} ]])
      vim.fn.writefile({vim.json.encode(state)},e.dir..'/language-state.json')
      T.eq(state.installs,0);assert(not state.mode.blocking,'неожиданный prompt')
      assert(not state.messages:match('E%d%d%d+:'),state.messages)
      for _,n in ipairs(state.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
    end)
    if e then
      local got_state,observed=pcall(function() return e:lua([[local function map(key)
        local m=vim.fn.maparg(key,'n',false,true);return {desc=m.desc,rhs=m.rhs,callback=type(m.callback),buffer=m.buffer} end;
        local plan;if package.loaded.conform then local f,l=require('conform').list_formatters_to_run(0);
          plan={names=vim.tbl_map(function(v) return v.name end,f),lsp=l} end
        return {requests=_G.forge_language_requests,mode=vim.api.nvim_get_mode(),cursor=vim.api.nvim_win_get_cursor(0),
          maps={s=map('s'),format=map(' lf'),gd=map('gd')},format_plan=plan,
          lsp_format_clients=#vim.lsp.get_clients({bufnr=0,method='textDocument/formatting'}),conform_loaded=package.loaded.conform~=nil} ]]) end)
      if got_state then vim.fn.writefile({vim.json.encode(observed)},e.dir..'/action-state.json') end
      local got,log=pcall(function() return e:lua('return vim.lsp.log.get_filename()') end)
      if got and vim.fn.filereadable(log)==1 then vim.uv.fs_copyfile(log,e.dir..'/lsp.log') end
      e:snapshot(name);io.stdout:write('  artifacts: '..e.dir..'\n');e:stop(not ok and tostring(err) or nil)
    end
    assert(ok,err)
  end)
end
check('definition и references настоящего server',false,function(e)
  open(e,'use.go');seek(e,'Double');e:input('gd')
  e:wait('definition в другом файле',function() return e:current_file():sub(-10)=='library.go' and e:lua('return vim.api.nvim_get_current_line()'):find('func Double',1,true) end,20000)
  open(e,'use.go');seek(e,'Double');e:input('gr')
  e:wait('references в quickfix',function() return e:current_ft()=='qf' end,20000)
  local refs=e:lua([[local out={};for _,r in ipairs(vim.fn.getqflist()) do out[#out+1]={path=vim.api.nvim_buf_get_name(r.bufnr),line=r.lnum} end;return out]])
  local found={};for _,r in ipairs(refs) do if r.path:sub(-6)=='use.go' then found[r.line]=true end end
  assert(found[4] and found[8],vim.inspect(refs));e:input('<CR>')
  e:wait('references открыл код',function() return e:current_ft()=='go' end)
end)
check('rename F2 меняет объявление и два usages на диске',false,function(e)
  open(e,'use.go');seek(e,'Double');e:input('<F2>')
  e:wait('диалог rename',function() return e.rpc:request('nvim_get_mode',{}).mode=='c' end,20000)
  e:input('<C-u>TwiceForge<CR>')
  e:wait('rename обновил usages',function() return lines(e):find('TwiceForge(21)',1,true) and lines(e):find('TwiceForge(2)',1,true) end,20000)
  e:input(':wall<CR>')
  e:wait('rename сохранён во всех файлах',function()
    local lib=table.concat(vim.fn.readfile(e.go..'/library.go'),'\n');local uses=table.concat(vim.fn.readfile(e.go..'/use.go'),'\n')
    return lib:find('func TwiceForge(',1,true) and uses:find('TwiceForge(21)',1,true) and uses:find('TwiceForge(2)',1,true)
      and not lib:find('func Double(',1,true) and not uses:find('Double(',1,true)
  end,10000)
end)
check('LSP completion принимается, диагностика появляется и устраняется',false,function(e)
  open(e,'completion.go');e:input('4G0f0')
  e:wait('курсор на значении 0',function() return e:lua([[return vim.fn.expand('<cword>')]])=='0' end)
  e:input('ciw');e:wait('insert перед completion',function() return e.rpc:request('nvim_get_mode',{}).mode=='i' end)
  e:input('Forg<C-Space>')
  e:wait('cmp получил ForgeAnswer из gopls',function()
    return e:lua([[local c=require('cmp');if not c.visible() then return false end;
      for _,v in ipairs(c.get_entries()) do if v.source.name=='nvim_lsp' and v.completion_item.label=='ForgeAnswer' then return true end end;return false]])
  end,20000)
  for _=1,30 do
    if e:lua([[local v=require('cmp').get_selected_entry();return v and v.source.name=='nvim_lsp' and v.completion_item.label=='ForgeAnswer' or false]]) then break end
    e:input('<C-n>');vim.wait(60)
  end
  assert(e:lua([[local v=require('cmp').get_selected_entry();return v and v.source.name=='nvim_lsp' and v.completion_item.label=='ForgeAnswer' or false]]))
  e:input('<CR>');e:wait('completion вставлен',function() return lines(e):find('return ForgeAnswer',1,true) end)
  e:input('<Esc>')
  e:input('4Gccreturn MissingForgeName<Esc>')
  e:wait('настоящая ошибка gopls',function() return e:lua([[for _,d in ipairs(vim.diagnostic.get(0)) do if d.severity==1 and d.message:find('MissingForgeName',1,true) then return true end end;return false]]) end,20000)
  e:input('gl');e:wait('диагностика видна в UI',function() return e:lua([[for _,w in ipairs(vim.api.nvim_list_wins()) do if vim.api.nvim_win_get_config(w).relative~='' then
    if table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w),0,-1,false),'\n'):find('MissingForgeName',1,true) then return true end end end;return false]]) end)
  e:input('<Esc>4Gccreturn ForgeAnswer<Esc>')
  e:wait('исправление убрало ошибку',function() return e:lua([[return #vim.diagnostic.get(0,{severity=vim.diagnostic.severity.ERROR})==0]]) end,20000)
  e:input(':write<CR>');e:wait('completion сохранён',function() return table.concat(vim.fn.readfile(e.go..'/completion.go'),'\n'):find('return ForgeAnswer',1,true) end)
end)
local function formatted(e,fallback,file,symbol,keys)
  file=file or 'format.go';symbol=symbol or 'Unformatted';open(e,file)
  T.eq(e:lua([[return vim.fn.executable('gofumpt')]]),fallback and 0 or 1)
  T.eq(e:lua([[return vim.fn.executable('golines')]]),0)
  e:input(keys or ' lf')
  local expected='package sample\n\nfunc '..symbol..'() int {\n\treturn 21 + 21\n}'
  e:wait('настоящее форматирование',function() return lines(e)==expected end,20000)
  e:input(':write<CR>');e:wait('формат сохранён',function() return table.concat(vim.fn.readfile(e.go..'/'..file),'\n')==expected end)
  if fallback then
    assert(e:lua([[for _,r in ipairs(_G.forge_language_requests) do if r.method=='textDocument/formatting' then return true end end;return false]]),'нет LSP formatting request')
  else
    assert(e:lua([[for _,s in ipairs(_G.forge_e2e_spawns) do if s.cmd:find('gofumpt',1,true) then return true end end;return false]]),'gofumpt не запускался')
  end
end
check('IDE-FMT-1 format gofumpt и сохранение файла',false,function(e)
  formatted(e,false)
  e:input(':checkhealth forge<CR>')
  e:wait('health показывает динамический Go formatter',function()
    return e:current_ft()=='checkhealth' and lines(e):match('%[go%][^\n]*gofumpt')~=nil
  end,15000)
  assert(not lines(e):find('Failed to run healthcheck',1,true),lines(e))
end)
check('IDE-FMT-1 format LSP fallback без внешних форматтеров',true,function(e)
  formatted(e,true)
  formatted(e,true,'command.go','CommandFormat',':Format<CR>')
  formatted(e,true,'shortcut.go','KeyFormat','<S-A-f>')
  open(e,'save.go');e:input(':write<CR>')
  local expected='package sample\n\nfunc AutoFormat() int {\n\treturn 21 + 21\n}'
  e:wait('format_after_save сам записал LSP результат',function()
    return lines(e)==expected and table.concat(vim.fn.readfile(e.go..'/save.go'),'\n')==expected
  end,20000)
end)
check('IDE-FMT-1 trim Go и plaintext без LSP и внешних tools','no-lsp',function(e)
  T.eq(e:lua([[return vim.fn.executable('gopls')+vim.fn.executable('gofumpt')+vim.fn.executable('golines')]]),0)
  for _,item in ipairs({{'cleanup.txt','plain text'},{'cleanup.go','package sample\n\nfunc Cleanup() int { return 1 }'}}) do
    e:input(':edit '..vim.fn.fnameescape(e.go..'/'..item[1])..'<CR>')
    e:wait('файл без LSP',function()
      if e.rpc:request('nvim_get_mode',{}).blocking then e:ack_warning('gopls');return false end
      return e:current_file():sub(-#item[1])==item[1]
    end,10000)
    e:input(' lf');e:wait('common trim',function() return lines(e)==item[2] end)
    e:input(':write<CR>');e:wait('cleanup сохранён',function() return table.concat(vim.fn.readfile(e.go..'/'..item[1]),'\n')==item[2] end)
  end
  T.eq(e:lua('return #vim.lsp.get_clients({bufnr=0})'),0)
end)
T.finish()
