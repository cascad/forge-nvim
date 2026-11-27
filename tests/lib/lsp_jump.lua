-- После нажатия проверяем файл и строку реализации, затем точный возврат к вызову.
return function(e, key, target, target_line)
  local function position()
    return e:lua([[return {file=vim.api.nvim_buf_get_name(0):gsub('\\','/'),
      window=vim.api.nvim_get_current_win(),cursor=vim.api.nvim_win_get_cursor(0)}]])
  end
  local origin = position()
  e:input(key)
  -- Если сервер вернул несколько адресов, выбираем реализацию из видимого Quickfix.
  e:wait('LSP returned locations', function()
    return e:current_ft() == 'qf' or e:current_file():sub(-#target) == target
  end, 20000)
  if e:current_ft() == 'qf' then
    local row = e:lua([[local suffix=...
      for index,item in ipairs(vim.fn.getqflist()) do
        if vim.api.nvim_buf_get_name(item.bufnr):gsub('\\','/'):sub(-#suffix)==suffix then return index end
      end]], {target})
    assert(type(row) == 'number', 'Implementation missing from Quickfix: ' .. target)
    e:input(row .. 'G<CR>')
  end
  e:wait('jump to ' .. target .. ' on ' .. target_line, function()
    return e:current_file():sub(-#target) == target
      and e:lua('return vim.api.nvim_get_current_line()'):find(target_line, 1, true)
  end, 20000)
  assert(position().window == origin.window, 'LSP jump changed the code split')
  e:input('<C-o>')
  e:wait('return to original file, split and cursor', function() return vim.deep_equal(position(), origin) end)
end
