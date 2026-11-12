-- IDE-PANEL-21: штатные команды backend и общие переходы IDE.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')

local function visible(e,ft)
  return e:lua([[local ft=...;for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(w)].filetype==ft then return true end end;return false]],{ft})
end

local function tree(e)
  e:input(':Neotree filesystem left<CR>')
  e:wait('штатное Files',function()
    return e:current_ft()=='neo-tree' and e:lua('return vim.b.neo_tree_source')=='filesystem'
      and e:lua([[return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n'):find('file_one.txt',1,true)~=nil]])
  end)
end
local function sidebar(e)
  e:lua([[require('dapui').open({layout=1})]])
  e:wait('штатные Locals',function() return e:has_window('dapui_scopes') end)
end
local function quickfix(e)
  e:lua([[vim.fn.setqflist({{filename='file_one.txt',lnum=1,text='panel transition'}})]])
  e:input(' w0:copen<CR>')
  e:wait('штатный quickfix',function() return e:has_window('qf') end)
end
local function check(name,fn)
  if vim.env.FORGE_PANEL_CASE and not name:find(vim.env.FORGE_PANEL_CASE,1,true) then return end
  T.check('IDE-PANEL-21 '..name,function()
    local e
    local ok,err=xpcall(function()
      e=require('editor').start(root,{timeout=90000})
      e:wait('Forge ready',function() return e:lua('return _G.forge_e2e_observed') end,10000)
      assert(vim.uv.fs_copyfile(root..'/tests/e2e/panel-transitions.test.lua',e.dir..'/panel-transitions.test.lua'))
      -- nvim_input подтверждает приём, а не выполнение. Повторный Show
      -- может начинаться и заканчиваться в том же FT: нужен барьер ввода.
      e:lua([[_G.forge_panel_keys=0;vim.keymap.set('n','<F35>',function() _G.forge_panel_keys=_G.forge_panel_keys+1 end)]])
      local input=e.input
      e.input=function(self,value)
        local before=self:lua('return _G.forge_panel_keys')
        input(self,value..'<F35>')
        self:wait('нажатия обработаны',function() return self:lua('return _G.forge_panel_keys')>before end)
      end
      e:input(':edit file_one.txt<CR> pc')
      e:wait('код без панелей',function()
        return e:current_ft()=='text' and not e:has_window('neo-tree')
      end)
      fn(e)
      T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
      for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
    end,debug.traceback)
    if e then
      e:snapshot('panel-transitions');io.stdout:write('  artifacts: '..e.dir..'\n')
      local stopped,cleanup=pcall(e.stop,e,not ok and err or nil)
      if not stopped then ok=false;err=tostring(err or '')..'\nCleanup: '..tostring(cleanup) end
      local exited,issue=pcall(function()
        T.eq(e.rpc.exit_code,0);T.eq(e.rpc.exit_signal,0);T.eq(e.rpc.api_errors,{})
        assert(e.rpc.shutdown_result and e.rpc.shutdown_result.ok)
      end)
      if not exited then ok=false;err=tostring(err or '')..'\nNative exit: '..tostring(issue) end
    end
    assert(ok,err)
  end)
end

check('hide left закрывает штатное Files',function(e)
  tree(e);e:input(' w0 PL')
  e:wait('левый слот скрыт',function() return not e:has_window('neo-tree') end,1500)
  T.eq(e:current_ft(),'text')
end)

check('toggle slot закрывает и возвращает штатное Files',function(e)
  tree(e);e:input(' w0 Pt')
  e:wait('toggle скрывает Files',function() return not e:has_window('neo-tree') end,1500)
  e:input(' Pt');e:wait('toggle возвращает Files',function() return e:has_window('neo-tree') end)
  T.eq(e:lua([[return require('ide').current().slots.left]]),'explorer')
end)

check('toggle component закрывает штатное Files',function(e)
  tree(e);e:lua([[require('ide').toggle('explorer')]])
  e:wait('component скрыт',function() return not e:has_window('neo-tree') end,1500)
end)

check('show Files заменяет все штатные Locals, сохраняя quickfix',function(e)
  sidebar(e);quickfix(e);e:input(' we')
  e:wait('Files в фокусе',function() return e:current_ft()=='neo-tree' end)
  T.eq(e:has_window('dapui_scopes'),false,'штатные Locals остались рядом с Files')
  for _,ft in ipairs({'dapui_watches','dapui_stacks','dapui_breakpoints'}) do T.eq(e:has_window(ft),false,ft) end
  T.eq(e:has_window('qf'),true,'другой слот потерян')
end)

check('code layout закрывает штатные Files и quickfix',function(e)
  tree(e);quickfix(e);e:input(' pc')
  e:wait('чистый код',function() return not e:has_window('neo-tree') and not e:has_window('qf') end,1500)
  T.eq(e:current_ft(),'text')
end)

check('hide компонента сохраняет другой компонент того же слота',function(e)
  tree(e);e:lua([[require('ide').show('explorer')]])
  sidebar(e);e:lua([[require('ide').hide('dap.sidebar')]])
  e:wait('native Locals скрыты',function() return not e:has_window('dapui_scopes') end,1500)
  T.eq(e:has_window('neo-tree'),true,'hide Locals закрыл Files')
  T.eq(e:lua([[return require('ide').current().slots.left]]),'explorer')
end)

check('show принимает видимое Files без пересоздания окна',function(e)
  tree(e)
  local win=e:lua('return vim.api.nvim_get_current_win()')
  local buf=e:lua('return vim.api.nvim_get_current_buf()')
  e:input(' w0 we')
  e:wait('Files снова в фокусе',function() return e:current_ft()=='neo-tree' end)
  T.eq(e:lua('return vim.api.nvim_get_current_win()'),win)
  T.eq(e:lua('return vim.api.nvim_get_current_buf()'),buf)
  T.eq(e:lua([[return require('ide').current().slots.left]]),'explorer')
end)

check('toggle all запоминает штатные Files и quickfix',function(e)
  tree(e);quickfix(e)
  e:lua([[require('ide').toggle_panels()]])
  e:wait('все панели скрыты',function() return not e:has_window('neo-tree') and not e:has_window('qf') end,1500)
  e:lua([[require('ide').toggle_panels()]])
  e:wait('набор восстановлен',function() return e:has_window('neo-tree') and e:has_window('qf') end)
  T.eq(e:current_ft(),'text')
end)

check('focus slot находит штатное Files',function(e)
  tree(e);e:input(' w0');e:lua([[require('ide').focus_slot('left')]])
  e:wait('native Files в фокусе',function() return e:current_ft()=='neo-tree' end,1500)
end)

check('cycle начинается с видимого штатного источника',function(e)
  tree(e);e:input(' w0 Pl')
  e:wait('после Files идёт Git Files',function()
    return e:current_ft()=='neo-tree' and e:lua('return vim.b.neo_tree_source')=='git_status'
  end)
  T.eq(e:lua([[return require('ide').current().slots.left]]),'git_status')
end)

check('hide одного источника сохраняет соседний источник Neo-tree',function(e)
  tree(e);e:lua([[require('ide').show('explorer')]])
  e:input(':Neotree buffers right<CR>')
  e:wait('два настоящих источника',function()
    return e:lua([[local r=require('ide.registry');return r.get('explorer').is_open() and r.get('buffers').is_open()]])
  end)
  e:lua([[require('ide').hide('explorer')]])
  e:wait('Files закрыт отдельно',function() return not e:lua([[return require('ide.registry').get('explorer').is_open()]]) end)
  T.eq(e:lua([[return require('ide.registry').get('buffers').is_open()]]),true,'hide Files закрыл Buffers')
end)

check('повторный show убирает соседа, сохраняя окно Files',function(e)
  tree(e);e:lua([[require('ide').show('explorer')]])
  local win=e:lua('return vim.api.nvim_get_current_win()')
  sidebar(e);e:input(' we')
  e:wait('Files в фокусе',function() return e:current_ft()=='neo-tree' end)
  T.eq(e:has_window('dapui_scopes'),false,'идемпотентный show пропустил соседа')
  T.eq(e:lua('return vim.api.nvim_get_current_win()'),win)
end)

check('code layout сохраняет дерево другой вкладки',function(e)
  tree(e)
  local tab=e:lua('return vim.api.nvim_get_current_tabpage()')
  local win=e:lua('return vim.api.nvim_get_current_win()')
  e:input(' w0:tabnew file_two.txt<CR>')
  e:wait('вторая вкладка',function() return e:current_ft()=='text' and e:lua('return vim.api.nvim_get_current_tabpage()')~=tab end)
  tree(e);quickfix(e);e:input(' pc')
  e:wait('текущая вкладка без панелей',function() return not visible(e,'neo-tree') and not visible(e,'qf') end)
  T.eq(e:lua('return vim.api.nvim_win_is_valid(...)',{win}),true,'закрыто чужое окно')
  e:lua('vim.api.nvim_set_current_tabpage(...)',{tab})
  T.eq(e:has_window('neo-tree'),true)
end)
T.finish()
