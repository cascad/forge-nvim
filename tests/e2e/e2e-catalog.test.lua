-- Настоящий CLI проверяет контракт; fixture requirements не означают IDE feature PASS.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local driver=vim.env.FORGE_TRACE_SOURCE or root
local function write(path,text)
  vim.fn.mkdir(vim.fs.dirname(path),'p')
  local f=assert(io.open(path,'wb'));f:write(text);f:close()
end
local function read(path)
  local f=assert(io.open(path,'rb'));local out=f:read('*a');f:close();return out
end
local id='IDE-BOOT-1'
local flow='tests/e2e/flow.test.lua'
local function req(identifier,proof)
  return '### Requirement: '..identifier..' Fixture\nПоведение SHALL иметь проверяемый контракт.\n'
    ..(proof and 'Проверка: '..proof..'\n' or '')
end
local cases={
  {name='completed change без E2E отклонён',kind='missing',complete=true,code=1},
  {name='unit не заменяет E2E завершённой фичи',kind='unit',complete=true,code=1},
  {name='declared path активного change существует',kind='missing_file',code=1,path_error=true},
  {name='selected unfinished change требует E2E',kind='missing',change='demo',code=1},
  {name='MODIFIED сохраняет собственную E2E связь',kind='modified',complete=true,code=1},
  {name='main IDE requirement требует E2E',kind='main',code=1},
  {name='unfinished coverage остаётся PENDING в JSON',kind='missing',code=0,catalog='PENDING'},
  {name='registered E2E принимается',kind='valid',complete=true,code=0},
  {name='native Python suite входит в общий inventory',kind='native',complete=true,code=0,catalog='REGISTERED'},
  {name='inline platform proof сохраняет E2E связь',kind='inline',complete=true,code=0,catalog='REGISTERED'},
  {name='archive не требует новых behavioral тестов',kind='archive',code=0},
  {name='non-IDE unit policy сохраняется',kind='other',code=0},
  {name='unknown selected change не даёт false PASS',kind='valid',change='not-a-change',code=1,unknown=true},
  {name='общий runner сохраняет structured каталог',kind='runner',code=0,catalog='REGISTERED',runner=true},
  {name='default runner сохраняет native Python каталог',kind='native',code=0,catalog='REGISTERED',runner=true},
}
for _,case in ipairs(cases) do
  T.check('SELF: E2E-CATALOG '..case.name,function()
    local dir=root..'/.tests/e2e-catalog/'..tostring(vim.uv.hrtime())
    local tree=dir..'/tree';vim.fn.mkdir(tree,'p')
    local registry={}
    local proof
    if case.kind=='unit' or case.kind=='other' then
      proof='tests/unit/flow.test.lua';registry[#registry+1]={file=proof,suite='unit'}
      write(tree..'/'..proof,'return true\n')
    elseif case.kind=='native' then
      proof='tests/install-flow.test.py';write(tree..'/'..proof,'print("fixture suite")\n')
    elseif case.kind=='valid' or case.kind=='inline' or case.kind=='runner' or case.kind=='modified' or case.kind=='missing_file' then
      proof=flow;registry[#registry+1]={file=flow,suite='e2e'}
      if case.kind~='missing_file' then write(tree..'/'..flow,'return true\n') end
    end
    if case.kind=='main' or case.kind=='other' then
      write(tree..'/openspec/specs/fixture/spec.md',req(case.kind=='other' and 'WT-CLIP-1' or id,proof))
    elseif case.kind=='archive' then
      write(tree..'/openspec/changes/archive/2026-01-01-demo/specs/fixture/spec.md','## ADDED Requirements\n'..req(id))
    else
      if case.kind=='modified' then write(tree..'/openspec/specs/fixture/spec.md',req(id,flow)) end
      local change_proof=proof;if case.kind=='modified' then change_proof=nil end
      local definition=req(id,change_proof)
      if case.kind=='inline' then definition=definition:gsub('\nПроверка:','\nПлатформы: все. Проверка:') end
      write(tree..'/openspec/changes/demo/specs/fixture/spec.md',
        '## '..(case.kind=='modified' and 'MODIFIED' or 'ADDED')..' Requirements\n'..definition)
      write(tree..'/openspec/changes/demo/tasks.md','- ['..(case.complete and 'x' or ' ')..'] Реализация\n')
    end
    if case.runner then
      for name,kind in vim.fs.dir(driver..'/tests/lib') do
        if kind=='file' and name:match('%.lua$') and not name:match('%.test%.lua$') then
          write(tree..'/tests/lib/'..name,read(driver..'/tests/lib/'..name))
        end
      end
      write(tree..'/tests/run.lua',read(driver..'/tests/run.lua'))
      write(tree..'/tests/trace.test.lua',read(driver..'/tests/trace.test.lua'))
      registry[#registry+1]={file='tests/trace.test.lua',suite='trace'}
    end
    local rows={};for _,entry in ipairs(registry) do rows[#rows+1]=('{file=%q,suite=%q}'):format(entry.file,entry.suite) end
    write(tree..'/tests/registry.lua','return {'..table.concat(rows,',')..'}\n')
    local env=vim.fn.environ()
    env.FORGE_TEST_ID=nil;env.VIMINIT=nil;env.EXINIT=nil;env.GVIMINIT=nil
    env.FORGE_REPO=case.runner and tree or driver;env.NVIM_LOG_FILE=dir..'/nvim.log'
    local argv={vim.v.progpath,'--clean','-l',case.runner and tree..'/tests/run.lua' or driver..'/tests/trace.test.lua'}
    if case.runner then argv[#argv+1]='trace' else
      argv[#argv+1]=tree
      if case.change then argv[#argv+1]='--change';argv[#argv+1]=case.change end
      if case.catalog then argv[#argv+1]='--catalog-json';argv[#argv+1]=dir..'/catalog.json' end
    end
    local result=vim.system(argv,{cwd=case.runner and tree or root,env=env,clear_env=true,text=true,timeout=30000}):wait()
    write(dir..'/result.json',vim.json.encode({case=case.name,argv=argv,result=result,driver=driver}))
    write(dir..'/stdout.txt',result.stdout or '');write(dir..'/stderr.txt',result.stderr or '')
    write(dir..'/e2e-catalog.test.lua',read(root..'/tests/e2e/e2e-catalog.test.lua'))
    for _,path in ipairs({'tests/lib/spec_index.lua','tests/lib/trace.lua','tests/trace.test.lua','tests/run.lua'}) do
      write(dir..'/driver-source/'..path,read(driver..'/'..path))
    end
    io.stdout:write('  artifacts: '..dir..'\n')
    T.eq(result.signal,0);T.eq(result.code,case.code,'Native CLI verdict')
    local text=(result.stdout or '')..(result.stderr or '')
    assert(text:find(case.runner and 'Итог:' or 'passed',1,true),'Trace CLI не исполнил проверки')
    if case.code==1 then
      assert(text:find('TRACE:',1,true),text)
      assert(text:find(case.unknown and 'not-a-change' or id,1,true),text)
      assert(text:find(case.path_error and 'Проверка:' or 'E2E',1,true),text)
    end
    if case.catalog then
      local path=case.runner and tree..'/.tests/report.json' or dir..'/catalog.json'
      assert(vim.fn.filereadable(path)==1,'Нет structured E2E catalogue: '..path)
      local data=vim.json.decode(read(path));if case.runner then data=assert(data.e2e_catalog,'Report потерял E2E catalogue') end
      T.eq(#data.requirements,1);T.eq(data.requirements[1].id,id)
      T.eq(data.requirements[1].state,case.catalog)
      if case.kind=='native' then T.eq(data.requirements[1].runners[proof],'native-python') end
    end
  end)
end
T.finish()
