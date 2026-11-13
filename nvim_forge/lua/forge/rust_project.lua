-- spec: IDE-RUST-2 IDE-RUST-3. Native Cargo workspace до первого Rust-буфера.
local M = {}
local generation, pending, directory = 0, nil, nil

local function log(message, level)
    require('forge.log_store').record(message, level or vim.log.levels.INFO, 'Rust project')
end

local function cancel()
    generation = generation + 1
    if pending then pcall(pending.kill, pending, 15); pending = nil end
end

function M.warmup()
    local cwd = vim.fs.normalize(vim.fn.getcwd())
    if directory == cwd then return end
    directory = cwd
    cancel()
    if vim.fn.filereadable(cwd .. '/Cargo.toml') ~= 1 then return end

    require('lazy').load({ plugins = { 'nvim-lspconfig' } })
    if not vim.lsp.is_enabled('rust_analyzer') then
        log('Подготовка Rust пропущена: rust_analyzer отключён.')
        return
    end
    local config = vim.deepcopy(vim.lsp.config.rust_analyzer)
    local cargo = vim.env.CARGO or vim.fn.exepath('cargo')
    local command = type(config.cmd) == 'table' and config.cmd[1] or nil
    if cargo == '' or vim.fn.executable(cargo) ~= 1 then
        log('Подготовка ' .. cwd .. ' пропущена: Cargo не найден; установи Rust SDK явно.', vim.log.levels.WARN)
        return
    end
    if type(config.cmd) ~= 'function' and (not command or vim.fn.executable(command) ~= 1) then
        log('Подготовка ' .. cwd .. ' пропущена: rust-analyzer не найден; :MasonInstall rust-analyzer.', vim.log.levels.WARN)
        return
    end
    local epoch = generation
    log('Подготовка Cargo workspace: ' .. cwd)
    local ok, job = pcall(vim.system,
        { cargo, 'metadata', '--no-deps', '--format-version', '1', '--manifest-path', cwd .. '/Cargo.toml' },
        { cwd = cwd, text = true, env = { RUSTUP_AUTO_INSTALL = '0' } },
        function(result)
            vim.schedule(function()
                if epoch ~= generation or vim.fs.normalize(vim.fn.getcwd()) ~= cwd then return end
                pending = nil
                if not vim.lsp.is_enabled('rust_analyzer') then
                    log('Запуск Rust отменён: rust_analyzer отключён.')
                    return
                end
                if result.code ~= 0 then
                    log('Cargo metadata: ' .. cwd .. '\n' .. (result.stderr or ''), vim.log.levels.WARN)
                    return
                end
                local decoded, metadata = pcall(vim.json.decode, result.stdout or '')
                if not decoded or type(metadata) ~= 'table' or type(metadata.workspace_root) ~= 'string' then
                    log('Cargo metadata не вернул workspace_root: ' .. cwd, vim.log.levels.WARN)
                    return
                end
                config.name = 'rust_analyzer'
                config.root_dir = vim.fs.normalize(metadata.workspace_root)
                config.cmd_env = vim.tbl_extend('force', config.cmd_env or {}, { RUSTUP_AUTO_INSTALL = '0' })
                local id = vim.lsp.start(config, { attach = false })
                if id then log('rust-analyzer #' .. id .. ': ' .. config.root_dir) end
            end)
        end)
    if ok then pending = job
    else log('Cargo metadata не запущен: ' .. tostring(job), vim.log.levels.WARN) end
end

function M.setup()
    local group = vim.api.nvim_create_augroup('ForgeRustProject', { clear = true })
    vim.api.nvim_create_autocmd('User', { group = group, pattern = 'VeryLazy',
        callback = function() vim.schedule(M.warmup) end })
    vim.api.nvim_create_autocmd('DirChanged', { group = group, pattern = 'global',
        callback = function() vim.schedule(M.warmup) end })
    vim.api.nvim_create_autocmd('VimLeavePre', { group = group, callback = cancel })
end

return M
