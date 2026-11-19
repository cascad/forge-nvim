-- spec: IDE-PANEL-30. Real managed shell/PTY/stdin; no mocked terminal APIs.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local win=vim.fn.has('win32')==1
local python=vim.fn.exepath(win and 'python' or 'python3')
assert(python~='','Prepared native Python required for PTY stdin fixture')
local reader=[=[import json,os,sys
from pathlib import Path
p=Path(sys.argv[1]);lines=[]
def save():
    p.write_text(json.dumps({'pid':os.getpid(),'cwd':os.getcwd(),'lines':lines},ensure_ascii=False),encoding='utf-8')
save();print('FORGE_SELECTION_READER_READY',flush=True)
for line in sys.stdin:
    text=line.rstrip('\r\n')
    if text=='__FORGE_SELECTION_EXIT__':break
    lines.append(text);save();print('FORGE_SELECTION_RX_'+str(len(lines)),flush=True)
]=]
local function code(e)
  if e:current_ft()~='text' then
    e:input('<F7>');e:wait('code focus',function()return e:current_ft()=='text'end)
  end
end
local function data(e,path)
  return e:lua([[local ok,lines=pcall(vim.fn.readfile,...);if not ok then return false end
    local good,value=pcall(vim.json.decode,table.concat(lines,'\n'));return good and value or false]],{path})
