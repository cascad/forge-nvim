-- spec: IDE-DAP-2 Текст исключения принадлежит паузе конкретной DAP-сессии.
local M = {}

function M.new(active_session, append)
    local pauses = setmetatable({}, { __mode = "k" })
    return function(session, body)
        if not session or type(body) ~= "table" then return end
        local pause = {}
        pauses[session] = pause
        if body.reason ~= "exception" then return end
        local thread = body.threadId or session.stopped_thread_id
        local function current()
            return active_session() == session and pauses[session] == pause
                and session.stopped_thread_id ~= nil
                and (thread == nil or session.stopped_thread_id == thread)
        end
        if not current() then return end

        local seen = {}
        local function add(lines, value)
            if type(value) == "string" and value ~= "" and not seen[value] then
                seen[value] = true
                lines[#lines + 1] = value
            end
        end
        local summary = {}
        add(summary, body.description)
        add(summary, body.text)
        if #summary == 0 then summary[1] = "exception" end
        append("[DAP exception] " .. table.concat(summary, ": "))

        if not thread or not (session.capabilities or {}).supportsExceptionInfoRequest then return end
        session:request("exceptionInfo", { threadId = thread }, function(err, info)
            if err or type(info) ~= "table" or not current() then return end
            local lines = {}
            add(lines, info.exceptionId)
            add(lines, info.description)
            local function details(value)
                if type(value) ~= "table" then return end
                add(lines, value.typeName)
                add(lines, value.message)
                add(lines, value.stackTrace)
                for _, inner in ipairs(value.innerException or {}) do details(inner) end
            end
            details(info.details)
            if #lines > 0 then append(table.concat(lines, "\n")) end
        end)
    end
end

function M.setup(dap)
    -- IDE-DAP-2: сведения адаптера видны в REPL до runtime stderr/continue.
    dap.listeners.after.event_stopped.forge_exception_output = M.new(dap.session, function(text)
        require("dap.repl").append(text)
    end)
end

return M
