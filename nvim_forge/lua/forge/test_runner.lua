-- spec: IDE-TEST-5 IDE-BOOT-49. Consumer/client/public run API; no private fields.
local original=setmetatable({}, {__mode='k'})
return function(client)
    local nio=require('nio')
    local lib=require('neotest.lib')
    local windows=vim.fn.has('win32')==1
    local function inside(path,parent)
        path,parent=vim.fs.normalize(path),vim.fs.normalize(parent)
        if windows then path,parent=path:lower(),parent:lower() end
        return path==parent or path:sub(1,#parent+1)==parent..'/'
    end
    local function has_tests(tree)
        for _,pos in tree:iter() do if pos.type=='test' then return true end end
        return false
    end
    local function ready(tree,args,adapter)
        if tree and args.strategy~='dap' and type(adapter)=='string' and adapter:find('neotest-rust',1,true)==1 then
            return require('forge.nextest').available(tree:data().path)~=nil
        end
        return true
    end
    local function position(args)
        local opts=type(args)=='string' and {args} or args or {}
        if opts.suite then return client:get_position(nil,{adapter=opts.adapter or client:get_adapters()[1]}) end
        if opts[1] then return client:get_position(vim.uv.fs_realpath(opts[1]) or lib.files.path.real(opts[1]) or opts[1],opts) end
        local file=nio.fn.expand('%:p');file=vim.uv.fs_realpath(file) or file
        return client:get_nearest(file,nio.fn.getpos('.')[2]-1,opts)
    end
    return {running=function() return #client:running_positions()>0 end,
    bind_run_api=function(run)
        -- Native build_spec=nil means "try each descendant", not cancellation.
        -- Reject an unavailable prerequisite before native state marks tests running.
        -- Keep native selection, augmentation, results and last-run storage.
        local base=original[run] or {run=run.run,last=run.run_last};original[run]=base
        run.run=nio.create(function(args)
            local opts=type(args)=='table' and args or {}
            local tree,adapter=position(args)
            if ready(tree,opts,adapter) then base.run(args) end
        end,1)
        run.run_last=nio.create(function(args)
            local id,previous=run.get_last_run()
            local opts=vim.tbl_extend('force',previous or {},args or {})
            local tree,adapter
            if id then tree,adapter=client:get_position(id,opts) end
            if ready(tree,opts,adapter) then base.last(args) end
        end,1)
    end,
    all=nio.create(function()
        local cwd=nio.fn.getcwd();cwd=vim.uv.fs_realpath(cwd) or cwd
        local targets,unavailable={},false
        for _,adapter in ipairs(client:get_adapters()) do
            local root=client:get_position(nil,{adapter=adapter})
            local tree=root and client:get_position(cwd,{adapter=adapter})
            if not tree and root and inside(root:data().path,cwd) then tree=root end
            if tree and has_tests(tree) then
                if ready(tree,{},adapter) then targets[#targets+1]={tree=tree,adapter=adapter}
                else unavailable=true end
            end
        end
        for _,target in ipairs(targets) do client:run_tree(target.tree,{adapter=target.adapter}) end
        if #targets==0 and not unavailable then
            nio.scheduler();vim.notify('Tests не найдены в '..cwd,vim.log.levels.WARN)
        end
    end,0)}
end
