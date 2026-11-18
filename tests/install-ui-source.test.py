"""IDE-BOOT-46: native shell resolver and real frontend, source catalog identity."""
import hashlib,importlib.util,json,os
from pathlib import Path
import platform,shutil,subprocess,time,unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('ui_source_transport',ROOT/'tests/install-bootstrap.test.py')
transport=importlib.util.module_from_spec(spec);spec.loader.exec_module(transport)
WIN=os.name=='nt';PLATFORM=('windows' if WIN else 'macos' if platform.system()=='Darwin' else 'linux')+'-'+('arm64' if platform.machine().lower() in ('arm64','aarch64') else 'x64')
BINARY=Path(os.environ.get('FORGE_INSTALL_UI_BINARY',str(ROOT/'.tools/installer-ui'/PLATFORM/('fride-setup.exe' if WIN else 'fride-setup'))))
BASE=Path(os.environ.get('FORGE_INSTALL_STAND_ROOT',str(ROOT/'.tests/installer-ui-source')))/('ui-source-'+str(time.time_ns()));BASE.mkdir(parents=True)
sha=lambda data:hashlib.sha256(data).hexdigest()


class SourceUI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        assert BINARY.is_file(),'Prepare native frontend explicitly first'
        cls.binary=BINARY.read_bytes();cls.server=transport.serve()
        cls.url,cls.routes,cls.requests=cls.server.__enter__();cls.addClassCleanup(cls.server.__exit__,None,None,None)
        cls.routes['/source-ui']=cls.binary

    def prepare(self,name,matching=False,catalog=True):
        base=BASE/name;base.mkdir();source=base/'source';(source/'installer-ui').mkdir(parents=True)
        (source/'nvim_forge/scripts').mkdir(parents=True)
        shutil.copyfile(ROOT/'nvim_forge/scripts/components.tsv',source/'nvim_forge/scripts/components.tsv')
        entry=f'{PLATFORM}\t{self.url}/source-ui\t{sha(self.binary)}\n'
        (source/'installer-ui/artifacts.tsv').write_text(entry if catalog else '# unpublished\n')
        binary=base/'checkout/.tools/installer-ui'/PLATFORM/('fride-setup.exe' if WIN else 'fride-setup')
        binary.parent.mkdir(parents=True);binary.write_bytes(self.binary if matching else self.binary+b'LEGACY_TEST_TRAILER')
        binary.chmod(0o755);(binary.parent/'binary.sha256').write_text(sha(binary.read_bytes())+'\n')
        return base,source,binary

    def resolve(self,base,source,explicit=''):
        if WIN:
            script=base/'resolve.ps1'
            script.write_text("param($Lib,$Source,$Cache,$Checkout,$Explicit)\n. $Lib\nGet-ForgeInstallerUI -Source $Source -CacheRoot $Cache -Checkout $Checkout -ExplicitPath $Explicit\n")
            command=[transport.SHELL,'-NoProfile','-File',str(script),str(ROOT/'scripts/lib/installer-ui.ps1'),str(source),str(base/'cache'),str(base/'checkout'),str(explicit)]
        else:
            command=[transport.SHELL,'-c','. "$1"; forge_installer_ui "$2" "$3" "$4" "$5"','_',str(ROOT/'scripts/lib/installer-ui.sh'),str(source),str(base/'cache'),str(base/'checkout'),str(explicit)]
        result=subprocess.run(command,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=20)
        (base/('resolve-'+str(time.time_ns())+'.json')).write_text(json.dumps({'command':command,'exit':result.returncode,'stdout':result.stdout,'stderr':result.stderr},ensure_ascii=False,indent=2))
        return result

    def test_01_stale_local_digest_does_not_override_source(self):
        base,source,legacy=self.prepare('stale');before=legacy.read_bytes();start=len(self.requests)
        result=self.resolve(base,source);self.assertEqual(result.returncode,0,result.stderr)
        chosen=Path(result.stdout.strip());self.assertNotEqual(chosen,legacy);self.assertEqual(chosen.read_bytes(),self.binary)
        self.assertIn('/source-ui',self.requests[start:]);self.assertEqual(legacy.read_bytes(),before)
        run=subprocess.run([str(chosen),'--source',str(source),'--print-plan','--tools-versions','preserve'],capture_output=True,text=True,timeout=10)
        self.assertEqual(run.returncode,0,run.stderr);self.assertEqual(json.loads(run.stdout)['tools_versions'],'preserve')

    def test_02_matching_local_digest_reuses_binary(self):
        base,source,binary=self.prepare('matching',matching=True);start=len(self.requests)
        result=self.resolve(base,source);self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(Path(result.stdout.strip()),binary);self.assertEqual(len(self.requests),start)

    def test_03_unpublished_catalog_never_runs_local_fallback(self):
        base,source,binary=self.prepare('unpublished',catalog=False)
        result=self.resolve(base,source);self.assertNotEqual(result.returncode,0)
        self.assertIn('not published',result.stderr);self.assertIn('explicitly',result.stderr);self.assertFalse((base/'cache').exists())

    def test_04_explicit_developer_override_remains_available(self):
        base,source,binary=self.prepare('explicit',catalog=False)
        result=self.resolve(base,source,binary);self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(Path(result.stdout.strip()),binary)

    def test_05_download_cache_reuses_source_digest(self):
        base,source,binary=self.prepare('cache');self.assertEqual(self.resolve(base,source).returncode,0)
        start=len(self.requests);result=self.resolve(base,source);self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(len(self.requests),start);self.assertEqual(Path(result.stdout.strip()).read_bytes(),self.binary)

    def test_06_bad_source_digest_rejects_transport(self):
        base,source,binary=self.prepare('bad-digest')
        (source/'installer-ui/artifacts.tsv').write_text(f'{PLATFORM}\t{self.url}/source-ui\t'+('0'*64)+'\n')
        result=self.resolve(base,source);self.assertNotEqual(result.returncode,0);self.assertIn('SHA256 mismatch',result.stderr)


if __name__=='__main__':unittest.main()
