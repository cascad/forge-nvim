-- CLI E2E: separate Neovim, real executable lookups and actual Python sentinel.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local title='PYTHON-CASE ü contract'
local name='SELF: '..title
local cases={
  {key='foreign',filter='IDE-PANEL-15',kind='excluded'},
  {key='boundary',filter='SELF: PYTHON-CAS',kind='excluded'},
  {key='foreign-no-python',filter='IDE-PANEL-15',kind='excluded',empty_path=true},
  {key='unfiltered',filter='',kind='ok'},
  {key='prefix',filter='SELF:',kind='ok'},
  {key='failure',filter=name,kind='failure'},
  {key='missing-python',filter='SELF:',kind='missing',empty_path=true},
}
for _,case in ipairs(cases) do
  T.check('SELF: PYTHON-CASE '..case.key..' native filter and execution',function()
    local dir=root..'/.tests/python-case/'..tostring(vim.uv.hrtime());vim.fn.mkdir(dir,'p')
    local project=dir..'/Project ü with spaces';vim.fn.mkdir(project..'/tmp','p')
    local source=vim.env.FORGE_PYTHON_CASE_SOURCE or root..'/tests/lib'
    assert(vim.uv.fs_copyfile(root..'/tests/e2e/python-case.test.lua',dir..'/python-case.test.lua'))
    assert(vim.uv.fs_copyfile(root..'/tests/e2e/fixtures/python-case/driver.lua',dir..'/driver.lua'))
    assert(vim.uv.fs_copyfile(root..'/tests/e2e/fixtures/python-case/probe.py',project..'/Python fixture ü.py'))
    local class=(case.kind=='failure' and 'fail' or 'pass')..' ü suite'
    local env={FORGE_TEST_ID=case.filter,FORGE_PYTHON_CASE_PROBE=dir..'/python-ran.json',
      PYTHONIOENCODING='utf-8',PYTHONDONTWRITEBYTECODE='1',
      TEMP=project..'/tmp',TMP=project..'/tmp',TMPDIR=project..'/tmp',NVIM_LOG_FILE=dir..'/nvim.log'}
    if case.empty_path then env.PATH=project..'/tmp' end
    local argv={vim.v.progpath,'--headless','-u','NONE','-i','NONE','-l',dir..'/driver.lua',
      root,source,project,'Python fixture ü.py',class,title,dir}
    local result=vim.system(argv,{cwd=project,text=true,timeout=15000,env=env}):wait()
    assert(vim.fn.writefile({vim.json.encode({case=case,argv=argv,code=result.code,signal=result.signal,
      stdout=result.stdout,stderr=result.stderr})},dir..'/result.json')==0)
    io.stdout:write('  artifacts: '..dir..'\n')
    local function read(file) return vim.json.decode(table.concat(vim.fn.readfile(dir..'/'..file),'\n')) end
    local ready=read('driver-ready.json')
    T.eq(ready.source:gsub('\\','/'),source:gsub('\\','/')..'/python_case.lua')
    T.eq(ready.filter or '',case.filter)
    T.eq(ready.cwd:gsub('\\','/'),project)
    local lookups={};for _,line in ipairs(vim.fn.readfile(dir..'/lookups.jsonl')) do lookups[#lookups+1]=vim.json.decode(line).name end
    T.eq(result.signal,0)
    local ran=vim.fn.filereadable(dir..'/python-ran.json')==1
    if case.kind=='excluded' then
      T.eq(result.code,0);T.eq(result.stdout,'');T.eq(result.stderr,'')
      T.eq(lookups,{},'Filtered suite must not search for Python')
      T.eq(ran,false,'Filtered Python process executed')
    elseif case.kind=='missing' then
      T.eq(result.code,0);T.eq(result.stderr,'');T.eq(ran,false)
      T.eq(result.stdout,'  SKIP '..name..' -- нет Python 3\n')
      table.sort(lookups);T.eq(lookups,{'python','python3'})
    else
      assert(ran,'Selected Python fixture did not run; stdout='..tostring(result.stdout)..' stderr='..tostring(result.stderr))
      local marker=read('python-ran.json');T.eq(marker.argv,{class})
      T.eq(marker.cwd:gsub('\\','/'),project);T.eq(marker.major,3)
      assert(marker.pid>0 and marker.executable~='' and #lookups>=1 and #lookups<=2)
      if case.kind=='failure' then
        T.eq(result.code,1);T.eq(result.stdout,'  FAIL '..name..' -- код 7\n')
        T.eq(result.stderr,'PYTHON_CASE_STDOUT ü\nPYTHON_CASE_STDERR ü\n')
      else
        T.eq(result.code,0);T.eq(result.stdout,'  ok   '..name..'\n');T.eq(result.stderr,'')
      end
    end
  end)
end
T.finish()
