local root=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p:h:h:h')
package.path=root..'/tests/lib/?.lua;'..package.path
local T=require('check')
local P=require('output_policy')
for _,case in ipairs({
  {'terminal viewport shrink','terminal','one\ntwo\n\n\n','one\ntwo\n',true},
  {'lost nonempty prefix','terminal','one\ntwo\n\n','two\n',false},
  {'internal blank line loss','terminal','one\n\ntwo\n','one\ntwo\n',false},
  {'REPL trailing lines remain exact','prompt','one\n\n','one\n',false},
  {'appended output','terminal','one\n\n','one\n\nmore\n',true},
}) do
  T.check('SELF: OUTPUT-HISTORY '..case[1],function()
    T.eq(P.history_preserved({buftype=case[2],text=case[3]},{buftype=case[2],text=case[4]}),case[5])
  end)
end
T.finish()
