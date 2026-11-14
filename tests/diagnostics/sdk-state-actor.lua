-- spec: IDE-BOOT-16. Actual offline SDK commands inside managed fride.
local request=vim.json.decode(table.concat(vim.fn.readfile(vim.env.FORGE_SDK_REQUEST),'\n'))
local results={}
local function run(args,extra)
 local response=vim.system(args,{cwd=request.project,env=extra,text=true}):wait(60000)
 results[#results+1]={argv=args,code=response.code,stdout=response.stdout,stderr=response.stderr}
 vim.fn.writefile({vim.json.encode(results)},vim.env.FORGE_SDK_RESULT)
 assert(response.code==0,vim.json.encode(results[#results]))
 return response.stdout
end
if request.action=='go' then
 run({request.go,'env','-json','GOPATH','GOBIN','GOCACHE','GOMODCACHE','GOENV'},{GOTOOLCHAIN='local',GOPROXY='off'})
 run({request.go,'env','-w','GOPRIVATE=forge-state.invalid'},{GOTOOLCHAIN='local',GOPROXY='off'})
elseif request.action=='rust' then
 run({request.rustup,'show','home'},{RUSTUP_AUTO_INSTALL='0'})
 run({request.rustup,'set','profile','minimal'},{RUSTUP_AUTO_INSTALL='0'})
 run({request.cargo,'install','--offline','--path',request.project},{RUSTC=request.rustc,CARGO_BUILD_JOBS='1',CARGO_INCREMENTAL='0',RUSTUP_AUTO_INSTALL='0'})
 local exe=vim.fn.exepath('forge_sdk_state_bin');assert(exe~='' and exe:find('sdk%-state'),'Mutable Cargo bin not in PATH')
 run({exe})
elseif request.action=='node' then
 local extra={npm_config_update_notifier='false'}
 run({request.node,request.npm,'prefix','--global'},extra)
 run({request.node,request.npm,'install','--global','--offline','--ignore-scripts','--no-audit','--no-fund',request.archive},extra)
 local exe=vim.fn.exepath('forge-sdk-state-node');assert(exe~='' and exe:find('sdk%-state'),'Mutable npm bin not in PATH')
 if vim.fn.has('win32')==1 then run({'cmd.exe','/d','/c',exe},extra) else run({exe},extra) end
elseif request.action=='python' then
 local extra={PYTHONNOUSERSITE=''}
 if request.pip_path then extra.PYTHONPATH=request.pip_path..(vim.env.PYTHONPATH and (vim.fn.has('win32')==1 and ';' or ':')..vim.env.PYTHONPATH or '') end
 run({request.python,'-m','pip','--disable-pip-version-check','install','--user','--no-index','--no-deps','--no-warn-script-location','--break-system-packages',request.archive},extra)
 run({request.python,'-c','import forge_sdk_state_probe;print(forge_sdk_state_probe.__file__)'},extra)
else error('Unknown SDK operation') end
