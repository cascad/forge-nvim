-- "Scroll beyond last line" (как в VS Code: editor.scrollBeyondLastLine).
--
-- Neovim из коробки НЕ умеет скроллить за последнюю строку файла: когда
-- курсор на последней строке, окно упирается, и при большом 'scrolloff'
-- курсор уезжает к низу экрана (нет строк снизу, чтобы держать отступ).
--
-- Решение: добавляем под последней строкой буфера N виртуальных пустых
-- строк через extmark.virt_lines. Это чисто визуальные строки (в файле
-- их нет, в буфер не пишутся, не сохраняются), но Neovim учитывает их
-- при скролле — значит 'scrolloff' может держать отступ снизу даже на
-- последней реальной строке, и её можно поднять почти к верху окна.
--
-- Применяется ТОЛЬКО к обычным file-буферам. Спец-окна (neo-tree, dap-ui,
-- terminal, telescope, ...) пропускаем — там свой рендер.
--
-- Toggle: vim.g.forge_eob_scroll = false  (или :ForgeEobScroll).

local M = {}

local ns = vim.api.nvim_create_namespace("forge_eob_pad")

local SKIP_FT = {
    ["neo-tree"] = true, aerial = true, alpha = true, lazy = true,
    mason = true, trouble = true, qf = true, help = true, man = true,
    ["dap-repl"] = true, ["dap-terminal"] = true,
    dapui_scopes = true, dapui_watches = true, dapui_stacks = true,
    dapui_breakpoints = true, dapui_console = true,
    TelescopePrompt = true, TelescopeResults = true,
    ["grug-far"] = true, OverseerList = true, overseer = true,
    ["neotest-summary"] = true, ["neotest-output-panel"] = true,
    NeogitStatus = true, NeogitPopup = true, gitcommit = true,
}

local function eligible(buf, win)
    if not (buf and vim.api.nvim_buf_is_valid(buf)) then return false end
    if vim.bo[buf].buftype ~= "" then return false end
    if SKIP_FT[vim.bo[buf].filetype] then return false end
    if not (win and vim.api.nvim_win_is_valid(win)) then return false end
    -- floating-окна (popup, hover) — не трогаем.
    if vim.api.nvim_win_get_config(win).relative ~= "" then return false end
    return true
end

---Пересчитать виртуальный padding под последней строкой буфера в окне.
---@param win? integer
function M.update(win)
    win = win or vim.api.nvim_get_current_win()
    if not vim.api.nvim_win_is_valid(win) then return end
    local buf = vim.api.nvim_win_get_buf(win)

    -- Сначала всегда чистим — на случай если буфер стал неподходящим
    -- (сменили filetype, открыли special) или фича выключена.
    pcall(vim.api.nvim_buf_clear_namespace, buf, ns, 0, -1)

    if vim.g.forge_eob_scroll == false then return end
    if not eligible(buf, win) then return end

    local line_count = vim.api.nvim_buf_line_count(buf)
    local height = vim.api.nvim_win_get_height(win)
    -- height-2 виртуальных строк => последнюю реальную строку можно
    -- поднять почти к самому верху окна (оставляем пару строк снизу,
    -- чтобы не было ощущения "бездонного" низа).
    local pad = math.max(0, height - 2)
    if pad == 0 then return end

    local virt = {}
    for _ = 1, pad do
        virt[#virt + 1] = { { "", "NonText" } }
    end

    pcall(vim.api.nvim_buf_set_extmark, buf, ns, line_count - 1, 0, {
        virt_lines = virt,
        virt_lines_above = false,
    })
end

function M.setup()
    local group = vim.api.nvim_create_augroup("ForgeEobScroll", { clear = true })

    -- Перерисовываем при: входе в окно/буфер, изменении текста (двигается
    -- последняя строка), ресайзе окна/Vim'а (меняется высота → нужно
    -- другое число виртуальных строк).
    vim.api.nvim_create_autocmd(
        { "BufWinEnter", "WinEnter", "TextChanged", "TextChangedI",
          "InsertLeave", "VimResized", "WinResized", "FileType" },
        {
            group = group,
            callback = function()
                -- vim.schedule — TextChanged может прилететь до того как
                -- line_count устаканится; плюс не блокируем редактирование.
                vim.schedule(function() M.update() end)
            end,
        }
    )

    vim.api.nvim_create_user_command("ForgeEobScroll", function()
        local enabled = vim.g.forge_eob_scroll ~= false  -- nil/true => on
        vim.g.forge_eob_scroll = not enabled
        M.update()
        vim.notify("scroll beyond last line: " ..
            (enabled and "OFF" or "ON"), vim.log.levels.INFO)
    end, { desc = "Toggle scroll-beyond-last-line padding" })

    M.update()
end

return M
