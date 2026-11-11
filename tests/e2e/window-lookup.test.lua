-- IDE-080: одинаковый native baseline до/после внутреннего refactor.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local function check(name,fn)
  T.check(name,function()
    local e,report
    local ok,err=xpcall(function()
      e=require('editor').start(root,{timeout=90000})
      assert(vim.uv.fs_copyfile(root..'/tests/e2e/window-lookup.test.lua',e.dir..'/window-lookup.test.lua'))
      e:wait('Forge ready',function() return e:lua('return _G.forge_e2e_observed') end,10000)
      report=fn(e)
      T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
      for _,n in ipairs(e.rpc.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
    end,debug.traceback)
    if e then
      report=report or {};report.ok=ok;report.error=not ok and tostring(err) or nil
      vim.fn.writefile({vim.json.encode(report)},e.dir..'/window-lookup.json')
      e:snapshot('window-lookup');io.stdout:write('  artifacts: '..e.dir..'\n')
      local stopped,cleanup=pcall(e.stop,e,not ok and err or nil)
      if not stopped then ok=false;err=tostring(err or '')..'\nCleanup: '..tostring(cleanup) end
      local exited,issue=pcall(function()
        T.eq(e.rpc.exit_code,0);T.eq(e.rpc.exit_signal,0);T.eq(e.rpc.api_errors,{})
        assert(e.rpc.shutdown_result and e.rpc.shutdown_result.ok)
      end)
      if not exited then ok=false;err=tostring(err or '')..'\nNative exit: '..tostring(issue) end
      report.ok=ok;report.error=not ok and tostring(err) or nil
      vim.fn.writefile({vim.json.encode(report)},e.dir..'/window-lookup.json')
    end
    assert(ok,err)
  end)
end

check('IDE-PANEL-2 component focus preserves native window priority and tab boundary',function(e)
  -- Настоящие normal/float окна; проверяем публичный registry без backend mocks.
  return e:lua([[local api=vim.api;local registry=require('ide.registry');local first_tab=api.nvim_get_current_tabpage()
    local main=api.nvim_get_current_win()
    local function buffer(ft) local b=api.nvim_create_buf(false,true);vim.bo[b].filetype=ft;return b end
    local a=api.nvim_open_win(buffer('forge-lookup-a'),false,{split='right',win=main})
    local b=api.nvim_open_win(buffer('forge-lookup-b'),false,{relative='editor',row=3,col=8,width=25,height=7,border='rounded'})
    vim.w[b].edgy_disable=true
    local order=api.nvim_tabpage_list_wins(0);local expected,other
    for _,w in ipairs(order) do if w==a or w==b then if not expected then expected=w else other=w end end end
    assert(expected and other)
    local function kind(w) return vim.bo[api.nvim_win_get_buf(w)].filetype end
    local spec={id='lookup.fixture',slot='right',filetypes={kind(other),kind(expected)},
      open=function() error('focus called open') end,close=function() error('focus called close') end,is_open=function() return false end}
    registry.register(spec)
    local before=api.nvim_tabpage_list_wins(0)
    api.nvim_set_current_win(main)
    local result=registry.get(spec.id).focus()
    assert(result==nil,'default return changed')
    assert(api.nvim_get_current_win()==expected,'FT-first replaced window-first order')
    assert(vim.deep_equal(before,api.nvim_tabpage_list_wins(0)),'focus changed topology')
    spec.filetypes={kind(other)};spec.focus()
    assert(api.nvim_get_current_win()==other,'live filetypes not read')
    spec.filetypes={};spec.focus();assert(api.nvim_get_current_win()==other,'empty metadata moved focus')
    api.nvim_set_current_win(main);vim.cmd('tabnew')
    local remote_tab=api.nvim_get_current_tabpage();local remote=api.nvim_get_current_win()
    api.nvim_win_set_buf(remote,buffer('forge-lookup-remote'))
    api.nvim_set_current_tabpage(first_tab);api.nvim_set_current_win(main)
    spec.filetypes={'forge-lookup-remote'};spec.focus()
    assert(api.nvim_get_current_tabpage()==first_tab and api.nvim_get_current_win()==main,'background match stole focus')
    spec.filetypes={'forge-lookup-missing'};spec.focus();assert(api.nvim_get_current_win()==main,'no-match moved focus')
    assert(vim.deep_equal(before,api.nvim_tabpage_list_wins(0)),'no-match created a window')
    local called=0
    local custom={id='lookup.custom',slot='bottom',open=spec.open,close=spec.close,is_open=spec.is_open,
      focus=function() called=called+1;api.nvim_set_current_win(b);return 17 end}
    local original=custom.focus;registry.register(custom)
    assert(custom.focus==original and custom.focus()==17 and called==1 and api.nvim_get_current_win()==b,'custom focus overwritten')
    return {normal=a,float=b,native_order=order,expected=expected,remote_tab=remote_tab,checks={
      window_first=true,live_metadata=true,empty=true,tab_boundary=true,no_match=true,topology=true,custom=true,nil_return=true}}
  ]])
end)

check('IDE-PANEL-1 native Neo-tree sources share FT without sharing visibility',function(e)
  local report={sources={}}
  e:input(':edit file_one.txt<CR>');e:wait('plain code',function() return e:current_ft()=='text' end)
  local function visible()
    return e:lua([[local r=require('ide.registry');local result={}
      for _,id in ipairs({'explorer','buffers','git_status'}) do result[id]=r.get(id).is_open() end;return result]])
  end
  local function source(name,id)
    e:input(':Neotree '..name..' left<CR>')
    e:wait('real Neo-tree '..name,function()
      return e:current_ft()=='neo-tree' and e:lua('return vim.b.neo_tree_source')==name
    end)
    local state=visible()
    for _,component in ipairs({'explorer','buffers','git_status'}) do T.eq(state[component],component==id,name..' visibility '..component) end
    report.sources[#report.sources+1]={source=name,visible=state}
  end
  source('filesystem','explorer');source('buffers','buffers');source('git_status','git_status')
  local original_tab=e:lua('return vim.api.nvim_get_current_tabpage()')
  e:input(':tabnew file_two.txt<CR>');e:wait('second tab text',function() return e:current_ft()=='text' end)
  T.eq(visible(),{explorer=false,buffers=false,git_status=false},'background source appears in current tab')
  e:lua('vim.api.nvim_set_current_tabpage(...)',{original_tab})
  T.eq(visible(),{explorer=false,buffers=false,git_status=true},'original source was changed')
  e:input(':Neotree close<CR>');e:wait('tree closed',function() return not e:has_window('neo-tree') end)
  T.eq(visible(),{explorer=false,buffers=false,git_status=false},'closed tree visible')
  report.closed=true;report.background_ignored=true
  return report
end)
T.finish()
