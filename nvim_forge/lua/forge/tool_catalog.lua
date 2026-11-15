-- spec: IDE-BOOT-15. Existing catalogs, shared by config and explicit setup checks.
local M = {}
-- IDE-BOOT-22. Mason owns these IDE tools; language SDKs remain native.
function M.versions()
    return { gopls = 'v0.23.0', gofumpt = 'v0.12.0', golines = 'v0.16.0',
        stylua = 'v2.6.0', prettier = '3.9.10' }
end
function M.mason()
    local tools = {
        'gopls', 'gofumpt', 'golines', 'stylua', 'prettier',
        "pyright",
        "ruff",
        "lua-language-server",
        "rust-analyzer",
        "bash-language-server",
        "shfmt",
        "shellcheck",
        "sqls",
        "sqruff",
        -- DAP
        -- Delve follows Go runtime/compiler internals closely. Keep it
        -- current so project toolchain upgrades do not break debugging.
        "delve",
        "debugpy",
        --
        -- Existing formatter consumers use the same Mason bin/JS entrypoints.
        -- Линтеры (если ruff/gopls/pyright чего-то не покрывают)
        "golangci-lint",
        "gotestsum",
    }
    -- codelldb: на Windows НЕ ставим — пользователь держит его в PATH
    -- (%LocalAppData%\codelldb\adapter\codelldb.exe). На macOS/Linux
    -- ставим через Mason — dap.lua найдёт его mason_bin-фолбэком.
    if vim.fn.has("win32") == 0 then
        table.insert(tools, "codelldb")
    end
    return require('forge.install_profile').filter(tools,4)
end

function M.mason_specs()
    local versions, specs = M.versions(), {}
    for _, name in ipairs(M.mason()) do
        specs[#specs + 1] = versions[name] and { name, version = versions[name] } or name
    end
    return specs
end

function M.parsers()
    local languages = {
        "rust", "go", "gomod", "gosum", "gowork",
        "python",
        "lua", "luadoc", "luap",
        "vim", "vimdoc", "query",
        "markdown", "markdown_inline",
        "json", "yaml", "toml",
        "bash", "regex", "sql",
        "c", "cpp", "cmake",
        "html", "css", "javascript", "typescript",
        "diff", "git_config", "gitcommit", "gitignore", "gitattributes",
        "dockerfile",
    }
    return require('forge.install_profile').filter(languages,5)
end
return M
