-- Cargo targets and native nvim-dap program coroutine.
local normalize_path = require("forge.dap.context").normalize_path

local function cargo_root()
    local launch_buf = vim.g.user_dap_launch_buf
    local current_buf = type(launch_buf) == "number"
        and vim.api.nvim_buf_is_valid(launch_buf)
        and launch_buf
        or vim.api.nvim_get_current_buf()
    local current = vim.api.nvim_buf_get_name(current_buf)
    local start = current ~= "" and vim.fs.dirname(current) or vim.fn.getcwd()
    local cargo_toml = vim.fs.find("Cargo.toml", { upward = true, path = start })[1]
    return cargo_toml and vim.fs.dirname(cargo_toml) or vim.fn.getcwd()
end

local function dap_abort()
    local ok, dap = pcall(require, "dap")
    return ok and dap.ABORT or nil
end

local function rust_target_has_kind(target, kind)
    for _, value in ipairs(target.kind or {}) do
        if value == kind then return true end
    end
    return false
end

local function rust_target_exe(parsed, target, kind)
    local exe_dir = (parsed.target_directory or cargo_root() .. "/target") .. "/debug"
    if kind == "example" then exe_dir = exe_dir .. "/examples" end

    local exe = exe_dir .. "/" .. target.name
    if vim.fn.has("win32") == 1 then exe = exe .. ".exe" end
    return exe
end

local function rust_select_program(parsed, manifest_path, current_file, complete)
    local selected_pkg = nil
    for _, pkg in ipairs(parsed.packages or {}) do
        if vim.fs.normalize(pkg.manifest_path or "") == manifest_path then
            selected_pkg = pkg
            break
        end
    end
    selected_pkg = selected_pkg or (parsed.packages or {})[1]
    if not selected_pkg then
        vim.notify("No Cargo package found for debug", vim.log.levels.ERROR, { title = "DAP" })
        return complete(dap_abort())
    end

    local candidates = {}
    for _, target in ipairs(selected_pkg.targets or {}) do
        if rust_target_has_kind(target, "bin") then
            table.insert(candidates, {
                kind = "bin",
                target = target,
                exe = rust_target_exe(parsed, target, "bin"),
            })
        elseif rust_target_has_kind(target, "example") then
            table.insert(candidates, {
                kind = "example",
                target = target,
                exe = rust_target_exe(parsed, target, "example"),
            })
        end
    end

    local normalized_current = normalize_path(current_file)
    for _, candidate in ipairs(candidates) do
        if normalize_path(candidate.target.src_path) == normalized_current then
            return complete(candidate.exe)
        end
    end

    for _, candidate in ipairs(candidates) do
        if candidate.kind == "bin" and candidate.target.name == selected_pkg.name then
            return complete(candidate.exe)
        end
    end

    if #candidates == 1 then
        return complete(candidates[1].exe)
    elseif #candidates > 1 then
        return vim.ui.select(candidates, {
            prompt = "Cargo debug target:",
            format_item = function(candidate)
                return candidate.target.name .. " [" .. candidate.kind .. "]"
            end,
        }, function(candidate)
            complete(candidate and candidate.exe or dap_abort())
        end)
    end

    vim.notify("No bin/example Cargo target found for debug", vim.log.levels.ERROR, { title = "DAP" })
    return complete(dap_abort())
end

local function cargo_metadata(root, done)
    local args = { "cargo", "metadata", "--no-deps", "--format-version", "1",
        "--manifest-path", root .. "/Cargo.toml" }
    local opts = { cwd = root, text = true, env = { RUSTUP_AUTO_INSTALL = "0" } }
    local ok, err = pcall(vim.system, args, opts, vim.schedule_wrap(function(result)
        if result.code == 0 then
            local decoded, metadata = pcall(vim.json.decode, result.stdout or "")
            if decoded and type(metadata) == "table" and type(metadata.packages) == "table" then
                return done(metadata)
            end
        end
        vim.notify("cargo metadata: " .. vim.trim(result.stderr or "invalid response"),
            vim.log.levels.WARN, { title = "DAP" })
        done(nil)
    end))
    if not ok then
        vim.notify("cargo metadata: " .. tostring(err), vim.log.levels.WARN, { title = "DAP" })
        done(nil)
    end
end

-- spec: IDE-DAP-9. Вся program option использует штатную coroutine nvim-dap.
local function rust_current_program()
    local root = cargo_root()
    local manifest_path = vim.fs.normalize(root .. "/Cargo.toml")
    local launch_cwd = normalize_path(vim.fn.getcwd())
    local launch_buf = vim.g.user_dap_launch_buf
    local current_file = type(launch_buf) == "number"
        and vim.api.nvim_buf_is_valid(launch_buf)
        and vim.api.nvim_buf_get_name(launch_buf)
        or vim.api.nvim_buf_get_name(0)

    return coroutine.create(function(co)
        local function complete(program)
            vim.schedule(function()
                if normalize_path(vim.fn.getcwd()) ~= launch_cwd then program = dap_abort() end
                coroutine.resume(co, program)
            end)
        end
        cargo_metadata(root, function(parsed)
            if not parsed or normalize_path(vim.fn.getcwd()) ~= launch_cwd then
                return complete(dap_abort())
            end
            rust_select_program(parsed, manifest_path, current_file, complete)
        end)
    end)
end

return {
    cargo_root = cargo_root,
    rust_current_program = rust_current_program,
}
