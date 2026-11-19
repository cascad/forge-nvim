-- spec: IDE-BOOT-31. Native LuaLS controls for dependency cleanup; no mocked LSP.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local exe=vim.env.FORGE_E2E_LUALS or vim.fn.exepath('lua-language-server')
assert(exe and vim.fn.executable(exe)==1,'Prepare native LuaLS and set FORGE_E2E_LUALS')
local baseline=vim.env.FORGE_LUA_BASELINE=='1'
local function request(e,method,line,col)
  e:lua([[local method,line,col=...;_G.forge_lua_response=nil
    local c=assert(vim.lsp.get_clients({bufnr=0,name='lua_ls'})[1])
    local params={textDocument=vim.lsp.util.make_text_document_params(),position={line=line,character=col}}
    assert(c:request(method,params,function(err,result)
      _G.forge_lua_response={error=err,result=result}
    end,0))]],{method,line,col})
  local response
  e:wait('native '..method,function()response=e:lua('return _G.forge_lua_response or false');return response end,20000)
  assert(not response.error,vim.inspect(response.error))
  return response.result
end
local function attach(e,file)
  e:input(':edit '..vim.fn.fnameescape(e.project..'/'..file)..'<CR>')
  e:wait('native LuaLS attached',function()return e:lua([[local c=vim.lsp.get_clients({bufnr=0,name='lua_ls'})[1]
    return c and c.initialized or false]])end,30000)
end
local function state(e)
  return e:lua([[local clients={};for _,c in ipairs(vim.lsp.get_clients())do
    clients[#clients+1]={name=c.name,settings=c.config.settings,cmd=c.config.cmd,root=c.root_dir}
  end;return {clients=clients,diagnostics=vim.diagnostic.get(0),runtime=vim.env.VIMRUNTIME,
    neodev_loaded=package.loaded.neodev~=nil,
    neodev_spec=require('lazy.core.config').plugins['neodev.nvim']~=nil,
    installs=vim.g.forge_e2e_installs,messages=vim.fn.execute('messages')} ]])
end
local function check(name,kind,fn)
  if vim.env.FORGE_LUA_CASE and not name:find(vim.env.FORGE_LUA_CASE,1,true)then return end
  T.check('IDE-BOOT-31 '..name,function()
    local e
    local ok,why=xpcall(function()
      e=require('editor').start(root,{timeout=30000,prepare=function(project,env,runtime)
        env.PATH=vim.fs.dirname(exe)..(vim.fn.has('win32')==1 and ';' or ':')..env.PATH
        local library=runtime..'/project-library';vim.fn.mkdir(library,'p')
        vim.fn.writefile({'local M={}','--- FRIDE_PROJECT_LIBRARY_MARKER','---@param value integer',
          '---@return string','function M.render(value) return tostring(value) end','return M'},library..'/fride_probe.lua')
        if kind then
          local config=vim.json.encode({workspace={library={library},checkThirdParty=false},
            diagnostics={globals={'FRIDE_PROJECT_GLOBAL'}}})
          if kind=='jsonc'then config='// explicit project library\n'..config end
          vim.fn.writefile(vim.split(config,'\n',{plain=true}),project..'/.luarc.'..kind)
          vim.fn.writefile({'local probe=require("fride_probe")','local result=probe.render(3)',
            'print(FRIDE_PROJECT_GLOBAL)','return result'},project..'/main.lua')
        else
          vim.fn.writefile({'---@type integer','local amount = "wrong"',
            'local current = vim.api.nvim_get_current_line()','return amount,current'},project..'/main.lua')
        end
      end})
      e:wait('editor ready',function()return e:lua('return _G.forge_e2e_observed')end,10000)
      -- Native executable/logpath only; the production on_init/settings stay intact.
      e:lua([[local exe,log=...;vim.lsp.config('lua_ls',{cmd={exe,'--logpath='..log}})]],{exe,e.runtime..'/luals-log'})
      attach(e,'main.lua');fn(e)
      local seen=state(e);T.eq(seen.neodev_loaded,baseline);T.eq(seen.neodev_spec,baseline);T.eq(seen.installs,0)
      assert(not seen.messages:match('E%d%d%d+:'),seen.messages)
      for _,n in ipairs(e.rpc.notifications)do assert(n.level<vim.log.levels.ERROR,n.message)end
    end,debug.traceback)
    if e then
      local observed,value=pcall(state,e)
      if observed then vim.fn.writefile({vim.json.encode(value)},e.dir..'/lua-language-state.json')end
      e:snapshot('lua-language');io.stdout:write('  artifacts: '..e.dir..'\n')
      local stopped,err=pcall(e.stop,e,not ok and why or nil)
      if not stopped then ok=false;why=tostring(why or '')..'\nCleanup: '..tostring(err)end
    end
    assert(ok,why)
  end)
end
check('Lua diagnostics edit/save and Neovim API',nil,function(e)
  e:wait('real type mismatch',function()return e:lua([[for _,d in ipairs(vim.diagnostic.get(0))do
    if d.code=='assign-type-mismatch'then return true end end;return false]])end,25000)
  local seen=state(e);T.eq(seen.clients[1].settings.Lua.workspace.library,{seen.runtime})
  local hover=request(e,'textDocument/hover',2,29)
  assert(vim.inspect(hover):find('nvim_get_current_line',1,true),vim.inspect(hover))
  local result=request(e,'textDocument/completion',2,#'local current = vim.api.nvim_get_')
  local found=false
  for _,item in ipairs(result.items or result)do if item.label:find('nvim_get_current_line',1,true)then found=true end end
  assert(found,'Neovim API completion missing')
  e:input('gg0j0cclocal amount = 3<Esc>:write<CR>')
  e:wait('diagnostic clears after edit/save',function()return e:lua([[if vim.bo.modified then return false end
    for _,d in ipairs(vim.diagnostic.get(0))do if d.code=='assign-type-mismatch'then return false end end
    return vim.fn.readfile('main.lua')[2]=='local amount = 3']])end,20000)
end)
for _,kind in ipairs({'json','jsonc'})do
  check('explicit .luarc.'..kind..' project library',kind,function(e)
    local result
    e:wait('project library hover',function()
      result=request(e,'textDocument/hover',1,21)
      return vim.inspect(result):find('FRIDE_PROJECT_LIBRARY_MARKER',1,true)~=nil
    end,25000)
    T.eq(state(e).clients[1].settings.Lua.workspace.library or {},{})
    assert(not e:lua([[for _,d in ipairs(vim.diagnostic.get(0))do
      if d.code=='undefined-global' and d.message:find('FRIDE_PROJECT_GLOBAL',1,true)then return true end
    end;return false]]),'Explicit project globals overwritten')
  end)
end
T.finish()
