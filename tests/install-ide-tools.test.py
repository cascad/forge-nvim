"""IDE-BOOT-22. Real Mason/tools and native consumers; no host SDK installation.

--prepare downloads/builds IDE tools into .tests only, with existing SDKs.
Tests use those prepared tools offline. Mac needs the same native preparation.
"""
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import time
import unittest
from contextlib import contextmanager
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import threading
import urllib.request

ROOT=Path(__file__).resolve().parents[1]
WIN=os.name=='nt'
SYSTEM={'Windows':'windows','Linux':'linux','Darwin':'macos'}[platform.system()]
ARCH='arm64' if platform.machine().lower() in ('arm64','aarch64') else 'x64'
CACHE=Path(os.environ.get('FORGE_IDE_CACHE',str(ROOT/'.tests/ide-tools'/f'{SYSTEM}-{ARCH}')))
SHARED=Path(os.environ.get('FORGE_IDE_SHARED',str(CACHE.parent/'shared')))
MASON=CACHE/'data'/('fride-data' if WIN else 'fride')/'mason'
DEPS=Path(os.environ.get('FORGE_E2E_DEPS',str(ROOT/'.tests/editor-deps')))
NVIM=Path(os.environ.get('FORGE_INSTALL_TEST_NVIM',str(ROOT/'.tools/neovim/windows-x64/bin/nvim.exe') if WIN else shutil.which('nvim') or ''))
BASE=ROOT/'.tests/install-ide-tools'/(str(time.time_ns())+' ü space');BASE.mkdir(parents=True)

def environment(base):
    env=os.environ.copy();env.update(FORGE_IDE_ROOT=str(ROOT),FORGE_E2E_DEPS=str(DEPS),FORGE_IDE_CACHE=str(CACHE),
        HOME=str(base/'user'),USERPROFILE=str(base/'user'),LOCALAPPDATA=str(base/'local'),
        XDG_CONFIG_HOME=str(base/'config'),XDG_DATA_HOME=str(CACHE/'data'),XDG_STATE_HOME=str(base/'state'),XDG_CACHE_HOME=str(base/'cache'),
        NVIM_APPNAME='fride',NVIM_LOG_FILE=str(base/'nvim.log'),PSModuleAnalysisCachePath=str(base/'ps-module-cache'),
        GOTOOLCHAIN='local',RUSTUP_AUTO_INSTALL='0',GOMAXPROCS='2',GOFLAGS='-p=2',
        GOSUMDB='sum.golang.org',GOPROXY='https://proxy.golang.org,direct',GOMEMLIMIT='512MiB',GOTELEMETRY='off',
        GOMODCACHE=str(SHARED/'gomod'),GOCACHE=str(CACHE/'gocache'),GOPATH=str(SHARED/'gopath'),
        npm_config_cache=str(SHARED/'npm'),npm_config_audit='false',npm_config_fund='false')
    if env.get('FORGE_IDE_OFFLINE')=='1':env.update(GOPROXY=(SHARED/'gomod/cache/download').resolve().as_uri(),GOSUMDB='off',npm_config_offline='true')
    (base/'user').mkdir(parents=True,exist_ok=True)
    if WIN:
        env['PATH']=os.pathsep.join([str(ROOT/'.tests/dap-tools/go/bin'),str(ROOT/'.tests/node-deps/sdk/node-v24.11.0-win-x64'),env.get('PATH','')])
    else:
        node=Path(os.environ.get('FORGE_E2E_NODE_DEPS',str(ROOT/'.tests/node-deps')))/'sdk'/f'node-v24.11.0-{SYSTEM if SYSTEM!="macos" else "darwin"}-{ARCH}'/'bin'
        env['PATH']=str(node)+os.pathsep+env.get('PATH','')
    return env

def invoke(base,script,extra=(),timeout=60,env_overrides=None):
    env=environment(base)
    env.update(env_overrides or {})
    result=subprocess.run([str(NVIM),'--headless','-u','NONE','-i','NONE','-l',str(script),*map(str,extra)],env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=timeout)
    (base/'result.json').write_text(json.dumps({'exit':result.returncode,'stdout':result.stdout,'stderr':result.stderr},ensure_ascii=False,indent=2),encoding='utf-8')
    return result

