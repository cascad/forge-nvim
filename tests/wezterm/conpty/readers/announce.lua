-- Проба A: объявление nvim_forge через ConPTY (add-nvim-chords-on-windows,
-- design, решение 1). Способ — $FORGE_ANNOUNCE_WAY: ui_send | chansend.
-- Последовательность — OSC 1337 SetUserVar=FORGE_NVIM=<base64 "1">.
local seq = '\027]1337;SetUserVar=FORGE_NVIM=' .. vim.base64.encode('1') .. '\007'
local way = os.getenv('FORGE_ANNOUNCE_WAY')
vim.api.nvim_create_autocmd('VimEnter', {
  callback = function()
    if way == 'ui_send' then
      vim.api.nvim_ui_send(seq)
    elseif way == 'chansend' then
      vim.fn.chansend(vim.v.stderr, seq)
    end
  end,
})
