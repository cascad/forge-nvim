-- spec: IDE-BOOT-41. Real editor, strict settings and native process recovery.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local win=vim.fn.has('win32')==1
local deps=vim.env.FORGE_E2E_NODE_DEPS or root..'/.tests/node-deps'
local function read(path) return vim.json.decode(table.concat(vim.fn.readfile(path),'\n')) end
local node=vim.fs.normalize(deps..'/'..read(deps..'/manifest.json').node)
local bashdeps=vim.env.FORGE_E2E_BASH_DEPS or root..'/.tests/bash-deps'
local bash=read(bashdeps..'/manifest.json').bash
local function json(path,value) vim.fn.mkdir(vim.fs.dirname(path),'p');vim.fn.writefile({vim.json.encode(value)},path) end
local function idle(e)
  local mode=e.rpc:request('nvim_get_mode',{})
  assert(not mode.blocking and mode.mode~='r?','Unexpected hit-enter/confirm prompt')
end
local function logs(e)
  return e:lua([[local lines={};for _,v in ipairs(require('forge.log_store').entries()) do lines[#lines+1]=v.message end;return table.concat(lines,'\n')]])
end
local function open(e,name)
  e:input(' w0:edit '..name..'<CR>');e:wait('file '..name,function() idle(e);return e:current_file()==e.project..'/'..name end)
end
local function saved(e,name)
  open(e,name)
  e:input('Go'..(name:match('%.sh$') and '# STILL_EDITABLE' or '// STILL_EDITABLE')..'<Esc>')
  e:wait('edit returns to normal',function() idle(e);return e.rpc:request('nvim_get_mode',{}).mode=='n' end)
  e:input(':write<CR>')
  e:wait('save without prompt',function()
    idle(e)
    local lines=vim.fn.readfile(e.project..'/'..name)
    return e.rpc:request('nvim_get_mode',{}).mode=='n' and lines[#lines]:find('STILL_EDITABLE',1,true) and not e:lua('return vim.bo.modified')
  end)
end
local function no_work(e)
  idle(e)
  T.eq(e:lua([[return require('dap').session()==nil]]),true)
  T.eq(e:lua([[return #require('overseer').list_tasks()]]),0)
  T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
  for _,spawn in ipairs(e:lua('return _G.forge_e2e_spawns')) do
    local text=tostring(spawn.cmd):gsub('\\','/'):lower()
    assert(not text:find('wsl.exe',1,true),'Missing tool launched WSL')
    for _,arg in ipairs(spawn.args or {}) do
      assert(not tostring(arg):find('dapDebugServer',1,true) and not tostring(arg):find('bashDebug.js',1,true),'Missing tool launched adapter')
    end
  end
end
local function check(name,prepare,run)
  if vim.env.FORGE_MISSING_TOOL_CASE and not name:find(vim.env.FORGE_MISSING_TOOL_CASE,1,true) then return end
  T.check('IDE-BOOT-41 '..name,function()
    local e
    local ok,err=xpcall(function()
      e=require('editor').start(root,{site=deps..'/site',env={
        PATH=vim.fs.dirname(node)..(win and ';' or ':')..vim.env.PATH,
        FORGE_NODE_EXECUTABLE=node,FORGE_NODE_TOOLS=deps..'/tools',FORGE_BASH_EXECUTABLE=bash,
        FORGE_JS_DEBUG_SERVER=deps..'/debug/js-debug/src/dapDebugServer.js',
        NODE_OPTIONS='',NODE_PATH=''},prepare=function(project,env,runtime)
          vim.fn.writefile({'{"name":"missing-tools","scripts":{"start":"node run.js"}}'},project..'/package.json')
          vim.fn.writefile({[[require('fs').writeFileSync('node-ran.txt',process.execPath);]]},project..'/run.js')
          vim.fn.writefile({'#!/usr/bin/env bash',[[printf BASH_RECOVERED > bash-ran.txt]]},project..'/run.sh')
          prepare(project,env,runtime)
        end})
      e:wait('ready',function() idle(e);return e:lua('return _G.forge_e2e_observed') end,12000)
      run(e);idle(e);T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
    end,debug.traceback)
    if e then
      pcall(function() vim.fn.writefile({logs(e)},e.dir..'/tool-errors.txt') end)
      e:snapshot(name);io.stdout:write('  artifacts: '..e.dir..'\n')
      local stopped,why=pcall(e.stop,e,not ok and err or nil)
      if not stopped then ok=false;err=tostring(err or '')..'\n'..tostring(why) end
    end
    assert(ok,err)
  end)
end

check('invalid Node env edit run debug and native recovery',function(project,env)
  env.FORGE_NODE_EXECUTABLE=project..'/missing-node'
end,function(e)
  saved(e,'run.js')
  T.eq(e:lua([[return #vim.lsp.get_clients({name='ts_ls',bufnr=0})]]),0)
  local before=e:lua([[local n=0;for _,v in ipairs(require('forge.log_store').entries()) do if v.source=='LSP' then n=n+1 end end;return n]])
  e:input(':doautocmd FileType<CR>:doautocmd FileType<CR>')
  e:wait('repeated filetype remains usable',function() idle(e);return e:current_ft()=='javascript' end)
  T.eq(e:lua([[local n=0;for _,v in ipairs(require('forge.log_store').entries()) do if v.source=='LSP' then n=n+1 end end;return n]]),before)
  e:input(':NodeRunFile<CR>');e:wait('Node cause in Logs',function() idle(e);local s=logs(e);return s:find('Node.js не найден',1,true) and s:find('$FORGE_NODE_EXECUTABLE',1,true) end)
  e:input('<F5>');e:wait('failed F5 returns to code',function() idle(e);return e:current_ft()=='javascript' end)
  no_work(e);T.eq(vim.fn.filereadable(e.project..'/node-ran.txt'),0)
  e:lua([[vim.env.FORGE_NODE_EXECUTABLE=...]],{node})
  open(e,'run.js');e:input(':LspStart ts_ls<CR>')
  e:wait('native ts_ls after fix',function() idle(e);return e:lua([[for _,c in ipairs(vim.lsp.get_clients({name='ts_ls',bufnr=0})) do if c.initialized then return true end end;return false]]) end,30000)
  e:input(':NodeRunFile<CR>');e:wait('native Node after fix',function() idle(e);return vim.fn.filereadable(e.project..'/node-ran.txt')==1 end,15000)
  T.eq(vim.fs.normalize(vim.fn.readfile(e.project..'/node-ran.txt')[1]),node)
end)

for _,scope in ipairs({'project','user'}) do
  check('malformed '..scope..' JSON preserves editing and strict inspection',function(project,env)
    local path=scope=='project' and project..'/.fride/tools.json' or env.XDG_CONFIG_HOME..'/nvim_forge/tools.json'
    vim.fn.mkdir(vim.fs.dirname(path),'p');vim.fn.writefile({'{broken settings'},path)
  end,function(e)
    saved(e,'run.js');e:input(':NodeRunFile<CR>')
    e:wait('JSON source in Logs',function() idle(e);local s=logs(e);return s:find(scope..':',1,true) and s:find('tools.json',1,true) end)
    no_work(e)
    local strict=e:lua([[local ok,err=pcall(require('forge.node').executable);return {ok=ok,error=tostring(err)}]])
    T.eq(strict.ok,false);assert(strict.error:find(scope..':',1,true))
    local path=e:lua([[local f=require('forge.tool_paths').files();return f[...] ]],{scope})
    json(path,{tools={node=node}})
    e:input(':NodeRunFile<CR>');e:wait('fixed JSON runs Node',function() idle(e);return vim.fn.filereadable(e.project..'/node-ran.txt')==1 end,15000)
  end)
end

for _,kind in ipairs({'js','bash'}) do
  check(kind..' invalid adapter aborts before session',function(project,env)
    if kind=='js' then env.FORGE_JS_DEBUG_SERVER=project..'/missing-dapDebugServer.js'
    else env.FORGE_BASH_DEBUG_ADAPTER=project..'/missing-bashDebug.js' end
  end,function(e)
    local file=kind=='js' and 'run.js' or 'run.sh'
    saved(e,file);e:input('<F5>')
    e:wait('adapter error in Logs',function() idle(e);local s=logs(e);return s:find(kind=='js' and 'js-debug adapter не найден' or 'bash-debug adapter не найден',1,true)
      and s:find(kind=='js' and '$FORGE_JS_DEBUG_SERVER' or '$FORGE_BASH_DEBUG_ADAPTER',1,true) end)
    no_work(e);saved(e,file)
  end)
end

check('invalid native Bash selection and recovery without WSL',function(project)
  json(project..'/.fride/tools.json',{tools={bash=project..'/missing-bash'}})
end,function(e)
  saved(e,'run.sh');e:input(':BashRunFile<CR>')
  e:wait('Bash source in Logs',function() idle(e);local s=logs(e);return s:find('Bash не найден',1,true) and s:find('project:',1,true) end)
  no_work(e);T.eq(vim.fn.filereadable(e.project..'/bash-ran.txt'),0)
  json(e.project..'/.fride/tools.json',{tools={bash=bash}})
  e:input(':BashRunFile<CR>');e:wait('native Bash after fix',function() idle(e);return vim.fn.filereadable(e.project..'/bash-ran.txt')==1 end,15000)
  T.eq(vim.fn.readfile(e.project..'/bash-ran.txt')[1],'BASH_RECOVERED')
end)

check('shared LSP guard rejects explicit gopls without blocking',function(project)
  json(project..'/.fride/tools.json',{tools={gopls=project..'/missing-gopls'}})
  vim.fn.writefile({'module example.com/missing-tools','','go 1.23.0'},project..'/go.mod')
  vim.fn.writefile({'package main','func main() {}'},project..'/main.go')
end,function(e)
  saved(e,'main.go')
  e:wait('gopls reason in Logs',function() idle(e);local s=logs(e);return s:find('missing-gopls',1,true) and s:find('project:',1,true) end)
  T.eq(e:lua([[return #vim.lsp.get_clients({name='gopls',bufnr=0})]]),0)
  no_work(e)
end)
T.finish()
