local M = {}

-- spec: IDE-DAP-3 пустой eval не открывает бессодержательный DAP widget.
function M.open()
    local session = require("dap").session()
    if not session or not session.stopped_thread_id or not session.current_frame then
        vim.notify("Для вычисления выражения нужна отладка на паузе.", vim.log.levels.INFO, { title = "DAP" })
        return
    end
    return require("dap.ui.widgets").hover()
end

-- Только transient DAP-окна текущей вкладки; sidebar/файлы не затрагиваются.
function M.close()
    local closed = false
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_is_valid(win)
            and vim.api.nvim_win_get_config(win).relative ~= ""
            and vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "dap-float" then
            closed = pcall(vim.api.nvim_win_close, win, true) or closed
        end
    end
    return closed
end

function M.setup()
    vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("ForgeDapFloatClose", { clear = true }),
        pattern = "dap-float",
        callback = function(ev)
            for _, key in ipairs({ "q", "<Esc>" }) do
                vim.keymap.set("n", key, M.close, { buffer = ev.buf, nowait = true, silent = true, desc = "Close DAP float" })
            end
        end,
    })
end

return M
