local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
package.path = root .. '/tests/lib/?.lua;' .. package.path
local go_cache = require('go_cache').path(root)
local T = require('check')
local uv = vim.uv

local function new_editor(on_create)
  local deps = vim.env.FORGE_E2E_TEST_DEPS or root .. '/.tests/test-deps'
  assert(vim.fn.filereadable(deps .. '/manifest.json') == 1,
    'Выполни python[3] -B tests/e2e/prepare_tests.py --download')
  local manifest = vim.json.decode(table.concat(vim.fn.readfile(deps .. '/manifest.json'), '\n'))
  local lock = vim.json.decode(table.concat(vim.fn.readfile(root .. '/nvim_forge/lazy-lock.json'), '\n'))
  T.eq(manifest.treesitter_commit, lock['nvim-treesitter'].commit, 'Go parser соответствует lock')
  local path, sep = vim.env.PATH, vim.fn.has('win32') == 1 and ';' or ':'
  T.eq(manifest.gotestsum_version, 'v1.13.0', 'gotestsum соответствует явной подготовке')
  path = deps .. '/bin' .. sep .. path
  local tools = vim.env.FORGE_E2E_DAP_TOOLS or root .. '/.tests/dap-tools'
  if vim.fn.isdirectory(tools .. '/go/bin') == 1 then
    path = tools .. '/bin' .. sep .. tools .. '/go/bin' .. sep .. path
  end
  local e = require('editor').start(root, { timeout = 180000, site = deps .. '/site',
    env = { PATH = path, GOTOOLCHAIN = 'local', GOPROXY = 'off', GOENV = 'off',
      GOCACHE = go_cache } })
  on_create(e)
  local project = e.project .. '/go project with spaces'
  vim.fn.mkdir(project, 'p')
  for _, name in ipairs({ 'go.mod', 'sample_test.go' }) do
    assert(uv.fs_copyfile(root .. '/tests/e2e/fixtures/test-runner/' .. name, project .. '/' .. name))
  end
  e.test_project = project
  e:input([[:cd go\ project\ with\ spaces<CR>:edit sample_test.go<CR>]])
  e:wait('Go-файл отрисован', function()
    local screen = table.concat(e.rpc:screen_lines(), '\n')
    if screen:find('Press ENTER', 1, true) then e:input('<CR>'); return false end
    return screen:find('TestNearest', 1, true) ~= nil
  end, 10000)
  e:wait('Go filetype готов', function()
    if e.rpc:request('nvim_get_mode', {}).blocking then
      vim.fn.writefile(e.rpc:screen_lines(), e.dir .. '/go-open-prompt.txt')
      e:input('<CR>')
      return false
    end
    return e:current_ft() == 'go'
  end)
  for _, notification in ipairs(e:lua('return vim.g.forge_e2e_notifications')) do
    assert(notification.level < vim.log.levels.ERROR, notification.message)
  end
  return e
end

local function counts(e)
  return e:lua([[local n=require('neotest'); local out={passed=0,failed=0,skipped=0,running=0,total=0};
    for _,id in ipairs(n.state.adapter_ids()) do local s=n.state.status_counts(id);
      if s then for k in pairs(out) do out[k]=out[k]+(s[k] or 0) end end end; return out]])
end

local function wait_results(e)
  e:wait('реальный результат neotest', function()
    local s = counts(e)
    return s.passed + s.failed + s.skipped > 0 and s.running == 0
  end, 30000)
end

local function text(e, ft)
  return e:lua([[local ft=...; local lines={}; for _,b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].filetype==ft then vim.list_extend(lines,vim.api.nvim_buf_get_lines(b,0,-1,false)) end
    end; return table.concat(lines,'\n')]], { ft })
end

local function hover_visible(e)
  return e:has_window('dap-float')
end

local function check(name, fn)
  T.check(name, function()
    local e
    local ok, failure = pcall(function() new_editor(function(created) e = created end); fn(e) end)
    if e then
      e:snapshot(name)
      pcall(function()
        for _, logger_name in ipairs({ 'neotest', 'neotest-golang' }) do
          local log = e:lua([[local name=...; return require('neotest.logging').new(name):get_filename()]], { logger_name })
          if vim.fn.filereadable(log) == 1 then uv.fs_copyfile(log, e.dir .. '/' .. logger_name .. '.log') end
        end
      end)
      pcall(function()
        local state = e:lua([[local n=require('neotest'); local out={}; for _,id in ipairs(n.state.adapter_ids()) do out[id]=n.state.status_counts(id) end; return out]])
        vim.fn.writefile({ vim.json.encode(state) }, e.dir .. '/test-results.json')
      end)
      pcall(function()
        e:lua([[local d=package.loaded.dap; if d and d.session() then d.terminate() end]])
        e:wait('cleanup DAP', function() return e:lua([[local d=package.loaded.dap;return not d or d.session()==nil]]) end)
      end)
      io.stdout:write('  artifacts: ' .. e.dir .. '\n')
      e:stop()
    end
    assert(ok, failure)
  end)
end