end
local function received(e,path,count)
  local value
  e:wait('native stdin '..count,function()value=data(e,path);return value and #value.lines==count end,10000)
  return value
end
local function terms(e)
  return e:lua([[local out={};for _,t in ipairs(require('toggleterm.terminal').get_all(true))do
    local good,pid=pcall(vim.fn.jobpid,t.job_id)
    out[#out+1]={id=t.id,buf=t.bufnr,job=t.job_id,pid=good and pid or 0,hidden=t.hidden or false,
      open=t:is_open(),direction=t.direction,window=t.window}
  end;return out]])
end
local function find(e,id)for _,t in ipairs(terms(e))do if t.id==id then return t end end end
local function prepare(e,lines,col)
  code(e)
  return e:lua([[local lines,col=...;vim.cmd.stopinsert();vim.cmd('normal! '..string.char(27))
    vim.o.clipboard='';vim.fn.writefile(lines,'selection.txt');vim.cmd('edit! selection.txt');vim.api.nvim_win_set_cursor(0,{1,col or 0})
    vim.fn.setreg('"','FORGE_KEEP_UNNAMED');vim.fn.setreg('0','FORGE_KEEP_ZERO')
    return {buf=vim.api.nvim_get_current_buf(),lines=vim.api.nvim_buf_get_lines(0,0,-1,false),
      unnamed=vim.fn.getreg('"'),zero=vim.fn.getreg('0'),modified=vim.bo.modified}]],{lines,col or 0})
end
local function unchanged(e,before)
  local after=e:lua([[local b=...;return {buf=b,lines=vim.api.nvim_buf_get_lines(b,0,-1,false),
    unnamed=vim.fn.getreg('"'),zero=vim.fn.getreg('0'),modified=vim.bo[b].modified}]],{before.buf})
  T.eq(after,before,'source buffer/registers changed')
end
local function send(e,selection,alias)
  e:input(selection);e:wait('visual selection',function()
    return e:lua([[local m=vim.fn.mode();return m=='v' or m=='V' or m==string.char(22) or m=='s']])
  end)
  e:input(alias or ' te')
end
local function open_reader(e,id,direction,hidden)
  code(e)
  local path=e.project..'/reader-'..id..'.json'
  local dir=e.project..'/session-'..id
  e:lua([[local id,direction,hidden,python,script,path,dir=...
    vim.fn.mkdir(dir,'p');local args={python,'-X','utf8','-u',script,path}
    local command=table.concat(vim.tbl_map(vim.fn.shellescape,args),' ')
    local shell=vim.o.shell:lower();if shell:find('pwsh',1,true) or shell:find('powershell',1,true)then command='& '..command end
    local t=require('toggleterm.terminal').Terminal:new({id=id,cmd=command,dir=dir,direction=direction,hidden=hidden})
    _G.forge_selection_test_terms=_G.forge_selection_test_terms or {};_G.forge_selection_test_terms[id]=t
    t:open()]],{id,direction or 'horizontal',hidden or false,python,e.project..'/selection-reader.py',path,dir})
  e:wait('real stdin reader ready',function()return data(e,path)~=false end,10000)
  code(e)
  return path,find(e,id)
end
local function same(before,after)
  for _,key in ipairs({'id','buf','job','pid'})do T.eq(after[key],before[key],key..' replaced')end
end
local function check(name,fn)
  if vim.env.FORGE_SELECTION_CASE and not name:find(vim.env.FORGE_SELECTION_CASE,1,true)then return end
  T.check('IDE-PANEL-30 '..name,function()
    local e
    local ok,why=xpcall(function()
      e=require('editor').start(root,{timeout=30000,prepare=function(project)
        assert(vim.fn.writefile(vim.split(reader,'\n',{plain=true}),project..'/selection-reader.py')==0)
      end})
      e:wait('editor ready',function()return e:lua('return _G.forge_e2e_observed')end,10000)
      e:input(':edit file_one.txt<CR>');e:wait('text file',function()return e:current_ft()=='text'end)
      fn(e)
      T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
      for _,n in ipairs(e.rpc.notifications)do assert(n.level<vim.log.levels.ERROR,n.message)end
    end,debug.traceback)
    if e then
      local observed,value=pcall(e.lua,e,[[local result={readers={}}
        for _,path in ipairs(vim.fn.glob('reader-*.json',false,true))do
          local ok,data=pcall(vim.json.decode,table.concat(vim.fn.readfile(path),'\n'))
          result.readers[path]=ok and data or false
        end
        return result]])
      if observed then vim.fn.writefile({vim.json.encode(value)},e.dir..'/selection-readers.json')end
      e:snapshot('terminal-selection');io.stdout:write('  artifacts: '..e.dir..'\n')
      local stopped,err=pcall(e.stop,e,not ok and why or nil)
      if not stopped then ok=false;why=tostring(why or '')..'\nCleanup: '..tostring(err)end
    end
    assert(ok,why)
  end)
end
check('first CtrlEnter creates integrated shell and shows real output',function(e)
  local marker='FORGE_SELECTION_FIRST_OUTPUT'
  local before=prepare(e,{'echo '..marker})
  send(e,'V','<C-CR>')
  e:wait('managed Terminal created',function()return e:has_window('toggleterm')end,8000)
  e:wait('native shell output',function()return e:lua([[for _,t in ipairs(require('toggleterm.terminal').get_all())do
    for _,line in ipairs(vim.api.nvim_buf_get_lines(t.bufnr,0,-1,false))do if line==... then return true end end
    end;return false]],{marker})end,10000)
  T.eq(#terms(e),1);unchanged(e,before)
  local t=terms(e)[1];code(e)
  before=prepare(e,{'echo FORGE_SELECTION_REPEAT_OUTPUT'});send(e,'V')
  e:wait('repeat stdout',function()return e:lua([[local t=require('toggleterm.terminal').get(...)
    return table.concat(vim.api.nvim_buf_get_lines(t.bufnr,0,-1,false),'\n'):find('FORGE_SELECTION_REPEAT_OUTPUT',1,true)~=nil]],{t.id})end)
  T.eq(#terms(e),1);same(t,find(e,t.id));unchanged(e,before)
end)
check('hidden and visible session retains stdin program cwd and history',function(e)
  local path,before=open_reader(e,1)
  local source=prepare(e,{'outside  exact λ漢🙂  outside'},9)
  send(e,'v10l');local first=received(e,path,1)
  T.eq(first.lines,{'exact λ漢🙂  '});unchanged(e,source)
  e:lua([[require('toggleterm.terminal').get(1):close()]])
  source=prepare(e,{'    first "quoted"','  second λ漢🙂'});send(e,'Vj')
  local second=received(e,path,3)
  T.eq(second.lines,{'exact λ漢🙂  ','    first "quoted"','  second λ漢🙂'})
  T.eq(second.pid,first.pid);T.eq(second.cwd,first.cwd);same(before,find(e,1));T.eq(#terms(e),1)
  assert(find(e,1).open);unchanged(e,source)
end)
check('char reversed exclusive block Select and aliases preserve exact text',function(e)
  local path,before=open_reader(e,1);local expected={}
  local function one(lines,col,selection,want,alias)
    local source=prepare(e,lines,col);send(e,selection,alias)
    for _,line in ipairs(want)do expected[#expected+1]=line end
    T.eq(received(e,path,#expected).lines,expected);unchanged(e,source)
  end
  one({'xxλ漢🙂yy'},2,'v2l',{'λ漢🙂'})
  one({'xxABCDyy'},5,'v3h',{'ABCD'})
  e:lua([[vim.o.selection='exclusive']]);one({'xxABCDyy'},2,'v4l',{'ABCD'})
  e:lua([[vim.o.selection='inclusive']])
  local source=prepare(e,{'::FIRST??','::THIRD??'},2)
  e:lua([[vim.cmd('normal! '..string.char(22)..'j4l')]])
  e:input(' te');expected[#expected+1]='FIRST';expected[#expected+1]='THIRD'
  T.eq(received(e,path,#expected).lines,expected);unchanged(e,source)
  one({'SEL'},0,'v2l<C-g>',{'SEL'},'<C-CR>')
  one({'RU'},0,'V',{'RU'},' еу')
  one({'    ','','untouched'},0,'Vj',{'    ',''})
  if win then one({'WEZTERM'},0,'V',{'WEZTERM'},'<C-F19>')end
  same(before,find(e,1))
end)
check('last active of multiple terminals receives selection',function(e)
  local first,a=open_reader(e,1);local second,b=open_reader(e,2)
  e:lua([[require('toggleterm.terminal').get(2):close()]])
  local source=prepare(e,{'second session'});send(e,'V')
  T.eq(received(e,second,1).lines,{'second session'});T.eq(data(e,first).lines,{})
  unchanged(e,source);same(a,find(e,1));same(b,find(e,2));T.eq(#terms(e),2)
  e:lua([[local t=require('toggleterm.terminal').get(1);t:open();t:focus()]])
  source=prepare(e,{'first session'});send(e,'V')
  T.eq(received(e,first,1).lines,{'first session'});T.eq(data(e,second).lines,{'second session'})
  same(a,find(e,1));same(b,find(e,2));unchanged(e,source)
end)
check('private hidden task is excluded from selection target',function(e)
  local first,a=open_reader(e,1);local private,b=open_reader(e,9,'horizontal',true)
  e:lua([[require('toggleterm.terminal').get(9,true):close()]])
  local source=prepare(e,{'public console'});send(e,'V')
  T.eq(received(e,first,1).lines,{'public console'});T.eq(data(e,private).lines,{})
  same(a,find(e,1));same(b,find(e,9));T.eq(#terms(e),2);unchanged(e,source)
end)
check('floating terminal retains native reveal and focus',function(e)
  local path,before=open_reader(e,1,'float')
  e:lua([[require('toggleterm.terminal').get(1):close()]])
  local source=prepare(e,{'floating output'});send(e,'V')
  T.eq(received(e,path,1).lines,{'floating output'});same(before,find(e,1));unchanged(e,source)
  e:wait('native float focused',function()return e:current_ft()=='toggleterm' and e:lua([[return vim.api.nvim_win_get_config(0).relative=='editor']])end)
end)
check('finished console is revealed without replacing job or history',function(e)
  local path,before=open_reader(e,1)
  local source=prepare(e,{'__FORGE_SELECTION_EXIT__'});send(e,'V')
  e:wait('reader exited',function()return e:lua([[return vim.fn.jobwait({_G.forge_selection_test_terms[1].job_id},0)[1]~=-1]])end,10000)
  e:lua([[_G.forge_selection_test_terms[1]:close()]])
  source=prepare(e,{'MUST_NOT_EXECUTE'});send(e,'V')
  e:wait('actionable finished warning',function()return e:lua([[for _,entry in ipairs(require('forge.log_store').entries())do
    if entry.message:find('Активная консоль завершена',1,true)then return true end end;return false]])end)
  local after=e:lua([[local t=_G.forge_selection_test_terms[1];return {job=t.job_id,buf=t.bufnr,open=vim.fn.bufwinid(t.bufnr)>0}]])
  T.eq(after.job,before.job);T.eq(after.buf,before.buf);assert(after.open)
  T.eq(e:lua([[local count=0;for _,t in ipairs(require('toggleterm.terminal').get_all())do
    if t.job_id and vim.fn.jobwait({t.job_id},0)[1]==-1 then count=count+1 end end;return count]]),0,'Finished job silently replaced')
  T.eq(data(e,path).lines,{});unchanged(e,source)
end)
T.finish()
