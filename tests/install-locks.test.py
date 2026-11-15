"""IDE-BOOT-20: real Windows deny-delete handle during atomic kit commit."""
import ctypes
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import sys
import threading
import time
import unittest
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('stand',ROOT/'tests/install-isolation.test.py')
stand=importlib.util.module_from_spec(spec);spec.loader.exec_module(stand)

@unittest.skipUnless(stand.WINDOWS,'Windows deny-delete file handles')
class Locks(stand.Isolation):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        with (cls.source/'nvim_forge/scripts/setup-stage.lua').open('a',encoding='utf-8') as f:
            f.write("\nif arg[1]=='tools' and vim.env.FORGE_LOCK_READY then vim.fn.writefile({vim.v.progpath},vim.env.FORGE_LOCK_READY);assert(vim.wait(10000,function() return vim.uv.fs_stat(vim.env.FORGE_LOCK_ACQUIRED)~=nil end,10),'Native lock not acquired') end\n")

    def locked_install(self,base,env,target,persistent):
        ready=base/'ready.txt';acquired=base/'acquired.txt'
        env.update(FORGE_LOCK_READY=str(ready),FORGE_LOCK_ACQUIRED=str(acquired))
        release=threading.Event();errors=[];events=[]
        def holder():
            handle=None
            try:
                kernel=ctypes.WinDLL('kernel32',use_last_error=True)
                kernel.CreateFileW.argtypes=[ctypes.c_wchar_p,ctypes.c_uint32,ctypes.c_uint32,ctypes.c_void_p,ctypes.c_uint32,ctypes.c_uint32,ctypes.c_void_p]
                kernel.CreateFileW.restype=ctypes.c_void_p;kernel.CloseHandle.argtypes=[ctypes.c_void_p]
                deadline=time.monotonic()+15
                while not ready.exists() and time.monotonic()<deadline:time.sleep(.01)
                assert ready.exists(),'No tools-stage signal'
                exe=Path(ready.read_text(encoding='utf-8').strip()).resolve()
                assert exe.is_relative_to(target.resolve()),exe
                handle=kernel.CreateFileW(str(exe),0x80000000,3,None,3,0x80,None)
                assert handle!=ctypes.c_void_p(-1).value,ctypes.get_last_error()
                events.append('acquired deny-delete');acquired.write_text('locked')
                release.wait(15 if persistent else .4)
            except Exception as error:errors.append(str(error))
            finally:
                if handle is not None and handle!=ctypes.c_void_p(-1).value:kernel.CloseHandle(handle);events.append('released')
        worker=threading.Thread(target=holder);worker.start()
        try:return self.install(base,env,target)
        finally:
            release.set();worker.join(16)
            (base/'lock.json').write_text(json.dumps({'persistent':persistent,'events':events,'errors':errors},indent=2))
            self.assertFalse(worker.is_alive());self.assertEqual(errors,[])
            env.pop('FORGE_LOCK_READY',None);env.pop('FORGE_LOCK_ACQUIRED',None)

    def test_lock_01_transient_rename(self):
        base,env,target=self.prepare('transient-lock');self.assert_ok(self.locked_install(base,env,target,False));self.assert_ok(self.launch(base,env,target))

    def test_lock_02_persistent_lock_preserves_previous(self):
        base,env,target=self.prepare('persistent-lock');self.assert_ok(self.install(base,env,target))
        before=stand.snapshot(target/'bin');owner=(target/'.forge-install.json').read_bytes()
        binary=hashlib.sha256((target/'runtime/bin/nvim.exe').read_bytes()).hexdigest()
        result=self.locked_install(base,env,target,True);self.assertNotEqual(result.returncode,0)
        self.assertEqual(stand.snapshot(target/'bin'),before);self.assertEqual((target/'.forge-install.json').read_bytes(),owner)
        self.assertEqual(hashlib.sha256((target/'runtime/bin/nvim.exe').read_bytes()).hexdigest(),binary);self.assert_ok(self.launch(base,env,target))

if __name__=='__main__':
    print('work:',stand.BASE,'artifacts:',stand.ARTIFACTS,flush=True)
    names=sys.argv[1:] or [n for n in Locks.__dict__ if n.startswith('test_lock_')]
    result=unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(Locks(n) for n in names))
    (stand.BASE/'locks-summary.json').write_text(json.dumps({'tests':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),'platform':stand.PLATFORM}))
    raise SystemExit(0 if result.wasSuccessful() else 1)
