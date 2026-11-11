-- Явная bounded запись native redraw; default RPC не открывает файл.
local M={}
local function utf8(value)
  local pos=1
  while pos<=#value do
    local byte=value:byte(pos)
    if byte<128 then pos=pos+1
    else
      local length=byte>=194 and byte<=223 and 2 or byte>=224 and byte<=239 and 3 or byte>=240 and byte<=244 and 4
      if not length or pos+length-1>#value then return false end
      local nextbyte=value:byte(pos+1)
      if (byte==224 and nextbyte<160) or (byte==237 and nextbyte>159)
        or (byte==240 and nextbyte<144) or (byte==244 and nextbyte>143) then return false end
      for i=1,length-1 do local part=value:byte(pos+i);if part<128 or part>191 then return false end end
      pos=pos+length
    end
  end
  return true
end
local function serializable(value)
  if type(value)=='string' and not utf8(value) then
    -- Unpacker сохраняет некоторые MessagePack window handles бинарной строкой.
    return {__ui_bytes_hex=value:gsub('.',function(char) return ('%02x'):format(char:byte()) end)}
  end
  if type(value)~='table' then return value end
  local copy={};for key,item in pairs(value) do copy[key]=serializable(item) end
  return copy
end
function M.new(path,limit)
  local file=assert(io.open(path,'wb'))
  local self={path=path,limit=limit or 16*1024*1024,bytes=0,flushes=0}
  function self:close()
    if file then file:close();file=nil end
  end
  function self:write(record)
    if self.error then return end
    local ok,err=pcall(function()
      assert(file,'capture already closed')
      local line=vim.json.encode(serializable(record))..'\n'
      assert(self.bytes+#line<=self.limit,'UI capture byte limit exceeded')
      assert(file:write(line));assert(file:flush());self.bytes=self.bytes+#line
    end)
    if not ok then self.error=tostring(err);self:close() end
  end
  function self:redraw(events)
    for _,batch in ipairs(events) do if batch[1]=='flush' then self.flushes=self.flushes+#batch-1 end end
    self:write({kind='redraw',events=events})
  end
  function self:checkpoint(label,metadata)
    self:write({kind='checkpoint',label=label,metadata=metadata})
  end
  return self
end
return M
