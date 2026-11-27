local M = { building = false, discovering = 0 }

function M.label()
    local dap = package.loaded.dap
    if not dap then return '' end
    local session = dap.session()
    if session then
        if session.stopped_thread_id then return 'Debug: paused' end
        return session.initialized and 'Debug: running' or 'Debug: starting'
    end
    if M.building then return 'Debug: building' end
    if M.discovering > 0 then return 'Debug: finding targets' end
    return 'Debug: idle'
end

return M
