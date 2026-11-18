"""IDE-BOOT-45: real native tools/private setup and actual Mason fixture releases.

Manager fixture is not a language server; gopls and Prettier consumers are real.
No host SDK installation. Uses the same explicit prepared inputs as controls.
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
spec=importlib.util.spec_from_file_location('external_versions',ROOT/'tests/install-tool-versions.test.py')
versions=importlib.util.module_from_spec(spec);spec.loader.exec_module(versions)
stand=versions.stand


class External(versions.Versions):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        deps=Path(os.environ.get('FORGE_E2E_LSP_DEPS',str(ROOT/'.tests/lsp-deps')))
        cls.gopls=deps/json.loads((deps/'manifest.json').read_text())['tools']['gopls']['path']
        node_deps=Path(os.environ.get('FORGE_E2E_NODE_DEPS',str(ROOT/'.tests/node-deps')))
        node_platform=stand.PLATFORM.replace('macos-','darwin-').replace('windows-','win-')
        cls.node=Path(shutil.which('node')) if shutil.which('node') else node_deps/'sdk'/('node-v24.11.0-'+node_platform)/('node.exe' if stand.WINDOWS else 'bin/node')
        cls.prettier=ROOT/'.tests/ide-tools'/stand.PLATFORM/'data'/('fride-data' if stand.WINDOWS else 'fride')/'mason/packages/prettier/node_modules/prettier/bin/prettier.cjs'
        assert cls.gopls.is_file() and cls.prettier.is_file() and cls.node.is_file(),'Prepare existing native gopls/Prettier/Node explicitly first'

    def prepare_external(self,name,names=('gopls',),mixed=False):
        base,env,target=self.prepare_versions('external-'+name)
        self.configure(env,names=list(names)+([versions.NAME] if mixed else []),versions={versions.NAME:'v1.0.0','gopls':'v0.23.0','prettier':'3.9.10'})
        chosen=base/'selected tools with spaces'/('gopls'+versions.SUFFIX)
        chosen.parent.mkdir();shutil.copy2(self.gopls,chosen)
        self.user(env,{'gopls':str(chosen)})
        return base,env,target,chosen

    def configure(self,env,**options):
        path=Path(env['FRIDE_VERSION_CONFIG']);data=json.loads(path.read_text());data.update(options)
        path.write_text(json.dumps(data),encoding='utf-8')

    def user(self,env,tools):
        path=Path(env['XDG_CONFIG_HOME'])/'fride/tools.json';path.parent.mkdir(parents=True,exist_ok=True)
        path.write_text(json.dumps({'tools':tools}),encoding='utf-8');return path

    def setup(self,base,env,target,mode=None):
        (base/'result.json').unlink(missing_ok=True)
        return self.run_process(self.arguments(base,target,mode),env,base,'setup-'+str(len(list(base.glob('setup-*.json')))))

    def mason(self,base):
        info=json.loads((base/'version-report.json').read_text())
        return Path(info['data'])/'mason'

    def assert_external(self,base,target,key,path):
        log=(target/'log/setup-tools.log').read_text(encoding='utf-8')
        line=next(line for line in log.splitlines() if line.startswith('External IDE tools: '))
        entry=next(entry for entry in json.loads(line.split(': ',1)[1]) if entry['key']==key)
        self.assertEqual(Path(entry['path']),path);self.assertIn('user:',entry['source'])
        self.assertFalse((self.mason(base)/'packages'/entry['name']).exists())
        return entry

    def test_external_01_only_ready_gopls_preserve_repeat(self):
        base,env,target,chosen=self.prepare_external('only')
        self.configure(env,empty_path=True)
        before=chosen.read_bytes();settings=(Path(env['XDG_CONFIG_HOME'])/'fride/tools.json').read_bytes();start=len(self.requests)
        self.assert_ok(self.setup(base,env,target));self.assert_external(base,target,'gopls',chosen)
        self.assert_ok(self.setup(base,env,target));self.assert_ok(self.launch(base,env,target))
        self.assertFalse(any('/versions/' in request for request in self.requests[start:]))
        self.assertEqual(chosen.read_bytes(),before);self.assertEqual((Path(env['XDG_CONFIG_HOME'])/'fride/tools.json').read_bytes(),settings)
        result=subprocess.run([str(chosen),'version'],capture_output=True,text=True,timeout=10)
        self.assertEqual(result.returncode,0,result.stderr);self.assertIn('gopls',result.stdout)
        self.assertIn('"packages":0',(target/'log/setup-tools.log').read_text().replace(' ',''))
        self.assertEqual(json.loads((base/'version-report.json').read_text())['go_available'],0)

    def test_external_02_baseline_keeps_user_choice(self):
        base,env,target,chosen=self.prepare_external('baseline');start=len(self.requests)
        self.assert_ok(self.setup(base,env,target,'baseline'));self.assert_external(base,target,'gopls',chosen)
        self.assertFalse(any('/versions/' in request for request in self.requests[start:]))

    def test_external_03_mixed_installs_missing_package(self):
        base,env,target,chosen=self.prepare_external('mixed',mixed=True)
        self.assert_ok(self.setup(base,env,target));self.assert_external(base,target,'gopls',chosen)
        info,_,_=self.observed(base);self.assertEqual(info['version'],'v1.0.0')

    def test_external_04_invalid_path_retains_previous_kit(self):
        base,env,target,chosen=self.prepare_external('invalid');self.assert_ok(self.setup(base,env,target))
        before={name:stand.snapshot(target/name) for name in ('bin','config','runtime')};owner=(target/'.forge-install.json').read_bytes()
        user=self.user(env,{'gopls':str(chosen.parent/'missing-gopls')});start=len(self.requests)
        result=self.setup(base,env,target)
        self.assertNotEqual(result.returncode,0);log=(target/'log/setup-tools.log').read_text()
        self.assertIn('invalid executable',log);self.assertIn(user.as_posix(),log.replace('\\','/'))
        self.assertEqual({name:stand.snapshot(target/name) for name in before},before);self.assertEqual((target/'.forge-install.json').read_bytes(),owner)
        self.assert_ok(self.launch(base,env,target));self.assertFalse(any('/versions/' in request for request in self.requests[start:]))

    def test_external_05_project_settings_do_not_change_setup(self):
        base,env,target,chosen=self.prepare_external('scope')
        project=target/'.fride';project.mkdir(parents=True);(project/'tools.json').write_text('{invalid project settings')
        # An owned not-ready marker permits a target containing only test setup state.
        (target/'.forge-install.json').write_text(json.dumps({'schema':1,'product':'forge-nvim','ready':False}))
        self.assert_ok(self.setup(base,env,target));self.assert_external(base,target,'gopls',chosen)

    def test_external_06_prettier_js_uses_node(self):
        base,env,target,chosen=self.prepare_external('js',names=('prettier',))
        self.user(env,{'prettier':str(self.prettier),'node':str(self.node)})
        self.assert_ok(self.setup(base,env,target));entry=self.assert_external(base,target,'prettier',self.prettier)
        result=subprocess.run(entry['command']+['--version'],capture_output=True,text=True,timeout=10)
        self.assertEqual(result.returncode,0,result.stderr);self.assertEqual(result.stdout.strip(),'3.9.10')

    def test_external_07_invalid_node_never_falls_back(self):
        base,env,target,chosen=self.prepare_external('node-missing',names=('prettier',))
        self.user(env,{'prettier':str(self.prettier),'node':str(chosen.parent/'missing-node')})
        result=self.setup(base,env,target);self.assertNotEqual(result.returncode,0)
        self.assertIn('node',(target/'log/setup-tools.log').read_text());self.assertFalse((target/'bin/fride').exists())

    def test_external_08_existing_mason_payload_is_untouched(self):
        base,env,target,chosen=self.prepare_external('existing')
        self.configure(env,package_name='gopls');self.manual(base,env,'v2.0.0')
        package=self.mason(base)/'packages/gopls';before=stand.snapshot(package);start=len(self.requests)
        self.assert_ok(self.setup(base,env,target,'baseline'));self.assertEqual(stand.snapshot(package),before)
        self.assertFalse(any('/versions/' in request for request in self.requests[start:]))

    def test_external_09_unknown_key_does_not_skip_mason(self):
        base,env,target,chosen=self.prepare_external('unknown',names=(versions.NAME,))
        self.user(env,{versions.NAME:str(chosen)});self.assert_ok(self.setup(base,env,target))
        info,_,_=self.observed(base);self.assertEqual(info['version'],'v1.0.0')

    def test_external_10_replaced_kit_path_is_rejected(self):
        base,env,target,chosen=self.prepare_external('replaced');self.assert_ok(self.setup(base,env,target))
        self.user(env,{'gopls':str(target/'runtime/bin'/('nvim'+versions.SUFFIX))})
        owner=(target/'.forge-install.json').read_bytes();result=self.setup(base,env,target)
        self.assertNotEqual(result.returncode,0);self.assertIn('inside replaced kit runtime',(target/'log/setup-tools.log').read_text())
        self.assertEqual((target/'.forge-install.json').read_bytes(),owner)

    def test_external_11_disappearing_tool_fails_postcondition(self):
        base,env,target,chosen=self.prepare_external('disappears',mixed=True)
        self.configure(env,remove_external=str(chosen))
        result=self.setup(base,env,target);self.assertNotEqual(result.returncode,0)
        self.assertFalse(chosen.exists());self.assertIn('invalid executable',(target/'log/setup-tools.log').read_text())
        self.assertFalse((target/'bin/fride').exists())

    def test_external_12_delve_maps_to_dlv(self):
        base,env,target,chosen=self.prepare_external('delve',names=('delve',))
        tools=Path(os.environ.get('FORGE_E2E_DAP_TOOLS',str(ROOT/'.tests/dap-tools')))
        dlv=tools/'bin'/('dlv'+versions.SUFFIX)
        if not dlv.is_file():dlv=Path(shutil.which('dlv') or dlv)
        self.assertTrue(dlv.is_file(),'Prepare existing native Delve explicitly first')
        self.user(env,{'dlv':str(dlv)});self.assert_ok(self.setup(base,env,target))
        entry=self.assert_external(base,target,'dlv',dlv);self.assertEqual(entry['name'],'delve')
        result=subprocess.run(entry['command']+['version'],capture_output=True,text=True,timeout=10)
        self.assertEqual(result.returncode,0,result.stderr);self.assertIn('Delve',result.stdout)

    def test_external_13_native_mti_invalid_path_finishes(self):
        base,env,target,chosen=self.prepare_external('native-mti')
        self.user(env,{'gopls':str(chosen.parent/'missing-gopls')});self.configure(env,mti_only=True)
        env.update(NVIM_APPNAME='fride',FRIDE_VERSION_SOURCE=str(self.source))
        result=subprocess.run([str(stand.NVIM),'-u','NONE','-i','NONE','--cmd',
            'lua package.path=vim.env.FRIDE_VERSION_SOURCE.."/nvim_forge/lua/?.lua;"..package.path',
            '-l',str(ROOT/'tests/diagnostics/install-tool-versions.lua')],env=env,capture_output=True,text=True,timeout=20)
        (base/'native-mti.json').write_text(json.dumps({'exit':result.returncode,'out':result.stdout,'err':result.stderr}),encoding='utf-8')
        self.assertNotEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertIn('invalid executable',result.stderr);self.assertFalse((self.mason(base)/'packages/gopls').exists())

    def test_external_14_js_without_node_stops_setup(self):
        base,env,target,chosen=self.prepare_external('js-no-node',names=('prettier',))
        self.user(env,{'prettier':str(self.prettier)});self.configure(env,empty_path=True)
        result=self.setup(base,env,target);self.assertNotEqual(result.returncode,0)
        self.assertIn('requires Node',(target/'log/setup-tools.log').read_text());self.assertFalse((target/'bin/fride').exists())


if __name__=='__main__':
    print('work:',stand.BASE,'artifacts:',stand.ARTIFACTS,flush=True)
    names=sys.argv[1:] or sorted(name for name in External.__dict__ if name.startswith('test_external_'))
    result=unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(External(name) for name in names))
    if stand.BASE!=stand.ARTIFACTS:
        def ignore(directory,names):return [name for name in names if name in ('runtime','prepared','.runtime-cache','.ui-cache') or name.endswith(('.zip','.tar.gz')) or (Path(directory)/name).is_symlink()]
        shutil.copytree(stand.BASE,stand.ARTIFACTS,ignore=ignore)
    raise SystemExit(0 if result.wasSuccessful() else 1)
