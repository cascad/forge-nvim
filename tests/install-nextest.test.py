"""IDE-BOOT-49: native frontend/Core/nextest, ordinary Cargo home, no SDK installs."""
import hashlib,importlib.util,json,os
from pathlib import Path
import shutil,sys,unittest
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('sdk_settings_tests',ROOT/'tests/install-sdk-settings.test.py')
settings=importlib.util.module_from_spec(spec);spec.loader.exec_module(settings)
stand,ui=settings.stand,settings.prereq.ui
SUFFIX='.exe' if stand.WINDOWS else ''
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()

class Nextest(settings.Settings):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        deps=Path(os.environ.get('FORGE_E2E_RUST_DEPS',str(ROOT/'.tests/rust-deps')))
        cls.nextest=deps/'nextest'/('cargo-nextest'+SUFFIX)
        assert cls.nextest.is_file(),'Prepare actual upstream nextest first, no downloads by default'
        cls.original_hash=sha(cls.nextest)

    def prepare_nextest(self,name):
        base,env,target=self.prepare(name)
        env['CARGO_HOME']=str(base/'ordinary cargo home ü')
        self.user(env,'sdk.json',{'version':1,'sdks':{'rust':str(self.rust)}})
        env['PATH']=str(self.fixture_path(base,'git'))+os.pathsep+env['PATH']
        return base,env,target

    def command(self,base,target,check=False):
        args=[str(ui.BINARY),'--source',str(self.source),'--runtime-path',str(self.runtime),
            '--components','rust','--install-dir',str(target),'--log-dir',str(base/'logs')]
        if check:args+=['--check-rust-tools']
        return args

    def home_binary(self,env):return Path(env['CARGO_HOME'])/'bin'/('cargo-nextest'+SUFFIX)

    def put(self,target):
        target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(self.nextest,target)
        if not stand.WINDOWS:target.chmod(0o755)

    def probe(self,base,env,target):
        result=self.run_process(self.command(base,target,True),env,base,'nextest-check')
        return result,json.loads(result.stdout)['tools'][0]

    def test_nextest_01_normal_cargo_home_reuses_ready_version(self):
        base,env,target=self.prepare_nextest('nextest-home');binary=self.home_binary(env);self.put(binary)
        before=sha(binary);result,report=self.probe(base,env,target)
        self.assert_ok(result);self.assertEqual(report['status'],'ready')
        self.assertEqual(Path(report['tools'][0]['path']),binary);self.assertEqual(sha(binary),before)
        self.assertFalse(target.exists());self.assertEqual(sha(self.nextest),self.original_hash)

    def test_nextest_02_user_path_ignores_project_and_preserves_binary(self):
        base,env,target=self.prepare_nextest('nextest-user');binary=base/'chosen tools'/('runner'+SUFFIX);self.put(binary)
        self.user(env,'tools.json',{'tools':{'cargo-nextest':str(binary)}})
        project=base/'.fride';project.mkdir();(project/'tools.json').write_text('{bad project JSON')
        result,report=self.probe(base,env,target);self.assert_ok(result)
        self.assertEqual(Path(report['tools'][0]['path']),binary);self.assertEqual(sha(binary),self.original_hash)

    def test_nextest_03_invalid_user_choice_never_uses_ready_home(self):
        base,env,target=self.prepare_nextest('nextest-invalid');self.put(self.home_binary(env))
        chosen=self.user(env,'tools.json',{'tools':{'cargo-nextest':str(base/'missing-nextest')}})
        result,report=self.probe(base,env,target);self.assertEqual(result.returncode,2)
        self.assertEqual(report['status'],'unavailable');self.assertIn(str(chosen).replace('\\','/'),json.dumps(report,ensure_ascii=False).replace('\\\\','/'))
        self.assertEqual(sha(self.home_binary(env)),self.original_hash)

    def test_nextest_04_headless_missing_keeps_previous_kit(self):
        base,env,target=self.prepare_nextest('nextest-missing')
        target.mkdir(parents=True);(target/'keep').write_text('previous kit');before=stand.snapshot(target)
        result=self.run_process(self.command(base,target),env,base,'missing')
        self.assertNotEqual(result.returncode,0);self.assertIn('cargo-nextest не готов',result.stderr)
        self.assertEqual(stand.snapshot(target),before);self.assertFalse(self.home_binary(env).exists())

    def test_nextest_05_menu_existing(self):
        base,env,target=self.prepare_nextest('nextest-existing')
        env['FORGE_UI_SDK_INPUT']=str(self.nextest.parent)
        self.pty(base,env,self.command(base,target),'nextest-existing')
        self.assertTrue((target/'bin/fride').exists());self.assertEqual(sha(self.nextest),self.original_hash)

    def test_nextest_06_menu_skip_rust(self):
        base,env,target=self.prepare_nextest('nextest-skip')
        self.pty(base,env,self.command(base,target),'nextest-skip')
        owner=json.loads((target/'.forge-install.json').read_text());self.assertEqual(owner['components'],['core'])
        self.assertFalse(self.home_binary(env).exists())

    def test_nextest_07_cancel_and_decline_keep_home(self):
        for action in ('cancel','decline'):
            base,env,target=self.prepare_nextest('nextest-'+action);env['FORGE_UI_EXPECTED_EXIT']='130'
            value=self.pty(base,env,self.command(base,target),'nextest-'+action)
            self.assertEqual(value['exit'],130);self.assertFalse(target.exists());self.assertFalse(self.home_binary(env).exists())

    def test_nextest_08_install_action_preserves_tool_appearing_after_inspection(self):
        base,env,target=self.prepare_nextest('nextest-appeared')
        env.update(FORGE_UI_NEXTEST_TARGET=str(self.home_binary(env)),FORGE_UI_NEXTEST_READY=str(self.nextest))
        value=self.pty(base,env,self.command(base,target)+['--tools-versions','baseline'],'nextest-install-appeared')
        self.assertEqual(sha(self.home_binary(env)),self.original_hash)
        raw=''.join(f['raw'] for f in value['frames'])
        self.assertIn('версия сохранена',raw)

    def test_nextest_09_install_action_preserves_conflicting_file(self):
        base,env,target=self.prepare_nextest('nextest-conflict')
        env.update(FORGE_UI_NEXTEST_TARGET=str(self.home_binary(env)),FORGE_UI_EXPECTED_EXIT='130')
        self.pty(base,env,self.command(base,target),'nextest-install-conflict')
        self.assertTrue(self.home_binary(env).read_bytes().startswith(b'user file'));self.assertFalse(target.exists())

    @unittest.skipUnless(os.environ.get('FORGE_NEXTEST_NETWORK_TEST')=='1','Explicit official installer network acceptance')
    def test_nextest_10_official_installer_and_repeat(self):
        base,env,target=self.prepare_nextest('nextest-official');env['FORGE_UI_WAIT_MS']='45000'
        other=base/'another install prefix';other.mkdir()
        protected=other/('cargo-nextest'+SUFFIX);protected.write_text('existing unrelated prefix')
        env['NEXTEST_INSTALL_DIR']=str(other)
        self.pty(base,env,self.command(base,target),'nextest-install')
        binary=self.home_binary(env);self.assertTrue(binary.is_file());before=sha(binary)
        result,report=self.probe(base,env,target);self.assert_ok(result);self.assertEqual(report['status'],'ready')
        self.assert_ok(self.run_process(self.command(base,target),env,base,'repeat'))
        self.assertEqual(sha(binary),before)
        self.assertEqual(protected.read_text(),'existing unrelated prefix')
        (stand.BASE/'nextest-official-home.json').write_text(json.dumps({'home':env['CARGO_HOME'],
            'binary':str(binary),'sha256':before,'version':report['tools'][0]['version']},ensure_ascii=False),encoding='utf-8')

if __name__=='__main__':
    print('work:',stand.BASE,'artifacts:',stand.ARTIFACTS,flush=True)
    names=sys.argv[1:] or sorted(n for n in Nextest.__dict__ if n.startswith('test_nextest_'))
    result=unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(Nextest(n) for n in names))
    if stand.BASE!=stand.ARTIFACTS:
        def ignore(directory,names):return [n for n in names if n in ('runtime','prepared','.runtime-cache','.ui-cache') or n.endswith(('.zip','.tar.gz')) or (Path(directory)/n).is_symlink()]
        shutil.copytree(stand.BASE,stand.ARTIFACTS,ignore=ignore)
    raise SystemExit(0 if result.wasSuccessful() else 1)
