"""spec: IDE-BOOT-29 IDE-BOOT-32. Native CLI/report/notices E2E, no SDK installs.

Small source/receipt/archive fixtures test inventory evidence; they are explicitly
not functional IDE bundles. The separate real-input report uses authentic notices.
Network is opt-in only for the explicit source-fetch case.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import unittest
import zipfile

ROOT=Path(__file__).resolve().parents[1]
PLATFORM=('windows' if os.name=='nt' else 'macos' if sys.platform=='darwin' else 'linux')+'-'+('arm64' if __import__('platform').machine().lower() in ('arm64','aarch64') else 'x64')
NVIM=Path(os.environ.get('FORGE_INSTALL_TEST_NVIM',str(ROOT/'.tools/neovim/windows-x64/bin/nvim.exe') if os.name=='nt' else shutil.which('nvim') or '')).resolve()
FRONTEND=Path(os.environ.get('FORGE_INSTALL_UI_BINARY',str(ROOT/'.tools/installer-ui'/PLATFORM/('fride-setup.exe' if os.name=='nt' else 'fride-setup')))).resolve()
DEPS=Path(os.environ.get('FORGE_E2E_DEPS',str(ROOT/'.tests/editor-deps'))).resolve()
SITE=Path(os.environ.get('FORGE_PARSER_SITE',str(ROOT/'.tests/parser-runtime'/PLATFORM/'site'))).resolve()
BASE=Path(os.environ.get('FORGE_RELEASE_TEST_ROOT',str(ROOT/'.tests/release-audit/e2e')))/(PLATFORM+'-'+str(time.time_ns())+' ü')
BASE.mkdir(parents=True)


def digest(data):return hashlib.sha256(data).hexdigest()
def snapshot(root):return {p.relative_to(root).as_posix():digest(p.read_bytes()) for p in root.rglob('*') if p.is_file()}


class ReleaseInventory(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.deps=BASE/'editor-inputs';cls.deps.mkdir()
        shutil.copy2(DEPS/'manifest.json',cls.deps/'manifest.json')
        for name in json.loads((ROOT/'nvim_forge/lazy-lock.json').read_text()):
            source=DEPS/'lazy'/name;target=cls.deps/'lazy'/name;target.mkdir(parents=True)
            for file in source.iterdir():
                if file.is_file() and file.name.lower().startswith(('license','licence','copying','notice','unlicense')):shutil.copy2(file,target/file.name)
        for name,entry in json.loads((ROOT/'nvim_forge/patches/plugins.json').read_text()).items():
            for patch in [entry,*entry.get('extra',[])]:
                relative=Path('lazy')/name/patch['file'];target=cls.deps/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(DEPS/relative,target)
        shutil.copytree(DEPS/'lazy/mason.nvim/lua',cls.deps/'lazy/mason.nvim/lua')
        shutil.copytree(DEPS/'lazy/nvim-treesitter/lua',cls.deps/'lazy/nvim-treesitter/lua')
        env=os.environ.copy();env.update(NVIM_LOG_FILE=str(BASE/'catalog.log'),NVIM_APPNAME='fride',TEMP=str(BASE),TMP=str(BASE),TMPDIR=str(BASE))
        cls.catalog=BASE/'catalog.json'
        subprocess.run([str(NVIM),'--headless','-u','NONE','-i','NONE','-l',str(ROOT/'scripts/inspect-release-catalog.lua'),str(ROOT/'nvim_forge'),str(cls.deps/'lazy/nvim-treesitter'),str(cls.catalog)],check=True,env=env,capture_output=True,timeout=30)
        catalog=json.loads(cls.catalog.read_text());cache=BASE/'license-cache';cache.mkdir();items=[]
        for name,source in catalog['grammars'].items():
            path=Path('licenses/parser')/name/'LICENSE';file=cache/path;file.parent.mkdir(parents=True);data=b'Controlled document fixture. Not a redistribution notice.\n';file.write_bytes(data)
            items.append({'id':'parser:'+name,'kind':'parser',**source,'licenses':[{'path':path.as_posix(),'sha256':digest(data)}]})
        (cache/'inventory.json').write_text(json.dumps({'schema':1,'items':items}));cls.cache=cache
        cls.mason=BASE/'mason'
        for name in ['lua-language-server','stylua']:
            folder=cls.mason/'packages'/name;folder.mkdir(parents=True)
            (folder/'entry').write_text('not executable: inventory must never run tool binaries\n')
            (folder/'LICENSE').write_text('Controlled package document fixture\n')
            version=catalog['pins'].get(name,'fixture-version')
            (folder/'mason-receipt.json').write_text(json.dumps({'name':name,'schema_version':'2.0','source':{'id':'pkg:github/fixture/'+name+'@'+version},'install_options':{'version':version},'links':{'bin':{name:'entry'}}}))
        cls.archive=BASE/'core.zip';cls.write_archive(cls.archive)
        cls.before=snapshot(cls.deps);cls.site_before=snapshot(SITE)

    @classmethod
    def tearDownClass(cls):
        assert snapshot(cls.deps)==cls.before,'Prepared inputs changed'
        assert snapshot(SITE)==cls.site_before,'Parser site changed'

    @staticmethod
    def write_archive(path,corrupt=False,incomplete=False):
        suffix='.exe' if os.name=='nt' else ''
        files={'LICENSE.txt':b'Controlled archive document fixture\n','bin/nvim'+suffix:b'Not a runtime: metadata-only fixture\n'}
        if not incomplete:files.update({'search/bin/rg'+suffix:b'Never executed\n','search/prepared.json':b'{}','treesitter/prepared.json':b'{}'})
        manifest={'schema':1,'platform':PLATFORM,'components':['core'],'nvim':'bin/nvim','files':{n:digest(b) for n,b in files.items()}}
        with zipfile.ZipFile(path,'w') as archive:
            archive.writestr('forge-runtime.json',json.dumps(manifest))
            for name,data in files.items():archive.writestr(name,data+b'corrupt' if corrupt and name=='LICENSE.txt' else data)

    def run_cli(self,name,components='core',extra=(),archive=None,output=None):
        base=BASE/name;base.mkdir(exist_ok=True);output=output or base/'report'
        env=os.environ.copy();empty=base/'empty-path';empty.mkdir(exist_ok=True)
        env.update(PATH=str(empty),TEMP=str(base),TMP=str(base),TMPDIR=str(base),PYTHONUTF8='1',SDK_PROBE_MARKER=str(base/'sdk-probe-marker'))
        args=[sys.executable,'-B',str(ROOT/'scripts/release-inventory.py'),'--editor-deps',str(self.deps),'--site',str(SITE),'--nvim',str(NVIM),'--frontend',str(FRONTEND),
              '--components',components,'--mason-root',str(self.mason),'--license-cache',str(self.cache),'--archive','core='+str(archive or self.archive),'--output',str(output),*extra]
        result=subprocess.run(args,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=60)
        (base/'process.json').write_text(json.dumps({'exit':result.returncode,'out':result.stdout,'err':result.stderr},ensure_ascii=False,indent=2),encoding='utf-8')
        self.assertFalse((base/'sdk-probe-marker').exists());return result,output

    def test_01_strict_complete_metadata_is_not_runtime_acceptance(self):
        result,output=self.run_cli('complete',extra=['--strict']);self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        data=json.loads((output/'inventory.json').read_text());self.assertTrue(data['metadata_complete']);self.assertFalse(data['full_release_ready'])
        self.assertEqual(data['components'],['core']);self.assertEqual(data['native_sdks'],[])
        self.assertEqual(len([i for i in data['items'] if i['kind']=='plugin']),67)
        for item in data['items']:
            for doc in item['licenses']:self.assertEqual(digest((output/doc['path']).read_bytes()),doc['sha256'])
        notices=(output/'THIRD_PARTY_NOTICES.txt').read_bytes();self.assertIn(b'Controlled document fixture',notices)
        source=next((self.deps/'lazy/neo-tree.nvim').glob('LICENSE*')).read_bytes();self.assertIn(source,notices)
        again,other=self.run_cli('deterministic',extra=['--strict']);self.assertEqual(again.returncode,0,again.stderr)
        self.assertEqual((output/'inventory.json').read_bytes(),(other/'inventory.json').read_bytes())

    def test_02_selected_profile_missing_packages_and_external_sdks(self):
        result,output=self.run_cli('profile','go,python',extra=['--strict']);self.assertEqual(result.returncode,2,result.stderr)
        data=json.loads((output/'inventory.json').read_text());self.assertEqual(data['components'],['core','go','python'])
        self.assertEqual(data['native_sdks'],['go','python','node'])
        parsers={i['name'] for i in data['items'] if i['kind']=='parser'};self.assertIn('gowork',parsers);self.assertIn('python',parsers);self.assertNotIn('rust',parsers)
        self.assertIn({'item':'artifact:python','code':'archive_not_supplied','detail':''},data['gaps'])
        self.assertTrue(any(g['item']=='mason:debugpy' for g in data['gaps']))
        self.assertNotIn(str(BASE).replace('\\','/'),json.dumps(data).replace('\\\\','/'))

    def test_03_archive_corruption_and_existing_output(self):
        corrupt=BASE/'corrupt.zip';self.write_archive(corrupt,True);before=corrupt.read_bytes()
        result,output=self.run_cli('corrupt',extra=['--strict'],archive=corrupt);self.assertEqual(result.returncode,2,result.stderr)
        data=json.loads((output/'inventory.json').read_text());self.assertTrue(any(g['item']=='artifact:core' and g['code']=='archive_invalid' for g in data['gaps']))
        self.assertEqual(corrupt.read_bytes(),before);saved=snapshot(output)
        result,_=self.run_cli('exists',output=output);self.assertEqual(result.returncode,1);self.assertEqual(snapshot(output),saved)

    def test_04_revision_and_backport_drift_are_reported(self):
        manifest=self.deps/'manifest.json';original=manifest.read_bytes();data=json.loads(original);data['plugins']['Comment.nvim']='0'*40
        patch=self.deps/'lazy/neo-tree.nvim/lua/neo-tree/sources/filesystem/init.lua';saved=patch.read_bytes()
        try:
            manifest.write_text(json.dumps(data));patch.write_bytes(saved+b'\n-- drift\n')
            result,output=self.run_cli('drift',extra=['--strict']);self.assertEqual(result.returncode,2,result.stderr)
            gaps=json.loads((output/'inventory.json').read_text())['gaps']
            self.assertTrue(any(g['item']=='plugin:Comment.nvim' and g['code']=='prepared_revision_mismatch' for g in gaps))
            self.assertTrue(any(g['item']=='backport:neo-tree.nvim' and g['code']=='prepared_patch_mismatch' for g in gaps))
        finally:manifest.write_bytes(original);patch.write_bytes(saved)

    def test_05_legacy_archive_missing_current_runtime_is_explicit(self):
        legacy=BASE/'legacy-core.zip';self.write_archive(legacy,incomplete=True)
        result,output=self.run_cli('legacy',extra=['--strict'],archive=legacy);self.assertEqual(result.returncode,2,result.stderr)
        gaps=json.loads((output/'inventory.json').read_text())['gaps']
        self.assertTrue(any(g['item']=='artifact:core' and g['code']=='declared_runtime_file_missing' and g['detail']=='search/prepared.json' for g in gaps))

    def test_06_missing_manifest_and_broken_receipt_are_named(self):
        manifest=self.deps/'manifest.json';saved=manifest.read_bytes()
        receipt=self.mason/'packages/stylua/mason-receipt.json';original=receipt.read_bytes()
        try:
            manifest.unlink();receipt.write_text('{broken')
            result,output=self.run_cli('missing-metadata',extra=['--strict']);self.assertEqual(result.returncode,2,result.stderr)
            gaps=json.loads((output/'inventory.json').read_text())['gaps']
            self.assertTrue(any(g['code']=='prepared_manifest_missing' for g in gaps))
            self.assertIn({'item':'mason:stylua','code':'receipt_invalid','detail':''},gaps)
            self.assertFalse(manifest.exists());self.assertEqual(receipt.read_text(),'{broken')
        finally:manifest.write_bytes(saved);receipt.write_bytes(original)

    def test_07_installed_version_comes_from_native_receipt(self):
        lua=self.mason/'packages/lua-language-server/mason-receipt.json';stylua=self.mason/'packages/stylua/mason-receipt.json'
        saved={p:p.read_bytes() for p in [lua,stylua]}
        try:
            data=json.loads(saved[lua]);data['install_options']['version']=None;lua.write_text(json.dumps(data))
            data=json.loads(saved[stylua]);data['install_options']['version']='requested-not-installed';stylua.write_text(json.dumps(data))
            result,out=self.run_cli('installed-version',extra=['--strict']);self.assertEqual(result.returncode,0,result.stderr)
            packages={i['name']:i for i in json.loads((out/'inventory.json').read_text())['items'] if i['kind']=='mason'}
            self.assertEqual(packages['lua-language-server']['version'],'fixture-version')
            self.assertEqual(packages['stylua']['version'],json.loads(saved[stylua])['source']['id'].rsplit('@',1)[1])
        finally:
            for p,data in saved.items():p.write_bytes(data)

    def test_08_source_bound_nested_cache_and_corruption(self):
        folder=self.mason/'packages/stylua';license=folder/'LICENSE';saved=license.read_bytes()
        nested=folder/'third-party/NOTICE.txt';nested.parent.mkdir();nested.write_bytes(b'Controlled nested document\n')
        try:
            result,cache=self.run_cli('cache-seed',extra=['--strict']);self.assertEqual(result.returncode,0,result.stderr)
            license.unlink();nested.unlink()
            result,out=self.run_cli('tool-cache',extra=['--license-cache',str(cache),'--strict']);self.assertEqual(result.returncode,0,result.stderr)
            data=json.loads((out/'inventory.json').read_text());item=next(i for i in data['items'] if i['id']=='mason:stylua')
            self.assertEqual({d['path'] for d in item['licenses']},{'licenses/mason/stylua/LICENSE','licenses/mason/stylua/third-party/NOTICE.txt'})
            metadata=cache/'inventory.json';original=metadata.read_bytes();old=json.loads(original)
            next(i for i in old['items'] if i['id']=='mason:stylua')['source']='pkg:github/another/source@v2.6.0';metadata.write_text(json.dumps(old))
            result,out=self.run_cli('stale-tool-cache',extra=['--license-cache',str(cache),'--strict']);self.assertEqual(result.returncode,2,result.stderr)
            self.assertTrue(any(g['item']=='mason:stylua' and g['code']=='license_documents_missing' for g in json.loads((out/'inventory.json').read_text())['gaps']))
            metadata.write_bytes(original);doc=cache/'licenses/mason/stylua/LICENSE';doc.write_bytes(b'changed')
            result,_=self.run_cli('corrupt-tool-cache',extra=['--license-cache',str(cache),'--strict']);self.assertEqual(result.returncode,1,result.stderr)
            self.assertIn('License cache SHA mismatch: stylua',result.stderr)
        finally:
            license.write_bytes(saved)
            if nested.exists():nested.unlink()
            nested.parent.rmdir()

    @unittest.skipUnless(os.environ.get('FORGE_RELEASE_NETWORK_TEST')=='1','Explicit publisher network preparation only')
    def test_09_explicit_pinned_tool_document_fetch(self):
        folder=self.mason/'packages/stylua';receipt=folder/'mason-receipt.json';saved=receipt.read_bytes();license=folder/'LICENSE';original=license.read_bytes()
        try:
            data=json.loads(saved);data['source']['id']='pkg:github/johnnymorganz/stylua@v2.6.0';receipt.write_text(json.dumps(data));license.unlink()
            offline,out=self.run_cli('fetch-disabled',extra=['--strict']);self.assertEqual(offline.returncode,2,offline.stderr)
            result,out=self.run_cli('explicit-fetch',extra=['--fetch-tool-licenses','--strict']);self.assertEqual(result.returncode,0,result.stderr)
            doc=out/'licenses/mason/stylua/LICENSE.md';self.assertTrue(doc.is_file())
            self.assertIn(b'Mozilla Public License Version 2.0',doc.read_bytes())
            item=next(i for i in json.loads((out/'inventory.json').read_text())['items'] if i['id']=='mason:stylua')
            self.assertEqual(item['licenses'][0]['sha256'],digest(doc.read_bytes()));self.assertEqual(item['licenses'][0]['origin'],data['source']['id'])
        finally:receipt.write_bytes(saved);license.write_bytes(original)


if __name__=='__main__':
    print('work:',BASE,flush=True)
    names=sys.argv[1:] or [n for n in ReleaseInventory.__dict__ if n.startswith('test_')]
    result=unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(ReleaseInventory(n) for n in names))
    (BASE/'summary.json').write_text(json.dumps({'tests':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),'platform':PLATFORM},indent=2))
    destination=os.environ.get('FORGE_RELEASE_TEST_EXPORT')
    if destination:shutil.copytree(BASE,Path(destination)/BASE.name,ignore=shutil.ignore_patterns('editor-inputs','core.zip','corrupt.zip'))
    raise SystemExit(0 if result.wasSuccessful() else 1)
