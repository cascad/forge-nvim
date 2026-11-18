-- spec: IDE-BOOT-15. Existing catalogs, shared by config and explicit setup checks.
local M = {}
-- IDE-BOOT-22. Mason owns these IDE tools; language SDKs remain native.
function M.versions()
    return { gopls = 'v0.23.0', gofumpt = 'v0.12.0', golines = 'v0.16.0',
        stylua = 'v2.6.0', prettier = '3.9.10', codelldb = 'v1.12.2',
        ['bash-debug-adapter'] = 'untagged-438733f35feb8659d939' }
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
    table.insert(tools, 'codelldb')
    return require('forge.install_profile').filter(tools,4)
end

function M.native_versions()
    local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
    return vim.json.decode(table.concat(vim.fn.readfile(root..'/scripts/native-tools.json'),'\n'))
end

function M.install_policy()
    local policy=vim.env.FRIDE_TOOLS_VERSIONS or 'preserve'
    assert(policy=='preserve' or policy=='baseline','Invalid FRIDE_TOOLS_VERSIONS: '..policy)
    return policy
end
function M.mason_specs()
    local versions, specs = M.versions(), {}
    local preserve=M.install_policy()=='preserve'
    for _, name in ipairs(M.mason()) do
        local spec={name,version=versions[name]}
        -- Native MTI evaluates this only for an explicit install, not at startup.
        spec.condition=function()
            local ok,external=pcall(function() return require('forge.setup_tools').external(name) end)
            if not ok then
                -- MTI runs conditions inside an async refresh: throwing here
                -- would leave its synchronous command waiting forever.
                vim.notify(external,vim.log.levels.ERROR,{title='Setup tools'})
                return false
            end
            if external then return false end
            return not (preserve and versions[name]) or not require('mason-registry').get_package(name):is_installed()
        end
        specs[#specs+1]=spec
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
