"""IDE-BOOT-9: native installer/Neovim orchestration, fixture commands, real backports."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shlex
import shutil
import subprocess
import time
import unittest

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--backend',choices=['windows','linux','macos'],default='windows' if os.name=='nt' else ('macos' if platform.system()=='Darwin' else 'linux'))
parser.add_argument('--nvim')
OPTIONS=parser.parse_args()
BACKEND=OPTIONS.backend
assert (BACKEND=='windows')==(os.name=='nt'),'Use native PowerShell for Windows, POSIX shell for Linux/macOS backend'
SOURCE=Path(os.environ.get('FORGE_INSTALL_SETUP_SOURCE',str(ROOT/'nvim_forge')))
DEPS=Path(os.environ.get('FORGE_E2E_DEPS',str(ROOT/'.tests/editor-deps')))
NVIM=OPTIONS.nvim or (str(ROOT/'.tools/neovim/windows-x64/bin/nvim.exe') if os.name=='nt' else shutil.which('nvim'))
assert NVIM and Path(NVIM).is_file(),'Prepared Neovim required; no SDK downloads in this stand'
BASE=ROOT/'.tests/install-setup'/(str(time.time_ns())+' ü space')
BASE.mkdir(parents=True)

INIT=r'''
local function record(kind,args)
  vim.fn.writefile({vim.json.encode({kind=kind,args=args,profile=PROFILE,
    config=vim.fn.stdpath('config'),pid=vim.uv.os_getpid(),argv=vim.v.argv})},vim.env.FORGE_SETUP_TRACE,'a')
end
record('init')
vim.api.nvim_create_user_command('Lazy',function(a)
  record('Lazy',a.args)
  if not a.args:find('load',1,true) and vim.env.FORGE_SETUP_CASE=='plugins' then error('FORGE_SETUP_FAILURE_plugins') end
  if a.args:find('load',1,true) and vim.env.FORGE_SETUP_CASE~='missing-tools' then
    vim.api.nvim_create_user_command('MasonToolsInstallSync',function()
      record('MasonToolsInstallSync')
      if vim.env.FORGE_SETUP_CASE=='tools' then error('FORGE_SETUP_FAILURE_tools') end
    end,{force=true})
  end
end,{nargs='*',bang=true})
vim.api.nvim_create_user_command('ForgeTreesitterInstall',function()
  record('ForgeTreesitterInstall')
  if vim.env.FORGE_SETUP_CASE=='parsers' then error('FORGE_SETUP_FAILURE_parsers') end
end,{})
'''


def run(args,env):
    return subprocess.run(args,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=45)


class Setup(unittest.TestCase):
    def execute(self,name,default=False):
        base=BASE/name;base.mkdir()
        checkout=base/'checkout';profile=checkout/'nvim_forge'
        (profile/'lua/ide').mkdir(parents=True)
        shutil.copytree(SOURCE/'scripts',profile/'scripts')
        shutil.copytree(SOURCE/'patches',profile/'patches')
        shutil.copyfile(SOURCE/'lua/ide/backports.lua',profile/'lua/ide/backports.lua')
        shutil.copyfile(SOURCE/'lazy-lock.json',profile/'lazy-lock.json')
        (checkout/'nvim_forge.sh').write_text('#!/bin/sh\n')
        (checkout/'wezterm.lua').write_text('-- stand\n')
        (profile/'init.lua').write_text("local PROFILE='installed'\n"+INIT,encoding='utf-8')
        ambient=base/'ambient'
        (ambient/'other').mkdir(parents=True)
        (ambient/'other/init.lua').write_text("local PROFILE='ambient'\n"+INIT,encoding='utf-8')
        home=base/'home';home.mkdir()
        target=(base/'localapp/nvim' if BACKEND=='windows' else ambient/'nvim') if default else base/'new parents ü/deep/config/nvim'
        self.assertFalse(target.exists());self.assertFalse(target.parent.exists() if not default else target.exists())
        env=os.environ.copy()
        env.update(HOME=str(home),LOCALAPPDATA=str(base/'localapp'),XDG_CONFIG_HOME=str(ambient),
            XDG_DATA_HOME=str(base/'data'),XDG_STATE_HOME=str(base/'state'),XDG_CACHE_HOME=str(base/'cache'),
            NVIM_APPNAME='other',FORGE_SETUP_TRACE=str(base/'trace.jsonl'),FORGE_SETUP_CASE=name,
            FORGE_NVIM_SKIP_DEPS='1',FORGE_NVIM_SKIP_WEZTERM='1',FORGE_NVIM_USE_LOCAL_SOURCE='1',
            FORGE_NVIM_DEPS_ONLY='0',FORGE_INSTALL_TEST_NVIM=NVIM,NVIM_LOG_FILE=str(base/'nvim.log'))
        env.pop('FORGE_NVIM_NO_BACKUP',None)
        env.pop('FORGE_NVIM_WITH_LANGUAGES',None)
        if default:env.pop('FORGE_NVIM_INSTALL_DIR',None)
        else:env['FORGE_NVIM_INSTALL_DIR']=str(target)
        query=base/'stdpath.lua';query.write_text("io.stdout:write(vim.fn.stdpath('data'))",encoding='utf-8')
        selected=env.copy();selected.update(XDG_CONFIG_HOME=str(target.parent),NVIM_APPNAME=target.name)
        result=run([NVIM,'-u','NONE','-i','NONE','-l',str(query)],selected)
        self.assertEqual(result.returncode,0,result.stderr)
        lazy=Path(result.stdout)/'lazy'
        plans=json.loads((profile/'patches/plugins.json').read_text(encoding='utf-8'))
        for plugin,plan in plans.items():
            for item in [plan]+plan.get('extra',[]):
                original=DEPS/'lazy'/plugin/item['file']
                raw=original.read_bytes().replace(b'\r\n',b'\n')
                digest=hashlib.sha256(raw).hexdigest()
                self.assertIn(digest,[item['before_sha256'],item['after_sha256']],str(original))
                dest=lazy/plugin/item['file'];dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(raw)
        neo=plans['neo-tree.nvim'];changed=lazy/'neo-tree.nvim'/neo['file']
        raw=changed.read_text(encoding='utf-8')
        if hashlib.sha256(raw.encode()).hexdigest()==neo['after_sha256']:
            changed.write_text(raw.replace(neo['after'],neo['before'],1),encoding='utf-8',newline='\n')
        if name=='backports':changed.write_text('invalid private fixture\n',encoding='utf-8')
        if BACKEND=='windows':
            process_bin=base/'process-bin';process_bin.mkdir()
            env['PATH']=str(process_bin)+os.pathsep+env['PATH']
            wrapper=base/'run.ps1'
            wrapper.write_text(r'''param([string]$Installer,[string]$Destination,[switch]$DefaultPath)
function nvim { & $env:FORGE_INSTALL_TEST_NVIM @args }
if ($DefaultPath) { . $Installer -SkipDependencies -UseLocalSource }
else { . $Installer -SkipDependencies -UseLocalSource -InstallPath $Destination }
[IO.File]::WriteAllLines($env:FORGE_SETUP_ENV_AFTER, @(($env:NVIM_APPNAME+'|'+$env:XDG_CONFIG_HOME),$env:Path))
''',encoding='utf-8')
            env['FORGE_SETUP_ENV_AFTER']=str(base/'env-after.txt')
            args=[shutil.which('powershell.exe') or shutil.which('pwsh'),'-NoProfile','-ExecutionPolicy','Bypass',
                '-File',str(wrapper),'-Installer',str(profile/'scripts/install-windows.ps1'),'-Destination',str(target)]
            if default:args+=['-DefaultPath']
        else:
            shims=base/'bin';shims.mkdir()
            shim=shims/'nvim';shim.write_text('#!/bin/sh\nexec '+shlex.quote(NVIM)+' "$@"\n',encoding='utf-8');shim.chmod(0o755)
            env['PATH']=str(shims)+os.pathsep+env['PATH']
            args=[shutil.which('bash'),str(profile/('scripts/install-'+BACKEND+'.sh'))]
        result=run(args,env)
        (base/'result.json').write_text(json.dumps({'backend':BACKEND,'system':platform.system(),'source':str(SOURCE),
            'argv':args,'exit':result.returncode,'stdout':result.stdout,'stderr':result.stderr},ensure_ascii=False,indent=2),encoding='utf-8')
        trace=[json.loads(line) for line in (base/'trace.jsonl').read_text(encoding='utf-8').splitlines()] if (base/'trace.jsonl').exists() else []
        return result,trace,target,base,lazy,plans

    def success(self,default):
        result,trace,target,base,lazy,plans=self.execute('default' if default else 'custom',default)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertTrue(target.is_dir() and (target/'init.lua').is_file())
        self.assertTrue(trace)
        self.assertTrue(all(row['profile']=='installed' for row in trace),'Ambient config was prepared')
        for row in trace:self.assertEqual(Path(row['config']),target)
        commands=[(row['kind'],row.get('args')) for row in trace if row['kind']!='init']
        self.assertEqual(commands,[('Lazy','restore'),('ForgeTreesitterInstall',None),('Lazy','load mason-tool-installer.nvim'),('MasonToolsInstallSync',None)])
        self.assertEqual(len({row['pid'] for row in trace}),3,'Fresh process per setup stage')
        for plugin,plan in plans.items():
            for item in [plan]+plan.get('extra',[]):
                digest=hashlib.sha256((lazy/plugin/item['file']).read_bytes().replace(b'\r\n',b'\n')).hexdigest()
                self.assertEqual(digest,item['after_sha256'])
        if BACKEND=='windows':
            after=(base/'env-after.txt').read_text(encoding='utf-8-sig').splitlines()
            self.assertEqual(after[0],'other|'+str(base/'ambient'))
            self.assertIn(str(base/'process-bin'),after[1].split(os.pathsep))
        self.assertIn('forge-nvim installed:',result.stdout)

    def test_01_missing_custom_parents(self):self.success(False)
    def test_02_missing_default_directory(self):self.success(True)
    def failure(self,name,stage):
        result,trace,_,_,_,_=self.execute(name)
        self.assertNotEqual(result.returncode,0,'Installer reported success after required failure')
        output=result.stdout+result.stderr
        self.assertIn('Setup stage '+stage+' failed',output)
        self.assertNotIn('forge-nvim installed:',output)
        if stage in ('plugins','parsers'):self.assertFalse(any(r['kind']=='MasonToolsInstallSync' for r in trace))
        if stage=='plugins':self.assertFalse(any(r['kind']=='ForgeTreesitterInstall' for r in trace))
    def test_03_parser_failure(self):self.failure('parsers','parsers')
    def test_04_tool_failure(self):self.failure('tools','tools')
    def test_05_missing_tool_command(self):self.failure('missing-tools','tools')
    def test_06_plugin_failure(self):self.failure('plugins','plugins')
    def test_07_unknown_backport(self):self.failure('backports','plugins')


if __name__=='__main__':
    print('artifacts: '+str(BASE),flush=True)
    print('Native '+platform.system()+'; backend='+BACKEND+'; Neovim='+NVIM,flush=True)
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(Setup))
    (BASE/'summary.json').write_text(json.dumps({'backend':BACKEND,'system':platform.system(),'source':str(SOURCE),
        'tests':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),
        'test_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()},indent=2),encoding='utf-8')
    raise SystemExit(0 if result.wasSuccessful() else 1)
