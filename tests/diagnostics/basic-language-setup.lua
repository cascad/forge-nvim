-- IDE-BOOT-35. Real setup command/catalog, controlled readiness and Mason command.
local root,base=arg[1],arg[2]
package.path=root..'/nvim_forge/lua/?.lua;'..package.path
vim.env.FORGE_NVIM_COMPONENTS='core,sql,bash'
vim.env.FRIDE_RUNTIME=base..'/runtime-without-advanced-tools'
vim.fn.mkdir(vim.env.FRIDE_RUNTIME,'p')
local catalog=require('forge.tool_catalog')
local expected={'lua-language-server','stylua','bash-language-server','shfmt','shellcheck','sqruff'}
assert(vim.deep_equal(catalog.mason(),expected),vim.inspect(catalog.mason()))
local installed=0
vim.api.nvim_create_user_command('Lazy',function()
    vim.api.nvim_create_user_command('MasonToolsInstallSync',function() installed=installed+1 end,{force=true})
end,{nargs='*'})
package.preload['forge.setup_readiness']=function() return {
    build_sdks=function(names) assert(vim.deep_equal(names,expected)) end,
    tools=function(names)
        assert(vim.deep_equal(names,expected));assert(installed==1)
        assert(not package.loaded['forge.bash_debug'])
        vim.fn.writefile({vim.json.encode({tools=names,install_calls=installed,advanced=false})},base..'/setup-proof.json')
        return {packages=#names}
    end,
} end
package.preload['forge.bash_debug']=function() error('Basic setup must not load a Bash debug adapter') end
arg={'tools'};dofile(root..'/nvim_forge/scripts/setup-stage.lua')
