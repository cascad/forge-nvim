-- IDE-061: нормализация опубликованного SQLS 0.2.48 на внешней границе.
local M={}
function M.rpc(rpc,version)
    if version~='0.2.48' then return rpc end
    local request=rpc.request
    rpc.request=function(method,params,...)
        if method=='textDocument/rename' and params and params.position then
            -- В отличие от definition, rename передаёт zero-based character
            -- прямо в walker, который выбирает identifier после его начала.
            params=vim.deepcopy(params)
            params.position.character=params.position.character+1
        end
        return request(method,params,...)
    end
    return rpc
end
function M.initialized(client,version)
    -- SQLS lexer считает []rune; encoding не объявлен в initialize reply.
    -- Ответы уже zero-based, их диапазоны менять не требуется.
    if version=='0.2.48' then client.offset_encoding='utf-32' end
end
return M
