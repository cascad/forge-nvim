-- Граница native Bash/MSYS: общие workflow не знают формат путей Windows.
local M={}
local win=vim.fn.has('win32')==1
local function usable(path)
    if not path or path=='' or vim.fn.executable(path)~=1 then return false end
    local resolved=vim.fn.exepath(path)
    if resolved=='' then return nil end
    local normalized=vim.fs.normalize(resolved):lower()
    -- Это launchers другой ОС, не native Bash. Не запускаем даже --version.
    if win and (normalized:match('/system32/bash%.exe$') or normalized:match('/sysnative/bash%.exe$')) then return nil end
    return resolved
end
function M.executable()
    local explicit=vim.g.forge_bash_executable or vim.env.FORGE_BASH_EXECUTABLE
    if explicit and explicit~='' then return usable(explicit) end
    local path=usable(vim.fn.exepath('bash'))
    if path then return path end
    if win then
        local git=vim.fn.exepath('git')
        local candidates={}
        if git~='' then candidates[#candidates+1]=vim.fs.joinpath(vim.fs.dirname(vim.fs.dirname(git)),'bin/bash.exe') end
        for _,dir in ipairs({vim.env.ProgramFiles or '',vim.env['ProgramFiles(x86)'] or ''}) do
            if dir~='' then candidates[#candidates+1]=vim.fs.joinpath(dir,'Git/bin/bash.exe') end
        end
        for _,candidate in ipairs(candidates) do local found=usable(candidate);if found then return found end end
    end
end
function M.cygpath(bash)
    if not win then return nil end
    local bin=vim.fs.dirname(bash)
    for _,candidate in ipairs({bin..'/cygpath.exe',vim.fs.dirname(bin)..'/usr/bin/cygpath.exe',vim.fn.exepath('cygpath')}) do
        if candidate~='' and vim.fn.executable(candidate)==1 then return candidate end
    end
end
function M.path(path,bash)
    if not win then return path end
    local converter=M.cygpath(bash)
    if not converter then return nil,'Нужен cygpath из native Bash (Git Bash/MSYS/Cygwin).' end
    local result=vim.system({converter,'-u',path},{text=true,timeout=3000}):wait()
    if result.code~=0 then return nil,'cygpath: '..(result.stderr or '') end
    return vim.trim(result.stdout)
end
function M.environment(bash,bats)
    -- Не читаем пользовательские startup scripts даже при заданном BASH_ENV.
    local env={BASH_ENV='',ENV=''}
    if bats then
        for _,key in ipairs({'TMPDIR','BATS_TMPDIR'}) do
            if vim.env[key] and vim.env[key]~='' then
                local path,err=M.path(vim.env[key],bash)
                if not path then return nil,err end
                env[key]=path
            end
        end
        if win then
            local msys=vim.env.MSYS or ''
            if not msys:find('winsymlinks:',1,true) then msys=msys..' winsymlinks:lnk' end
            env.MSYS=vim.trim(msys)
        end
    end
    return env
end
return M
