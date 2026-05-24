-- Global autocmds. One augroup per concern so :autocmd shows clean groups.

local function augroup(name)
    return vim.api.nvim_create_augroup("user_" .. name, { clear = true })
end

-- Highlight yanked text briefly.
vim.api.nvim_create_autocmd("TextYankPost", {
    group = augroup("highlight_yank"),
    callback = function() vim.hl.on_yank({ timeout = 200 }) end,
})

-- Restore the last cursor position when reopening a file.
vim.api.nvim_create_autocmd("BufReadPost", {
    group = augroup("last_loc"),
    callback = function(args)
        local exclude = { "gitcommit", "gitrebase", "svn", "hgcommit" }
        local buf = args.buf
        if vim.tbl_contains(exclude, vim.bo[buf].filetype) then return end
        if vim.b[buf].user_last_loc then return end
        vim.b[buf].user_last_loc = true

        local mark = vim.api.nvim_buf_get_mark(buf, '"')
        local lcount = vim.api.nvim_buf_line_count(buf)
        if mark[1] > 0 and mark[1] <= lcount then
            pcall(vim.api.nvim_win_set_cursor, 0, mark)
        end
    end,
})

-- `q` closes scratch windows (help, qf, neotest output, ...).
vim.api.nvim_create_autocmd("FileType", {
    group = augroup("close_with_q"),
    pattern = {
        "help", "qf", "lspinfo", "checkhealth", "man",
        "notify", "PlenaryTestPopup", "neotest-output", "neotest-output-panel",
        "neotest-summary", "dap-view", "dap-view-term", "dap-float",
    },
    callback = function(args)
        vim.bo[args.buf].buflisted = false
        vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = args.buf, silent = true })
    end,
})

-- Auto-create missing parent dirs on :w. Saves the "no such file or directory" trip.
vim.api.nvim_create_autocmd("BufWritePre", {
    group = augroup("auto_mkdir"),
    callback = function(args)
        if args.match:match("^%w%w+:[\\/][\\/]") then return end   -- skip scp://, ftp://, ...
        local file = vim.uv.fs_realpath(args.match) or args.match
        local dir = vim.fn.fnamemodify(file, ":p:h")
        if vim.fn.isdirectory(dir) == 0 then
            vim.fn.mkdir(dir, "p")
        end
    end,
})

-- Resize splits when the host terminal resizes.
vim.api.nvim_create_autocmd("VimResized", {
    group = augroup("resize_splits"),
    callback = function()
        local current_tab = vim.fn.tabpagenr()
        vim.cmd("tabdo wincmd =")
        vim.cmd("tabnext " .. current_tab)
    end,
})

-- Strip trailing whitespace on save for code files (skip diff/markdown).
vim.api.nvim_create_autocmd("BufWritePre", {
    group = augroup("trim_whitespace"),
    callback = function(args)
        local ft = vim.bo[args.buf].filetype
        local skip = { markdown = true, diff = true, gitcommit = true, mail = true }
        if skip[ft] then return end
        local view = vim.fn.winsaveview()
        pcall(vim.cmd, [[keeppatterns %s/\s\+$//e]])
        vim.fn.winrestview(view)
    end,
})
