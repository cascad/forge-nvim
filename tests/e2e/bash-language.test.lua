-- spec: IDE-SH-1 IDE-SH-2 IDE-SH-3 IDE-SH-4. Настоящие Bash tools и UI.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local function content(e) return e:lua([[return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n')]]) end
local function text(e,ft)
  return e:lua([[local ft=...;local out={};for _,b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].filetype==ft then vim.list_extend(out,vim.api.nvim_buf_get_lines(b,0,-1,false)) end end;return table.concat(out,'\n')]],{ft})
end
local function open(e,path)
  e:input(':edit '..vim.fn.fnameescape(e.bash_project..'/'..path)..'<CR>')
  e:wait('Bash файл '..path,function() return e:current_file():sub(-#path)==path end)
end
local function seek(e,word)
  e:input('gg/\\<lt>'..word..'\\><CR>')
  e:wait('курсор '..word,function() return e:lua([[return vim.fn.expand('<cword>')]])==word end)
end
local function language(e,path)
  open(e,path)
  e:wait('bashls готов',function() return e:lua([[for _,c in ipairs(vim.lsp.get_clients({bufnr=0,name='bashls'})) do
    if c.initialized and vim.fn.maparg('gd','n',false,true).buffer==1 and _G.forge_bash_diagnostics[vim.uri_from_bufnr(0)] then return true end end;return false]]) end,30000)
end
local function state(e)
  return e:lua([[local n=package.loaded.neotest;local positions,statuses={},{};
    if n then for _,id in ipairs(n.state.adapter_ids()) do local t=n.state.positions(id);if t then positions[id]=t:to_list() end;statuses[id]=n.state.status_counts(id) end end;
    return {mode=vim.api.nvim_get_mode(),messages=vim.fn.execute('messages'),notifications=vim.g.forge_e2e_notifications,
      installs=vim.g.forge_e2e_installs,spawns=_G.forge_e2e_spawns,diagnostics=vim.diagnostic.get(0),positions=positions,statuses=statuses,
      clients=vim.tbl_map(function(c) return {name=c.name,root=c.root_dir} end,vim.lsp.get_clients())} ]])
end
local function check(name,fn,missing)
  if vim.env.FORGE_BASH_CASE and not name:find(vim.env.FORGE_BASH_CASE,1,true) then return end
  T.check(name,function()
    local e
    local ok,err=pcall(function()
      require('bash_project').start(root,function(child) e=child end,missing)
      for _,source in ipairs({'tests/e2e/bash-language.test.lua','tests/lib/bash_project.lua'}) do
        assert(vim.uv.fs_copyfile(root..'/'..source,e.dir..'/'..vim.fs.basename(source)))
      end
      fn(e)
      T.eq(vim.fn.filereadable(e.bash_project..'/startup-ran.txt'),0,'BASH_ENV/ENV не исполнялись редактором')
      local s=state(e);T.eq(s.installs,0);assert(not s.mode.blocking,'неожиданный prompt')
      assert(not s.messages:match('E%d%d%d+:'),s.messages)
      for _,n in ipairs(s.notifications) do assert(n.level<vim.log.levels.ERROR or (e.expected_errors or {})[n.message],n.message) end
    end)
    if e then
      local got,s=pcall(state,e);if got then vim.fn.writefile({vim.json.encode(s)},e.dir..'/bash-state.json') end
      for _,path in ipairs({e.log_lsp,e.log_state..'/neotest.log'}) do
        if vim.fn.filereadable(path)==1 then assert(vim.uv.fs_copyfile(path,e.dir..'/'..vim.fs.basename(path))) end
      end
      e:snapshot(name);io.stdout:write('  artifacts: '..e.dir..'\n');e:stop(not ok and tostring(err) or nil)
    end
    assert(ok,err)
  end)
end
check('IDE-SH-1 IDE-058 definition references rename sourced library',function(e)
  language(e,'use.sh');seek(e,'calculate_answer');e:input('gd')
  e:wait('definition в library',function() return e:current_file():sub(-11)=='lib/math.sh' end,20000)
  language(e,'use.sh');seek(e,'calculate_answer');e:input('gr')
  e:wait('references quickfix',function() return e:current_ft()=='qf' end,20000)
  local refs=e:lua([[local rows={};for _,r in ipairs(vim.fn.getqflist()) do if vim.api.nvim_buf_get_name(r.bufnr):find('use.sh',1,true) then rows[tostring(r.lnum)]=true end end;return rows]])
  assert(refs['6'] and refs['10'],vim.inspect(refs));e:input('<CR>')
  language(e,'use.sh');seek(e,'calculate_answer');e:input('<F2>')
  e:wait('rename prompt',function() return e.rpc:request('nvim_get_mode',{}).mode=='c' end)
  e:input('<C-u>twice_forge<CR>')
  e:wait('rename usages',function() return content(e):find('twice_forge 21',1,true)~=nil end,20000)
  e:input(':wall<CR>')
  e:wait('rename сохранён в двух files',function()
    local a=table.concat(vim.fn.readfile(e.bash_project..'/lib/math.sh'),'\n')
    local b=table.concat(vim.fn.readfile(e.bash_project..'/use.sh'),'\n')
    return a:find('twice_forge()',1,true) and b:find('twice_forge 21',1,true) and b:find('twice_forge 2',1,true)
  end,20000)
end)
check('IDE-SH-1 completion diagnostics correction',function(e)
  language(e,'complete.sh');e:input('4G0f0ciw')
  e:wait('insert ready',function() return e.rpc:request('nvim_get_mode',{}).mode=='i' end)
  e:input('$FORG<C-Space>')
  e:wait('LSP cmp FORGE_ANSWER',function() return e:lua([[local c=require('cmp');if not c.visible() then return false end;for _,v in ipairs(c.get_entries()) do
    if v.source.name=='nvim_lsp' and v.completion_item.label:find('FORGE_ANSWER',1,true) then return true end end;return false]]) end,30000)
  for _=1,30 do
    if e:lua([[local v=require('cmp').get_selected_entry();return v and v.source.name=='nvim_lsp' and v.completion_item.label:find('FORGE_ANSWER',1,true)~=nil or false]]) then break end
    e:input('<C-n>');vim.wait(60)
  end
  e:input('<CR>');e:wait('completion вставлен',function() return content(e):find('$FORGE_ANSWER',1,true)~=nil end);e:input('<Esc>')
  e:input('4Gccprintf "%s\\n" $missing_forge_name<Esc>:write<CR>')
  e:wait('ShellCheck diagnostic',function() return e:lua([[for _,d in ipairs(vim.diagnostic.get(0)) do if d.message:find('missing_forge_name',1,true) then return true end end;return false]]) end,30000)
  e:input('gl');e:wait('diagnostic UI',function() return e:lua([[for _,w in ipairs(vim.api.nvim_list_wins()) do if vim.api.nvim_win_get_config(w).relative~='' and
    table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w),0,-1,false),'\n'):find('missing_forge_name',1,true) then return true end end;return false]]) end)
  e:input('<Esc>4Gccprintf "%s\\n" "$FORGE_ANSWER"<Esc>:write<CR>')
  e:wait('diagnostic убрана',function() return e:lua([[for _,d in ipairs(vim.diagnostic.get(0)) do if d.message:find('missing_forge_name',1,true) then return false end end;return true]]) end,30000)
end)
check('IDE-SH-2 shfmt manual и save editorconfig',function(e)
  open(e,'format.sh');e:input(' lf')
  local expected='#!/usr/bin/env bash\nif true; then\n  echo "format"\nfi'
  e:wait('shfmt manual',function() return content(e)==expected end,15000)
  e:input('ggVGc#!/usr/bin/env bash<CR>if true;then<CR>echo "format"<CR>fi<Esc>:write<CR>')
  e:wait('shfmt сохранён без второго write',function() return table.concat(vim.fn.readfile(e.bash_project..'/format.sh'),'\n')==expected end,15000)
end)
check('IDE-SH-3 native run args cwd output status',function(e)
  e.expected_errors={['FAILURE Bash: run.sh']=true}
  open(e,'run.sh');e:input(':BashRunFile hello\\ world_ü 7<CR>')
  e:wait('failed task',function() return e:lua([[local t=require('overseer').list_tasks();return #t==1 and t[1].status=='FAILURE']]) end,20000)
  e:input(' wb');e:wait('Tasks',function() return e:current_ft()=='OverseerList' end)
  e:input('gg/Bash:<CR><C-s>')
  e:wait('stdout stderr',function() return e:lua([[return vim.bo.buftype=='terminal' and table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n'):find('BASH_RUN hello world_ü',1,true)~=nil]]) end)
  assert(content(e):find('BASH_STDERR',1,true));assert(content(e):find('exited 7',1,true),content(e))
  local actual=table.concat(vim.fn.readfile(e.bash_project..'/run-cwd.txt'),'\n')
  if vim.fn.has('win32')==1 then
    local cygpath=vim.fs.dirname(vim.fs.dirname(e.bash_manifest.bash))..'/usr/bin/cygpath.exe'
    local native=vim.system({cygpath,'-w',actual},{text=true}):wait();assert(native.code==0,native.stderr)
    actual=vim.trim(native.stdout)
  end
  T.eq(vim.uv.fs_realpath(actual),vim.uv.fs_realpath(e.bash_project))
  e:input('<Esc><Esc><F7> jb')
  e:wait('successful task',function() return e:lua([[local t=require('overseer').list_tasks();return #t==2 and (t[1].status=='SUCCESS' or t[2].status=='SUCCESS')]]) end,20000)
end)
local function counts(e)
  return e:lua([[local n=require('neotest');local out={total=0,passed=0,failed=0,running=0};for _,id in ipairs(n.state.adapter_ids()) do local s=n.state.status_counts(id);if s then for k in pairs(out) do out[k]=out[k]+(s[k] or 0) end end end;return out]])
end
local function discover(e,file)
  file=file or 'math.bats'
  open(e,'tests/'..file);e:input(' wt');e:wait('Tests panel',function() return e:current_ft()=='neotest-summary' end)
  e:wait('Bats tests обнаружены',function() return counts(e).total==4 end,30000)
  e:input('<F7>')
  e:wait('Bats code focus',function() return e:current_file():sub(-#file)==file end)
end
check('IDE-SH-4 nearest canonical и file pass fail output',function(e)
  discover(e);e:input('5G Tt')
  e:wait('nearest result',function() local s=counts(e);return s.passed+s.failed>0 and s.running==0 end,30000)
  T.eq(counts(e).passed,1);T.eq(counts(e).failed,0);T.eq(vim.fn.filereadable(e.bash_project..'/neighbor-ran.txt'),0)
  e:wait('Test Output pass',function() return text(e,'neotest-output-panel'):find('BASH_TEST_VALUE 42',1,true)~=nil end)
  e:input('<F7> Tf');e:wait('file results',function() local s=counts(e);return s.passed==1 and s.failed==1 and s.running==0 end,30000)
  T.eq(vim.fn.filereadable(e.bash_project..'/neighbor-ran.txt'),1)
  T.eq(e:lua([[return require('dap').session()==nil]]),true)
  assert(not e:lua([[return vim.fn.execute('messages')]]):find('No active session',1,true))
end)
check('IDE-SH-4 nearest function comment fail',function(e)
  discover(e);e:input('11G Tt')
  e:wait('neighbor result',function() local s=counts(e);return s.passed+s.failed>0 and s.running==0 end,30000)
  T.eq(counts(e).passed,0);T.eq(counts(e).failed,1);T.eq(vim.fn.filereadable(e.bash_project..'/neighbor-ran.txt'),1)
  e:wait('Test Output fail',function() return text(e,'neotest-output-panel'):find('not ok',1,true)~=nil end)
end)
check('IDE-SH-4 literal regex Unicode nearest и file',function(e)
  discover(e,'literal.bats');e:input('4G Tt')
  e:wait('literal nearest',function() local s=counts(e);return s.passed+s.failed>0 and s.running==0 end,30000)
  T.eq(counts(e).passed,1);T.eq(counts(e).failed,0)
  T.eq(vim.fn.filereadable(e.bash_project..'/literal-neighbor-ran.txt'),0)
  e:wait('literal output',function() return text(e,'neotest-output-panel'):find('BATS_LITERAL ü',1,true)~=nil end)
  e:input('<F7> Tf');e:wait('literal file',function() local s=counts(e);return s.passed==1 and s.failed==1 and s.running==0 end,30000)
  T.eq(vim.fn.filereadable(e.bash_project..'/literal-neighbor-ran.txt'),1)
end)
check('IDE-SH-1 IDE-SH-3 missing tools editable без WSL',function(e)
  open(e,'run.sh');e:input('gg0i# STILL_EDITABLE<CR><Esc>:write<CR>:BashRunFile<CR>')
  e:wait('missing Bash notice',function()
    if e.rpc:request('nvim_get_mode',{}).blocking then e:ack_warning('Bash');return false end
    return e:lua([[for _,n in ipairs(vim.g.forge_e2e_notifications) do if n.message:find('Bash не найден',1,true) then return true end end;return false]])
  end)
  T.eq(e:lua([[return #vim.lsp.get_clients({name='bashls'})]]),0)
  assert(vim.fn.readfile(e.bash_project..'/run.sh')[1]:find('STILL_EDITABLE',1,true))
  for _,spawn in ipairs(e:lua([[return _G.forge_e2e_spawns or {}]])) do
    local s=(spawn.cmd or ''):gsub('\\','/'):lower()
    assert(not s:find('system32/bash.exe',1,true) and not s:find('sysnative/bash.exe',1,true) and not s:find('wsl.exe',1,true),s)
  end
end,true)
T.finish()
