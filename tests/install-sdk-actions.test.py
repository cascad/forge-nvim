"""IDE-BOOT-19: native SDK menus/manager fixture/real kit and launcher."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('runtime',ROOT/'tests/install-runtime.test.py')
runtime=importlib.util.module_from_spec(spec);spec.loader.exec_module(runtime);ui=runtime.ui;stand=ui.stand

class Actions(runtime.Runtime):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        rustc=(Path(os.environ['USERPROFILE'])/'.rustup/toolchains/stable-x86_64-pc-windows-msvc/bin/rustc.exe') if stand.WINDOWS else shutil.which('rustc')
        sdk=Path(subprocess.check_output([str(rustc),'--print','sysroot'],env=dict(os.environ,RUSTUP_AUTO_INSTALL='0'),text=True).strip())
        cls.fixture=stand.BASE/('sdk-fixture.exe' if stand.WINDOWS else 'sdk-fixture')
        args=[str(sdk/'bin'/('rustc.exe' if stand.WINDOWS else 'rustc')),'--edition=2021',str(ROOT/'tests/diagnostics/sdk-probe-fixture.rs'),'-o',str(cls.fixture)]
        if stand.WINDOWS:args+=['-C','target-feature=+crt-static']
        subprocess.run(args,cwd=stand.BASE,check=True)

    def prepared(self,name,manager=True):
        base,env,target=super().prepare(name)
        toolkit=base/'native tools';toolkit.mkdir()
        if not stand.WINDOWS:
            for name in ['bash','sh','dirname','readlink','mktemp','mkdir','uname','cut','sha256sum','shasum','tar','gzip','curl','wget','mv','rm','cat']:
                if source:=shutil.which(name):(toolkit/name).symlink_to(source)
        if manager:shutil.copy2(self.fixture,toolkit/('winget.exe' if stand.WINDOWS else 'apt-get'))
        env.update(PATH=str(toolkit),SDK_PACKAGE_TRACE=str(base/'package.tsv'),SDK_PACKAGE_BIN=str(toolkit),SDK_PACKAGE_MODE='success')
        return base,env,target

    def sdk(self,folder):
        folder.mkdir(parents=True,exist_ok=True)
        shutil.copy2(self.fixture,folder/('node.exe' if stand.WINDOWS else 'node'))
        npm=folder/('npm.cmd' if stand.WINDOWS else 'npm');npm.write_text('fixture entrypoint\n')
        if not stand.WINDOWS:npm.chmod(0o755)
        return folder

    def arguments(self,base,target):
        args=[str(ui.BINARY),'--source',str(self.source),'--install-dir',str(target),'--components','node',
            '--profile','default','--log-dir',str(base/'logs'),'--result',str(base/'result.json')]
        if stand.WINDOWS:args+=['--powershell',stand.SHELL]
        return args

    def interact(self,base,env,target,scenario,expected=0):
        env['FORGE_UI_EXPECTED_EXIT']=str(expected)
        result=self.pty(base,env,self.arguments(base,target),scenario)
        return result

    def test_actions_01_existing_repeat_and_project_priority(self):
        base,env,target=self.prepared('sdk-existing');sdk=self.sdk(base/"SDK ü 'choice'")
        env['FORGE_UI_SDK_INPUT']=str(sdk);self.interact(base,env,target,'sdk-existing')
        plan=json.loads((base/'result.json').read_text(encoding='utf-8'));self.assertEqual([Path(p) for p in plan['sdk_paths']],[sdk])
        self.assertEqual((target/'bin/sdk-paths.txt').read_text(encoding='utf-8').splitlines(),[str(sdk)])
        args=self.arguments(base,target);index=args.index('--result');del args[index:index+2]
        self.assert_ok(self.run_process(args,env,base,'repeat-no-menu'));self.assertFalse((base/'package.tsv').exists())
        venv=base/'project/.venv';self.assert_ok(self.run_process([sys.executable,'-m','venv','--without-pip',str(venv)],env,base,'venv'))
        project_bin=venv/('Scripts' if stand.WINDOWS else 'bin');self.sdk(project_bin)
        env.update(VIRTUAL_ENV=str(venv),PATH=str(project_bin)+os.pathsep+env['PATH'],SDK_PRIORITY_OUTPUT=str(base/'priority.json'))
        observer=base/'priority.lua';observer.write_text("vim.fn.writefile({vim.json.encode({node=vim.fn.exepath('node'),python=vim.fn.exepath('python'),venv=vim.env.VIRTUAL_ENV})},vim.env.SDK_PRIORITY_OUTPUT)\n")
        launcher=([stand.SHELL,'-NoProfile','-ExecutionPolicy','Bypass','-File',str(target/'bin/fride.ps1')] if stand.WINDOWS else [stand.SHELL,str(target/'bin/fride')])
        self.assert_ok(self.run_process(launcher+['--headless','-u','NONE','-i','NONE','-l',str(observer)],env,base,'project-priority'))
        value=json.loads((base/'priority.json').read_text(encoding='utf-8'))
        self.assertTrue(Path(value['node']).is_relative_to(project_bin));self.assertTrue(Path(value['python']).is_relative_to(project_bin));self.assertEqual(Path(value['venv']),venv)

    def test_actions_02_invalid_existing_retry(self):
        base,env,target=self.prepared('sdk-existing-retry');bad=base/'empty SDK';bad.mkdir()
        env.update(FORGE_UI_BAD_SDK_INPUT=str(bad),FORGE_UI_SDK_INPUT=str(self.sdk(base/'SDK')))
        self.interact(base,env,target,'sdk-invalid-existing');self.assertFalse((base/'package.tsv').exists())

    def test_actions_03_skip_dependencies(self):
        base,env,target=self.prepared('sdk-skip')
        shutil.copy2(self.fixture,Path(env['PATH'])/('python3.exe' if stand.WINDOWS else 'python3'))
        args=self.arguments(base,target);args[args.index('--components')+1]='node,python,bash'
        env['FORGE_UI_EXPECTED_EXIT']='0';self.pty(base,env,args,'sdk-skip')
        plan=json.loads((base/'result.json').read_text());self.assertEqual(plan['components'],['core']);self.assertEqual(plan['native_sdks'],[])
        self.assertFalse((base/'package.tsv').exists());self.assertTrue((target/'bin/fride').exists())

    def test_actions_04_cancel_preserves_kit(self):
        base,env,target=self.prepared('sdk-cancel');target.mkdir(parents=True)
        (target/'keep').write_text('existing kit');before=stand.snapshot(target)
        self.interact(base,env,target,'sdk-cancel',130);self.assertEqual(stand.snapshot(target),before)
        self.assertFalse((base/'result.json').exists());self.assertFalse((base/'package.tsv').exists())

    def test_actions_05_install_declined(self):
        base,env,target=self.prepared('sdk-decline')
        if stand.WINDOWS:
            aliases=base/'Microsoft/WindowsApps';aliases.mkdir(parents=True)
            (Path(env['PATH'])/'winget.exe').rename(aliases/'winget.exe')
            env['PATH']+=os.pathsep+str(aliases)
        self.interact(base,env,target,'sdk-decline',130)
        self.assertFalse((base/'package.tsv').exists());self.assertFalse(target.exists())

    def test_actions_06_confirmed_install(self):
        base,env,target=self.prepared('sdk-install');self.interact(base,env,target,'sdk-install')
        calls=(base/'package.tsv').read_text().splitlines();self.assertEqual(len(calls),1)
        self.assertIn('OpenJS.NodeJS.LTS' if stand.WINDOWS else 'nodejs',calls[0]);self.assertIn('--no-upgrade',calls[0])
        self.assertTrue(list((base/'logs').glob('sdk-install-*.log')));self.assertTrue((target/'bin/fride').exists())

    def test_actions_07_failed_install_retry(self):
        base,env,target=self.prepared('sdk-retry');env['SDK_PACKAGE_MODE']='once-fail'
        self.interact(base,env,target,'sdk-retry');self.assertEqual(len((base/'package.tsv').read_text().splitlines()),2)

    def test_actions_08_exit_zero_without_sdk(self):
        base,env,target=self.prepared('sdk-noop');env['SDK_PACKAGE_MODE']='noop'
        self.interact(base,env,target,'sdk-noop',130);self.assertFalse(target.exists());self.assertFalse((base/'result.json').exists())

    def test_actions_09_missing_manager(self):
        base,env,target=self.prepared('sdk-no-manager',False);self.interact(base,env,target,'sdk-no-manager',130)
        self.assertFalse((base/'package.tsv').exists());self.assertFalse(target.exists())

    def test_actions_10_sdk_inside_kit_rejected(self):
        base,env,target=self.prepared('sdk-inside-kit');target.mkdir(parents=True)
        env['FORGE_UI_BAD_SDK_INPUT']=str(self.sdk(target/'not-a-shared-SDK'));before=stand.snapshot(target)
        self.interact(base,env,target,'sdk-inside-kit',130);self.assertEqual(stand.snapshot(target),before)

    def test_actions_11_headless_explicit_fallback(self):
        base,env,target=self.prepared('sdk-headless');sdk=self.sdk(base/'SDK/bin');args=self.arguments(base,target)+['--sdk-path',str(sdk)]
        self.assert_ok(self.run_process(args,env,base,'headless-fallback'));self.assertFalse((base/'package.tsv').exists())
        self.assertEqual((target/'bin/sdk-paths.txt').read_text().splitlines(),[str(sdk)])

    def test_actions_12_cancel_after_sdk_install(self):
        base,env,target=self.prepared('sdk-installed-cancel');target.mkdir(parents=True)
        (target/'keep').write_text('existing kit');before=stand.snapshot(target)
        self.interact(base,env,target,'sdk-install-cancel',130)
        self.assertEqual(stand.snapshot(target),before);self.assertFalse((base/'result.json').exists())
        self.assertTrue((Path(env['SDK_PACKAGE_BIN'])/('node.exe' if stand.WINDOWS else 'node')).exists())
        self.assertEqual(len((base/'package.tsv').read_text().splitlines()),1)

if __name__=='__main__':
    print('work:',stand.BASE,'artifacts:',stand.ARTIFACTS,flush=True)
    names=sys.argv[1:] or [name for name in Actions.__dict__ if name.startswith('test_actions_')]
    result=unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(Actions(name) for name in names))
    (stand.BASE/'sdk-actions-summary.json').write_text(json.dumps({'tests':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),'platform':stand.PLATFORM},indent=2))
    if stand.BASE!=stand.ARTIFACTS:
        def ignore(directory,names):return [n for n in names if n in ('runtime','prepared','.runtime-cache') or n.endswith(('.zip','.tar.gz')) or (Path(directory)/n).is_symlink()]
        shutil.copytree(stand.BASE,stand.ARTIFACTS,ignore=ignore)
    raise SystemExit(0 if result.wasSuccessful() else 1)
