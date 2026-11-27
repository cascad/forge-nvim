-- Local TUI. Translate ambiguous punctuation using the keyboard layout
-- selected in macOS. No process launch, layout switching, or idle polling.
local M = {}

function M.reader(copy_source)
    local ffi = require('ffi')
    ffi.cdef[[
        void *TISCopyCurrentKeyboardLayoutInputSource(void);
        extern const void *kTISPropertyUnicodeKeyLayoutData;
        const void *TISGetInputSourceProperty(void *, const void *);
        unsigned char LMGetKbdType(void);
        int32_t UCKeyTranslate(const void *, uint16_t, uint16_t, uint32_t, uint32_t,
            uint32_t, uint32_t *, unsigned long, unsigned long *, uint16_t *);
        const unsigned char *CFDataGetBytePtr(const void *);
        void CFRelease(const void *);
        unsigned char CFEqual(const void *, const void *);
        extern const void *kCFRunLoopDefaultMode;
        int32_t CFRunLoopRunInMode(const void *, double, unsigned char);
    ]]
    local carbon = ffi.load('/System/Library/Frameworks/Carbon.framework/Carbon')
    local cf = ffi.load('/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation')
    copy_source = copy_source or carbon.TISCopyCurrentKeyboardLayoutInputSource
    -- ANSI virtual key codes (unshifted and shifted US symbols).
    local positions = {
        [18]='1!', [19]='2@', [20]='3#', [21]='4$', [23]='5%', [22]='6^',
        [26]='7&', [28]='8*', [25]='9(', [29]='0)', [27]='-_', [24]='=+',
        [33]='[{', [30]=']}', [42]='\\|', [41]=';:', [39]="'\"",
        [43]=',<', [47]='.>', [44]='/?', [50]='`~',
    }
    local previous, mapping
    return function()
        -- A terminal process has no Cocoa event loop. Deliver queued TIS
        -- source-change notifications before querying its cached source.
        cf.CFRunLoopRunInMode(cf.kCFRunLoopDefaultMode, 0, 0)
        local source = copy_source()
        if source == nil then return nil end
        if previous and cf.CFEqual(previous, source) ~= 0 then
            cf.CFRelease(source)
            return mapping
        end
        previous = ffi.gc(source, cf.CFRelease)
        mapping = nil
        local data = carbon.TISGetInputSourceProperty(source, carbon.kTISPropertyUnicodeKeyLayoutData)
        if data == nil then return nil end
        local layout = cf.CFDataGetBytePtr(data)
        local keyboard = carbon.LMGetKbdType()
        local function translate(code, shift)
            local dead, length, output = ffi.new('uint32_t[1]'), ffi.new('unsigned long[1]'), ffi.new('uint16_t[4]')
            local status = carbon.UCKeyTranslate(layout, code, 0, shift and 2 or 0, keyboard,
                1, dead, 4, length, output)
            if status == 0 and length[0] == 1 then return vim.fn.nr2char(output[0]) end
        end
        if translate(0, false) == 'ф' and translate(12, false) == 'й' then
            mapping = {}
            for code, us in pairs(positions) do
                for i = 1, 2 do
                    local key, symbol = us:sub(i, i), translate(code, i == 2)
                    if symbol and symbol ~= key then mapping[symbol] = key end
                end
            end
        end
        return mapping
    end
end

return M
