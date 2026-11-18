-- spec: IDE-BOOT-49 IDE-TEST-3. Native nextest/Neotest, root files and custom executable.
local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h'):gsub('\\','/')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local win=vim.fn.has('win32')==1
local sep,suffix=win and ';' or ':',win and '.exe' or ''
local function counts(e)
    return e:lua([[local n=require('neotest');local out={passed=0,failed=0,running=0,total=0};for _,id in ipairs(n.state.adapter_ids()) do
        local s=n.state.status_counts(id);if s then for k in pairs(out) do out[k]=out[k]+(s[k] or 0) end end end;return out]])
end
local function body(e)
    return e:lua([[local b=require('neotest').output_panel.buffer();return table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false),'')]])
end
local function check(name,mode,target)
    local filter=vim.env.FORGE_NEXTEST_CASE
    if filter and filter~='' and not name:find(filter,1,true) then return end
    T.check('IDE-BOOT-49 IDE-TEST-3 '..name,function()
        local e
        local ok,err=xpcall(function()
            e=require('rust_project').start(root,function(child) e=child end,function(child)
                local dir=child.rust_project..'/app/src'
                local function lines(kind,pass)
                    return {'#[test]','fn root_answer() { println!("ROOT_'..kind..'"); assert!('..tostring(pass)..'); }',
                        '#[cfg(test)] mod arbitrary { #[test] fn nested_answer() { assert!('..tostring(pass)..'); } }'}
                end
                local main={'fn main() {}'};vim.list_extend(main,lines('BIN',target=='main'))
                vim.fn.writefile(main,dir..'/main.rs');vim.fn.writefile(lines('LIB',target=='lib'),dir..'/lib.rs')
                local original=child.rust_deps..'/nextest/cargo-nextest'..suffix
                if mode=='explicit' or mode=='invalid' then
                    local path=child.runtime..'/selected tools/cargo-nextest'..suffix
                    vim.fn.mkdir(vim.fs.dirname(path),'p');assert(vim.uv.fs_copyfile(original,path))
                    if not win then assert(vim.uv.fs_chmod(path,493)) end
                    child.nextest_path=path
                    local config=child.rust_project..'/.fride';vim.fn.mkdir(config,'p')
                    vim.fn.writefile({vim.json.encode({tools={['cargo-nextest']=mode=='invalid' and path..'-missing' or path}})},config..'/tools.json')
                end
                if mode=='home' or mode=='missing' then
                    child:lua([[local sep,suffix=...;local kept={};for _,dir in ipairs(vim.split(vim.env.PATH,sep,{plain=true})) do
                        if vim.fn.filereadable(dir..'/cargo-nextest'..suffix)~=1 then kept[#kept+1]=dir end end;vim.env.PATH=table.concat(kept,sep)]],{sep,suffix})
                    if mode=='home' then
                        local path=child:lua([[return vim.env.CARGO_HOME..'/bin/cargo-nextest'..(...) ]],{suffix})
                        vim.fn.mkdir(vim.fs.dirname(path),'p');assert(vim.uv.fs_copyfile(original,path))
                        if not win then assert(vim.uv.fs_chmod(path,493)) end
                        child.nextest_path=path
                    end
                end
            end)
            local file=e.rust_project..'/app/src/'..(target=='main' and 'main.rs' or 'lib.rs')
            e:lua([[vim.cmd.edit(vim.fn.fnameescape(...));require('neotest').summary.open()]],{file})
            e:wait('native test discovery',function() return counts(e).total>=4 end,30000)
            assert(e:lua([[for _,s in ipairs(_G.forge_e2e_spawns) do if tostring(s.cmd):find('cargo-nextest',1,true)
                and s.args and s.args[1]=='--version' then return false end end;return true]]),'Startup/discovery must not probe nextest versions')
            e:lua([[local file=...;require('neotest').run.run(file);require('ide').triggers.fire('test:run')]],{file})
            if mode=='invalid' or mode=='missing' then
                e:wait('missing/invalid nextest warning',function() return e:lua([[for _,n in ipairs(vim.g.forge_e2e_notifications) do
                    if n.message:find('cargo-nextest недоступен',1,true) then return true end end;return false]]) end)
                assert(not e.rpc:request('nvim_get_mode',{}).blocking)
                T.eq(counts(e).passed,0)
                local notices=e:lua('return #vim.g.forge_e2e_notifications')
                e:lua([[require('neotest').forge_runner.all()]])
                e:wait('Run all checks missing prerequisite',function() return e:lua('return #vim.g.forge_e2e_notifications')>notices end)
                T.eq(counts(e).running,0)
                e:lua([[local file=...;require('ide').focus_main();vim.cmd.edit(vim.fn.fnameescape(file));
                    vim.api.nvim_buf_set_lines(0,0,0,false,{'// STILL_EDITABLE'});vim.cmd.write()]],{file})
                T.eq(vim.fn.readfile(file)[1],'// STILL_EDITABLE')
            else
                e:wait('root file actual passed tests',function() local s=counts(e);return s.passed+s.failed>0 and s.running==0 end,45000)
                T.eq(counts(e).passed,2);T.eq(counts(e).failed,0,'Neighbor target must not run')
                e:wait('native test stdout',function() return body(e):find('ROOT_'..(target=='main' and 'BIN' or 'LIB'),1,true)~=nil end)
                if e.nextest_path then
                    local actual=e:lua([[return require('forge.nextest').executable(...)]],{file})
                    T.eq(vim.fs.normalize(actual),vim.fs.normalize(e.nextest_path))
                end
                if mode=='explicit' then
                    local config=e.rust_project..'/.fride/tools.json'
                    vim.fn.writefile({vim.json.encode({tools={['cargo-nextest']=e.nextest_path..'-missing'}})},config)
                    e:lua([[require('neotest').run.run_last()]])
                    e:wait('last-run prerequisite error stays editable',function() return e:lua([[for _,n in ipairs(vim.g.forge_e2e_notifications) do
                        if n.message:find('cargo-nextest недоступен',1,true) then return true end end;return false]]) end)
                    T.eq(counts(e).passed,2);T.eq(counts(e).running,0)
                end
            end
            T.eq(e:lua('return vim.g.forge_e2e_installs'),0)
            vim.fn.writefile({vim.json.encode(counts(e))},e.dir..'/nextest-counts.json')
        end,debug.traceback)
        if e then
            e:snapshot(name);io.stdout:write('  artifacts: '..e.dir..'\n')
            local stopped,why=pcall(e.stop,e,not ok and err or nil)
            if not stopped then ok=false;err=tostring(err or '')..'\n'..tostring(why) end
        end
        assert(ok,err)
    end)
end
check('main root/nested tests keep the bin target','auto','main')
check('lib root/nested tests use normal Cargo home outside PATH','home','lib')
check('manual nextest path with spaces uses native executable','explicit','main')
check('invalid explicit nextest never uses ready PATH fallback','invalid','main')
check('missing nextest leaves editing and logs available','missing','main')
T.finish()
