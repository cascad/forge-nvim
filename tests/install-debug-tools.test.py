"""IDE-BOOT-23: actual Mason codelldb/Bash, owned patch and native DAP."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import unittest
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
import threading

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('ide_tools',ROOT/'tests/install-ide-tools.test.py')
helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)
CACHE=Path(os.environ.get('FORGE_DEBUG_CACHE',str(ROOT/'.tests/debug-tools'/f'{helper.SYSTEM}-{helper.ARCH}')))
helper.CACHE=CACHE;helper.MASON=CACHE/'data'/('fride-data' if helper.WIN else 'fride')/'mason'
BASE=ROOT/'.tests/install-debug-tools'/helper.BASE.name;BASE.mkdir(parents=True)
MASON=helper.MASON

def invoke(base,mode,extra=None):
    return helper.invoke(base,ROOT/'tests/diagnostics/install-debug-tools.lua',[mode,base],timeout=180,env_overrides=extra)

class DebugTools(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        assert (MASON/'packages/codelldb/mason-receipt.json').is_file(),'Run --prepare first'
    def base(self,name):
        path=BASE/name;path.mkdir();return path
    def assert_ok(self,r):self.assertEqual(r.returncode,0,r.stdout+r.stderr)
    def test_01_owned_patch_repeat(self):
        base=self.base('patch');self.assert_ok(invoke(base,'patch'))
        file=MASON/'packages/bash-debug-adapter/extension/out/bashDebug.js';before=file.read_bytes()
        repeat=self.base('repeat');self.assert_ok(invoke(repeat,'patch'));self.assertEqual(before,file.read_bytes())
        self.assertIn('уже готов',(repeat/'patch.txt').read_text(encoding='utf-8'))
    def test_02_unknown_patch_is_nonzero_unchanged(self):
        file=MASON/'packages/bash-debug-adapter/extension/out/bashDebug.js';before=file.read_bytes()
        try:
            file.write_bytes(b'unknown adapter bytes\n');base=self.base('unknown');r=invoke(base,'stage')
            self.assertNotEqual(r.returncode,0);self.assertIn('Неизвестный SDK',r.stderr);self.assertEqual(file.read_bytes(),b'unknown adapter bytes\n')
        finally:file.write_bytes(before)
    def test_03_setup_ignores_external_adapter_override(self):
        base=self.base('external');external=base/'external.js';external.write_text('user-owned adapter')
        self.assert_ok(invoke(base,'stage',{'FORGE_BASH_DEBUG_ADAPTER':str(external)}));self.assertEqual(external.read_text(),'user-owned adapter')
    def test_04_real_codelldb_launch(self):
        base=self.base('dap');source=base/'main.rs';source.write_text('fn main() { println!("FRIDE_DEBUG_DELIVERY"); }\n')
        rustc=Path(os.environ['USERPROFILE'])/'.rustup/toolchains/stable-x86_64-pc-windows-msvc/bin/rustc.exe' if helper.WIN else Path(shutil.which('rustc'))
        binary=base/('debug.exe' if helper.WIN else 'debug')
        env=helper.environment(base);subprocess.run([str(rustc),'-g',str(source),'-o',str(binary)],env=env,cwd=base,check=True)
        self.assert_ok(invoke(base,'debug',{'FORGE_DEBUG_PROGRAM':str(binary),'PYTHONDONTWRITEBYTECODE':'1'}))
        report=json.loads((base/'dap.json').read_text());self.assertTrue(report['stopped']);self.assertTrue(Path(report['command']).is_relative_to(MASON))
    @unittest.skipIf(helper.WIN,'Windows Bash launch needs owner-provided WSL2; no WSL management in this stand')
    def test_05_real_bash_launch(self):
        base=self.base('bash');script=base/'script.sh';script.write_text('#!/bin/bash\necho FRIDE_BASH_DELIVERY\n');script.chmod(0o755)
        self.assert_ok(invoke(base,'bash-debug'));self.assertTrue(json.loads((base/'dap.json').read_text())['stopped'])

if __name__=='__main__':
    print('work:',BASE,'cache:',CACHE,flush=True)
    if '--prepare' in sys.argv:
        CACHE.mkdir(parents=True,exist_ok=True);server=None
        try:
            if os.environ.get('FORGE_DEBUG_OFFLINE')=='1':
                rust=Path(os.environ['FORGE_E2E_RUST_DEPS'])
                asset='codelldb-'+('win32' if helper.WIN else 'darwin' if helper.SYSTEM=='macos' else 'linux')+'-'+helper.ARCH+'.vsix'
                files={asset:rust/'archives'/asset,'bash-debug-0.3.9.vsix':Path(os.environ['FORGE_DEBUG_BASH_ARCHIVE'])}
                sources=json.loads((ROOT/'tests/e2e/rust-tools/sources.json').read_text());key=('win32' if helper.WIN else 'darwin' if helper.SYSTEM=='macos' else 'linux')+'-'+helper.ARCH
                assert hashlib.sha256(files[asset].read_bytes()).hexdigest()==sources['platforms'][key]['codelldb']['sha256']
                assert hashlib.sha256(files['bash-debug-0.3.9.vsix'].read_bytes()).hexdigest()=='7605265eb3de643f0817d9b1870eec0d36a7de5a0d50628edb59937f1515fabc'
                class Assets(BaseHTTPRequestHandler):
                    def do_GET(self):
                        file=files.get(self.path.rsplit('/',1)[-1])
                        if not file:self.send_error(404);return
                        self.send_response(200);self.send_header('Content-Length',str(file.stat().st_size));self.end_headers()
                        with file.open('rb') as f:shutil.copyfileobj(f,self.wfile)
                    def log_message(self,*args):pass
                server=ThreadingHTTPServer(('127.0.0.1',0),Assets);threading.Thread(target=server.serve_forever,daemon=True).start()
                os.environ['FORGE_IDE_GITHUB_TEMPLATE']=f'http://127.0.0.1:{server.server_port}/%s/%s/%s'
            r=invoke(BASE,'prepare')
        finally:
            if server:server.shutdown();server.server_close()
        print(r.stdout);print(r.stderr)
        if r.returncode:
            for p in (BASE/'state').rglob('mason.log'):print(p.read_text(encoding='utf-8',errors='replace')[-20000:])
        raise SystemExit(r.returncode)
    names=sys.argv[1:]
    suite=unittest.defaultTestLoader.loadTestsFromNames(names,sys.modules[__name__]) if names else unittest.defaultTestLoader.loadTestsFromTestCase(DebugTools)
    result=unittest.TextTestRunner(verbosity=2).run(suite)
    (BASE/'summary.json').write_text(json.dumps({'tests':result.testsRun,'failures':len(result.failures),'errors':len(result.errors)},indent=2))
    raise SystemExit(0 if result.wasSuccessful() else 1)
