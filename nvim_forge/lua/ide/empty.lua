-- Совместимый facade; модель файлов/закрытие находятся в ide.buffers.
local buffers=require('ide.buffers')
return {
    close_buffer_safe=buffers.close,
    is_code_buffer=buffers.is_file,
    other_code_buffers=buffers.other_files,
    open_alpha_screen=buffers.open_alpha_screen,
}
