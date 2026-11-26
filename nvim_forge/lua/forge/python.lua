-- spec: IDE-PY-1. Общий выбор Python; установка окружения остаётся явной.
local M={}
local function executable(path)
    if type(path)~='string' or path=='' then return nil end
    path=vim.fn.expand(path)
    if vim.fn.executable(path)==1 then return path end
end
local function python_in(env)
    if not env or env=='' then return nil end
    return env..(vim.fn.has('win32')==1 and '/Scripts/python.exe' or '/bin/python')
end
function M.resolve(roots)
    local paths=require('forge.tool_paths')
    local selected,explicit=paths.override('python',{root=roots and roots[1],
        global='forge_python_path',env='FORGE_PYTHON_PATH'})
    if explicit then return selected end
    local function found(path,source) return paths.selected('python',path,source,roots and roots[1]) end
    local function in_project(root)
        for _,folder in ipairs({'.venv','venv','.env','env'}) do
            local path=executable(python_in(root..'/'..folder))
            if path then return found(path,'project venv') end
        end
    end
    -- Prefer the file's project environment before inheriting the shell environment.
    for _,root in ipairs(roots or {}) do
        selected=in_project(root)
        if selected then return selected end
    end
    local workspace=roots and roots[1] and paths.root(roots[1])
    if workspace and not vim.tbl_contains(roots,workspace) then
        selected=in_project(workspace)
        if selected then return selected end
    end
    selected=executable(python_in(vim.env.VIRTUAL_ENV))
    if selected then return found(selected,'VIRTUAL_ENV') end
    local conda=vim.env.CONDA_PREFIX
    selected=executable(conda and conda~='' and (conda..(vim.fn.has('win32')==1 and '/python.exe' or '/bin/python')) or nil)
    if selected then return found(selected,'CONDA_PREFIX') end
    -- spec: IDE-PY-3. Native Windows Python is normally named python.exe.
    local names=vim.fn.has('win32')==1 and {'python','python3'} or {'python3','python'}
    for _,name in ipairs(names) do
        if vim.fn.executable(name)==1 then
            local path=vim.fn.exepath(name)
            return found(path~='' and path or name,'PATH')
        end
    end
    paths.selected('python',nil,'PATH',roots and roots[1])
    return 'python'
end
function M.before_pyright_init(_,config)
    config.settings=config.settings or {}
    config.settings.python=config.settings.python or {}
    if not config.settings.python.pythonPath or config.settings.python.pythonPath=='' then
        config.settings.python.pythonPath=M.resolve(config.root_dir and {config.root_dir} or {})
    end
end
return M
