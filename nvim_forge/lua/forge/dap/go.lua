-- Delve discovery and selection; native async behaviour is unchanged.
-- Resolve a tool installed by Mason. Returns absolute path or nil.
-- Used to bypass $PATH lookup when there are multiple competing copies of
-- the same tool on disk (e.g. user's own ~/go/bin/dlv vs Mason's pinned dlv).
-- Mason wraps binaries on Windows with .cmd shims; check all suffixes.
local function mason_bin(name)
    local data = vim.fn.stdpath("data")
    local candidates = {
        data .. "/mason/bin/" .. name .. ".cmd",
        data .. "/mason/bin/" .. name .. ".exe",
        data .. "/mason/bin/" .. name,
    }
    for _, candidate in ipairs(candidates) do
        if vim.fn.filereadable(candidate) == 1 then return candidate end
    end
    return nil
end

local function path_join(...)
    return table.concat({ ... }, "/")
end

local function executable_file(path)
    return path and path ~= "" and (vim.fn.executable(path) == 1 or vim.fn.filereadable(path) == 1)
end

local function add_executable_variants(add, dir, name, source)
    if not dir or dir == "" then return end
    local suffixes = vim.fn.has("win32") == 1 and { ".exe", ".cmd", ".bat" } or { "" }
    for _, suffix in ipairs(suffixes) do
        local candidate = path_join(vim.fs.normalize(dir), name .. suffix)
        if executable_file(candidate) then
            add(candidate, source)
        end
    end
end

-- spec: IDE-DAP-10. Metadata ждём в native coroutine, UI остаётся доступным.
local function probe_output(command)
    local co = coroutine.running()
    assert(co, "Tool probe requires a coroutine")
    local ok = pcall(vim.system, command, { text = true, env = { GOTOOLCHAIN = "local" } }, function(result)
        vim.schedule(function() coroutine.resume(co, result) end)
    end)
    if not ok then return nil end
    local result = coroutine.yield()
    return result.code == 0 and result.stdout or nil
end

local function go_paths()
    if vim.fn.executable("go") ~= 1 then return {} end
    local out = probe_output({ "go", "env", "-json", "GOBIN", "GOPATH" })
    local ok, paths = pcall(vim.json.decode, out or "")
    return ok and type(paths) == "table" and paths or {}
end

local function parse_dlv_version(path)
    if not executable_file(path) then return nil end
    local out = probe_output({ path, "version" })
    if not out then return nil end
    local major, minor, patch = out:match("Version:%s*v?(%d+)%.(%d+)%.(%d+)")
    if not major then return nil end
    return {
        major = tonumber(major),
        minor = tonumber(minor),
        patch = tonumber(patch),
        text = ("v%s.%s.%s"):format(major, minor, patch),
    }
end

local function compare_versions(a, b)
    if not a and not b then return 0 end
    if a and not b then return 1 end
    if b and not a then return -1 end
    for _, key in ipairs({ "major", "minor", "patch" }) do
        if a[key] ~= b[key] then
            return a[key] > b[key] and 1 or -1
        end
    end
    return 0
end

local function unique_dlv_candidates()
    local candidates, seen = {}, {}

    local function add(path, source)
        if not executable_file(path) then return end
        local normalized = vim.fs.normalize(path):gsub("\\", "/")
        if vim.fn.has("win32") == 1 then
            normalized = normalized:lower()
        end
        if seen[normalized] then return end
        seen[normalized] = true
        table.insert(candidates, {
            path = path,
            source = source,
            version = parse_dlv_version(path),
        })
    end

    local paths = go_paths()
    local gobin = paths.GOBIN
    if gobin and gobin ~= "" then
        add_executable_variants(add, gobin, "dlv", "GOBIN")
    end

    local gopath = paths.GOPATH
    if gopath and gopath ~= "" then
        local sep = vim.fn.has("win32") == 1 and ";" or ":"
        for dir in gopath:gmatch("([^" .. sep .. "]+)") do
            add_executable_variants(add, path_join(dir, "bin"), "dlv", "GOPATH/bin")
        end
    end

    local path_dlv = vim.fn.exepath("dlv")
    if path_dlv and path_dlv ~= "" then
        add(path_dlv, "PATH")
    end

    local mason = mason_bin("dlv")
    if mason then
        add(mason, "Mason")
    end

    table.sort(candidates, function(a, b)
        local cmp = compare_versions(a.version, b.version)
        if cmp ~= 0 then return cmp > 0 end
        return a.source < b.source
    end)

    return candidates
end

local function resolve_dlv_path(candidates,root)
    local override, explicit = require('forge.debug_tools').dlv_override(root)
    if explicit then return override end

    candidates = candidates or unique_dlv_candidates()
    if #candidates > 0 then
        return require('forge.tool_paths').selected('dlv',candidates[1].path,candidates[1].source,root)
    end
    return "dlv"
end

local function show_dlv_info()
    require("dap.async").run(function()
        local candidates = unique_dlv_candidates()
        local lines = { "Delve candidates:" }
        for _, candidate in ipairs(candidates) do
            table.insert(lines, ("  %s  %s  (%s)"):format(
                candidate.version and candidate.version.text or "unknown",
                candidate.path,
                candidate.source
            ))
        end
        if #lines == 1 then table.insert(lines, "  <none found>") end
        table.insert(lines, "Selected: " .. resolve_dlv_path(candidates))
        vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "DAP Go" })
    end)
end

local function package_config(path)
    local directory = vim.fs.dirname(path) or vim.fn.getcwd()
    local work = vim.env.GOWORK
    local workspace = work ~= 'off' and
        ((work and work ~= 'auto' and work ~= '') or vim.fs.root(directory, 'go.work'))
    local standalone = not workspace and not vim.fs.root(directory, 'go.mod')
    return {
        type = "go",
        request = "launch",
        mode = "debug",
        -- Delve builds from dlvCwd and starts the program in cwd.
        -- GOPATH mode builds "." because Go rejects absolute package paths in that mode.
        program = (standalone or vim.env.GO111MODULE == 'off') and "." or directory,
        dlvCwd = directory,
        cwd = "${workspaceFolder}",
        env = standalone and { GO111MODULE = "off" } or nil,
        outputMode = "remote",
    }
end

return {
    resolve_dlv_path = resolve_dlv_path,
    show_dlv_info = show_dlv_info,
    package_config = package_config,
}
