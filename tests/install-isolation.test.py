"""IDE-BOOT-11: native runtime/install/launch; fixture config, не full SDK acceptance."""
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tarfile
import time
import unittest
import zipfile

ROOT=Path(__file__).resolve().parents[1]
WINDOWS=os.name=='nt'
PLATFORM=('windows' if WINDOWS else ('macos' if platform.system()=='Darwin' else 'linux'))+'-'+('arm64' if platform.machine().lower() in ('arm64','aarch64') else 'x64')
STAND_ID=str(time.time_ns())+' ü space'
ARTIFACTS=ROOT/'.tests/install-isolation'/STAND_ID
BASE=Path(os.environ.get('FORGE_INSTALL_STAND_ROOT',str(ROOT/'.tests/install-isolation')))/STAND_ID
BASE.mkdir(parents=True)
SHELL=(shutil.which('powershell.exe') or shutil.which('pwsh')) if WINDOWS else shutil.which('bash')
NVIM=Path(os.environ.get('FORGE_INSTALL_TEST_NVIM',str(ROOT/'.tools/neovim/windows-x64/bin/nvim.exe') if WINDOWS else shutil.which('nvim') or ''))
assert NVIM.is_file(),'Prepared native Neovim required; no host downloads/installs'
SDK=NVIM.resolve().parent.parent


def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path);result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result


packager=module('forge_runtime_packager',ROOT/'scripts/package-runtime.py')
transport=module('forge_install_transport',ROOT/'tests/install-bootstrap.test.py')

INIT=r'''
if vim.env.FORGE_PROBE_OUTPUT then
  local result={argv=vim.v.argv,exe=vim.v.progpath,config=vim.fn.stdpath('config'),data=vim.fn.stdpath('data'),
    state=vim.fn.stdpath('state'),cache=vim.fn.stdpath('cache'),app=vim.env.NVIM_APPNAME,
    tmp=vim.env.TEMP,path=vim.env.PATH,mask=vim.env.FORGE_NVIM_COMPONENTS}
  vim.fn.writefile({vim.json.encode(result)},vim.env.FORGE_PROBE_OUTPUT)
end
'''
STAGE=r'''
vim.fn.writefile({arg[1]},vim.env.FORGE_STAGE_TRACE,'a')
if vim.env.FORGE_FAIL_STAGE==arg[1] then vim.cmd('cquit 13') end
'''


def snapshot(path):
    return {p.relative_to(path).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in path.rglob('*') if p.is_file()}


def foreign_snapshot(path):
    result=snapshot(path)
    # Windows PowerShell создаёт этот cache ДО выполнения любого -File, включая
    # пустой скрипт. Это side effect host, не конфиг/SDK и не запись installer.
    result.pop('AppData/Local/Microsoft/Windows/PowerShell/StartupProfileData-NonInteractive',None)
    return result


