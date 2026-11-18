"""IDE-BOOT-14 IDE-BOOT-35: HTTP selected parts -> private IDE parts + native Neovim/host Node/npm.

Init/setup and the feature-marker module are fixtures; this is delivery E2E,
not full language/plugin readiness or Terminal GUI acceptance. The Terminal part is a controlled IDE library fixture. No downloads outside localhost/host installs.
"""
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import sys
import tarfile
import unittest
import zipfile

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('ui',ROOT/'tests/install-ui.test.py')
ui=importlib.util.module_from_spec(spec);spec.loader.exec_module(ui)
stand=ui.stand


class Runtime(ui.UI):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.routes['/runtime-core']=cls.archive.read_bytes()
        os_name,arch=stand.PLATFORM.split('-')
        node_os={'windows':'win','macos':'darwin','linux':'linux'}[os_name]
        node_deps=Path(os.environ.get('FORGE_E2E_NODE_DEPS',str(ROOT/'.tests/node-deps')))
        sdk=Path(os.environ.get('FORGE_INSTALL_NODE_SDK',str(node_deps/'sdk'/('node-v24.11.0-'+node_os+'-'+arch))))
        assert sdk.is_dir(),'Prepared Node SDK required; stand never installs/downloads it'
        cls.node_sdk=sdk
        feature=stand.BASE/'node-feature-source';feature.mkdir()
        (feature/'node-feature.txt').write_text('fixture IDE library, not a language SDK\n')
        (feature/'node-tool.js').write_text('console.log("fride IDE tool fixture")\n')
        # Controlled Terminal CLI for transport tests, not a GUI/font acceptance.
        # Real WezTerm/font delivery is covered by install-terminal-runtime.test.py.
        shutil.copyfile(ROOT/'wezterm.lua',cls.source/'wezterm.lua')
        terminal=feature/'terminal';(terminal/'bin').mkdir(parents=True)
        stub=stand.BASE/'terminal-cli-fixture.rs'
        stub.write_text('fn main() { let p=std::env::current_exe().unwrap(); println!("{}",p.parent().unwrap().parent().unwrap().join("fonts/CaskaydiaCoveNerdFont-Regular.ttf").display()); }')
        exe='bin/wezterm-fixture'+('.exe' if stand.WINDOWS else '')
        subprocess_env=dict(os.environ,RUSTUP_AUTO_INSTALL='0')
        import subprocess
        subprocess.run([shutil.which('rustc'),str(stub),'-o',str(terminal/exe)],env=subprocess_env,check=True,capture_output=True)
        policy={'wezterm':{'platforms':{stand.PLATFORM:{'executable':exe}}}}
        (terminal/'prepared.json').write_text(json.dumps({'platform':stand.PLATFORM,'policy':policy}))
        cls.feature_recipe={'schema':1,'platform':stand.PLATFORM,'components':['terminal'],'paths':[],'probes':[]}
        cls.good_feature=cls.component_archive('terminal',feature,cls.feature_recipe)
        cls.routes['/runtime-terminal']=cls.good_feature
        cls.catalog()

    @classmethod
    def component_archive(cls,id,source,recipe):
        path=stand.BASE/(id+'-recipe.json');path.write_text(json.dumps(recipe),encoding='utf-8')
        archive=stand.BASE/(id+('.zip' if stand.WINDOWS else '.tar.gz'))
        stand.packager.package(source,path,archive,component=id)
        return archive.read_bytes()

    @classmethod
    def catalog(cls,changes=None,extra='',omit=()):
        rows=[]
        for id in ['core','terminal']:
            if id in omit:continue
            payload=cls.routes['/runtime-'+id]
            fields=[stand.PLATFORM,id,cls.url+'/runtime-'+id,hashlib.sha256(payload).hexdigest()]
            for index,value in (changes or {}).get(id,{}).items():fields[index]=value
            rows.append('\t'.join(fields))
        (cls.source/'scripts/runtime/artifacts.tsv').write_text('\n'.join(rows)+'\n'+extra,encoding='utf-8')
        cls.publish_source(cls.ui_digest)

    def tearDown(self):
        self.routes['/runtime-terminal']=self.good_feature
        self.catalog()

    def install_auto(self,base,env,target,components='node,terminal'):
        start=len(self.requests)
        result=self.root_entry(base,env,target,components,runtime=False)
        (base/'http.json').write_text(json.dumps(self.requests[start:],indent=2),encoding='utf-8')
        return result

    def prepare(self,name):
        base,env,target=super().prepare(name)
        node_bin=self.node_sdk if stand.WINDOWS else self.node_sdk/'bin'
        env['PATH']=str(node_bin)+os.pathsep+env['PATH']
        return base,env,target

    def observe_node(self,base,env,target):
        observer=base/'observe.lua'
        observer.write_text("""local node=vim.fn.exepath('node')
local version=vim.system({node,'--version'},{text=true}):wait()
local tool=vim.system({node,vim.env.FORGE_NODE_TOOL},{text=true}):wait()
vim.fn.writefile({vim.json.encode({node=node,version=version.stdout,tool=tool.stdout,codes={version.code,tool.code}})},vim.env.FORGE_NODE_REPORT)
assert(version.code==0 and tool.code==0)
""",encoding='utf-8')
        env.update(FORGE_NODE_TOOL=str(target/'runtime/node-tool.js'),FORGE_NODE_REPORT=str(base/'node.json'))
        command=([stand.SHELL,'-NoProfile','-ExecutionPolicy','Bypass','-File',str(target/'bin/fride.ps1')] if stand.WINDOWS else [stand.SHELL,str(target/'bin/fride')])
        self.assert_ok(self.run_process(command+['--headless','-u','NONE','-i','NONE','-l',str(observer)],env,base,'observe'))
        proof=json.loads((base/'node.json').read_text(encoding='utf-8'))
        self.assertTrue(Path(proof['node']).resolve().is_relative_to(self.node_sdk.resolve()))
        self.assertFalse(Path(proof['node']).resolve().is_relative_to((target/'runtime').resolve()))
        self.assertEqual(proof['version'].strip(),'v24.11.0');self.assertEqual(proof['tool'].strip(),'fride IDE tool fixture');self.assertEqual(proof['codes'],[0,0])

    @classmethod
    def mutate(cls,payload,edit,extra=None):
        output=io.BytesIO()
        if stand.WINDOWS:
            with zipfile.ZipFile(io.BytesIO(payload)) as src,zipfile.ZipFile(output,'w',compression=zipfile.ZIP_DEFLATED) as dst:
                for info in src.infolist():
                    raw=src.read(info.filename)
                    if info.filename=='forge-component.json':raw=json.dumps(edit(json.loads(raw))).encode()
                    dst.writestr(info,raw)
                if extra:dst.writestr(extra,b'foreign\n')
        else:
            with tarfile.open(fileobj=io.BytesIO(payload),mode='r:gz') as src,tarfile.open(fileobj=output,mode='w:gz') as dst:
                for info in src:
                    raw=src.extractfile(info).read() if info.isfile() else b''
                    if info.name in ('forge-component.json','./forge-component.json'):
                        raw=json.dumps(edit(json.loads(raw))).encode();info.size=len(raw)
                    dst.addfile(info,io.BytesIO(raw) if info.isfile() else None)
                if extra:
                    info=tarfile.TarInfo(extra);info.size=8;info.mode=0o644;dst.addfile(info,io.BytesIO(b'foreign\n'))
        return output.getvalue()

    def assert_failed(self,result,base,target,reason):
        self.assertNotEqual(result.returncode,0,result.stdout+result.stderr)
        logs='\n'.join(p.read_text(encoding='utf-8',errors='replace') for p in (base/'sources/.ui-logs').glob('*.log'))
        self.assertIn(reason,result.stdout+result.stderr+logs)
        self.assertFalse((target/'bin/fride').exists());self.assertFalse((target/'bin/fride.cmd').exists())

    def test_runtime_01_core_only(self):
        base,env,target=self.prepare('runtime-core')
        self.assert_ok(self.install_auto(base,env,target,'core'));self.assert_ok(self.launch(base,env,target))
        requests=json.loads((base/'http.json').read_text());self.assertIn('/runtime-core',requests)
        self.assertNotIn('/runtime-terminal',requests);self.assertNotIn('/runtime-node-runtime',requests)

    def test_runtime_02_dependency_install_repeat(self):
        base,env,target=self.prepare('runtime-node')
        self.assert_ok(self.install_auto(base,env,target));self.observe_node(base,env,target)
        paths=json.loads((base/'http.json').read_text());self.assertEqual([p for p in paths if p.startswith('/runtime-')],['/runtime-core','/runtime-terminal'])
        self.assert_ok(self.install_auto(base,env,target));self.observe_node(base,env,target)
        self.assertFalse(any(p.startswith('/runtime-') for p in json.loads((base/'http.json').read_text())))
        manifest=json.loads((target/'runtime/forge-runtime.json').read_text());self.assertEqual(manifest['components'],['core','terminal'])

    def test_runtime_03_missing_selected(self):
        base,env,target=self.prepare('runtime-missing');self.catalog(omit=('terminal',))
        result=self.install_auto(base,env,target);self.assert_failed(result,base,target,'terminal')
        self.assertFalse(target.exists())
        self.assertEqual([p for p in json.loads((base/'http.json').read_text()) if p.startswith('/runtime-')],['/runtime-core'])

    def test_runtime_04_duplicate_catalog(self):
        base,env,target=self.prepare('runtime-duplicate')
        line=(self.source/'scripts/runtime/artifacts.tsv').read_text().splitlines()[0]
        self.catalog(extra=line+'\n');self.assert_failed(self.install_auto(base,env,target),base,target,'Duplicate IDE artifact')
        self.assertFalse(target.exists())

    def test_runtime_05_bad_archive_sha(self):
        base,env,target=self.prepare('runtime-sha');self.catalog(changes={'terminal':{3:'0'*64}})
        self.assert_failed(self.install_auto(base,env,target),base,target,'Runtime archive SHA256 mismatch')
        self.assertFalse(target.exists())

    def invalid_feature(self,name,edit,reason,extra=None):
        base,env,target=self.prepare(name)
        self.routes['/runtime-terminal']=self.mutate(self.good_feature,edit,extra);self.catalog()
        self.assert_failed(self.install_auto(base,env,target),base,target,reason)
        self.assertFalse(target.exists())

    def test_runtime_06_wrong_platform(self):
        self.invalid_feature('runtime-platform',lambda m:dict(m,platform='other-x64'),'Invalid component manifest')

    def test_runtime_07_wrong_component(self):
        self.invalid_feature('runtime-component',lambda m:dict(m,components=['sql']),'Invalid component manifest')

    def test_runtime_08_untracked_file(self):
        self.invalid_feature('runtime-untracked',lambda m:m,'Untracked component file',extra='untracked.txt')

    def test_runtime_09_manifest_file_sha(self):
        self.invalid_feature('runtime-file-sha',lambda m:dict(m,files={'node-feature.txt':'0'*64}),'Component SHA256 mismatch')

    def test_runtime_10_conflict_keeps_previous(self):
        base,env,target=self.prepare('runtime-conflict');self.assert_ok(self.install_auto(base,env,target))
        previous=stand.snapshot(target/'bin')
        source=stand.BASE/'conflict-part';source.mkdir();(source/'nvim.sha256').write_text('collision\n')
        self.routes['/runtime-terminal']=self.component_archive('terminal',source,self.feature_recipe);self.catalog()
        result=self.install_auto(base,env,target);self.assertNotEqual(result.returncode,0)
        logs='\n'.join(p.read_text(encoding='utf-8',errors='replace') for p in (base/'sources/.ui-logs').glob('*.log'))
        self.assertIn('Runtime file conflict',logs);self.assertEqual(stand.snapshot(target/'bin'),previous)
        self.observe_node(base,env,target)

    def test_runtime_11_invalid_catalog_url(self):
        base,env,target=self.prepare('runtime-url');self.catalog(changes={'terminal':{2:'file:///untrusted'}})
        self.assert_failed(self.install_auto(base,env,target),base,target,'Invalid IDE artifact catalog')
        self.assertFalse(target.exists())

    def test_runtime_12_cached_file_corruption(self):
        base,env,target=self.prepare('runtime-cache-corrupt');self.assert_ok(self.install_auto(base,env,target))
        digest=hashlib.sha256(self.good_feature).hexdigest()
        (base/'sources/.runtime-cache'/digest/'node-feature.txt').write_text('corrupted cache\n')
        result=self.install_auto(base,env,target);self.assertNotEqual(result.returncode,0)
        logs='\n'.join(p.read_text(encoding='utf-8',errors='replace') for p in (base/'sources/.ui-logs').glob('*.log'))
        self.assertIn('Component SHA256 mismatch',logs);self.observe_node(base,env,target)

    def test_runtime_13_file_directory_conflict(self):
        base,env,target=self.prepare('runtime-directory-conflict')
        source=stand.BASE/'directory-conflict';source.mkdir();(source/'bin').write_text('not a directory\n')
        self.routes['/runtime-terminal']=self.component_archive('terminal',source,self.feature_recipe);self.catalog()
        self.assert_failed(self.install_auto(base,env,target),base,target,'Runtime file conflict')
        self.assertFalse(target.exists())

    def test_runtime_14_target_inside_part(self):
        base,env,target=self.prepare('runtime-target-part');self.assert_ok(self.install_auto(base,env,target))
        digest=hashlib.sha256(self.good_feature).hexdigest()
        overlapping=base/'sources/.runtime-cache'/digest/'new-kit'
        result=self.install_auto(base,env,overlapping)
        self.assert_failed(result,base,overlapping,'Install target overlaps component runtime')
        self.assertFalse(overlapping.exists());self.observe_node(base,env,target)

    def test_runtime_15_default_requires_complete_catalog(self):
        base,env,target=self.prepare('runtime-default-gate');self.catalog(omit=('terminal',))
        import subprocess
        rustc=(Path(os.environ['USERPROFILE'])/'.rustup/toolchains/stable-x86_64-pc-windows-msvc/bin/rustc.exe') if stand.WINDOWS else 'rustc'
        sdk=Path(subprocess.check_output([str(rustc),'--print','sysroot'],env=dict(os.environ,RUSTUP_AUTO_INSTALL='0'),text=True).strip())
        env['PATH']=str(sdk/'bin')+os.pathsep+env['PATH']
        before=len(self.requests)
        result=self.run_process([str(ui.BINARY),'--source',str(self.source),'--install-dir',str(target),
            '--profile','default','--log-dir',str(base/'logs')],env,base,'default')
        self.assertNotEqual(result.returncode,0);self.assertIn('IDE artifacts not published',result.stderr)
        missing=result.stderr.split('IDE artifacts not published',1)[1]
        self.assertIn('terminal',missing);self.assertNotIn('go,',missing);self.assertNotIn('rust,',missing)
        self.assertFalse(target.exists())
        self.assertFalse((base/'stages.txt').exists());self.assertTrue(all(p=='/runtime-core' for p in self.requests[before:]))


    def test_runtime_16_no_sdk_artifacts(self):
        base,env,target=self.prepare('obsolete-sdk-part')
        self.catalog(extra=stand.PLATFORM+'\tnode-runtime\t'+self.url+'/must-not-download-sdk\t'+'f'*64+'\n')
        start=len(self.requests)
        self.assert_failed(self.install_auto(base,env,target),base,target,'cannot be a private IDE artifact')
        self.assertFalse(any(p.startswith('/runtime-') or p=='/must-not-download-sdk' for p in self.requests[start:]))
        recipe=base/'sdk-recipe.json';recipe.write_text(json.dumps(dict(self.feature_recipe,components=['node-runtime'])))
        with self.assertRaisesRegex(ValueError,'Native SDK'):
            stand.packager.package(stand.BASE/'node-feature-source',recipe,base/'forbidden.zip',component='node-runtime')

    def test_runtime_17_basic_languages_need_only_core_archive(self):
        base,env,target=self.prepare('basic-language-assets');self.catalog(omit=('terminal',))
        self.assert_ok(self.install_auto(base,env,target,'sql,bash'))
        requests=json.loads((base/'http.json').read_text())
        self.assertEqual([p for p in requests if p.startswith('/runtime-')],['/runtime-core'])
        meta=json.loads((target/'runtime/forge-runtime.json').read_text())
        self.assertEqual(meta['components'],['core'])
        self.assertFalse((target/'runtime/sql').exists())
        self.assert_ok(self.launch(base,env,target))

if __name__=='__main__':
    print('work:',stand.BASE,'artifacts:',stand.ARTIFACTS,flush=True)
    names=sys.argv[1:] or [name for name in dir(Runtime) if name.startswith('test_runtime_')]
    result=unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(Runtime(name) for name in names))
    (stand.BASE/'runtime-summary.json').write_text(json.dumps({'tests':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),'platform':stand.PLATFORM,'fixture_setup':True,'ui_sha256':hashlib.sha256(ui.BINARY.read_bytes()).hexdigest()},indent=2))
    if stand.BASE!=stand.ARTIFACTS:
        def ignore(directory,names):return [n for n in names if n in ('runtime','prepared','.runtime-cache','.ui-cache','node-runtime-source') or n.endswith(('.zip','.tar.gz')) or (Path(directory)/n).is_symlink()]
        shutil.copytree(stand.BASE,stand.ARTIFACTS,ignore=ignore)
    raise SystemExit(0 if result.wasSuccessful() else 1)
