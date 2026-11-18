-- Actual installed adapters and project test dependencies; no adapter/config substitutes.
local base=assert(arg[1],'Expected owned observation directory')
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local project=base..'/project'
local win=vim.fn.has('win32')==1
local function write(path,lines) vim.fn.mkdir(vim.fs.dirname(path),'p');assert(vim.fn.writefile(lines,path)==0) end
local function json(path,data) write(path,{vim.json.encode(data)}) end
local function copy(from,to)
    vim.fn.mkdir(to,'p')
    for name,kind in vim.fs.dir(from) do
        if name~='.bin' then
            if kind=='directory' then copy(from..'/'..name,to..'/'..name)
            elseif kind=='file' then assert(vim.uv.fs_copyfile(from..'/'..name,to..'/'..name))
            else error('Unexpected dependency entry: '..from..'/'..name) end
        end
    end
end
local cases={
    {id='go',file='main.go',line=5,picker='Current Go package',test='main_test.go',marker='FRIDE_GO',
        source={'package main','import "fmt"','func main() {','answer := 42','fmt.Println("FRIDE_GO",answer)','}'},
        tests={'package main','import "testing"','func TestAnswer(t *testing.T) { t.Log("FRIDE_TEST_GO"); if 21*2!=42 {t.Fatal("answer")} }'}},
    {id='rust',file='src/main.rs',line=3,picker='Current Rust file bin',test='src/main.rs',marker='FRIDE_RUST',
        source={'fn main() {','let answer = 42;','let _twice = answer * 2;','println!("FRIDE_RUST {}",answer);','}',
            '#[test]','fn answer_test() { println!("FRIDE_TEST_RUST"); assert_eq!(21*2,42); }'}},
    {id='python',file='app.py',line=2,picker='Current Python file',test='test_answer.py',marker='FRIDE_PYTHON',
        source={'answer = 42','print("FRIDE_PYTHON",answer)'},
        tests={'def test_answer():','    print("FRIDE_TEST_PYTHON")','    assert 21 * 2 == 42'}},
    {id='node',file='app.js',line=2,picker='Current Node file',test='answer.test.js',marker='FRIDE_NODE',
        source={'const answer = 42;','console.log("FRIDE_NODE",answer);'},
        tests={'test("answer", () => { console.log("FRIDE_TEST_NODE"); expect(21*2).toBe(42); });'}},
}
local info={cases={}}
for _,case in ipairs(cases) do
    if not vim.env.FORGE_INSTALLED_LANGUAGE_CASE or case.id==vim.env.FORGE_INSTALLED_LANGUAGE_CASE then
        local dir=project..'/'..case.id
        write(dir..'/'..case.file,case.source)
        if case.tests then write(dir..'/'..case.test,case.tests) end
        if case.id=='go' then write(dir..'/go.mod',{'module fride.local/workflow','go 1.26.0'}) end
        if case.id=='rust' then write(dir..'/Cargo.toml',{'[package]','name="fride_workflow"','version="0.1.0"','edition="2021"'}) end
        if case.id=='python' then
            write(dir..'/pyproject.toml',{'[tool.pytest.ini_options]','testpaths = ["."]','addopts = "-s"'})
            local host=require('forge.python').resolve({dir})
            local deps=vim.env.FORGE_E2E_PYTHON_DEPS or root..'/.tests/python-deps'
            local python=dir..'/.venv'..(win and '/Scripts/python.exe' or '/bin/python')
            for _,cmd in ipairs({{host,'-m','venv',dir..'/.venv'},
                {python,'-m','pip','install','--no-index','--find-links',deps..'/wheels','pytest'}}) do
                local r=vim.system(cmd,{text=true}):wait(60000);assert(r.code==0,r.stderr)
            end
            json(dir..'/.fride/tools.json',{tools={python=python}})
        end
        if case.id=='node' then
            local deps=vim.env.FORGE_E2E_NODE_DEPS or root..'/.tests/node-deps'
            copy(deps..'/tools/node_modules',dir..'/node_modules')
            local metadata=vim.json.decode(table.concat(vim.fn.readfile(deps..'/manifest.json'),'\n'))
            json(dir..'/package.json',{private=true,devDependencies={jest=metadata.packages.jest},
                jest={testEnvironment='node',cache=false,maxWorkers=1}})
        end
        local initialized=vim.system({'git','init','-q',dir},{text=true}):wait(5000)
        assert(initialized.code==0,initialized.stderr)
        local artifacts=base..'/observed/'..case.id;vim.fn.mkdir(artifacts,'p')
        local result={id=case.id};local rpc;local started=vim.uv.hrtime()
        local function phase(name)
            result.phase=name;write(artifacts..'/phase.txt',{name})
            io.stdout:write(case.id..': '..name..'\n');io.stdout:flush()
        end
        local function lua(code,args) return rpc:request('nvim_exec_lua',{code,args or {}}) end
        local function wait_for(name,fn,timeout)
            local deadline,last=vim.uv.hrtime()+(timeout or 30000)*1000000
            repeat
                local ok,value=pcall(fn)
                if ok and value and value~=vim.NIL then return value end
                if not ok then last=tostring(value) end
                vim.wait(30)
            until vim.uv.hrtime()>=deadline
            error(name..(last and ': '..last or ''))
        end
        result.ok,result.error=xpcall(function()
            phase('startup')
            rpc=require('editor_rpc').start({vim.v.progpath,'--headless','--embed','-i','NONE',
                '--cmd','lua vim.opt.rtp:prepend(vim.env.FRIDE_CONFIG)','-u',vim.env.FRIDE_CONFIG..'/init.lua'},
                {cwd=dir,env=vim.fn.environ(),clear_env=true,artifacts=artifacts,timeout=160000})
            rpc:request('nvim_ui_attach',{120,40,{rgb=true,ext_linegrid=true}})
            wait_for('startup',function() return lua('return vim.v.vim_did_enter==1') end,5000)
            lua([[vim.cmd.edit(vim.fn.fnameescape(...))]],{dir..'/'..case.file})
            if case.id=='rust' then
                result.prerequisite=lua([[local r=vim.system({'cargo','nextest','--version'},{text=true}):wait(10000)
                    return {code=r.code,signal=r.signal,stdout=r.stdout,stderr=r.stderr} ]])
                assert(result.prerequisite.code==0 and result.prerequisite.signal==0,
                    'Rust Tests prerequisite cargo-nextest: '..result.prerequisite.stderr)
            end
            lua([[local line=...;vim.api.nvim_win_set_cursor(0,{line,0});require('dap').toggle_breakpoint()]],{case.line})
            rpc:request('nvim_input',{'<F5>'})
            if case.id~='node' then -- Node has a single native default and starts directly.
                wait_for('native default config picker',function() return lua([[return vim.bo.filetype=='TelescopePrompt']]) end)
                rpc:request('nvim_input',{case.picker})
                wait_for('default config choice',function() return lua([[local e=require('telescope.actions.state').get_selected_entry();
                    return e and e.ordinal:find(...,1,true) and not e.ordinal:find('(args)',1,true)]],{case.picker}) end)
                rpc:request('nvim_input',{'<CR>'})
            end
            phase('debug breakpoint')
            result.session=wait_for('real breakpoint',function() return lua([[local s=require('dap').session();
                if s and s.stopped_thread_id and s.current_frame then return {type=tostring(s.config.type),program=tostring(s.config.program),
                    frame={id=s.current_frame.id,name=tostring(s.current_frame.name),line=s.current_frame.line},
                    adapter={type=tostring(s.adapter.type),command=tostring(s.adapter.command),port=tostring(s.adapter.port)}} end]],{}) end,60000)
            lua([[local s=require('dap').session();s:request('evaluate',{expression='answer',context='watch',frameId=s.current_frame.id},
                function(err,body) _G.fride_evaluation={error=err,result=body} end)]])
            result.evaluation=wait_for('evaluate answer',function() return lua('return _G.fride_evaluation') end)
            assert(not result.evaluation.error and tostring(result.evaluation.result.result):find('42',1,true),vim.inspect(result.evaluation))
            lua([[require('dap').continue()]])
            phase('program completion/output')
            wait_for('native session completion',function() return lua([[return require('dap').session()==nil]]) end)
            result.output=wait_for('program output',function() return lua([[local marker=...;for _,b in ipairs(vim.api.nvim_list_bufs()) do
                if vim.api.nvim_buf_is_loaded(b) and (vim.bo[b].buftype=='terminal' or vim.bo[b].filetype=='dap-repl' or vim.bo[b].filetype=='dapui_console') then
                    local lines=vim.api.nvim_buf_get_lines(b,0,-1,false);if table.concat(lines,''):find(marker,1,true) then return table.concat(lines,'\n') end end end]],{case.marker}) end)
            lua([[require('ide').focus_main();vim.cmd.edit(vim.fn.fnameescape(...));require('neotest').summary.open()]],{dir..'/'..case.test})
            phase('test discovery')
            wait_for('test discovery',function() return lua([[local n=require('neotest');for _,id in ipairs(n.state.adapter_ids()) do
                local s=n.state.status_counts(id);if s and (s.total or 0)>0 then return true end end]]) end)
            lua([[local file=...;require('neotest').run.run(file);require('ide').triggers.fire('test:run')]],{dir..'/'..case.test})
            phase('test result/output')
            result.tests=wait_for('native test result',function() return lua([[local n=require('neotest');for _,id in ipairs(n.state.adapter_ids()) do
                local s=n.state.status_counts(id);if s and s.passed+s.failed+s.skipped>0 and s.running==0 then return {adapter=id,counts=s} end end]]) end,60000)
            assert(result.tests.counts.failed==0 and result.tests.counts.passed>0,vim.inspect(result.tests))
            lua([[require('neotest').output_panel.open()]])
            result.test_output=wait_for('test output',function() return lua([[local marker=...;for _,b in ipairs(vim.api.nvim_list_bufs()) do
                if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].filetype=='neotest-output-panel' then
                    local lines=vim.api.nvim_buf_get_lines(b,0,-1,false);if table.concat(lines,''):find(marker,1,true) then return table.concat(lines,'\n') end end end]],{'FRIDE_TEST_'..case.id:upper()}) end)
            assert(#rpc.api_errors==0,vim.inspect(rpc.api_errors))
        end,debug.traceback)
        if rpc then
            local got,state=pcall(lua,[[return {messages=vim.api.nvim_exec2('messages',{output=true}).output,
                mode=vim.api.nvim_get_mode(),lsp=vim.lsp.log.get_filename(),cache=vim.fn.stdpath('cache'),log=vim.fn.stdpath('log')} ]])
            if got then
                result.state=state
                for _,pair in ipairs({{state.lsp,'lsp.log'},{state.cache..'/dap.log','dap.log'},{state.log..'/neotest.log','neotest.log'}}) do
                    if vim.fn.filereadable(pair[1])==1 then vim.uv.fs_copyfile(pair[1],artifacts..'/'..pair[2]) end
                end
            end
            write(artifacts..'/screen.txt',rpc:screen_lines())
            local stopped,cleanup=pcall(require('editor_process').stop,rpc,artifacts,result.error)
            result.cleanup=cleanup
            if not stopped or not cleanup.ok or cleanup.exit_code~=0 then result.ok=false;result.cleanup_error=tostring(cleanup) end
        end
        result.seconds=(vim.uv.hrtime()-started)/1e9;info.cases[#info.cases+1]=result
        json(base..'/observed/report.json',info)
        io.stdout:write(case.id..': '..(result.ok and 'PASS' or 'FAIL')..'\n'..(not result.ok and tostring(result.error)..'\n' or ''));io.stdout:flush()
    end
end
for _,case in ipairs(info.cases) do if not case.ok then vim.cmd('cquit 1') end end
print('Installed runtime workflows PASS')
