-- spec: IDE-TEST-5. Документированный Neotest consumer API; без private fields.
return function(client)
    local nio=require('nio')
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
    return {all=nio.create(function()
        local cwd=nio.fn.getcwd();cwd=vim.uv.fs_realpath(cwd) or cwd
        local targets={}
        for _,adapter in ipairs(client:get_adapters()) do
            local root=client:get_position(nil,{adapter=adapter})
            local tree=root and client:get_position(cwd,{adapter=adapter})
            if not tree and root and inside(root:data().path,cwd) then tree=root end
            if tree and has_tests(tree) then targets[#targets+1]={tree=tree,adapter=adapter} end
        end
        for _,target in ipairs(targets) do client:run_tree(target.tree,{adapter=target.adapter}) end
        if #targets==0 then
            nio.scheduler();vim.notify('Tests не найдены в '..cwd,vim.log.levels.WARN)
        end
    end,0)}
end
