"""IDE-BOOT-23 IDE-BOOT-35: real SQL part -> source/UI/private install -> query/SQLite test."""
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import sys
import tarfile
import unittest
import zipfile

ROOT=Path(__file__).resolve().parents[1]
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
ui=load('sql_ui',ROOT/'tests/install-ui.test.py');stand=ui.stand
publisher=load('sql_publisher',ROOT/'scripts/package-sql-tools.py')
SQL=Path(os.environ.get('FORGE_E2E_SQL_DEPS',str(ROOT/'.tests/sql-deps')))
RUNNER=Path(os.environ.get('FORGE_E2E_SQL_TEST_DEPS',str(ROOT/'.tests/sql-test-deps')))
DEPS=Path(os.environ.get('FORGE_E2E_DEPS',str(ROOT/'.tests/editor-deps')))

class SQLDelivery(ui.UI):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        config=cls.source/'nvim_forge';shutil.copytree(ROOT/'nvim_forge/lua',config/'lua')
        for name in ['setup-stage.lua','native-tools.json']:shutil.copyfile(ROOT/'nvim_forge/scripts'/name,config/'scripts'/name)
        with (config/'init.lua').open('a',encoding='utf-8') as f:f.write("\ndofile(assert(vim.env.FORGE_SQL_TEST_INIT))\n")
        cls.part=stand.BASE/('sql.zip' if stand.WINDOWS else 'sql.tar.gz')
        publisher.package(SQL,RUNNER,cls.part);cls.good=cls.part.read_bytes();cls.routes['/sql-part']=cls.good
        # Advanced tools are now an explicitly supplied complete bundle.
        # Keep the original Core archive for the basic-catalog control below.
        if stand.WINDOWS:
            with zipfile.ZipFile(io.BytesIO(cls.good)) as archive:
                files={name:archive.read(name) for name in archive.namelist() if not name.endswith('/')}
        else:
            with tarfile.open(fileobj=io.BytesIO(cls.good),mode='r:gz') as archive:
                files={member.name.removeprefix('./'):archive.extractfile(member).read() for member in archive if member.isfile()}
        part=json.loads(files.pop('forge-component.json'))
        meta_path=cls.runtime/'forge-runtime.json';meta=json.loads(meta_path.read_text())
        for name,digest in part['files'].items():
            dest=cls.runtime/name;dest.parent.mkdir(parents=True,exist_ok=True)
            self_data=files[name];assert hashlib.sha256(self_data).hexdigest()==digest
            dest.write_bytes(self_data)
            if not stand.WINDOWS:dest.chmod(0o755 if name.startswith('sql/bin/') else 0o644)
        meta['files'].update(part['files']);meta['paths'].extend(part['paths']);meta['probes'].extend(part['probes'])
        meta['components'].append('sql');meta_path.write_text(json.dumps(meta),encoding='utf-8')
        cls.catalog()
    @classmethod
    def catalog(cls):
        rows=[]
        for name,url,data in [('core','/runtime',cls.archive.read_bytes()),('sql','/sql-part',cls.routes['/sql-part'])]:
            rows.append('\t'.join([stand.PLATFORM,name,cls.url+url,hashlib.sha256(data).hexdigest()]))
        (cls.source/'scripts/runtime/artifacts.tsv').write_text('\n'.join(rows)+'\n',encoding='utf-8');cls.publish_source(cls.ui_digest)
    def tearDown(self):self.routes['/sql-part']=self.good;self.catalog()
    def prepared(self,name):
        base,env,target=super().prepare(name)
        env.update(FORGE_E2E_DEPS=str(DEPS),FORGE_SQL_TEST_INIT=str(ROOT/'tests/diagnostics/install-sql-init.lua'),FORGE_SQRUFF_FIXTURE=str(SQL/'bin'/('sqruff.exe' if stand.WINDOWS else 'sqruff')))
        env['PATH']=os.pathsep.join([str(Path(os.environ['SystemRoot'])/'System32'),str(Path(os.environ['SystemRoot'])/'System32/WindowsPowerShell/v1.0')]) if stand.WINDOWS else '/usr/bin:/bin'
        if stand.WINDOWS:env['PATH']+=os.pathsep+str(Path(shutil.which('git')).parent)
        return base,env,target
    def install_sql(self,base,env,target):return self.root_entry(base,env,target,'sql',runtime=True)
    def test_sql_01_native_delivery_without_sdk(self):
        base,env,target=self.prepared('sql-native');self.assert_ok(self.install_sql(base,env,target))
        project=base/'project';(project/'db').mkdir(parents=True);sqlite3.connect(project/'db/main.sqlite3').close()
        (project/'.sqls.json').write_text(json.dumps({'connections':[{'driver':'sqlite3','dataSourceName':'file:db/main.sqlite3?mode=rw'}]}))
        (project/'query.sql').write_text('-- published patch must handle comments\nSELECT 42 AS answer;\n')
        (project/'query.slt').write_text('query I\nSELECT 40 + 2;\n----\n42\n\n')
        shadow=base/'shadow';shadow.mkdir();copy=shadow/('sqls.exe' if stand.WINDOWS else 'sqls');copy.write_text('user-owned old tool');copy.chmod(0o755);env['PATH']=str(shadow)+os.pathsep+env['PATH']
        launcher=([stand.SHELL,'-NoProfile','-File',str(target/'bin/fride.ps1')] if stand.WINDOWS else [stand.SHELL,str(target/'bin/fride')])
        result=self.run_process(launcher+['--headless','-i','NONE','-l',str(ROOT/'tests/diagnostics/install-sql-observe.lua'),str(base)],env,base,'query-test');self.assert_ok(result)
        report=json.loads((base/'sql.json').read_text(encoding='utf-8'));self.assertEqual(report['slt']['status'],'passed')
        self.assertTrue(Path(report['tools']['sqls']['path']).is_relative_to(target/'runtime'))
    def test_sql_02_bad_manifest_rejected(self):
        base,env,target=self.prepared('sql-bad-manifest');copy=base/'runner';copy.mkdir()
        meta=json.loads((RUNNER/'manifest.json').read_text());meta['sources']['src/main.rs']='0'*64;(copy/'manifest.json').write_text(json.dumps(meta))
        with self.assertRaisesRegex(ValueError,'source/lock mismatch'):publisher.package(SQL,copy,base/'bad.zip')
        self.assertFalse((base/'bad.zip').exists());self.assertFalse(target.exists())
    def test_sql_03_missing_part_keeps_previous_kit(self):
        base,env,target=self.prepared('sql-retry');self.assert_ok(self.install_sql(base,env,target))
        before=(target/'.forge-install.json').read_bytes();binary=target/'runtime/sql/bin'/('sqls.exe' if stand.WINDOWS else 'sqls');sha=hashlib.sha256(binary.read_bytes()).hexdigest()
        source=self.runtime/'sql/bin'/('sqls.exe' if stand.WINDOWS else 'sqls');original=source.read_bytes()
        try:
            source.write_bytes(b'corrupt explicit bundle')
            result=self.install_sql(base,env,target);self.assertNotEqual(result.returncode,0)
            self.assertEqual((target/'.forge-install.json').read_bytes(),before);self.assertEqual(hashlib.sha256(binary.read_bytes()).hexdigest(),sha)
        finally:source.write_bytes(original)
    def test_sql_04_wrong_native_version_keeps_previous_kit(self):
        base,env,target=self.prepared('sql-version');self.assert_ok(self.install_sql(base,env,target))
        marker=(target/'.forge-install.json').read_bytes();policy=self.source/'nvim_forge/scripts/native-tools.json';original=policy.read_bytes()
        try:
            for name in ['sqls','forge-sqltest']:
                with self.subTest(tool=name):
                    data=json.loads(original);data[name]='99.0.0';policy.write_text(json.dumps(data));self.publish_source(self.ui_digest)
                    result=self.install_sql(base,env,target);self.assertNotEqual(result.returncode,0)
                    log=(target/'log/setup-tools.log').read_text(encoding='utf-8',errors='replace')
                    self.assertIn('Unexpected '+name+' version',log)
                    self.assertEqual((target/'.forge-install.json').read_bytes(),marker)
        finally:policy.write_bytes(original);self.publish_source(self.ui_digest)

    def test_sql_05_basic_catalog_ignores_advanced_bundle(self):
        base,env,target=self.prepared('sql-basic-only');start=len(self.requests)
        self.assert_ok(self.root_entry(base,env,target,'sql',runtime=False))
        self.assertNotIn('/sql-part',self.requests[start:])
        self.assertFalse((target/'runtime/sql').exists())
        log=(target/'log/setup-tools.log').read_text(encoding='utf-8',errors='replace')
        self.assertIn('Tool readiness:',log);self.assertNotIn('SQL native readiness:',log)

if __name__=='__main__':
    print('work:',stand.BASE,'artifacts:',stand.ARTIFACTS,flush=True)
    names=sys.argv[1:] or [n for n in SQLDelivery.__dict__ if n.startswith('test_sql_')]
    result=unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(SQLDelivery(n) for n in names))
    (stand.BASE/'sql-delivery-summary.json').write_text(json.dumps({'tests':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),'platform':stand.PLATFORM},indent=2))
    if stand.BASE!=stand.ARTIFACTS:
        def ignore(directory,names):return [n for n in names if n in ('runtime','prepared','.runtime-cache') or n.endswith(('.zip','.tar.gz')) or (Path(directory)/n).is_symlink()]
        shutil.copytree(stand.BASE,stand.ARTIFACTS,ignore=ignore)
    raise SystemExit(0 if result.wasSuccessful() else 1)
