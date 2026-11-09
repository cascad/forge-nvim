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
    local explicit=vim.g.forge_python_path
    if type(explicit)~='string' or explicit=='' then explicit=vim.env.FORGE_PYTHON_PATH end
    local selected=executable(explicit)
    if selected then return selected end
    selected=executable(python_in(vim.env.VIRTUAL_ENV))
    if selected then return selected end
    local conda=vim.env.CONDA_PREFIX
    selected=executable(conda and conda~='' and (conda..(vim.fn.has('win32')==1 and '/python.exe' or '/bin/python')) or nil)
    if selected then return selected end
    for _,root in ipairs(roots or {}) do
        for _,folder in ipairs({'.venv','venv','.env','env'}) do
            selected=executable(python_in(root..'/'..folder))
            if selected then return selected end
        end
    end
    for _,name in ipairs({'python3','python'}) do
        if vim.fn.executable(name)==1 then
            local path=vim.fn.exepath(name)
            return path~='' and path or name
        end
    end
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
