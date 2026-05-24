-- polish.lua запускается последним, после Lazy и всех плагинов.
-- Сюда уместно класть мелкие правки на чистом Lua/Vim API, которые
-- не вписываются в astrocore (опции/маппинги/автокоманды лучше
-- держать в lua/plugins/astrocore.lua).
--
-- Дефолт пустой — оставлено как точка расширения.

---@diagnostic disable-next-line: unused-local
local function example_filetype_hook()
  -- Пример: добавить распознавание расширения.
  -- vim.filetype.add({ extension = { foo = "fooscript" } })
end
