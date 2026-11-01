-- Читатель «nvim_forge»: что пришло в живой nvim_forge и во что оно
-- переназначено (WT-KEYS-10; add-nvim-chords-on-windows, задача 3.3).
-- Строка на нажатие: `<набрано> -> <привязка в текущем режиме>`. Путь — $FORGE_KEYLOG.
local f = assert(io.open(assert(os.getenv('FORGE_KEYLOG')), 'w'))
vim.api.nvim_create_autocmd('VimEnter', {
  callback = function()
    if vim.env.FORGE_CONPTY_PROFILE_RECORD then
      vim.fn.writefile({vim.json.encode({config=vim.fn.stdpath('config'),data=vim.fn.stdpath('data'),
        cache=vim.fn.stdpath('cache'),state=vim.fn.stdpath('state'),nvim=vim.v.progpath})},vim.env.FORGE_CONPTY_PROFILE_RECORD)
    end
    f:write('ready\n')
    f:flush()
  end,
})
vim.on_key(function(_, typed)
  if not typed or typed == '' then return end
  local k = vim.fn.keytrans(typed)
  local mode = vim.api.nvim_get_mode().mode:sub(1, 1)
  f:write(k .. ' -> ' .. vim.fn.maparg(k, mode) .. '\n')
  f:flush()
end)
