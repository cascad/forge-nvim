-- spec: IDE-TEST-10. Pure selection over the existing registry; no test launches.
local M={}
-- One discovery rule for the existing standalone native suites and trace.
function M.native_suites(root)
  local out={}
  local scan=vim.uv.fs_scandir(root..'/tests')
  if scan then
    while true do
      local name,kind=vim.uv.fs_scandir_next(scan)
      if not name then break end
      if kind=='file' and name:match('%.test%.py$') then out[#out+1]='tests/'..name end
    end
  end
  table.sort(out)
  return out
end
function M.select(registry,installers,mode,files,windows)
  local modes={quick={'unit'},e2e={'e2e'},full={'unit','e2e','wezterm','install','trace'},regression={'unit','e2e','wezterm','install','trace'}}
  local suites=assert(modes[mode],'Unknown test mode: '..tostring(mode))
  if windows and (mode=='full' or mode=='regression') then suites=vim.list_extend(vim.deepcopy(suites),{'conpty'}) end
  local by_file={};for _,row in ipairs(registry) do by_file[row.file]=row end
  local native={};for _,name in ipairs(installers) do native[name]=true end
  local chosen,python={},{}
  if #files>0 then
    local seen={}
    for _,file in ipairs(files) do
      assert(not seen[file],'Duplicate test file: '..file);seen[file]=true
      if by_file[file] then chosen[#chosen+1]=by_file[file]
      elseif native[file] then python[#python+1]=file
      else error('Unknown test file: '..file,0) end
    end
  else
    for _,row in ipairs(registry) do if vim.tbl_contains(suites,row.suite) then chosen[#chosen+1]=row end end
    if mode=='regression' then python=vim.deepcopy(installers) end
  end
  local selected_suites={}
  for _,row in ipairs(chosen) do
    if not vim.tbl_contains(selected_suites,row.suite) then selected_suites[#selected_suites+1]=row.suite end
  end
  return {registry=chosen,installers=python,suites=selected_suites}
end
return M
