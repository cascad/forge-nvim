local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
vim.opt.rtp:prepend(root..'/nvim_forge')
local T=require('check')
local ru=require('config.ru_keys')
ru.setup();vim.g.mapleader=' ';vim.o.langmap=ru.langmap();vim.o.langremap=false
local function type_keys(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys,true,false,true),'xt',false)
end
T.check('IDE-FILE-9 native mappings accept English Russian and explicit Shift Cyrillic',function()
  local hits=0
  vim.keymap.set('n','gR',function() hits=hits+1 end)
  for i,keys in ipairs({'gR','пК','п<S-К>'}) do type_keys(keys);T.eq(hits,i,'actual native sequence '..keys) end
  vim.keymap.set('n','<leader>E',function() hits=hits+1 end)
  type_keys(' <S-У>');T.eq(hits,4,'native uppercase leader alias')
end)
T.check('IDE-FILE-9 Cyrillic text input stays unchanged by normal aliases',function()
  vim.cmd('enew')
  type_keys('iп<S-К> текст<Esc>')
  T.eq(vim.api.nvim_get_current_line(),'пК текст')
end)
T.check('Mac layout switch on the first motion preserves English Ex and Russian text input',function()
  local russian = { [':']='^', [';']='$' }
  local layout = russian
  ru.follow_layout(function() return layout end)
  vim.api.nvim_buf_set_lines(0,0,-1,false,{'   first line'})
  type_keys('gg0:'); T.eq(vim.fn.col('.'),4)
  type_keys(';'); T.eq(vim.fn.col('.'),13)
  type_keys('v:'); T.eq(vim.fn.col('.'),4)
  type_keys('<Esc>0d;'); T.eq(vim.api.nvim_get_current_line(),'')
  type_keys('iтекст:;<Esc>'); T.eq(vim.api.nvim_get_current_line(),'текст:;')
  layout=nil
  type_keys(':let g:forge_test_colon = 17<CR>'); T.eq(vim.g.forge_test_colon,17)
  type_keys('0$'); T.eq(vim.fn.col('.'),#'текст:;')
end)
T.finish()
