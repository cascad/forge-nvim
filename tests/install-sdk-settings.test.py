"""IDE-BOOT-40: native frontend/Core/SDKs; fixture setup and bounded failure controls."""
import hashlib
from contextlib import contextmanager
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('prerequisites',ROOT/'tests/install-prerequisites.test.py')
prereq=importlib.util.module_from_spec(spec);spec.loader.exec_module(prereq)
ui,stand=prereq.ui,prereq.stand
SUFFIX='.exe' if stand.WINDOWS else ''


class Settings(prereq.Prerequisites):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        go=Path(os.environ.get('FORGE_SDK_GO_NEW',str(ROOT/'.tests/dap-tools/go' if stand.WINDOWS else '/opt/go')))
        assert (go/'bin'/('go'+SUFFIX)).is_file(),'Prepared native Go required; no downloads'
        cls.go=go.resolve()
        rustc=Path(os.environ['USERPROFILE'])/'.rustup/toolchains/stable-x86_64-pc-windows-msvc/bin/rustc.exe' if stand.WINDOWS else shutil.which('rustc')
        cls.rust=Path(subprocess.check_output([str(rustc),'--print','sysroot'],env=dict(os.environ,RUSTUP_AUTO_INSTALL='0'),text=True).strip()).resolve()
        with (cls.source/'nvim_forge/init.lua').open('a',encoding='utf-8') as f:
            f.write("\nif vim.env.FRIDE_SETTINGS_SETUP then local sdk=require('forge.sdk');sdk.setup();assert(not sdk.error,sdk.error);vim.fn.writefile({vim.json.encode({selection=sdk.active,scope=vim.g.forge_setup_sdk_report.scope})},vim.env.FRIDE_SETTINGS_SETUP..'.init','a') end\n")
        # Real SDK initialization at the actual private pre-init boundary, fixture Mason stage.
        with (cls.source/'nvim_forge/scripts/setup-stage.lua').open('a',encoding='utf-8') as f:
            f.write("\nif vim.env.FRIDE_SETTINGS_SETUP and arg[1]=='tools' then local r=vim.g.forge_setup_sdk_report;require('forge.sdk').initialize(nil,{scope=r.scope,kinds=r.sdk_kinds});vim.fn.writefile({vim.json.encode({report=r,go=vim.env.GOROOT,rust=vim.env.RUSTUP_TOOLCHAIN,path=vim.env.PATH})},vim.env.FRIDE_SETTINGS_SETUP) end\n")

    def user(self,env,name,data):
        path=Path(env['XDG_CONFIG_HOME'])/'fride'/name;path.parent.mkdir(parents=True,exist_ok=True)
        path.write_text(json.dumps(data) if not isinstance(data,str) else data,encoding='utf-8')
        return path

    def choices(self,base,env):
        venv=base/'Python venv with spaces'
        self.assert_ok(self.run_process([sys.executable,'-m','venv','--without-pip',str(venv)],env,base,'venv'))
        python=venv/('Scripts/python.exe' if stand.WINDOWS else 'bin/python')
        sdk=self.user(env,'sdk.json',{'version':1,'sdks':{'go':str(self.go),'rust':str(self.rust)}})
        rust_deps=Path(os.environ.get('FORGE_E2E_RUST_DEPS',str(ROOT/'.tests/rust-deps')))
        tools=self.user(env,'tools.json',{'tools':{'python':str(python),'node':str(self.node_bin/('node'+SUFFIX)),
            'cargo-nextest':str(rust_deps/'nextest'/('cargo-nextest'+SUFFIX))}})
        return sdk,tools,python

    def test_settings_01_four_native_choices_override_path_and_ignore_project(self):
        base,env,target=self.prepare('settings-native');sdk,tools,python=self.choices(base,env)
        wrong=self.fixture_path(base,'go','rustc','cargo','python','node')
        env.update(PATH=str(wrong),SDK_PROBE_MODE='invalid',SDK_PROBE_MARKER=str(base/'must-not-run'))
        project=base/'project/.fride';project.mkdir(parents=True)
        (project/'sdk.json').write_text('invalid project JSON');(project/'tools.json').write_text('invalid project JSON')
        # run_process uses caller cwd; explicitly run from a project whose settings must be ignored.
        previous=os.getcwd()
        try:
            os.chdir(project.parent)
            result,report=self.invoke(base,env,target,'go,rust,python,node')
        finally:os.chdir(previous)
        self.assert_ok(result);self.assertTrue(all(s['status']=='ready' for s in report['sdks']))
        by_id={s['id']:s for s in report['sdks']}
        for kind,expected in [('go',self.go/'bin'/('go'+SUFFIX)),('rust',self.rust/'bin'/('rustc'+SUFFIX)),('python',python),('node',self.node_bin/('node'+SUFFIX))]:
            tool=by_id[kind]['tools'][0]
            self.assertEqual(Path(tool['path']),expected)
            self.assertIn(str(sdk if kind in ('go','rust') else tools).replace('\\','/'),tool['source'].replace('\\','/'))
        self.assertFalse((base/'must-not-run').exists());self.assertFalse(target.exists())

    def test_settings_02_invalid_choice_preserves_kit_no_path_fallback(self):
        base,env,target=self.prepare('settings-invalid')
        path=self.user(env,'sdk.json',{'version':1,'sdks':{'go':str(base/'gone SDK')}})
        env.update(PATH=str(self.fixture_path(base,'go','git')),SDK_PROBE_MARKER=str(base/'marker'))
        target.mkdir(parents=True);(target/'keep').write_text('old kit');before=stand.snapshot(target)
        result,report=self.invoke(base,env,target,'go',False)
        self.assertNotEqual(result.returncode,0);self.assertEqual(report['sdks'][0]['status'],'unavailable')
        self.assertIn(str(path).replace('\\','/'),report['sdks'][0]['tools'][0]['detail'].replace('\\','/'))
        self.assertEqual(stand.snapshot(target),before)
        self.assertEqual((base/'marker').read_text().splitlines()[0],'git')
        self.assertNotIn('go',(base/'marker').read_text().splitlines())

    def test_settings_03_malformed_user_files_report_sources(self):
        base,env,target=self.prepare('settings-json')
        paths=[self.user(env,name,'{broken') for name in ('sdk.json','tools.json')]
        env.update(PATH=str(self.fixture_path(base,'go','rustc','cargo','python','node')),SDK_PROBE_MARKER=str(base/'marker'))
        result,report=self.invoke(base,env,target,'go,rust,python,node')
        self.assertEqual(result.returncode,2)
        for sdk in report['sdks']:
            self.assertEqual(sdk['status'],'unavailable')
            path=paths[0 if sdk['id'] in ('go','rust') else 1]
            self.assertIn(str(path).replace('\\','/'),sdk['tools'][0]['detail'].replace('\\','/'))
        self.assertFalse((base/'marker').exists())

    def test_settings_04_relative_tilde_and_auto(self):
        base,env,target=self.prepare('settings-relative')
        env.update(HOME=str(base/'native-home'),USERPROFILE=str(base/'native-home'))
        self.user(env,'sdk.json',{'version':1,'sdks':{'go':os.path.relpath(self.go,Path(env['XDG_CONFIG_HOME'])/'fride'),'rust':'auto'}})
        alias=Path(env['HOME'])/'selected Node';alias.parent.mkdir(parents=True,exist_ok=True)
        if stand.WINDOWS:
            subprocess.run([stand.SHELL,'-NoProfile','-Command','New-Item -ItemType Junction -Path $env:FRIDE_TEST_LINK -Target $env:FRIDE_TEST_NODE | Out-Null'],env=dict(env,FRIDE_TEST_LINK=str(alias),FRIDE_TEST_NODE=str(self.node_bin)),check=True)
        else:alias.symlink_to(self.node_bin,target_is_directory=True)
        self.user(env,'tools.json',{'tools':{'node':'~/selected Node/'+('node'+SUFFIX)}})
        env['PATH']=str(self.rust/'bin')
        result,report=self.invoke(base,env,target,'go,rust,node');self.assert_ok(result)
        for sdk in report['sdks']:
            if sdk['id']=='rust':self.assertNotIn('source',sdk['tools'][0])
            else:self.assertIn('user:',sdk['tools'][0]['source'])

    def test_settings_05_core_http_cache_before_missing_sdk(self):
        base,env,target=self.prepare('settings-core-first')
        env['PATH']=str(base/'empty');target.mkdir(parents=True);(target/'keep').write_text('old');before=stand.snapshot(target)
        # Fresh archive digest forces this case to exercise transport, not another suite's cache.
        runtime=base/'runtime';shutil.copytree(self.runtime,runtime)
        (runtime/'case.txt').write_text('Core first '+str(time.time_ns()))
        manifest=runtime/'forge-runtime.json';value=json.loads(manifest.read_text());value['files']['case.txt']=hashlib.sha256((runtime/'case.txt').read_bytes()).hexdigest();manifest.write_text(json.dumps(value))
        payload=base/('core.zip' if stand.WINDOWS else 'core.tar.gz')
        import io,tarfile,zipfile
        if stand.WINDOWS:
            with zipfile.ZipFile(payload,'w',compression=zipfile.ZIP_DEFLATED) as archive:
                for p in runtime.rglob('*'):
                    if p.is_file():archive.write(p,p.relative_to(runtime).as_posix())
        else:
            with tarfile.open(payload,'w:gz') as archive:
                for p in runtime.iterdir():archive.add(p,arcname=p.name)
        self.routes['/settings-core']=payload.read_bytes()
        catalog=self.source/'scripts/runtime/artifacts.tsv';previous=catalog.read_bytes()
        catalog.write_text(stand.PLATFORM+'\tcore\t'+self.url+'/settings-core\t'+hashlib.sha256(payload.read_bytes()).hexdigest()+'\n')
        try:
            start=len(self.requests)
            for _ in range(2):
                report=base/('report-'+str(time.time_ns())+'.json')
                args=[str(ui.BINARY),'--source',str(self.source),'--install-dir',str(target),'--components','go,terminal','--check-sdks','--sdk-report',str(report),'--log-dir',str(base/'logs')]
                result=self.run_process(args,env,base,'http-'+str(time.time_ns()))
                self.assertEqual(result.returncode,2,result.stderr)
                self.assertEqual(json.loads(report.read_text())['sdks'][0]['status'],'missing')
            self.assertEqual(self.requests[start:],['/settings-core']);self.assertEqual(stand.snapshot(target),before)
        finally:catalog.write_bytes(previous)

    def test_settings_06_bad_core_stops_before_probe(self):
        base,env,target=self.prepare('settings-bad-core');runtime=base/'runtime';shutil.copytree(self.runtime,runtime)
        (runtime/'unexpected').write_text('untracked')
        env.update(PATH=str(self.fixture_path(base,'go')),SDK_PROBE_MARKER=str(base/'marker'))
        result,report=self.invoke(base,env,target,'go',extra=('--runtime-path',str(runtime)))
        self.assertNotEqual(result.returncode,0);self.assertIn('Untracked runtime file',result.stderr)
        self.assertIsNone(report);self.assertFalse((base/'marker').exists());self.assertFalse(target.exists())

    def test_settings_07_preview_no_core_or_settings(self):
        base,env,target=self.prepare('settings-preview');self.user(env,'sdk.json','broken')
        start=len(self.requests)
        args=[str(ui.BINARY),'--source',str(self.source),'--components','go','--install-dir',str(target),'--preview','--log-dir',str(base/'logs')]
        self.assert_ok(self.run_process(args,env,base,'preview'));self.assertFalse((base/'logs').exists())
        self.assertEqual(self.requests[start:],[]);self.assertFalse(target.exists())

    def test_settings_08_private_setup_uses_same_user_choices(self):
        base,env,target=self.prepare('settings-setup');_,_,python=self.choices(base,env)
        project=self.source/'nvim_forge/.fride';project.mkdir(exist_ok=True)
        for name in ('sdk.json','tools.json'):(project/name).write_text('invalid project JSON')
        parent=base/'.fride';parent.mkdir()
        for name in ('sdk.json','tools.json'):(parent/name).write_text('invalid ancestor project JSON')
        env['FRIDE_SETTINGS_SETUP']=str(base/'setup.json')
        env.update(FRIDE_SDK_BASE='stale parent editor baseline',FRIDE_SDK_PROJECT=str(base/'other-project'))
        result,report=self.invoke(base,env,target,'go,rust,python,node',False)
        self.assert_ok(result);self.assertTrue(all(s['status']=='ready' for s in report['sdks']))
        setup=json.loads((base/'setup.json').read_text())
        self.assertEqual(Path(setup['go']),self.go);self.assertEqual(Path(setup['rust']),self.rust)
        self.assertEqual(setup['report']['scope'],'user')
        self.assertEqual(Path(setup['report']['selected']['python']['path']),python)
        self.assertIn(str(python.parent).replace('\\','/'),setup['path'].replace('\\','/'))
        initial=[json.loads(line) for line in (base/'setup.json.init').read_text().splitlines()]
        self.assertEqual(len(initial),3)
        for entry in initial:
            self.assertEqual(entry['scope'],'user')
            self.assertEqual(Path(entry['selection']['selected']['go']['path']),self.go)
            self.assertEqual(Path(entry['selection']['selected']['rust']['path']),self.rust)

    def test_settings_09_selected_bad_cli_never_uses_other_path(self):
        base,env,target=self.prepare('settings-cli');selected=self.fixture_path(base,'go')
        self.user(env,'sdk.json',{'version':1,'sdks':{'go':str(selected)}})
        env.update(PATH=str(self.go/'bin'),SDK_PROBE_MODE='invalid',SDK_PROBE_MARKER=str(base/'marker'))
        result,report=self.invoke(base,env,target,'go')
        self.assertEqual(result.returncode,2);tool=report['sdks'][0]['tools'][0]
        self.assertEqual(tool['status'],'unavailable');self.assertEqual(Path(tool['path']),selected/('go'+SUFFIX))
        self.assertIn('user:',tool['source']);self.assertTrue((base/'marker').exists());self.assertFalse(target.exists())

    def test_settings_10_sdk_in_replaced_kit_is_rejected(self):
        base,env,target=self.prepare('settings-inside-kit');folder=target/'sdk';folder.mkdir(parents=True)
        shutil.copy2(self.fixture,folder/('go'+SUFFIX));before=stand.snapshot(target)
        self.user(env,'sdk.json',{'version':1,'sdks':{'go':str(folder)}})
        env['SDK_PROBE_MARKER']=str(base/'marker')
        result,report=self.invoke(base,env,target,'go')
        self.assertEqual(result.returncode,2);self.assertIn('вне заменяемого',report['sdks'][0]['tools'][0]['detail'])
        self.assertFalse((base/'marker').exists());self.assertEqual(stand.snapshot(target),before)

    def test_settings_11_failed_class_setup_closes_native_http_stand(self):
        base,_,_=self.prepare('settings-failed-fixture')
        original_base,original_serve=stand.BASE,stand.transport.serve
        closed=[]
        @contextmanager
        def serve():
            with original_serve() as value:
                try:yield value
                finally:closed.append(True)
        class Broken(stand.Isolation):
            @classmethod
            def setUpClass(cls):
                super().setUpClass()
                raise RuntimeError('controlled fixture setup failure')
            def runTest(self):raise AssertionError('must not run')
        try:
            stand.BASE=base/'failed-class';stand.BASE.mkdir();stand.transport.serve=serve
            result=unittest.TestResult();unittest.TestSuite([Broken()]).run(result)
            self.assertEqual(len(result.errors),1);self.assertIn('controlled fixture setup failure',result.errors[0][1])
            self.assertEqual(closed,[True],'Native HTTP stand survived failed class setup')
        finally:
            if not closed and hasattr(Broken,'server'):Broken.server.__exit__(None,None,None)
            stand.BASE,stand.transport.serve=original_base,original_serve


    def test_settings_12_repo_entry_uses_source_frontend_and_user_sdks(self):
        base,env,target=self.prepare('settings-root-source');sdk,tools,python=self.choices(base,env)
        components='go,rust,python,node'
        if stand.WINDOWS:
            command=[stand.SHELL,'-NoProfile','-ExecutionPolicy','Bypass','-File',str(ROOT/'install.ps1'),
                '-ArchiveUrl',self.url+'/ui-source','-SourceRoot',str(base/'sources'),'-InstallPath',str(target),
                '-RuntimePath',str(self.runtime),'-Components',components]
        else:
            command=[stand.SHELL,str(ROOT/'install.sh'),'--archive-url',self.url+'/ui-source','--source-root',str(base/'sources'),
                '--install-dir',str(target),'--runtime-path',str(self.runtime),'--components',components]
        self.assert_ok(self.run_process(command,env,base,'root-source'))
        reports=[json.loads(p.read_text()) for p in (base/'sources/.ui-logs').glob('preflight-*.settings.json')];self.assertEqual(len(reports),2)
        data=next(report for report in reports if 'rust' in report['selections'])
        self.assertTrue(any('cargo-nextest' in report['selections'] for report in reports))
        # The shared reader's report must name the actual user files, not PATH discovery.
        raw=json.dumps(data).replace('\\\\','/')
        self.assertIn('sdk.json',raw);self.assertIn('tools.json',raw)
        self.assertTrue((target/'bin/fride').is_file())


if __name__=='__main__':
    print('work:',stand.BASE,'artifacts:',stand.ARTIFACTS,flush=True)
    names=sys.argv[1:] or [n for n in Settings.__dict__ if n.startswith('test_settings_')]
    result=unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(Settings(n) for n in names))
    (stand.BASE/'sdk-settings-summary.json').write_text(json.dumps({'tests':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),'skipped':len(result.skipped),'platform':stand.PLATFORM},indent=2))
    if stand.BASE!=stand.ARTIFACTS:
        def ignore(directory,names):return [n for n in names if n in ('runtime','prepared','.runtime-cache') or n.endswith(('.zip','.tar.gz')) or (Path(directory)/n).is_symlink()]
        shutil.copytree(stand.BASE,stand.ARTIFACTS,ignore=ignore)
    raise SystemExit(0 if result.wasSuccessful() else 1)
