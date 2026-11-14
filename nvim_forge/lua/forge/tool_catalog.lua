-- spec: IDE-BOOT-15. Existing catalogs, shared by config and explicit setup checks.
local M = {}
function M.mason()
    local tools = {
        -- gopls из активного Go-тулчейна: go install
        -- golang.org/x/tools/gopls@latest или setup WITH_LANGUAGES=1.
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
        -- Форматтеры здесь НЕ держим (единый механизм — системный):
        --   stylua   : cargo install stylua  (см. format.lua)
        --   prettier : npm i -g prettier
        --   gofumpt/golines : go install ...  (уже в PATH)
        -- Два конкурирующих механизма (mason + system) раньше давали
        -- «на костылях»: stylua числился тут, но Mason его не ставил,
        -- а system-установки не было → conform молча падал на lua/json.
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
