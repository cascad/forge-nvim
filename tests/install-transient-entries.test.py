"""IDE-BOOT-47: real AF_UNIX sockets + private installer; fixture config/stages."""
import importlib.util,json,os
from pathlib import Path
import shutil,subprocess,sys,time,unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('transient_stand',ROOT/'tests/install-isolation.test.py')
stand=importlib.util.module_from_spec(spec);spec.loader.exec_module(stand)


class Transient(stand.Isolation):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.socket_helper=stand.BASE/('unix-socket.exe' if stand.WINDOWS else 'unix-socket')
        go=ROOT/'.tests/dap-tools/go/bin/go.exe' if stand.WINDOWS else shutil.which('go')
        assert go and Path(go).is_file(),'Prepare an existing native Go SDK for the socket fixture'
        env=dict(os.environ,GOTOOLCHAIN='local',GOENV='off',GOWORK='off',GOMAXPROCS='2',GOFLAGS='-p=2',
            GOCACHE=str(ROOT/'.tests/transient-go-cache'/stand.PLATFORM))
        result=subprocess.run([str(go),'build','-o',str(cls.socket_helper),str(ROOT/'tests/e2e/fixtures/install-unix-socket/main.go')],
            env=env,capture_output=True,text=True,timeout=90)
        assert result.returncode==0,result.stderr

    def endpoint(self,name,live):
        base,env,target=self.prepare(name);self.assert_ok(self.install(base,env,target))
        config=stand.snapshot(target/'config');foreign=stand.foreign_snapshot(base/'foreign')
        endpoint=None
        try:
            command=[str(self.socket_helper),'live' if live else 'closed']
            if live:
                endpoint=subprocess.Popen(command,cwd=target/'tmp',env=env,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
                deadline=time.monotonic()+5
                while not (target/'tmp/ready').exists() and endpoint.poll() is None and time.monotonic()<deadline:time.sleep(.02)
                self.assertTrue((target/'tmp/ready').exists(),'Native socket helper did not become ready')
            else:
                result=subprocess.run(command,cwd=target/'tmp',env=env,capture_output=True,text=True,timeout=5)
                self.assertEqual(result.returncode,0,result.stderr)
            path=target/'tmp/ipc';self.assertTrue(path.exists())
            before=os.lstat(path)
            if stand.WINDOWS:self.assertEqual(before.st_reparse_tag,0x80000023)
            result=self.install(base,env,target);self.assert_ok(result)
            self.assertTrue(path.exists());self.assertEqual(os.lstat(path).st_ino,before.st_ino)
            if live:self.assertIsNone(endpoint.poll(),'Installer stopped the live socket owner')
            self.assertEqual(stand.snapshot(target/'config'),config)
            self.assertEqual(stand.foreign_snapshot(base/'foreign'),foreign)
            self.assert_ok(self.launch(base,env,target))
        finally:
            if endpoint is not None:
                output,errors=endpoint.communicate('close\n',timeout=5)
                self.assertEqual(endpoint.returncode,0,errors)
            if (target/'tmp/ipc').exists():(target/'tmp/ipc').unlink()

    def test_transient_01_closed_socket_repeat(self):self.endpoint('transient-closed',False)
    def test_transient_02_live_socket_repeat(self):self.endpoint('transient-live',True)

    def test_transient_03_foreign_tmp_root_is_rejected(self):
        base,env,target=self.prepare('transient-foreign-root');self.assert_ok(self.install(base,env,target))
        temp=target/'tmp';old=target/'tmp-original'
        for path in (temp,old):self.assertTrue(path.resolve().is_relative_to(target.resolve()))
        temp.rename(old)
        if stand.WINDOWS:
            result=subprocess.run(['cmd.exe','/c','mklink','/J',str(temp),str(base/'foreign/data')],capture_output=True)
            self.assertEqual(result.returncode,0,result.stderr)
        else:temp.symlink_to(base/'foreign/data',target_is_directory=True)
        result=self.install(base,env,target);self.assertNotEqual(result.returncode,0)
        self.assertIn('External link in Forge',result.stderr)

    def test_transient_04_persistent_foreign_link_is_rejected(self):self.test_12_external_link_in_owned_target()
    def test_transient_05_failed_setup_preserves_previous_kit(self):self.test_04_failed_setup_keeps_previous()


if __name__=='__main__':
    print('work:',stand.BASE,'artifacts:',stand.ARTIFACTS,flush=True)
    names=sys.argv[1:] or sorted(name for name in Transient.__dict__ if name.startswith('test_transient_'))
    result=unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(Transient(name) for name in names))
    if stand.BASE!=stand.ARTIFACTS:
        import shutil
        def ignore(directory,names):return [name for name in names if name in ('runtime','prepared','.runtime-cache') or name.endswith(('.zip','.tar.gz')) or (Path(directory)/name).is_symlink() or not ((Path(directory)/name).is_file() or (Path(directory)/name).is_dir())]
        shutil.copytree(stand.BASE,stand.ARTIFACTS,ignore=ignore)
    raise SystemExit(0 if result.wasSuccessful() else 1)
