-- spec: IDE-BOOT-53. Native metadata and optional explicit SDK checks, no user init.
local kit,project,output,versions=unpack(arg)
local function read(path,limit)
 local stat=vim.uv.fs_stat(path);if not stat or stat.type~='file' or stat.size>(limit or 65536)then return end
 local file=assert(io.open(path,'rb'));local text=file:read('*a');file:close();return text
end
local release=assert(read('/etc/os-release'),'Native Linux /etc/os-release required')
local id=release:match('\nID=([^\n]+)') or release:match('^ID=([^\n]+)') or ''
local like=release:match('\nID_LIKE=([^\n]+)') or ''
id=id:gsub('["\']','')
assert(id=='arch' or id=='omarchy' or like:find('arch',1,true),'This report requires native Arch/Omarchy')
local owner=vim.json.decode(assert(read(kit..'/.forge-install.json')))
assert(owner.schema==1 and owner.product=='forge-nvim' and owner.ready==true,'Ready fride kit required')
vim.opt.rtp:prepend(assert(vim.env.FRIDE_CONFIG))
vim.cmd.cd(vim.fn.fnameescape(project))
local policy={MISE_AUTO_INSTALL='false',MISE_EXEC_AUTO_INSTALL='false',MISE_NOT_FOUND_AUTO_INSTALL='false',GOTOOLCHAIN='local',RUSTUP_AUTO_INSTALL='0'}
local function command(args)
 local result=vim.system(args,{text=true,cwd=project,timeout=5000,env=policy}):wait(5000)
 return {code=result.code,stdout=(result.stdout or ''):sub(1,8192),stderr=(result.stderr or ''):sub(1,2048)}
end
local omarchy=vim.env.OMARCHY_PATH or vim.fn.expand('~/.local/share/omarchy')
local info={schema=1,os_release=release,architecture=vim.uv.os_uname().machine,kit=kit,project=project,
 omarchy_version=read(omarchy..'/version',4096),neovim=vim.version(),components=owner.components,
 desktop={type=vim.env.XDG_SESSION_TYPE,wayland=vim.env.WAYLAND_DISPLAY,desktop=vim.env.XDG_CURRENT_DESKTOP},
 config=vim.fn.stdpath('config'),data=vim.fn.stdpath('data'),state=vim.fn.stdpath('state'),sdks={},manual={}}
for i=1,8 do info.manual['O'..i]='not checked' end
for _,program in ipairs({'nvim','mise','git','pacman','wezterm'})do
 local path=vim.fn.exepath(program)
 info[program]={path=path~='' and path or nil}
 if path~='' then info[program].version=command({path,'--version'}) end
end
info.packages=command({'pacman','-Q','neovim','mise','git','curl','unzip','libx11','libxcb','fontconfig','wayland','libglvnd'})
local initialized,initialization_error=pcall(require('forge.sdk').initialize,project)
if not initialized then info.sdk_initialization_error=tostring(initialization_error) end
for _,kind in ipairs({'go','rust','python','node'})do
 local backend=(kind=='go' or kind=='rust') and require('forge.sdk') or require('forge.runtime_sdk')
 local ok,choice=pcall(backend.choice,kind,project)
 local entry={choice=ok and choice or nil,error=not ok and tostring(choice) or nil};info.sdks[kind]=entry
 if ok then
  local path
  if kind=='go' or kind=='rust' then
   local valid,selected=pcall(backend.selection,kind,project)
   if not valid then entry.error=tostring(selected)
   else path=selected and selected.executable or vim.fn.exepath(kind=='rust' and 'rustc' or 'go') end
  else path=choice.value~='auto' and choice.value or nil end
  entry.path=path~='' and path or nil
  if versions=='1' and entry.path then
   local finished
   backend.probe(kind,entry.path,function(sdk,err)entry.sdk=sdk;entry.error=err;finished=true end,project)
   assert(vim.wait(15000,function()return finished end,10),'SDK report timeout: '..kind)
  end
 end
end
assert(vim.fn.writefile({vim.json.encode(info)},output)==0)
print('Native report saved; O1-O8 remain manual checks')
