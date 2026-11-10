-- Инвентарь настоящего Forge через существующий isolated editor driver.
-- Это диагностический снимок, не benchmark и не feature E2E.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local e
local ok,err=xpcall(function()
  e=require('editor').start(root)
  local report=e:lua([[local out={};for name,p in pairs(require('lazy.core.config').plugins) do
    local function source(fn) return type(fn)=='function' and debug.getinfo(fn,'S').source or nil end
    local deps={};for _,d in ipairs(p.dependencies or {}) do deps[#deps+1]=type(d)=='string' and d or tostring(d.name) end
    table.sort(deps)
    out[#out+1]={name=name,url=p.url,lazy=p.lazy or false,loaded=p._ and p._.loaded~=nil,
      dependencies=deps,config_source=source(p.config),init_source=source(p.init)}
    end;table.sort(out,function(a,b) return a.name<b.name end)
    return {plugins=out,installs=vim.g.forge_e2e_installs,version=vim.version(),config=vim.fn.stdpath('config')} ]])
  report.artifacts=e.dir
  assert(vim.uv.fs_copyfile(root..'/tests/diagnostics/inspect-plugins.lua',e.dir..'/inspect-plugins.lua'))
  vim.fn.writefile({vim.json.encode(report)},root..'/.tests/feature-review-runtime.json')
  e:snapshot('feature-review-inventory')
  io.stdout:write('plugins: '..#report.plugins..'; installs: '..tostring(report.installs)..'; artifacts: '..e.dir..'\n')
end,debug.traceback)
if e then e:stop(not ok and tostring(err) or nil) end
if not ok then error(err) end
