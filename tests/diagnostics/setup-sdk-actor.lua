-- Real production setup preparation followed by pinned Mason's real spawn API.
local root,base,case=arg[1],arg[2],arg[3]
package.path=root..'/nvim_forge/lua/?.lua;'..package.path
vim.opt.rtp:prepend(root..'/nvim_forge')
vim.opt.rtp:prepend(assert(vim.env.FORGE_E2E_DEPS)..'/lazy/mason.nvim')
local before=vim.env.PATH
if case=='late' then require('mason-core.process') end
local report={case=case}
local ok,err=xpcall(function()
    report.selection=require('forge.setup_sdks').prepare()
    report.path=vim.env.PATH
    if case=='selected' then
        local process=require('mason-core.process')
        report.frozen=process.extend_path({})
        -- Prove actual Mason children use its captured environment, not a late edit.
        vim.env.PATH=before
        local spawn=require('mason-core.spawn')
        report.python=require('mason-core.async').run_blocking(function()
            local result=spawn[vim.fn.has('win32')==1 and 'python' or 'python3']({
                '-I','-B','-c','import sys,json;print(json.dumps({"prefix":sys.prefix,"executable":sys.executable}))',env={}}):get_or_throw()
            return vim.json.decode(result.stdout)
        end)
        report.node=require('mason-core.async').run_blocking(function()
            local result=spawn.node({'-e','console.log(JSON.stringify({executable:process.execPath,version:process.version}))',env={}}):get_or_throw()
            return vim.json.decode(result.stdout)
        end)
    else
        assert(vim.env.PATH==before,'Unexpected environment change')
    end
end,debug.traceback)
report.ok=ok;report.error=not ok and err or nil
report.mason_loaded=package.loaded['mason-core.process']~=nil
report.path_unchanged=vim.env.PATH==before
assert(vim.fn.writefile({vim.json.encode(report)},base..'/result.json')==0)
if not ok then io.stderr:write(err..'\n');vim.cmd('cquit 1') end
vim.cmd('qa!')