check('IDE-TEST-1 ближайший Go-тест без DAP, соседний тест не запускается', function(e)
  e:input('10G Tt')
  wait_results(e)
  T.eq(counts(e).passed, 1)
  T.eq(counts(e).failed, 0)
  T.eq(e:lua([[return require('neotest.lib').subprocess.enabled()]]), true,
    'discovery работает в настоящем neotest worker без fallback')
  T.eq(vim.fn.filereadable(e.test_project .. '/neighbour-ran.txt'), 0)
  T.eq(e:lua([[local d=package.loaded.dap;return not d or d.session()==nil]]), true)
  T.eq(hover_visible(e), false)
  T.eq(e:has_window('neotest-output-panel'), true)
  e:wait('вывод выбранного теста', function() return text(e, 'neotest-output-panel'):find('NEAREST_OUTPUT', 1, true) ~= nil end)
end)

check('IDE-TEST-1 запуск файла показывает pass/fail и не блокирует редактирование', function(e)
  e:input('15G Tt')
  wait_results(e)
  T.eq(counts(e).passed, 0)
  T.eq(counts(e).failed, 1)
  T.eq(hover_visible(e), false)
  e:input('10G Tf')
  e:wait('результат всего файла после nearest', function()
    local s = counts(e)
    return s.passed + s.failed == 2 and s.running == 0
  end, 30000)
  T.eq(counts(e).passed, 1)
  T.eq(counts(e).failed, 1)
  e:wait('ошибка соседнего теста видна', function() return text(e, 'neotest-output-panel'):find('NEIGHBOUR_FAILURE', 1, true) ~= nil end)
  T.eq(hover_visible(e), false)
  e:input('<F7>')
  e:wait('фокус в коде', function() return e:current_ft() == 'go' end)
  e:input(' TO')
  e:wait('Output скрыт', function() return not e:has_window('neotest-output-panel') end)
  e:input('Go// STILL_EDITABLE<Esc><C-s>')
  e:wait('код сохранён после теста', function()
    return table.concat(vim.fn.readfile(e.test_project .. '/sample_test.go'), '\n'):find('STILL_EDITABLE', 1, true) ~= nil
  end)
end)

check('IDE-DAP-3 eval без сессии не оставляет No active session float', function(e)
  e:input('10G de')
  e:wait('сообщение или окно eval обработано', function()
    return hover_visible(e) or e:lua([[for _,n in ipairs(vim.g.forge_e2e_notifications) do if n.message:find('на паузе',1,true) then return true end end; return false]])
  end)
  T.eq(hover_visible(e), false)
  T.eq(e:current_ft(), 'go')
  T.eq(e:lua("return require('dap').session()==nil"), true)
end)

check('IDE-DAP-3 оставшийся DAP float закрывается Esc и q, в том числе из кода', function(e)
  -- GIVEN: настоящий публичный widget уже открыт (например, старой командой).
  for _, key in ipairs({ '<Esc>', 'q', '<F7><Esc>' }) do
    e:input([[:lua require('dap.ui.widgets').hover()<CR>]])
    e:wait('виден настоящий DAP float', function() return hover_visible(e) end)
    e:input(key)
    e:wait('DAP float закрыт клавиатурой', function() return not hover_visible(e) end)
    T.eq(e:current_ft(), 'go')
  end
end)

check('IDE-TEST-2 debug nearest, реальный eval 42 и продолжение до результата', function(e)
  e:input('10G<F9> Td')
  e:wait('Delve остановился на breakpoint', function()
    if e:ack_warning("Debug adapter didn't respond.") then return false end
    return e:lua([[local d=require('dap'); local s=d.session(); return s~=nil and s.stopped_thread_id~=nil and s.current_frame~=nil]])
  end, 60000)
  T.eq(vim.fn.filereadable(e.test_project .. '/neighbour-ran.txt'), 0)
  e:input('$Fv de')
  e:wait('реальное значение переменной', function()
    return hover_visible(e) and text(e, 'dap-float'):find('42', 1, true) ~= nil
  end)
  e:input('q')
  e:wait('eval закрыт', function() return not hover_visible(e) end)
  T.eq(e:lua([[local s=require('dap').session();return s~=nil and s.stopped_thread_id~=nil]]), true)
  e:input('<F5>')
  e:wait('debug session завершена', function() return e:lua("return require('dap').session()==nil") end, 20000)
  -- Upstream намеренно возвращает skipped для DAP: он не получает go test -json.
  -- Реальный исход проверяем в REPL, не выдаём этот статус за PASS в панели.
  e:wait('debug завершён в neotest', function() return counts(e).skipped == 1 and counts(e).running == 0 end, 10000)
  T.eq(vim.fn.filereadable(e.test_project .. '/neighbour-ran.txt'), 0)
  local output = text(e, 'dap-repl')
  assert(output:find('NEAREST_OUTPUT', 1, true), 'Debug stdout должен сохраняться')
  assert(output:find('--- PASS: TestNearest', 1, true), 'Реальный итог debug виден в REPL')
end)

T.finish()
