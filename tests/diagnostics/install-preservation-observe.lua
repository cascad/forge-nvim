-- spec: IDE-BOOT-53. Fingerprints of real installed IDE state, no SDK mutation.
local kit,output=unpack(arg)
local function read(path)local file=io.open(path,'rb');if not file then return ''end;local text=file:read('*a');file:close();return text end
local config,data=vim.fn.stdpath('config'),vim.fn.stdpath('data')
local info={receipts={},pins={},preferences={},sdks={},fallback=read(kit..'/bin/sdk-paths.txt')}
for _,file in ipairs(vim.fn.globpath(data..'/mason/packages','*/mason-receipt.json',false,true))do
 info.receipts[vim.fs.basename(vim.fs.dirname(file))]=vim.fn.sha256(read(file))
end
for name,kind in vim.fs.dir(data..'/lazy')do if kind=='directory' then
 local result=vim.system({'git','-C',data..'/lazy/'..name,'rev-parse','HEAD'},{text=true}):wait(5000)
 assert(result.code==0,result.stderr);info.pins[name]=vim.trim(result.stdout)
end end
for _,name in ipairs({'guard-preserve.txt','sdk.json','tools.json','languages.json'})do
 info.preferences[name]=read(config..'/'..name)
end
for _,name in ipairs({'go','rustc','cargo','python3','node','npm'})do
 local path=vim.fn.exepath(name);info.sdks[name]={path=path}
 if path~='' and name~='npm' then
  local result=vim.system({path,name=='go' and 'version' or '--version'},{text=true,
   env={GOTOOLCHAIN='local',RUSTUP_AUTO_INSTALL='0',MISE_AUTO_INSTALL='false',MISE_EXEC_AUTO_INSTALL='false',MISE_NOT_FOUND_AUTO_INSTALL='false'}}):wait(5000)
  assert(result.code==0,result.stderr);info.sdks[name].version=result.stdout
  if name=='python3' then
   local prefix=vim.system({path,'-I','-B','-c','import sys;print(sys.prefix)'},{text=true}):wait(5000)
   assert(prefix.code==0,prefix.stderr);info.sdks[name].prefix=vim.trim(prefix.stdout)
   info.sdks[name].configuration=read(info.sdks[name].prefix..'/pyvenv.cfg')
  end
 end
end
assert(vim.fn.writefile({vim.json.encode(info)},output)==0)
