"""IDE-BOOT-18: actual native frontend/probes and bounded fixture SDKs, offline."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('ui',ROOT/'tests/install-ui.test.py')
ui=importlib.util.module_from_spec(spec);spec.loader.exec_module(ui);stand=ui.stand

class Prerequisites(ui.UI):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        node_os={'windows':'win','linux':'linux','macos':'darwin'}[stand.PLATFORM.split('-')[0]]
        cls.node_sdk=Path(os.environ.get('FORGE_E2E_NODE_DEPS',str(ROOT/'.tests/node-deps')))/'sdk'/('node-v24.11.0-'+node_os+'-'+stand.PLATFORM.split('-')[-1])
        cls.node_bin=cls.node_sdk if stand.WINDOWS else cls.node_sdk/'bin'
        assert cls.node_bin.is_dir(),'Prepared Node SDK required, no downloads'
        rustc=(Path(os.environ['USERPROFILE'])/'.rustup/toolchains/stable-x86_64-pc-windows-msvc/bin/rustc.exe') if stand.WINDOWS else shutil.which('rustc')
        sdk=Path(subprocess.check_output([str(rustc),'--print','sysroot'],env=dict(os.environ,RUSTUP_AUTO_INSTALL='0'),text=True).strip())
        cls.fixture=stand.BASE/('fixture.exe' if stand.WINDOWS else 'fixture')
        args=[str(sdk/'bin'/('rustc.exe' if stand.WINDOWS else 'rustc')),'--edition=2021',str(ROOT/'tests/diagnostics/sdk-probe-fixture.rs'),'-o',str(cls.fixture)]
        if stand.WINDOWS:args+=['-C','target-feature=+crt-static']
        subprocess.run(args,check=True,cwd=stand.BASE)
        with (cls.source/'nvim_forge/scripts/setup-stage.lua').open('a',encoding='utf-8') as f:
            f.write("\nif vim.env.FORGE_SDK_SETUP_ENV then vim.fn.writefile({vim.json.encode({go=vim.env.GOTOOLCHAIN,rust=vim.env.RUSTUP_AUTO_INSTALL})},vim.env.FORGE_SDK_SETUP_ENV,'a') end\n")

    def fixture_path(self,base,*names):
        folder=base/'SDK tools';folder.mkdir(exist_ok=True)
        for name in names:shutil.copy2(self.fixture,folder/(name+('.exe' if stand.WINDOWS else '')))
        return folder

    def invoke(self,base,env,target,components='node',check=True,extra=()):
        report=base/('sdk-'+str(time.time_ns())+'.json')
        args=[str(ui.BINARY),'--source',str(self.source),'--install-dir',str(target),'--components',components,
              '--log-dir',str(base/'logs'),'--sdk-report',str(report)]
        if check:args+=['--check-sdks']
        result=self.run_process(args+list(extra),env,base,'sdk-driver-'+str(time.time_ns()))
        return result,json.loads(report.read_text(encoding='utf-8')) if report.exists() else None

    def test_sdk_01_split_plan_and_preview(self):
        base,env,target=self.prepare('sdk-preview');folder=self.fixture_path(base,'go')
        env.update(PATH=str(folder),SDK_PROBE_MARKER=str(base/'marker'))
        result=self.run_process([str(ui.BINARY),'--source',str(self.source),'--print-plan','--components','go,node'],env,base,'plan')
        self.assert_ok(result);plan=json.loads(result.stdout)
        self.assertEqual(plan['components'],['core','go','node']);self.assertEqual(plan['native_sdks'],['go','node'])
        result,_=self.invoke(base,env,target,'go',False,('--preview',))
        self.assert_ok(result);self.assertFalse((base/'marker').exists());self.assertFalse(target.exists());self.assertFalse((base/'logs').exists())

    def test_sdk_02_native_node_ready(self):
        base,env,target=self.prepare('sdk-node');env['PATH']=str(self.node_bin)
        start=len(self.requests);result,report=self.invoke(base,env,target)
        self.assert_ok(result);self.assertEqual(report,json.loads(result.stdout));sdk=report['sdks'][0]
        self.assertEqual((sdk['id'],sdk['status']),('node','ready'))
        node=sdk['tools'][0];self.assertTrue(Path(node['path']).is_relative_to(self.node_sdk));self.assertEqual(node['version'],'v24.11.0')
        self.assertFalse(target.exists());self.assertEqual(self.requests[start:],[])

    def test_sdk_03_missing_does_not_touch_existing_kit(self):
        base,env,target=self.prepare('sdk-missing');env['PATH']=str(base/'no-SDK')
        target.mkdir(parents=True);(target/'keep').write_text('existing kit');before=stand.snapshot(target)
        start=len(self.requests);result,report=self.invoke(base,env,target,check=False)
        self.assertNotEqual(result.returncode,0);self.assertIn('SDK prerequisites',result.stderr)
        self.assertEqual(report['sdks'][0]['status'],'missing');self.assertEqual(stand.snapshot(target),before)
        self.assertFalse((base/'stages.txt').exists());self.assertEqual(self.requests[start:],[])

    def test_sdk_04_wrong_version_and_nonzero(self):
        base,env,target=self.prepare('sdk-broken');env['PATH']=str(self.fixture_path(base,'go'))
        for mode in ['invalid','exit']:
            env['SDK_PROBE_MODE']=mode;result,report=self.invoke(base,env,target,'go')
            self.assertEqual(result.returncode,2);self.assertEqual(report['sdks'][0]['status'],'unavailable')
        self.assertFalse(target.exists())

    def test_sdk_05_timeout(self):
        base,env,target=self.prepare('sdk-timeout');env.update(PATH=str(self.fixture_path(base,'go')),SDK_PROBE_MODE='timeout')
        start=time.monotonic();result,report=self.invoke(base,env,target,'go');elapsed=time.monotonic()-start
        self.assertEqual(result.returncode,2);self.assertLess(elapsed,7)
        self.assertIn('timeout',report['sdks'][0]['tools'][0]['detail']);self.assertFalse(target.exists())

    def test_sdk_06_probe_disables_auto_download_only_in_child(self):
        base,env,target=self.prepare('sdk-env');env.update(PATH=str(self.fixture_path(base,'go')),GOTOOLCHAIN='owner-choice',RUSTUP_AUTO_INSTALL='1',SDK_PROBE_MARKER=str(base/'marker'))
        result,report=self.invoke(base,env,target,'go');self.assert_ok(result)
        self.assertEqual(report['sdks'][0]['status'],'ready');self.assertEqual((base/'marker').read_text().splitlines(),['go','local','0'])
        self.assertEqual((env['GOTOOLCHAIN'],env['RUSTUP_AUTO_INSTALL']),('owner-choice','1'))

    def test_sdk_07_python3_fallback(self):
        base,env,target=self.prepare('sdk-python');folder=self.fixture_path(base,'python','python3')
        env['PATH']=str(folder)+os.pathsep+str(self.node_bin)
        result,report=self.invoke(base,env,target,'python');self.assert_ok(result)
        python=report['sdks'][0];self.assertEqual(python['id'],'python');self.assertEqual(python['tools'][0]['command'],'python3');self.assertEqual(python['status'],'ready')

    def test_sdk_08_setup_disables_auto_download(self):
        base,env,target=self.prepare('sdk-setup');env.update(GOTOOLCHAIN='owner-choice',RUSTUP_AUTO_INSTALL='1',FORGE_SDK_SETUP_ENV=str(base/'setup-env.jsonl'))
        result,_=self.invoke(base,env,target,'core',False,('--runtime-path',str(self.runtime)))
        self.assert_ok(result);values=[json.loads(line) for line in (base/'setup-env.jsonl').read_text().splitlines()]
        self.assertEqual(values,[{'go':'local','rust':'0'}]*3)
        self.assertEqual((env['GOTOOLCHAIN'],env['RUSTUP_AUTO_INSTALL']),('owner-choice','1'))

    @unittest.skipUnless(stand.WINDOWS,'Windows Store aliases')
    def test_sdk_09_store_alias_not_launched(self):
        base,env,target=self.prepare('sdk-store');folder=base/'Microsoft/WindowsApps';folder.mkdir(parents=True)
        shutil.copy2(self.fixture,folder/'python.exe');env.update(PATH=str(folder)+os.pathsep+str(self.node_bin),SDK_PROBE_MARKER=str(base/'marker'))
        result,report=self.invoke(base,env,target,'python');self.assertEqual(result.returncode,2)
        self.assertEqual(report['sdks'][0]['status'],'missing');self.assertFalse((base/'marker').exists())

    def test_sdk_11_active_venv_path(self):
        base,env,target=self.prepare('sdk-venv');venv=base/'project/.venv'
        self.assert_ok(self.run_process([sys.executable,'-m','venv','--without-pip',str(venv)],env,base,'create-venv'))
        env.update(VIRTUAL_ENV=str(venv),PATH=str(venv/('Scripts' if stand.WINDOWS else 'bin'))+os.pathsep+str(self.node_bin))
        result,report=self.invoke(base,env,target,'python');self.assert_ok(result)
        python=report['sdks'][0]['tools'][0]
        self.assertTrue(Path(python['path']).is_relative_to(venv),'Resolving the Python symlink would discard its venv')
        self.assertTrue(python['version'].startswith('Python 3.'))

    def test_sdk_10_default_requires_sdk_decision(self):
        base,env,target=self.prepare('sdk-default');env['PATH']=str(base/'no-SDK')
        result=self.run_process([str(ui.BINARY),'--source',str(self.source),'--install-dir',str(target),'--profile','default','--log-dir',str(base/'logs')],env,base,'default')
        self.assertNotEqual(result.returncode,0);self.assertIn('SDK prerequisites',result.stderr)
        report=json.loads(next((base/'logs').glob('sdks-*.json')).read_text())
        self.assertEqual([sdk['id'] for sdk in report['sdks']],['go','rust','python','node'])
        self.assertTrue(all(sdk['status']=='missing' for sdk in report['sdks']));self.assertFalse(target.exists());self.assertFalse((base/'stages.txt').exists())

if __name__=='__main__':
    print('work:',stand.BASE,'artifacts:',stand.ARTIFACTS,flush=True)
    names=sys.argv[1:] or [name for name in Prerequisites.__dict__ if name.startswith('test_sdk_')]
    result=unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(Prerequisites(name) for name in names))
    (stand.BASE/'prerequisites-summary.json').write_text(json.dumps({'tests':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),'platform':stand.PLATFORM},indent=2))
    if stand.BASE!=stand.ARTIFACTS:
        def ignore(directory,names):return [n for n in names if n in ('runtime','prepared','.runtime-cache') or n.endswith(('.zip','.tar.gz')) or (Path(directory)/n).is_symlink()]
        shutil.copytree(stand.BASE,stand.ARTIFACTS,ignore=ignore)
    raise SystemExit(0 if result.wasSuccessful() else 1)
