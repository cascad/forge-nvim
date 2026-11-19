-- spec: IDE-BOOT-50 IDE-BOOT-52. Real installed startup before SDK preparation.
local project,output=unpack(arg)
local function write(path,lines)vim.fn.mkdir(vim.fs.dirname(path),'p');assert(vim.fn.writefile(lines,path)==0)end
write(project..'/go.mod',{'module fride.local/first','go 1.26.0'})
write(project..'/main.go',{'package main','func main() { println("first") }'})
write(project..'/Cargo.toml',{'[package]','name="fride_first"','version="0.1.0"','edition="2021"'})
write(project..'/src/main.rs',{'fn main() { println!("first"); }'})
local init=vim.system({'git','init','-q',project},{text=true}):wait(5000);assert(init.code==0,init.stderr)
vim.cmd.cd(vim.fn.fnameescape(project))
local function offers()
 local n=0
 for _,item in ipairs(require('forge.log_store').memory)do if item.message:find('Space l S',1,true)then n=n+1 end end
 return n
end
local baseline=offers();local results={}
for _,case in ipairs({{'go','main.go'},{'rust','src/main.rs'}})do
 vim.cmd.edit(vim.fn.fnameescape(project..'/'..case[2]))
 assert(vim.wait(5000,function()return require('forge.languages').seen[project..'\n'..case[1]]end,10),'First-file hook did not run')
 local state=require('forge.languages').status(case[1],project)
 assert(not state.ready and not state.sdks[1].path,'SDK unexpectedly exists at first file')
 results[#results+1]={language=case[1],notice_count=offers()-baseline,ready=state.ready}
end
assert(offers()-baseline==2,'Expected one passive offer per language')
vim.cmd.edit(vim.fn.fnameescape(project..'/main.go'));vim.wait(100)
assert(offers()-baseline==2,'Repeated file offer')
for _,tool in ipairs({'go','rustc','cargo'})do assert(vim.fn.exepath(tool)=='','Opening a file installed SDK '..tool)end
write(output,{vim.json.encode({ready=true,cases=results,no_sdk_download=true})})
