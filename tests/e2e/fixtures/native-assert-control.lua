-- Only an owned diagnostic child; the release file is written after attach.
local ffi=require('ffi')
ffi.cdef'void _wassert(const uint16_t*,const uint16_t*,unsigned int); int _set_error_mode(int);'
local crt=ffi.load('ucrtbase')
crt._set_error_mode(1) -- Only this artificial child: CRT errors go to stderr.
assert(vim.wait(20000,function() return vim.fn.filereadable(arg[1])==1 end,20),'No diagnostic release')
local function wide(s)
  local a=ffi.new('uint16_t[?]',#s+1)
  for i=1,#s do a[i-1]=s:byte(i) end
  return a
end
crt._wassert(wide('FORGE_CONTROL_ONLY'),wide('forge_capture_control'),97)
