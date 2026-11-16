local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
package.path = root .. '/tests/lib/?.lua;' .. package.path
local T = require('check')
local reports = {}
for attempt = 1, 2 do
    T.check('IDE-BOOT-25 полный запуск на Unicode пути ' .. attempt, function()
        local e = require('editor').start(root)
        local ok, err = xpcall(function()
            e:wait('IDE ready', function() return e:lua('return _G.forge_e2e_observed') end, 10000)
            local report = e:lua([[
                local directory = vim.uv.cwd() .. '/модули с пробелами'
                vim.fn.mkdir(directory, 'p')
                local file = directory .. '/fride_cache_probe.lua'
                vim.fn.writefile({'return {value = 42}'}, file)
                package.path = directory .. '/?.lua;' .. package.path
                assert(require('fride_cache_probe').value == 42)
                vim.fn.writefile({'return {value = 43}'}, file)
                package.loaded.fride_cache_probe = nil
                assert(require('fride_cache_probe').value == 43, 'Stale Lua source')
                local config = require('lazy.core.config')
                assert(config.options.performance.cache.enabled == false, 'Disk cache still enabled')
                assert(vim.loader.enabled == false, 'Native bytecode loader is still active')
                assert(vim.fn.exists(':Neotree') == 2 and vim.fn.exists(':ForgeLogs') == 2, 'Full configuration did not load')
                assert(vim.g.forge_e2e_installs == 0, 'Startup installed tools')
                local stats = require('lazy').stats()
                local path = vim.fn.stdpath('config') .. '/lua/config/lazy.lua'
                local encoded_length = #vim.uri_encode(path, 'rfc2396') + 1
                assert(encoded_length > 255, 'Regression path is too short')
                return {startup_ms = stats.startuptime, real_cputime = stats.real_cputime,
                    plugins = stats.count, loaded = stats.loaded, encoded_basename = encoded_length,
                    config = vim.fn.stdpath('config'), runtime = vim.env.VIMRUNTIME, cache = false}
            ]])
            e:input(':edit file_one.txt<CR>gg0iCACHE_SAFE_<Esc>:w<CR>')
            e:wait('file saved', function() return vim.fn.readfile(e.project .. '/file_one.txt')[1] == 'CACHE_SAFE_first file' end)
            reports[#reports + 1] = report
        end, debug.traceback)
        local stopped, stop_error = pcall(e.stop, e, not ok and tostring(err) or nil)
        assert(ok, err)
        assert(stopped, stop_error)
        io.stdout:write('  artifacts: ' .. e.dir .. '\n')
    end)
end
vim.fn.writefile({vim.json.encode(reports)}, assert(vim.env.FORGE_LUA_CACHE_REPORT))
T.finish()
