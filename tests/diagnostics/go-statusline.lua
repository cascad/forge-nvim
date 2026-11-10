-- IDE-080: настоящий statusline Go в isolated editor, без доступа к proxy.
-- Диагностика не меняет product/результат go; наблюдает реальный vim.system.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local sep=vim.fn.has('win32')==1 and ';' or ':'
local tools=vim.env.FORGE_E2E_DAP_TOOLS or root..'/.tests/dap-tools'
local path=vim.env.PATH
if vim.fn.isdirectory(tools..'/go/bin')==1 then path=tools..'/go/bin'..sep..path end
local results={}
for _,toolchain in ipairs({'auto','local'}) do
  local e
  local ok,err=xpcall(function()
    e=require('editor').start(root,{env={PATH=path,GOTOOLCHAIN=toolchain,
      GOENV='off',GOPROXY='off',GOSUMDB='off',GOMAXPROCS='2',GOFLAGS='-p=2'},
      prepare=function(project,env,runtime)
        -- Даже неуспешный auto probe может создать download lock: cache только private.
        env.GOPATH=runtime..'/go'
        env.GOMODCACHE=runtime..'/go/pkg/mod'
        env.GOCACHE=runtime..'/go-build-cache'
        vim.fn.writefile({'module example.invalid/review','go 1.99.0'},project..'/go.mod')
        vim.fn.writefile({'package main','func main() {}'},project..'/main.go')
      end})
    e:lua([[
      local log=...
      _G.forge_go_statusline_probe={}
      local function record(command,api)
        local name=type(command)=='table' and command[1] or command
        if type(name)~='string' then return end
        if not (name=='go' or name:match('[/\\]go%.?e?x?e?$') or name:match('^go%s')) then return end
        local row={command=command,api=api,cwd=vim.fn.getcwd(),go=vim.fn.exepath('go'),
          stack=debug.traceback('',3),toolchain=vim.env.GOTOOLCHAIN,
          proxy=vim.env.GOPROXY,goenv=vim.env.GOENV}
        table.insert(_G.forge_go_statusline_probe,row)
        vim.fn.writefile({vim.json.encode(row)},log,'a')
        return row
      end
      local system=vim.system
      vim.system=function(command,options,callback)
        local row=record(command,'vim.system')
        if row then
          local caller=debug.getinfo(2,'Sl')
          row.caller=caller.source;row.line=caller.currentline
          row.timeout=options and options.timeout
          -- Не добавляем callback, если caller использует synchronous :wait().
          if type(callback)~='function' then return system(command,options,callback) end
          return system(command,options,function(result)
            row.result={code=result.code,signal=result.signal,stdout=result.stdout,stderr=result.stderr}
            row.done=true
            if callback then return callback(result) end
          end)
        end
        return system(command,options,callback)
      end
      for _,key in ipairs({'system','systemlist'}) do
        local api='vim.fn.'..key
        local original=vim.fn[key]
        vim.fn[key]=function(command,...)
          local row=record(command,api)
          local result=original(command,...)
          if row then row.done=true;row.result={stdout=result,code=vim.v.shell_error} end
          return result
        end
      end
    ]],{e.dir..'/go-spawns.jsonl'})
    -- Изолируем собственную metadata от асинхронных Go env готового gopls.
    -- Реальный language workflow проверяет отдельный go-language E2E.
    e:lua([[require('lazy').load({plugins={'nvim-lspconfig'}});vim.lsp.enable('gopls',false)]])
    e:input(':edit main.go<CR>')
    local prompts=0
    local quiet_since=vim.uv.hrtime()
    local notices=#e.rpc.notifications
    e:wait('Go file rendered and metadata callbacks settled',function()
      if e.rpc:request('nvim_get_mode',{}).blocking then
        prompts=prompts+1
        vim.fn.writefile(e.rpc:screen_lines(),e.dir..'/prompt-'..prompts..'.txt')
        e:input('<CR>')
        quiet_since=vim.uv.hrtime()
        return false
      end
      if notices~=#e.rpc.notifications then notices=#e.rpc.notifications;quiet_since=vim.uv.hrtime() end
      local screen=table.concat(e.rpc:screen_lines(),'\n')
      return screen:find('package main',1,true)~=nil and vim.uv.hrtime()-quiet_since>400e6
    end,20000)
    local records=e:lua('return _G.forge_go_statusline_probe')
    for _,record in ipairs(records) do
      assert(record.proxy=='off' and record.goenv=='off','Probe must remain offline')
      local source=(record.caller or '')..(record.stack or '')
      source=source:gsub('\\','/')
      assert(not source:find('/lua/forge/go.lua',1,true) and not source:find('/lua/plugins/dap.lua',1,true),
        'IDE-BOOT-4: own metadata must remain passive')
    end
    local report={toolchain=toolchain,artifacts=e.dir,records=records,
      installs=e:lua('return vim.g.forge_e2e_installs'),file=e:current_file(),prompts=prompts,
      label=e:lua([[return require('forge.go').label()]])}
    vim.fn.writefile({vim.json.encode(report)},e.dir..'/go-statusline.json')
    assert(vim.uv.fs_copyfile(root..'/tests/diagnostics/go-statusline.lua',e.dir..'/go-statusline.lua'))
    results[#results+1]=report
    e:snapshot('go-statusline-'..toolchain)
    io.stdout:write(toolchain..'; artifacts: '..e.dir..'\n')
  end,debug.traceback)
  if e then e:stop(not ok and tostring(err) or nil) end
  if not ok then error(err) end
end
local output=vim.env.FORGE_GO_STATUSLINE_OUTPUT or root..'/.tests/go-statusline-review.json'
vim.fn.writefile({vim.json.encode(results)},output)
io.stdout:write('Observed 2 passive Go labels; backend Go requests recorded separately/offline\n')
