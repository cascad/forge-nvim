-- spec: IDE-BOOT-5. Реальная DLL/SO и C scoring; только private artifact меняется.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local deps=vim.env.FORGE_E2E_DEPS or root..'/.tests/editor-deps'
local manifest=vim.json.decode(table.concat(vim.fn.readfile(deps..'/manifest.json'),'\n'))
local artifact=assert(manifest.native and manifest.native.fzf,'Явно выполни python[3] -B tests/e2e/prepare_fzf.py')
local library=vim.fn.has('win32')==1 and 'libfzf.dll' or 'libfzf.so'
assert(vim.fn.filereadable(deps..'/'..artifact.library)==1,'Повтори prepare_fzf.py')
local function text(e)
  return e:lua([[return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n')]])
end
local function observe(e)
  return e:lua([[return {status=vim.g.forge_telescope_fzf,cmake=vim.fn.executable('cmake'),
    fzf_loaded=type(package.loaded.fzf_lib)=='table',calls=_G.forge_fzf_calls or 0,scores=_G.forge_fzf_scores or {},
    installs=vim.g.forge_e2e_installs,notifications=vim.g.forge_e2e_notifications,
    messages=vim.fn.execute('messages'),spawns=_G.forge_e2e_spawns,mode=vim.api.nvim_get_mode()}]])
end
local function prompt(e,keys)
  e:input(keys)
  e:wait('Telescope insert prompt',function()
    return e:current_ft()=='TelescopePrompt' and e:lua('return vim.api.nvim_get_mode().mode')=='i'
  end)
end
local function selected(e,file)
  return e:lua([[local item=require('telescope.actions.state').get_selected_entry()
    if not item then return false end
    return tostring(item.filename or item.value):gsub('\\','/'):sub(-#(...))==(...) ]],{file})
end
local function health(e,expected)
  local function loaded()
    return e:lua([[return {status=vim.g.forge_telescope_fzf,telescope_loaded=package.loaded.telescope~=nil,
      reason=require('lazy.core.config').plugins['telescope.nvim']._.loaded} ]])
  end
  local before=loaded()
  e:input(':checkhealth forge<CR>')
  e:wait('health buffer',function() return e:current_ft()=='checkhealth' end,15000)
  vim.fn.writefile({vim.json.encode({before=before,after=loaded()})},e.dir..'/health-load-state.json')
  e:wait('health search status',function() return e:current_ft()=='checkhealth' and text(e):find(expected,1,true)~=nil end,15000)
  e:snapshot('health-'..expected)
end
local function check(name,variant,cmake,fn)
  if vim.env.FORGE_SEARCH_CASE and not name:find(vim.env.FORGE_SEARCH_CASE,1,true) then return end
  T.check('IDE-BOOT-5 '..name,function()
    local e
    local ok,err=pcall(function()
      local path={}
      for _,exe in ipairs({'git','rg'}) do
        local file=vim.fn.exepath(exe);assert(file~='',exe..' отсутствует')
        path[#path+1]=vim.fn.fnamemodify(file,':h')
      end
      if cmake then
        local file=vim.fn.exepath('cmake');assert(file~='','явно подготовь CMake для matrix case')
        path[#path+1]=vim.fn.fnamemodify(file,':h')
      end
      if vim.fn.has('win32')==1 then
        path[#path+1]=vim.env.SystemRoot..'/System32';path[#path+1]=vim.env.SystemRoot
      else
        -- Native case получает только git/rg: /usr/bin содержит CMake/cc.
        path={}
      end
      e=require('editor').start(root,{timeout=180000,env={PATH=table.concat(path,vim.fn.has('win32')==1 and ';' or ':')},
        prepare=function(project,env,runtime)
          if vim.fn.has('win32')==0 then
            local bin=runtime..'/bin';vim.fn.mkdir(bin,'p')
            for _,exe in ipairs(cmake and {'git','rg','cmake','sh'} or {'git','rg','sh'}) do
              local source=vim.fn.exepath(exe);assert(source~='')
              assert(vim.uv.fs_symlink(source,bin..'/'..exe))
            end
            env.PATH=bin
          end
          local data=runtime..'/data/nvim_forge'..(vim.fn.has('win32')==1 and '-data' or '')
          local lib=data..'/lazy/telescope-fzf-native.nvim/build/'..library
          assert(vim.fn.filereadable(lib)==1)
          if variant=='missing' then assert(vim.uv.fs_unlink(lib))
          elseif variant=='corrupt' then vim.fn.writefile({'not a shared library'},lib) end
          vim.fn.writefile({'first line','FORGE_FZF_CONTENT'},project..'/alpha_native.txt')
          vim.fn.writefile({'excluded markdown'},project..'/alpha_native.md')
          vim.fn.writefile({'other'},project..'/beta_native.txt')
        end})
      vim.fn.writefile(vim.fn.readfile(root..'/tests/e2e/search-sorter.test.lua'),e.dir..'/search-sorter.test.lua')
      T.eq(e:lua([[return vim.fn.executable('cmake')]]),cmake and 1 or 0)
      fn(e)
      local observed=observe(e)
      assert(not observed.mode.blocking and observed.installs==0)
      assert(not observed.messages:match('E%d+:'),observed.messages)
      for _,n in ipairs(observed.notifications) do assert(n.level<vim.log.levels.ERROR,n.message) end
      for _,p in ipairs(observed.spawns) do
        local exe=p.cmd:gsub('\\','/'):lower():match('([^/]+)$'):gsub('%.exe$','')
        assert(not vim.tbl_contains({'cmake','cl','gcc','clang','make','ninja','curl','wget'},exe),vim.inspect(p))
      end
      T.eq(vim.fn.readfile(e.project..'/alpha_native.txt'),{'first line','FORGE_FZF_CONTENT'})
    end)
    if e then
      pcall(function() local state=observe(e);state.artifact=artifact
        vim.fn.writefile({vim.json.encode(state)},e.dir..'/search-state.json') end)
      e:snapshot(name);io.stdout:write('  artifacts: '..e.dir..'\n');e:stop(not ok and tostring(err) or nil)
      if ok then
        T.eq(e.rpc.shutdown_result.exit_code,0,'редактор не завершился штатно; см. shutdown.json')
        T.eq(e.rpc.shutdown_result.exit_signal,0,'cleanup потребовал сигнал; см. shutdown.json')
        T.eq(#e.rpc.shutdown_result.api_errors,0,'получена ошибка API notification; см. shutdown.json')
      end
    end
    assert(ok,err)
  end)
end
local function search(e,native)
  prompt(e,'<C-p>')
  T.eq(e:lua([[return type(package.loaded.fzf_lib)=='table']]),native,'реальная native library не соответствует ожиданию')
  if native then
    e:lua([[_G.forge_fzf_calls=0;_G.forge_fzf_scores={};local f=package.loaded.fzf_lib;local score=f.get_score
      f.get_score=function(...) local value=score(...);_G.forge_fzf_calls=_G.forge_fzf_calls+1
        if #_G.forge_fzf_scores<12 then table.insert(_G.forge_fzf_scores,{text=(...),score=value}) end;return value end]])
  end
  local source=e:lua([[local p=require('telescope.actions.state').get_current_picker(vim.api.nvim_get_current_buf())
    return debug.getinfo(p.sorter.scoring_function,'S').source]])
  assert((source:find('/_extensions/fzf.lua',1,true)~=nil)==native,source)
  e:input(native and 'alpha_native !.md$' or 'alpha_native.txt')
  e:wait('выбран реальный файл',function() return selected(e,'alpha_native.txt') end)
  if native then assert(observe(e).calls>0,'native C scoring не выполнялся') end
  e:snapshot('file-results');e:input('<CR>')
  e:wait('Enter открыл файл',function() return e:current_file():sub(-16)=='alpha_native.txt' end)
  prompt(e,' fg');e:input('FORGE_FZF_CONTENT')
  e:wait('настоящий rg вернул content',function() return selected(e,'alpha_native.txt') end,10000)
  e:snapshot('content-results');e:input('<CR>')
  e:wait('Enter открыл точную строку',function()
    return e:current_file():sub(-16)=='alpha_native.txt' and e:lua('return vim.api.nvim_win_get_cursor(0)[1]')==2
  end)
  health(e,native and 'native fzf' or 'Lua fallback')
  T.eq(observe(e).status.available,native)
  if not native then assert(#observe(e).status.error>0) end
end
check('native без CMake выполняет C scoring и file/content переходы','ready',false,function(e) search(e,true) end)
check('missing с CMake сохраняет Lua поиск и причину','missing',true,function(e) search(e,false) end)
check('corrupt с CMake сохраняет Lua поиск и причину','corrupt',true,function(e) search(e,false) end)
check('missing без CMake: passive health до picker и рабочий fallback','missing',false,function(e)
  local before=observe(e).status
  health(e,before and 'Lua fallback' or 'Telescope not loaded')
  T.eq(observe(e).status,before,'health не должен менять выбранный режим')
  e:input(':bdelete<CR>');search(e,false)
end)
if not vim.env.FORGE_SEARCH_CASE then
  T.check('IDE-BOOT-5 health без init честно показывает незагруженный Telescope',function()
    local dir=root..'/.tests/editor-e2e/'..tostring(vim.uv.hrtime());vim.fn.mkdir(dir,'p')
    local scope=require('process_scope').new()
    local env=vim.fn.environ()
    for _,key in ipairs({'HOME','USERPROFILE','LOCALAPPDATA','APPDATA','TEMP','TMP','TMPDIR',
      'XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_STATE_HOME','XDG_CACHE_HOME'}) do
      env[key]=dir..'/runtime/'..key;vim.fn.mkdir(env[key],'p')
    end
    env.NVIM_LOG_FILE=dir..'/native-health.log'
    local script=dir..'/health-probe.lua'
    vim.fn.writefile({
      'vim.opt.rtp:append('..vim.inspect(root..'/nvim_forge')..')',
      'vim.cmd("checkhealth forge")',
      'vim.fn.writefile(vim.api.nvim_buf_get_lines(0,0,-1,false),'..vim.inspect(dir..'/health.txt')..')',
      'vim.fn.writefile({vim.json.encode({loaded=package.loaded.telescope~=nil,status=vim.g.forge_telescope_fzf})},'..vim.inspect(dir..'/health-state.json')..')',
      'vim.cmd("qa!")',
    },script)
    local result
    local ok,err=pcall(function()
      local command=scope:command({vim.v.progpath,'--headless','-u','NONE','-i','NONE','-l',script},{artifacts=dir})
      local process=vim.system(command,vim.tbl_extend('force',scope.spawn_options,
        {cwd=root,env=env,clear_env=true,text=true,timeout=15000}))
      scope:attach(process.pid);result=process:wait()
    end)
    local cleanup=scope:close()
    vim.fn.writefile({vim.json.encode({ok=ok,exit_code=result and result.code,scope=cleanup,error=err})},dir..'/health-process.json')
    io.stdout:write('  health artifacts: '..dir..'\n')
    assert(ok,err);T.eq(result.code,0,result.stderr)
    assert(cleanup.ok and (cleanup.active_after==0 or cleanup.active_after==false))
    local observed=vim.json.decode(table.concat(vim.fn.readfile(dir..'/health-state.json'),'\n'))
    T.eq(observed.loaded,false);T.eq(observed.status,nil)
    assert(table.concat(vim.fn.readfile(dir..'/health.txt'),'\n'):find('Telescope not loaded',1,true))
    assert(vim.uv.fs_copyfile(root..'/nvim_forge/lua/forge/health.lua',dir..'/health.lua'))
  end)
end
T.finish()
