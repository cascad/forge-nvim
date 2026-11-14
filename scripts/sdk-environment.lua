-- spec: IDE-BOOT-16. One policy; no SDK discovery/install or credential import.
local M = {}
function M.load(path)
    local rows={}
    for line in io.lines(path) do
        line=line:gsub('\r$','')
        if line~='' and line:sub(1,1)~='#' then
            local kind,key,value=line:match('^([^\t]+)\t([^\t]+)\t([^\t]+)$')
            assert(kind=='dir' or kind=='file' or kind=='clear' or kind=='bin','Invalid SDK policy kind')
            assert(key and key:match('^[A-Za-z_][A-Za-z0-9_]*$'),'Invalid SDK policy key')
            if kind=='bin' then assert(key=='all' or key=='windows' or key=='posix','Invalid SDK bin platform') end
            if kind~='clear' then
                assert(value~='' and not value:find('[\\:\r\n]') and value:sub(1,1)~='/' and not value:find('//',1,true),'Invalid SDK relative path')
                for part in value:gmatch('[^/]+') do assert(part~='.' and part~='..','Invalid SDK relative path') end
            end
            rows[#rows+1]={kind=kind,key=key,value=value}
        end
    end
    assert(#rows>0,'Empty SDK policy')
    return rows
end
local function active(row,windows)
    return row.key=='all' or row.key==(windows and 'windows' or 'posix')
end
function M.prepare(root,rows,windows)
    for _,row in ipairs(rows) do
        if row.kind~='clear' and (row.kind~='bin' or active(row,windows)) then
            local path=vim.fs.joinpath(root,row.value)
            vim.fn.mkdir(row.kind=='file' and vim.fs.dirname(path) or path,'p')
            if row.kind=='file' then
                local stat=vim.uv.fs_stat(path)
                if stat then assert(stat.type=='file','SDK config is not a file: '..path)
                else
                    local fd=assert(vim.uv.fs_open(path,'wx',384));assert(vim.uv.fs_close(fd))
                end
            end
        end
    end
    local ignore=vim.fs.joinpath(root,'sdk-state/.gitignore')
    if not vim.uv.fs_stat(ignore) then
        local fd=assert(vim.uv.fs_open(ignore,'wx',384));assert(vim.uv.fs_write(fd,'*\n',0));assert(vim.uv.fs_close(fd))
    end
end
function M.apply(env,root,rows,windows)
    local paths={}
    for _,row in ipairs(rows) do
        if row.kind=='bin' then
            if active(row,windows) then paths[#paths+1]=vim.fs.joinpath(root,row.value) end
        else
            if windows then
                for key in pairs(env) do if key:lower()==row.key:lower() then env[key]=nil end end
            end
            env[row.key]=row.kind~='clear' and vim.fs.joinpath(root,row.value) or nil
        end
    end
    return paths
end
return M
