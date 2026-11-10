-- spec: IDE-PANEL-10. Реальные gopls/Neo-tree/Edgy, управляемый порядок producer.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local deps=vim.env.FORGE_E2E_LSP_DEPS or root..'/.tests/lsp-deps'
local tools=vim.env.FORGE_E2E_DAP_TOOLS or root..'/.tests/dap-tools'
assert(vim.fn.filereadable(deps..'/manifest.json')==1,'сначала подготовь LSP SDK')
local function identity(e)
  return e:lua([[return {win=vim.api.nvim_get_current_win(),file=vim.api.nvim_buf_get_name(0),
    cursor=vim.api.nvim_win_get_cursor(0),ft=vim.bo.filetype}]])
end
local function check(name,fn)
  if vim.env.FORGE_OUTLINE_CASE and not name:find(vim.env.FORGE_OUTLINE_CASE,1,true) then return end
  T.check('IDE-PANEL-10 '..name,function()
    local e
    local ok,err=pcall(function()
      local sep=vim.fn.has('win32')==1 and ';' or ':'
      local path=deps..'/bin'..sep..vim.env.PATH
      if vim.fn.isdirectory(tools..'/go/bin')==1 then path=tools..'/go/bin'..sep..path end
      e=require('editor').start(root,{timeout=180000,env={PATH=path,
        GOENV='off',GOTOOLCHAIN='local',GOPROXY='off',GOSUMDB='off',GOTELEMETRY='off',
        GOMAXPROCS='2',GOFLAGS='-p=2',CGO_ENABLED='0'},prepare=function(project,env,runtime)
          env.GOPATH=runtime..'/go';env.GOMODCACHE=deps..'/gopath/pkg/mod'
          env.GOCACHE=require('go_cache').path(root)
          local dir=project..'/Outline workspace ü';vim.fn.mkdir(dir,'p')
          for _,file in ipairs({'go.mod','library.go','use.go'}) do
            assert(vim.uv.fs_copyfile(root..'/tests/e2e/fixtures/go-language/'..file,dir..'/'..file))
          end
        end})
      e.go=(e.project..'/Outline workspace ü'):gsub('\\','/')
      vim.fn.writefile(vim.fn.readfile(root..'/tests/e2e/outline-focus.test.lua'),e.dir..'/outline-focus.test.lua')
      e:input(':cd '..vim.fn.fnameescape(e.go)..'<CR>:lua require("config.start").open_project(vim.fn.getcwd())<CR>')
      e:wait('Explorer',function() return e:has_window('neo-tree') end)
      e:input(' w0');e:wait('main',function() return e:current_ft()~='neo-tree' end)
      e:input(':edit '..vim.fn.fnameescape(e.go..'/use.go')..'<CR>')
      e:wait('реальный gopls',function()
        return e:current_ft()=='go' and e:lua([[for _,c in ipairs(vim.lsp.get_clients({bufnr=0,name='gopls'})) do
          if c.initialized and not c:is_stopped() then return true end end;return false]])
      end,30000)
      e:input(' lo')
      e:wait('Outline LSP symbols',function()
        return e:lua([[for _,w in ipairs(vim.api.nvim_list_wins()) do local b=vim.api.nvim_win_get_buf(w)
          if vim.bo[b].filetype=='aerial' then local s=table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false),'\n')
            if s:find('Use',1,true) and s:find('OtherUse',1,true) then return true end end end;return false]])
      end,20000)
      fn(e)
      local observed=e:lua([[return {notifications=vim.g.forge_e2e_notifications,installs=vim.g.forge_e2e_installs,
        messages=vim.fn.execute('messages'),mode=vim.api.nvim_get_mode(),late_seen=_G.forge_late_seen,late_done=_G.forge_late_done}]])
      assert(observed.installs==0 and not observed.mode.blocking)
      assert(not observed.messages:match('E%d+:'),observed.messages)
      for _,n in ipairs(observed.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
      observed.current=identity(e)
      vim.fn.writefile({vim.json.encode(observed)},e.dir..'/outline-focus-state.json')
      for _,file in ipairs({'go.mod','library.go','use.go'}) do
        T.eq(vim.fn.readfile(e.go..'/'..file),vim.fn.readfile(root..'/tests/e2e/fixtures/go-language/'..file))
      end
    end)
    if e then
      e:snapshot(name);io.stdout:write('  artifacts: '..e.dir..'\n');e:stop(not ok and tostring(err) or nil)
    end
    assert(ok,err)
  end)
end
local function late_tree(e,expected)
  e:lua([[_G.forge_late_seen=0;_G.forge_late_done=false
    vim.api.nvim_create_autocmd({'BufEnter','FileType'},{callback=function()
      if vim.bo.filetype=='neo-tree' then _G.forge_late_seen=_G.forge_late_seen+1 end end})]])
  -- Настоящая public команда в отложенном producer; backend callbacks не подменяются.
  e:input([[:lua vim.defer_fn(function() vim.cmd('Neotree filesystem show left');_G.forge_late_done=true end,100)<CR>]])
  e:wait('позднее реальное дерево открыто и убрано',function()
    return e:lua([[return _G.forge_late_done and _G.forge_late_seen>0]]) and not e:has_window('neo-tree')
  end,10000)
  vim.wait(250)
  T.eq(identity(e),expected,'cleanup отменил выбранный фокус/позицию')
  T.eq(e:lua([[return require('ide').current().slots.left]]),'outline')
  assert(e:has_window('aerial'))
end
check('первое открытие сохраняет фокус после готовности LSP',function(e)
  e:wait('Outline получил фокус',function() return e:current_ft()=='aerial' end)
  local expected=identity(e)
  for _=1,12 do vim.wait(25);T.eq(identity(e),expected) end
end)
check('позднее дерево не отбирает фокус у Outline',function(e)
  e:input(' wa');e:wait('Outline',function() return e:current_ft()=='aerial' end)
  late_tree(e,identity(e))
end)
check('позднее дерево сохраняет явно выбранный code split',function(e)
  e:input(' w0:vsplit '..vim.fn.fnameescape(e.go..'/library.go')..'<CR>')
  e:wait('второе окно кода',function() return e:current_file():sub(-10)=='library.go' end)
  e:input('3G');local expected=identity(e)
  late_tree(e,expected)
end)
T.finish()
