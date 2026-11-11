-- IDE-076: явный эксперимент одной Locals; default runtime его не загружает.
local M={}
local controls,original,saved,highlights
local names={'ForgeFramePreviewAccent','ForgeFramePreviewDim'}
local chars={'╭','─','╮','│','╯','─','╰','│'}
local function decorate()
  for _,win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local cfg=vim.api.nvim_win_get_config(win)
    if cfg.relative=='editor' and vim.bo[vim.api.nvim_win_get_buf(win)].filetype=='dapui_scopes' then
      if not saved[win] then
        saved[win]={winbar=vim.wo[win].winbar,border=cfg.border,title=cfg.title,title_pos=cfg.title_pos}
      end
      local focused=win==vim.api.nvim_get_current_win()
      local group=names[focused and 1 or 2]
      local border={}
      for _,char in ipairs(chars) do border[#border+1]={char,group} end
      vim.wo[win].winbar=''
      vim.api.nvim_win_set_config(win,{border=border,title={{focused and ' Locals [focus] ' or ' Locals ',group}},title_pos='left'})
    end
  end
end
function M.start()
  assert(not original,'Frame preview already active')
  controls=require('ide.controls');original=controls.refresh;saved={};highlights={}
  for _,name in ipairs(names) do highlights[name]=vim.api.nvim_get_hl(0,{name=name,link=false,create=false}) end
  local accent=vim.api.nvim_get_hl(0,{name='DiagnosticInfo',link=false}).fg or 0x89b4fa
  local dim=vim.api.nvim_get_hl(0,{name='Comment',link=false}).fg or 0x6c7086
  vim.api.nvim_set_hl(0,names[1],{fg=accent,bold=true})
  vim.api.nvim_set_hl(0,names[2],{fg=dim})
  local base=original
  controls.refresh=function(...)
    base(...)
    if original then decorate() end
  end
  controls.refresh()
end
function M.stop()
  if not original then return end
  controls.refresh=original;original=nil
  for win,state in pairs(saved) do
    if vim.api.nvim_win_is_valid(win) then
      vim.wo[win].winbar=state.winbar
      vim.api.nvim_win_set_config(win,{border=state.border,title=state.title,title_pos=state.title_pos})
    end
  end
  for name,value in pairs(highlights) do vim.api.nvim_set_hl(0,name,value) end
  saved=nil;highlights=nil
  controls.refresh()
end
function M.active() return original~=nil end
return M
