-- spec: IDE-BOOT-17. Read-only SDK queries in the actual managed editor.
local request=vim.json.decode(table.concat(vim.fn.readfile(vim.env.FORGE_SDK_REQUEST),'\n'))
local results={}
for _,argv in ipairs(request.commands) do
 local response=vim.system(argv,{cwd=request.project,text=true}):wait(60000)
 results[#results+1]={argv=argv,code=response.code,stdout=response.stdout,stderr=response.stderr}
 vim.fn.writefile({vim.json.encode(results)},vim.env.FORGE_SDK_RESULT)
 assert(response.code==0,vim.json.encode(results[#results]))
end
