"""IDE-BOOT-43: native frontend/Mason/releases, real self-versioned fixture binaries."""
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import unittest
import zipfile

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('versions_ui',ROOT/'tests/install-ui.test.py')
ui=importlib.util.module_from_spec(spec);spec.loader.exec_module(ui);stand=ui.stand
NAME='fride-version-fixture';SUFFIX='.exe' if stand.WINDOWS else ''


class Versions(ui.UI):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.deps=Path(os.environ.get('FORGE_E2E_DEPS',str(ROOT/'.tests/editor-deps')))
        for version in ['v1.0.0','v2.0.0']:
            folder=stand.BASE/version;folder.mkdir();source=folder/'fixture.rs'
            source.write_text('fn main() { println!("'+version+'"); }')
            binary=folder/(NAME+SUFFIX)
            subprocess.run([shutil.which('rustc'),str(source),'-o',str(binary)],check=True,
                env=dict(os.environ,RUSTUP_AUTO_INSTALL='0'),capture_output=True)
            output=io.BytesIO()
            with zipfile.ZipFile(output,'w',compression=zipfile.ZIP_DEFLATED) as archive:
                info=zipfile.ZipInfo(NAME+SUFFIX);info.external_attr=(0o100755<<16)
                archive.writestr(info,binary.read_bytes())
            cls.routes['/versions/fride/version-fixture/'+version+'/fixture.zip']=output.getvalue()
        for name in ['setup_readiness']:
            shutil.copyfile(ROOT/f'nvim_forge/lua/forge/{name}.lua',cls.source/f'nvim_forge/lua/forge/{name}.lua')
        cls.stage=cls.source/'nvim_forge/scripts/setup-tools-production.lua'
        shutil.copyfile(ROOT/'nvim_forge/scripts/setup-stage.lua',cls.stage)
        (cls.source/'nvim_forge/scripts/setup-stage.lua').write_text(stand.STAGE+'''
if arg[1]=='tools' then dofile(vim.env.FRIDE_VERSION_HELPER) end
''',encoding='utf8')
        cls.publish_source(cls.ui_digest)

    def prepare_versions(self,name):
        base,env,target=self.prepare(name)
        config=base/'versions.json';report=base/'version-report.json'
        config.write_text(json.dumps({'deps':str(self.deps),'url':self.url+'/versions','stage':str(self.stage),'report':str(report)}))
        env.update(FRIDE_VERSION_CONFIG=str(config),FRIDE_VERSION_HELPER=str(ROOT/'tests/diagnostics/install-tool-versions.lua'),
            FRIDE_TOOLS_VERSIONS='baseline')  # Parent choice must not override default.
        return base,env,target

    def arguments(self,base,target,mode=None,preview=False):
        args=self.binary_args(base,target,preview=preview,profile='default',components='core')+['--no-color']
        if mode is not None:args+=['--tools-versions',mode]
        return args

    def manual(self,base,env,version):
        path=Path(env['FRIDE_VERSION_CONFIG']);data=json.loads(path.read_text());data['manual']=version;path.write_text(json.dumps(data))
        command=[str(stand.NVIM),'-u','NONE','-i','NONE','--cmd',
            'lua package.path=vim.env.FRIDE_VERSION_SOURCE.."/nvim_forge/lua/?.lua;"..package.path',
            '-l',str(ROOT/'tests/diagnostics/install-tool-versions.lua')]
        self.assert_ok(self.run_process(command,dict(env,NVIM_APPNAME='fride',FRIDE_VERSION_SOURCE=str(self.source)),base,'manual-'+version))
        data.pop('manual');path.write_text(json.dumps(data))

    def observed(self,base):
        info=json.loads((base/'version-report.json').read_text())
        package=Path(info['data'])/'mason/packages'/NAME
        binary=package/(NAME+SUFFIX)
        result=subprocess.run([str(binary)],capture_output=True,text=True,timeout=10)
        self.assertEqual(result.returncode,0,result.stderr);self.assertEqual(result.stdout.strip(),info['version'])
        return info,package,binary

    def test_versions_01_missing_gets_baseline(self):
        base,env,target=self.prepare_versions('versions-missing')
        self.assert_ok(self.run_process(self.arguments(base,target),env,base,'install'))
        info,_,_=self.observed(base);self.assertEqual(info['version'],'v1.0.0');self.assertEqual(info['policy'],'preserve')

    def test_versions_02_manual_version_survives_repeat(self):
        base,env,target=self.prepare_versions('versions-preserve');self.manual(base,env,'v2.0.0')
        _,package,binary=self.observed(base);payload=binary.read_bytes();receipt=(package/'mason-receipt.json').read_bytes()
        before=len(self.requests)
        self.assert_ok(self.run_process(self.arguments(base,target),env,base,'preserve'))
        info,package,binary=self.observed(base);self.assertEqual(info['version'],'v2.0.0')
        self.assertEqual(binary.read_bytes(),payload);self.assertEqual((package/'mason-receipt.json').read_bytes(),receipt)
        self.assertFalse(any('/versions/' in p for p in self.requests[before:]))
        self.assertEqual(json.loads((base/'result.json').read_text())['tools_versions'],'preserve')

    def test_versions_03_explicit_baseline_restores_v1(self):
        base,env,target=self.prepare_versions('versions-baseline');self.manual(base,env,'v2.0.0')
        self.assert_ok(self.run_process(self.arguments(base,target,'baseline'),env,base,'baseline'))
        info,_,_=self.observed(base);self.assertEqual(info['version'],'v1.0.0')
        self.assertEqual(json.loads((base/'result.json').read_text())['tools_versions'],'baseline')

    def test_versions_04_preserve_rejects_broken_export(self):
        base,env,target=self.prepare_versions('versions-broken');self.manual(base,env,'v2.0.0')
        info,package,binary=self.observed(base);binary.unlink();before=len(self.requests)
        result=self.run_process(self.arguments(base,target),env,base,'broken')
        self.assertNotEqual(result.returncode,0);self.assertIn('declared bin source missing',(target/'log/setup-tools.log').read_text())
        self.assertFalse(json.loads((target/'.forge-install.json').read_text())['ready'])
        self.assertFalse(any('/versions/' in p for p in self.requests[before:]))

    def test_versions_05_preserve_rejects_broken_receipt(self):
        base,env,target=self.prepare_versions('versions-receipt');self.manual(base,env,'v2.0.0')
        _,package,_=self.observed(base);path=package/'mason-receipt.json';data=json.loads(path.read_text());data['name']='another-package';path.write_text(json.dumps(data))
        result=self.run_process(self.arguments(base,target),env,base,'receipt')
        self.assertNotEqual(result.returncode,0);self.assertIn('receipt names another package',(target/'log/setup-tools.log').read_text())

    def test_versions_06_preview_does_not_restore(self):
        base,env,target=self.prepare_versions('versions-preview');self.manual(base,env,'v2.0.0')
        _,package,binary=self.observed(base);before=stand.snapshot(package)
        self.assert_ok(self.run_process(self.arguments(base,target,'baseline',preview=True),env,base,'preview'))
        self.assertEqual(stand.snapshot(package),before);self.assertFalse(target.exists())
        self.assertEqual(json.loads((base/'result.json').read_text())['tools_versions'],'baseline')

    def test_versions_07_root_entry_forwards_baseline(self):
        base,env,target=self.prepare_versions('versions-root');self.manual(base,env,'v2.0.0')
        self.assert_ok(self.root_entry(base,env,target,tools_versions='BASELINE' if stand.WINDOWS else 'baseline'))
        info,_,_=self.observed(base);self.assertEqual(info['version'],'v1.0.0')

    def test_versions_08_invalid_cli_fails_before_setup(self):
        base,env,target=self.prepare_versions('versions-invalid')
        result=self.run_process(self.arguments(base,target,'latest'),env,base,'invalid')
        self.assertNotEqual(result.returncode,0);self.assertIn('preserve',result.stderr);self.assertFalse(target.exists())


if __name__=='__main__':
    print('work:',stand.BASE,'artifacts:',stand.ARTIFACTS,flush=True)
    names=sys.argv[1:] or [n for n in Versions.__dict__ if n.startswith('test_versions_')]
    result=unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(Versions(n) for n in names))
    (stand.BASE/'versions-summary.json').write_text(json.dumps({'tests':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),'platform':stand.PLATFORM},indent=2))
    if stand.BASE!=stand.ARTIFACTS:
        def ignore(directory,names):return [n for n in names if n in ('runtime','prepared','.runtime-cache','.ui-cache') or n.endswith(('.zip','.tar.gz')) or (Path(directory)/n).is_symlink()]
        shutil.copytree(stand.BASE,stand.ARTIFACTS,ignore=ignore)
    raise SystemExit(0 if result.wasSuccessful() else 1)