class Tools(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        assert (CACHE/'prepared.json').is_file(),'Run this file --prepare with existing native SDKs first'
        cls.baseline={p:hashlib.sha256(p.read_bytes()).hexdigest() for p in (MASON/'packages').rglob('mason-receipt.json')}

    def check(self,name,mode='failure'):
        base=BASE/name;base.mkdir()
        result=invoke(base,ROOT/'tests/diagnostics/install-ide-tools-check.lua',[mode,base])
        return base,result

    def assert_ok(self,result):self.assertEqual(result.returncode,0,result.stdout+result.stderr)

    @contextmanager
    def receipt(self,name,change):
        path=MASON/'packages'/name/'mason-receipt.json';before=path.read_bytes();data=json.loads(before);change(data)
        try:
            path.write_text(json.dumps(data),encoding='utf-8');yield
        finally:path.write_bytes(before)

    def test_01_ready(self):
        base,result=self.check('ready','ready');self.assert_ok(result)
        self.assertEqual(json.loads((base/'check.json').read_text())['packages'],5)

    def test_02_wrong_version(self):
        with self.receipt('gopls',lambda d:d['source'].update(id='pkg:golang/golang.org/x/tools/gopls@v0.1.0')):
            _,result=self.check('version');self.assertNotEqual(result.returncode,0);self.assertIn('expected version v0.23.0',result.stderr)

    def test_03_missing_required_alias(self):
        with self.receipt('stylua',lambda d:d['links'].update(bin={})):
            _,result=self.check('alias');self.assertNotEqual(result.returncode,0);self.assertIn('required bin export missing: stylua',result.stderr)

    def test_04_prettier_entry_missing(self):
        path=MASON/'packages/prettier/node_modules/prettier/bin/prettier.cjs';data=path.read_bytes();mode=path.stat().st_mode
        try:
            path.unlink();_,result=self.check('entry');self.assertNotEqual(result.returncode,0)
            self.assertIn('Prettier JS entrypoint missing',result.stderr)
        finally:path.write_bytes(data);path.chmod(mode)

    def test_05_actual_formatters(self):
        base=BASE/'format';base.mkdir()
        # Give Prettier a project cwd: the repository intentionally ignores
        # .tests, which Prettier otherwise honors for stdin-filepath as well.
        (base/'.prettierrc.json').write_text('{}')
        go='package sample\nfunc sum(a int,b int)int{return a+b}\nfunc text(a,b,c string)string{return a+b+c}\nfunc long()string{return text('+','.join('"'+c*50+'"' for c in 'abc')+')}\n'
        for name,text in {'sample.lua':'local x={a=1,b=2}\nreturn x\n','sample.go':go,'sample.json':json.dumps({'key':{str(i):i for i in range(20)}})+'\n'}.items():(base/name).write_text(text)
        result=invoke(base,ROOT/'tests/diagnostics/install-ide-tools-check.lua',['format',base]);self.assert_ok(result)
        data=json.loads((base/'consumer.json').read_text());self.assertIn('local x = {',data['sample.lua']);self.assertIn('a + b',data['sample.go']);self.assertIn('\n  "key": {',data['sample.json'])
        self.assertIn('return text(\n',data['sample.go'],'golines must split the long call')
        self.assertTrue(Path(data['script']).is_relative_to(MASON/'packages/prettier'))

    def test_06_project_prettier_priority(self):
        base=BASE/'project';project=base/'project';project.mkdir(parents=True)
        shutil.copytree(MASON/'packages/prettier/node_modules/prettier',project/'node_modules/prettier')
        (project/'package.json').write_text('{"private":true}')
        (project/'.prettierrc.json').write_text('{"tabWidth":4}')
        (project/'sample.json').write_text(json.dumps({'key':{str(i):i for i in range(20)}})+'\n')
        result=invoke(base,ROOT/'tests/diagnostics/install-ide-tools-check.lua',['project',base]);self.assert_ok(result)
        data=json.loads((base/'consumer.json').read_text());self.assertTrue(Path(data['script']).is_relative_to(project/'node_modules'));self.assertIn('\n    "key": {',data['project/sample.json'])

    def test_07_gopls_navigation(self):
        base=BASE/'lsp';project=base/'project';project.mkdir(parents=True)
        (project/'go.mod').write_text('module example.com/fride-tool-test\n\ngo 1.26.0\n')
        (project/'main.go').write_text('package sample\nfunc Run() int { return Twice(2) }\n')
        (project/'defs.go').write_text('package sample\nfunc Twice(n int) int { return n * 2 }\n')
        result=invoke(base,ROOT/'tests/diagnostics/install-ide-tools-check.lua',['lsp',base]);self.assert_ok(result)
        self.assertIn('defs.go',json.loads((base/'consumer.json').read_text())['target'])

    def test_08_repeat_keeps_receipts(self):
        _,result=self.check('repeat','repeat');self.assert_ok(result)
        self.assertEqual({p:hashlib.sha256(p.read_bytes()).hexdigest() for p in self.baseline},self.baseline)

    def test_09_missing_node(self):
        base=BASE/'missing-node';base.mkdir();env=environment(base);env['FORGE_NODE_EXECUTABLE']=str(base/'not-installed-node')
        result=subprocess.run([str(NVIM),'--headless','-u','NONE','-i','NONE','-l',str(ROOT/'tests/diagnostics/install-ide-tools-check.lua'),'failure',str(base)],env=env,capture_output=True,text=True,encoding='utf-8',timeout=30)
        (base/'result.json').write_text(json.dumps({'exit':result.returncode,'stdout':result.stdout,'stderr':result.stderr},indent=2))
        self.assertNotEqual(result.returncode,0);self.assertIn('Node SDK missing for Prettier',result.stderr)

    def test_10_setup_stage_false_success(self):
        with self.receipt('gopls',lambda d:d['source'].update(id='pkg:golang/golang.org/x/tools/gopls@v0.1.0')):
            base=BASE/'stage-failure';base.mkdir()
            result=invoke(base,ROOT/'tests/diagnostics/install-ide-tools-stage.lua',[base],env_overrides={'GOTOOLCHAIN':'auto','RUSTUP_AUTO_INSTALL':'1'})
            self.assertNotEqual(result.returncode,0);self.assertIn('Setup stage tools failed',result.stderr);self.assertIn('expected version v0.23.0',result.stderr)
            self.assertEqual(json.loads((base/'setup-env.json').read_text()),{'go':'local','rust':'0'})

    @unittest.skipUnless(WIN and Path('E:/Go1.23/bin/go.exe').is_file(),'Native older Go SDK fixture is available on Windows only')
    def test_11_older_sdk_fails_before_install(self):
        base=BASE/'old-sdk';base.mkdir();cache=base/'empty-cache'
        env={'FORGE_IDE_CACHE':str(cache),'XDG_DATA_HOME':str(cache/'data'),
            'PATH':'E:/Go1.23/bin'+os.pathsep+environment(base)['PATH'],'GOTOOLCHAIN':'auto'}
        result=invoke(base,ROOT/'tests/diagnostics/install-ide-tools-stage.lua',[base],env_overrides=env)
        self.assertNotEqual(result.returncode,0);self.assertIn('Go 1.26.0+ SDK is required to build gopls',result.stderr)
        self.assertIn('go1.23',result.stderr);self.assertFalse((base/'setup-env.json').exists())

    @unittest.skipUnless(WIN and Path('E:/Go1.23/bin/go.exe').is_file(),'Native older Go SDK fixture is available on Windows only')
    def test_12_ready_tools_reuse_older_sdk(self):
        base=BASE/'old-sdk-ready';base.mkdir()
        result=invoke(base,ROOT/'tests/diagnostics/install-ide-tools-stage.lua',[base],env_overrides={
            'PATH':'E:/Go1.23/bin'+os.pathsep+environment(base)['PATH'],'GOTOOLCHAIN':'auto'})
        self.assert_ok(result);self.assertTrue((base/'setup-env.json').exists())

if __name__=='__main__' and '--fetch-linux-asset' in sys.argv:
    url='https://github.com/JohnnyMorganz/StyLua/releases/download/v2.6.0/stylua-linux-x86_64.zip'
    path=SHARED/'assets/johnnymorganz/stylua/v2.6.0/stylua-linux-x86_64.zip';path.parent.mkdir(parents=True,exist_ok=True)
    with urllib.request.urlopen(url,timeout=60) as response:data=response.read()
    path.write_bytes(data);(path.parent/'source.json').write_text(json.dumps({'url':url,'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data)},indent=2))
    print('Cached official Linux StyLua asset:',len(data),'bytes');raise SystemExit(0)

if __name__=='__main__' and '--prepare' not in sys.argv:
    print('work:',BASE,'cache:',CACHE,flush=True)
    suite=unittest.defaultTestLoader.loadTestsFromNames(sys.argv[1:],sys.modules[__name__]) if len(sys.argv)>1 else unittest.defaultTestLoader.loadTestsFromTestCase(Tools)
    result=unittest.TextTestRunner(verbosity=2).run(suite)
    (BASE/'summary.json').write_text(json.dumps({'tests':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),'platform':SYSTEM},indent=2))
    raise SystemExit(0 if result.wasSuccessful() else 1)

if __name__=='__main__' and '--prepare' in sys.argv:
    CACHE.mkdir(parents=True,exist_ok=True)
    print('work:',BASE,'cache:',CACHE,flush=True)
    server=None
    try:
        if os.environ.get('FORGE_IDE_OFFLINE')=='1':
            class Assets(SimpleHTTPRequestHandler):
                def __init__(self,*a,**kw):super().__init__(*a,directory=str(SHARED/'assets'),**kw)
                def log_message(self,*args):pass
            server=ThreadingHTTPServer(('127.0.0.1',0),Assets)
            threading.Thread(target=server.serve_forever,daemon=True).start()
            os.environ['FORGE_IDE_GITHUB_TEMPLATE']=f'http://127.0.0.1:{server.server_port}/%s/%s/%s'
        result=invoke(BASE,ROOT/'tests/diagnostics/install-ide-tools-prepare.lua',timeout=900)
    finally:
        if server:server.shutdown();server.server_close()
    print(result.stdout);print(result.stderr)
    if result.returncode:
        for p in (BASE/'state').rglob('mason.log'):
            print(p.read_text(encoding='utf-8',errors='replace')[-16000:])
    raise SystemExit(result.returncode)
