-- Compatibility facade. No winfix/size heuristics or editor split collapse.
local owner = require("ide.ownership")
local M = { sweep = owner.reconcile }
function M.setup()
    owner.setup()
    vim.api.nvim_create_user_command("PanelRepair", owner.reconcile, { desc = "Reconcile declared window ownership" })
    vim.api.nvim_create_user_command("ForgePanelHeal", owner.reconcile, { desc = "Reconcile declared window ownership" })
end
return M