class Isolation(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source=BASE/'source';cls.source.mkdir()
        (cls.source/'nvim_forge/scripts').mkdir(parents=True)
        (cls.source/'nvim_forge/init.lua').write_text(INIT,encoding='utf-8')
        (cls.source/'nvim_forge/scripts/setup-stage.lua').write_text(STAGE,encoding='utf-8')
        shutil.copytree(ROOT/'scripts',cls.source/'scripts',ignore=shutil.ignore_patterns('__pycache__'))
        for name in ['components.tsv','lib/install-profile.ps1','lib/install-profile.sh']:
            path=cls.source/'nvim_forge/scripts'/name;path.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(ROOT/'nvim_forge/scripts'/name,path)
        (cls.source/'nvim_forge.sh').write_text('#!/bin/sh\n')
        (cls.source/'wezterm.lua').write_text('-- fixture\n')
        recipe={'schema':1,'platform':PLATFORM,'nvim':'bin/nvim.exe' if WINDOWS else 'bin/nvim',
                'components':['core'],'paths':['bin'],'probes':[['bin/nvim.exe' if WINDOWS else 'bin/nvim','--version']]}
        if WINDOWS:recipe['windows_sdk']=json.loads((SDK/'forge-sdk.json').read_text(encoding='utf-8-sig'))
        recipe_path=BASE/'recipe.json';recipe_path.write_text(json.dumps(recipe),encoding='utf-8')
        cls.archive=BASE/('runtime.zip' if WINDOWS else 'runtime.tar.gz')
        cls.receipt=packager.package(SDK,recipe_path,cls.archive)
        cls.runtime=BASE/'prepared';cls.runtime.mkdir()
        if WINDOWS:
            with zipfile.ZipFile(cls.archive) as arc:arc.extractall(cls.runtime)
        else:
            with tarfile.open(cls.archive) as arc:arc.extractall(cls.runtime,filter='data')
        cls.server=transport.serve();cls.url,cls.routes,_=cls.server.__enter__()
        cls.routes['/runtime']=cls.archive.read_bytes()
        source_bytes=io.BytesIO()
        if WINDOWS:
            with zipfile.ZipFile(source_bytes,'w',compression=zipfile.ZIP_DEFLATED) as arc:
                for path in cls.source.rglob('*'):
                    if path.is_file():arc.write(path,'forge-main/'+path.relative_to(cls.source).as_posix())
        else:
            with tarfile.open(fileobj=source_bytes,mode='w:gz') as arc:arc.add(cls.source,arcname='forge-main')
        cls.routes['/isolation-source']=source_bytes.getvalue()

    @classmethod
    def tearDownClass(cls):cls.server.__exit__(None,None,None)

    def prepare(self,name):
        base=BASE/name;base.mkdir();foreign=base/'foreign';foreign.mkdir()
        for name in ['config/nvim/init.lua','data/nvim/keep','bin/nvim.exe' if WINDOWS else 'bin/nvim',
                     'profile.ps1','.zshrc','.config/wezterm/wezterm.lua']:
            path=foreign/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text('user-owned '+name,encoding='utf-8')
        env=os.environ.copy()
        env.update(HOME=str(foreign),USERPROFILE=str(foreign),LOCALAPPDATA=str(foreign/'local'),
            XDG_CONFIG_HOME=str(foreign/'config'),XDG_DATA_HOME=str(foreign/'data'),
            XDG_STATE_HOME=str(foreign/'state'),XDG_CACHE_HOME=str(foreign/'cache'),NVIM_APPNAME='nvim',
            FORGE_NVIM_COMPONENTS='core',FORGE_STAGE_TRACE=str(base/'stages.txt'),
            NVIM_LOG_FILE=str(base/'bootstrap.log'),FORGE_PROBE_OUTPUT=str(base/'probe.json'),
            PSModuleAnalysisCachePath=str(base/'powershell-module-cache'))
        env['PATH']=str(foreign/'bin')+os.pathsep+env.get('PATH','')
        self.addCleanup(lambda:self.assertEqual(foreign_snapshot(foreign),before,'Foreign files changed'))
        before=foreign_snapshot(foreign)
        return base,env,base/'missing parents ü/kit'

    def run_process(self,args,env,base,label):
        result=subprocess.run(args,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=90)
        (base/(label+'.json')).write_text(json.dumps({'args':args,'exit':result.returncode,'out':result.stdout,'err':result.stderr},ensure_ascii=False,indent=2),encoding='utf-8')
        return result

    def install(self,base,env,target,root=False,download=False,runtime=True,sha=None,default=False):
        if WINDOWS:
            args=[SHELL,'-NoProfile','-ExecutionPolicy','Bypass','-File',str(ROOT/('install.ps1' if root else 'scripts/install-private.ps1'))]
            if not default:args+=['-InstallPath',str(target)]
            if root:args+=['-ArchiveUrl',self.url+'/isolation-source','-SourceRoot',str(base/'sources'),'-Components','core']
            else:args+=['-Source',str(self.source)]
            if download:args+=['-RuntimeArchiveUrl',self.url+'/runtime','-RuntimeSHA256',sha or self.receipt['sha256']]
            elif runtime:args+=['-RuntimePath',str(self.runtime)]
        else:
            if root:
                args=[SHELL,str(ROOT/'install.sh'),'--archive-url',self.url+'/isolation-source','--source-root',str(base/'sources'),'--components','core']
                if not default:args+=['--install-dir',str(target)]
                if download:args+=['--runtime-archive-url',self.url+'/runtime','--runtime-sha256',sha or self.receipt['sha256']]
                elif runtime:args+=['--runtime-path',str(self.runtime)]
            else:args=[SHELL,str(ROOT/'scripts/install-private.sh'),str(self.source),str(target),str(self.runtime) if runtime else '',self.url+'/runtime' if download else '',sha or self.receipt['sha256'] if download else '']
        return self.run_process(args,env,base,'install-'+str(time.time_ns()))

    def assert_ok(self,result):self.assertEqual(result.returncode,0,result.stdout+result.stderr)

    def launch(self,base,env,target,exitcode=0):
        tail=['--headless','-i','NONE',str(base/'file with spaces.go'),'-c','cquit '+str(exitcode) if exitcode else 'qa!']
        args=([SHELL,'-NoProfile','-ExecutionPolicy','Bypass','-File',str(target/'bin/forge.ps1')] if WINDOWS else [SHELL,str(target/'bin/forge')])+tail
        return self.run_process(args,env,base,'launch-'+str(time.time_ns()))

    def test_01_install_launch_and_repeat(self):
        base,env,target=self.prepare('repeat');self.assert_ok(self.install(base,env,target))
        self.assert_ok(self.launch(base,env,target))
        probe=json.loads((base/'probe.json').read_text(encoding='utf-8'))
        for key in ['config','data','state','cache','tmp']:
            self.assertTrue(Path(probe[key]).is_relative_to(target),(key,probe[key]))
        self.assertTrue(Path(probe['exe']).is_relative_to(target/'runtime'))
        self.assertIn(str(base/'file with spaces.go'),probe['argv']);self.assertNotIn('mask',probe)
        (target/'data/keep.txt').write_text('keep');(target/'config/forge/local.lua').write_text('-- local')
        self.assert_ok(self.install(base,env,target))
        self.assertEqual((target/'data/keep.txt').read_text(),'keep')
        self.assertEqual(len(list((target/'backups').glob('*/config/forge/local.lua'))),1)
        self.assertEqual(self.launch(base,env,target,7).returncode,7)

    def test_02_foreign_target(self):
        base,env,target=self.prepare('foreign-target');target.mkdir(parents=True);(target/'init.lua').write_text('mine')
        before=snapshot(target);result=self.install(base,env,target)
        self.assertNotEqual(result.returncode,0);self.assertIn('not owned',result.stderr);self.assertEqual(snapshot(target),before)

    def test_03_no_runtime(self):
        base,env,target=self.prepare('missing-runtime');result=self.install(base,env,target,root=True,runtime=False)
        self.assertNotEqual(result.returncode,0);self.assertIn('Prepared private runtime is unavailable',result.stderr);self.assertFalse(target.exists())

    def test_04_failed_setup_keeps_previous(self):
        base,env,target=self.prepare('failed-update');self.assert_ok(self.install(base,env,target))
        before=snapshot(target/'bin');config=snapshot(target/'config');marker=(target/'.forge-install.json').read_bytes()
        env['FORGE_FAIL_STAGE']='parsers';result=self.install(base,env,target)
        self.assertNotEqual(result.returncode,0);self.assertIn('Command failed',result.stderr)
        self.assertEqual(snapshot(target/'bin'),before);self.assertEqual(snapshot(target/'config'),config)
        self.assertEqual((target/'.forge-install.json').read_bytes(),marker);self.assert_ok(self.launch(base,env,target))

    def test_05_root_download_and_repeat(self):
        base,env,target=self.prepare('download');self.assert_ok(self.install(base,env,target,root=True,download=True,runtime=False))
        self.assert_ok(self.launch(base,env,target));self.assert_ok(self.install(base,env,target,root=True,download=True,runtime=False))

    def test_06_wrong_archive_hash(self):
        base,env,target=self.prepare('bad-hash');result=self.install(base,env,target,root=True,download=True,runtime=False,sha='0'*64)
        self.assertNotEqual(result.returncode,0);self.assertIn('SHA256 mismatch',result.stderr);self.assertFalse(target.exists())

    def test_07_missing_component(self):
        base,env,target=self.prepare('missing-component');env['FORGE_NVIM_COMPONENTS']='core,rust'
        result=self.install(base,env,target);self.assertNotEqual(result.returncode,0)
        self.assertIn('lacks selected component: rust',result.stderr);self.assertFalse(target.exists())

    def test_08_linked_target(self):
        base,env,target=self.prepare('linked-target');target.parent.mkdir(parents=True)
        if WINDOWS:
            result=subprocess.run(['cmd.exe','/c','mklink','/J',str(target),str(base/'foreign')],capture_output=True)
            self.assertEqual(result.returncode,0,result.stderr)
        else:target.symlink_to(base/'foreign',target_is_directory=True)
        result=self.install(base,env,target);self.assertNotEqual(result.returncode,0);self.assertIn('Linked install',result.stderr)

    def test_09_corrupt_runtime(self):
        base,env,target=self.prepare('corrupt-runtime');checksum=self.runtime/'nvim.sha256';old=checksum.read_bytes()
        try:
            checksum.write_text('0'*64+'\n',encoding='ascii')
            result=self.install(base,env,target);self.assertNotEqual(result.returncode,0)
            self.assertIn('SHA256 mismatch',result.stderr);self.assertFalse(target.exists())
        finally:checksum.write_bytes(old)

    def test_10_default_path(self):
        base,env,_=self.prepare('default');env['LOCALAPPDATA']=str(base/'localapp');env['XDG_DATA_HOME']=str(base/'defaultdata')
        target=Path(env['LOCALAPPDATA'] if WINDOWS else env['XDG_DATA_HOME'])/'forge-nvim/installation'
        self.assertFalse(target.exists());self.assert_ok(self.install(base,env,target,root=True,default=True))
        self.assert_ok(self.launch(base,env,target))

    @unittest.skipUnless(WINDOWS,'PowerShell caller environment')
    def test_11_caller_environment(self):
        base,env,target=self.prepare('caller');self.assert_ok(self.install(base,env,target))
        wrapper=base/'caller.ps1'
        wrapper.write_text(r'''param([string]$Launcher,[string]$Report)
$keys=@('PATH','XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_STATE_HOME','XDG_CACHE_HOME','NVIM_APPNAME','TEMP','TMP','TMPDIR','FORGE_NVIM_COMPONENTS','VIMRUNTIME','GOPATH')
$before=@{};foreach($key in $keys){$before[$key]=[Environment]::GetEnvironmentVariable($key,'Process')}
& $Launcher --headless -i NONE -c 'qa!'
$code=$LASTEXITCODE
$after=@{};foreach($key in $keys){$after[$key]=[Environment]::GetEnvironmentVariable($key,'Process')}
[IO.File]::WriteAllText($Report,(@{before=$before;after=$after}|ConvertTo-Json -Depth 4))
exit $code
''',encoding='utf-8')
        report=base/'environment.json';self.assert_ok(self.run_process([SHELL,'-NoProfile','-File',str(wrapper),'-Launcher',str(target/'bin/forge.ps1'),'-Report',str(report)],env,base,'caller'))
        value=json.loads(report.read_text(encoding='utf-8-sig'));self.assertEqual(value['before'],value['after'])

    def test_12_external_link_in_owned_target(self):
        base,env,target=self.prepare('owned-link');target.mkdir(parents=True)
        (target/'.forge-install.json').write_text(json.dumps({'schema':1,'product':'forge-nvim','ready':True}))
        if WINDOWS:
            result=subprocess.run(['cmd.exe','/c','mklink','/J',str(target/'data'),str(base/'foreign/data')],capture_output=True)
            self.assertEqual(result.returncode,0,result.stderr)
        else:(target/'data').symlink_to(base/'foreign/data',target_is_directory=True)
        result=self.install(base,env,target);self.assertNotEqual(result.returncode,0)
        self.assertIn('External link in Forge',result.stderr)

    def test_13_bootstrap_without_log_override(self):
        base,env,target=self.prepare('bootstrap-environment');env.pop('NVIM_LOG_FILE',None)
        self.assert_ok(self.install(base,env,target,root=True));self.assert_ok(self.launch(base,env,target))

    def test_14_relative_custom_path(self):
        base,env,target=self.prepare('relative-target')
        relative=Path(os.path.relpath(target,Path.cwd()))
        self.assert_ok(self.install(base,env,relative))
        self.assert_ok(self.launch(base,env,target))
        probe=json.loads((base/'probe.json').read_text(encoding='utf-8'))
        self.assertTrue(Path(probe['data']).is_relative_to(target))


if __name__=='__main__':
    print('work:',BASE,'artifacts:',ARTIFACTS,flush=True)
    suite=(unittest.defaultTestLoader.loadTestsFromNames(sys.argv[1:],sys.modules[__name__]) if len(sys.argv)>1
           else unittest.defaultTestLoader.loadTestsFromTestCase(Isolation))
    result=unittest.TextTestRunner(verbosity=2).run(suite)
    summary={'platform':PLATFORM,'tests':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),
             'skips':len(result.skipped),'fixture_config':True,'test_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
    (BASE/'summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
    if BASE!=ARTIFACTS:
        # В Docker native FS быстрее Windows bind mount; доказательства сохраняются,
        # SDK binaries/архивы заново в host overlay не дублируются.
        def ignore(directory,names):
            return [n for n in names if n in ('runtime','prepared','.runtime-cache') or n.endswith(('.zip','.tar.gz')) or (Path(directory)/n).is_symlink()]
        shutil.copytree(BASE,ARTIFACTS,ignore=ignore)
    raise SystemExit(0 if result.wasSuccessful() else 1)
