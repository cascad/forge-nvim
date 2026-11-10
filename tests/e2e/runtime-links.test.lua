-- Real native filesystem links, no mocked stat/delete operations.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local R=require('editor_runtime')
local uv=vim.uv
for _,mode in ipairs({'live','dangling','malformed'}) do
  local name='SELF: RUNTIME-LINKS '..mode..' directory link removes link and preserves target'
  if mode=='malformed' and vim.fn.has('win32')~=1 then T.skip(name,'Windows NT junction format') else
    T.check(name,function()
      local p,target=R.create(root),R.create(root)
      local link=p.path..'/cache-link'
      local target_path=target.path..'/cache'
      vim.fn.mkdir(target_path,'p')
      vim.fn.writefile({'target sentinel'},target_path..'/keep.txt')
      local args={vim.fn.exepath(vim.fn.has('win32')==1 and 'python' or 'python3'),'-B',root..'/tests/e2e/create_directory_link.py',
        p.parent,link,target_path}
      if mode=='malformed' then args[#args+1]='--raw-slashes' end
      local result=vim.system(args,{text=true}):wait()
      assert(result.code==0,result.stderr)
      if mode~='live' then
        assert(uv.fs_unlink(target_path..'/keep.txt'));assert(uv.fs_rmdir(target_path))
      end
      local removed,err=pcall(R.remove,p)
      local target_kept=vim.fn.filereadable(target.path..'/.forge-e2e-owner.json')==1
      local sentinel=mode~='live' or (vim.fn.filereadable(target_path..'/keep.txt')==1 and vim.deep_equal(vim.fn.readfile(target_path..'/keep.txt'),{'target sentinel'}))
      -- On source RED remove only this known fixture link, then retry ownership-checked cleanup.
      if not p.removed then
        for child,kind in vim.fs.dir(p.path) do if child=='cache-link' and kind=='link' then uv.fs_rmdir(link) end end
        R.remove(p)
      end
      R.remove(target)
      assert(removed,tostring(err))
      assert(target_kept and sentinel,'Link cleanup traversed its target')
    end)
  end
end
T.finish()
