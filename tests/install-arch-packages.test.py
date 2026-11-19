"""IDE-BOOT-53: native Arch package recipes with controlled manager processes.

No network or host SDK installs. Real package/bootstrap acceptance is separate.
"""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('arch_actions',ROOT/'tests/install-sdk-actions.test.py')
actions=importlib.util.module_from_spec(spec);spec.loader.exec_module(actions)
stand=actions.stand

@unittest.skipUnless(actions.ARCH,'Native Arch family required; Windows/Ubuntu use their existing providers')
class Arch(actions.Actions):
    def calls(self,base):
        rows=[line.split('\t') for line in (base/'package.tsv').read_text().splitlines()]
        for row in rows:
            self.assertEqual(row[:4],['pacman','-S','--needed','--noconfirm'])
            self.assertFalse(set(row)&{'apt-get','-Sy','-Syu','--refresh','--sysupgrade'})
        return rows

    def test_arch_01_default_defers_sdk_with_foreign_manager_present(self):
        base,env,target=self.prepared('arch-deferred')
        args=self.arguments(base,target);args.remove('--prepare-languages')
        self.assert_ok(self.run_process(args,env,base,'install'))
        self.assertFalse((base/'package.tsv').exists())
        result=json.loads((base/'result.json').read_text())
        self.assertFalse(result['prepare_languages'])
        self.assertIn('node',result['components'])

    def test_arch_02_node_uses_native_pacman_without_refresh(self):
        base,env,target=self.prepared('arch-node')
        self.interact(base,env,target,'sdk-install')
        self.assertEqual(self.calls(base),[['pacman','-S','--needed','--noconfirm','nodejs','npm']])

    def test_arch_03_python_and_node_keep_upstream_package_names(self):
        base,env,target=self.prepared('arch-python')
        args=self.arguments(base,target);args[args.index('--components')+1]='python'
        self.pty(base,env,args,'cold-default')
        calls=self.calls(base)
        self.assertEqual(calls,[['pacman','-S','--needed','--noconfirm','python'],
            ['pacman','-S','--needed','--noconfirm','nodejs','npm']])

    def test_arch_04_core_git_uses_pacman(self):
        base,env,target=self.prepared('arch-git')
        (Path(env['SDK_PACKAGE_BIN'])/'git').unlink()
        args=self.binary_args(base,target,preview=False,profile='default',components='core')
        self.pty(base,env,args,'cold-default')
        self.assertEqual(self.calls(base),[['pacman','-S','--needed','--noconfirm','git']])

    def test_arch_05_existing_sdk_is_preserved(self):
        base,env,target=self.prepared('arch-existing')
        sdk=self.sdk(Path(env['SDK_PACKAGE_BIN']));before=stand.snapshot(sdk)
        self.assert_ok(self.run_process(self.arguments(base,target),env,base,'install'))
        self.assertFalse((base/'package.tsv').exists());self.assertEqual(stand.snapshot(sdk),before)

    def test_arch_06_cancel_and_noop_preserve_existing_target(self):
        for scenario,mode in [('sdk-cancel','success'),('sdk-noop','noop')]:
            with self.subTest(scenario=scenario):
                base,env,target=self.prepared('arch-'+scenario);env['SDK_PACKAGE_MODE']=mode
                target.mkdir(parents=True);(target/'keep').write_text('user installation')
                before=stand.snapshot(target);self.interact(base,env,target,scenario,130)
                self.assertEqual(stand.snapshot(target),before);self.assertFalse((base/'result.json').exists())

    def test_arch_07_mise_existing_sdk_context_and_missing_version(self):
        mise=shutil.which('mise')
        if not mise:self.skipTest('Native mise is required for this integration case')
        base,_,_=self.prepared('arch-mise-context')
        env=os.environ.copy()
        for key,part in [('HOME','home'),('USERPROFILE','home'),('XDG_CONFIG_HOME','config'),('XDG_DATA_HOME','data'),
                         ('XDG_STATE_HOME','state'),('XDG_CACHE_HOME','cache'),('TMPDIR','tmp'),('TEMP','tmp'),('TMP','tmp')]:
            folder=base/part;folder.mkdir(exist_ok=True);env[key]=str(folder)
        env.update(NVIM_APPNAME='fride-sdk-context',MISE_DATA_DIR=str(base/'mise'),MISE_OFFLINE='true',
            NVIM_LOG_FILE=str(base/'nvim.log'),PYTHONUTF8='1',PYTHONDONTWRITEBYTECODE='1')
        a=base/'project A';b=base/'project B'
        for project in (a,b):project.mkdir();(project/'.git').mkdir()
        venv=a/'SDK environment'
        self.assert_ok(self.run_process([sys.executable,'-m','venv','--without-pip',str(venv)],env,base,'venv'))
        self.assert_ok(self.run_process([mise,'link','python@fride-local',str(venv)],env,base,'link-existing-python'))
        (a/'mise.toml').write_text('[tools]\npython="fride-local"\n')
        (b/'mise.toml').write_text('[tools]\npython="999.123.0"\n[settings]\nnot_found_system_fallback=false\n')
        for project in (a,b):self.assert_ok(self.run_process([mise,'trust',str(project/'mise.toml')],env,base,'trust-'+project.name))
        self.assert_ok(self.run_process([mise,'reshim'],env,base,'reshim'))
        shims=base/'mise/shims';shim=shims/'python';self.assertTrue(shim.exists())
        env['PATH']=str(shims)+os.pathsep+env['PATH']
        result=base/'mise-sdk-result.json'
        self.assert_ok(self.run_process([str(stand.NVIM),'--headless','-u','NONE','-i','NONE','-l',
            str(ROOT/'tests/diagnostics/mise-sdk-observe.lua'),str(ROOT),str(a),str(b),str(shim),str(venv),str(result)],env,base,'mise-context'))
        self.assertTrue(json.loads(result.read_text())['ready'])
        self.assertFalse((base/'mise/installs/python/999.123.0').exists())

    def test_arch_08_frontend_prefers_mise_without_pacman(self):
        base,env,target=self.prepared('arch-mise-frontend')
        shutil.copy2(self.fixture,Path(env['SDK_PACKAGE_BIN'])/'mise')
        env.update(SDK_MISE_ROOT=str(base/'mise SDK'),SDK_MISE_TRACE=str(base/'mise.tsv'),SDK_MISE_CONFIGURED='1')
        self.interact(base,env,target,'sdk-install')
        self.assertFalse((base/'package.tsv').exists())
        calls=(base/'mise.tsv').read_text().splitlines()
        self.assertIn('install\t--jobs\t2\tnode',calls)
        self.assertNotIn('node@latest','\n'.join(calls))

    def test_arch_09_mise_worker_defaults_errors_and_reuse(self):
        for kind in ('go','rust','python','node'):
            with self.subTest(kind=kind):
                base,env,_=self.prepared('arch-mise-worker-'+kind)
                mise=Path(env['SDK_PACKAGE_BIN'])/'mise';shutil.copy2(self.fixture,mise)
                env.update(SDK_MISE_ROOT=str(base/'mise SDK'),SDK_MISE_TRACE=str(base/'mise.tsv'))
                output=base/'sdk.json'
                args=[str(stand.NVIM),'--headless','-u','NONE','-i','NONE','-l',
                    str(ROOT/'nvim_forge/scripts/install-sdk.lua'),kind,str(output),str(mise)]
                for mode in ('fail','noop','success'):
                    env['SDK_MISE_MODE']=mode
                    result=self.run_process(args,env,base,mode)
                    if mode!='success':
                        self.assertNotEqual(result.returncode,0);self.assertFalse(output.exists())
                    else:self.assert_ok(result)
                report=json.loads(output.read_text());self.assertTrue(report['ready']);self.assertFalse(report['reused'])
                calls=(base/'mise.tsv').read_text().splitlines()
                self.assertEqual(calls.count('install\t--jobs\t2\t'+kind+'@latest'),3)
                output.unlink();self.assert_ok(self.run_process(args,env,base,'reuse'))
                self.assertTrue(json.loads(output.read_text())['reused'])
                self.assertEqual((base/'mise.tsv').read_text().splitlines().count('install\t--jobs\t2\t'+kind+'@latest'),3)
                self.assertFalse((base/'package.tsv').exists())

    def test_arch_10_native_mise_installs_project_node_and_keeps_config(self):
        mise=shutil.which('mise')
        if not mise:self.skipTest('Native Mise required')
        base,_,_=self.prepared('native-mise-install')
        env=os.environ.copy()
        for key,part in [('HOME','home'),('XDG_CONFIG_HOME','config'),('XDG_DATA_HOME','data'),('XDG_CACHE_HOME','cache'),('TMPDIR','tmp')]:
            folder=base/part;folder.mkdir();env[key]=str(folder)
        env.update(MISE_DATA_DIR=str(base/'mise'),NVIM_LOG_FILE=str(base/'nvim.log'),MISE_AUTO_INSTALL='false',
            MISE_EXEC_AUTO_INSTALL='false',MISE_NOT_FOUND_AUTO_INSTALL='false')
        project=base/'project';project.mkdir()
        config=project/'mise.toml';config.write_text('[tools]\nnode="24.11.0"\n[settings]\nnot_found_system_fallback=false\n')
        before=config.read_bytes()
        self.assert_ok(self.run_process([mise,'trust',str(config)],env,project,'trust'))
        shims=base/'mise/shims';shims.mkdir(parents=True,exist_ok=True);(shims/'node').symlink_to(mise)
        env['PATH']=str(shims)+os.pathsep+env['PATH']
        args=[str(stand.NVIM),'--headless','-u','NONE','-i','NONE','-l',str(ROOT/'nvim_forge/scripts/install-sdk.lua'),'node']
        result=base/'first.json'
        self.assert_ok(self.run_process(args+[str(result),mise],env,project,'prepare',cwd=project))
        sdk=json.loads(result.read_text());self.assertFalse(sdk['reused']);self.assertIn('24.11.0',sdk['version'])
        executable=Path(sdk['selection']['tools']['node']);signature=executable.read_bytes()
        second=base/'second.json'
        self.assert_ok(self.run_process(args+[str(second),mise],env,project,'reuse',cwd=project))
        self.assertTrue(json.loads(second.read_text())['reused']);self.assertEqual(signature,executable.read_bytes())
        self.assertEqual(config.read_bytes(),before)
        self.assertFalse((Path(env['XDG_CONFIG_HOME'])/'mise/config.toml').exists())
        self.assertFalse((Path(env['HOME'])/'sdk').exists())
        (base/'native-mise-result.json').write_text(json.dumps({'ready':True,'version':sdk['version'],'config_preserved':True,'existing_sdk_preserved':True}))

if __name__=='__main__':
    print('work:',stand.BASE,flush=True)
    names=sys.argv[1:] or [name for name in Arch.__dict__ if name.startswith('test_arch_')]
    result=unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(Arch(name) for name in names))
    (stand.BASE/'arch-packages-summary.json').write_text(json.dumps({'tests':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),'skipped':len(result.skipped)}))
    raise SystemExit(0 if result.wasSuccessful() else 1)
