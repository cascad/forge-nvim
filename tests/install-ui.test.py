"""IDE-BOOT-13: ready native UI/HTTP/root entry/real private Neovim + fixture stages."""
import hashlib
import importlib.util
import io
import json
import os
import re
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tarfile
import unittest
import zipfile

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('install_isolation',ROOT/'tests/install-isolation.test.py')
stand=importlib.util.module_from_spec(spec);spec.loader.exec_module(stand)
SUFFIX='.exe' if stand.WINDOWS else ''
BINARY=Path(os.environ.get('FORGE_INSTALL_UI_BINARY',str(ROOT/'.tools/installer-ui'/stand.PLATFORM/('fride-setup'+SUFFIX))))
assert BINARY.is_file(),'Prepared fride-setup required; run developer build explicitly'


class UI(stand.Isolation):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        folder=cls.source/'installer-ui';folder.mkdir()
        shutil.copyfile(ROOT/'installer-ui/Cargo.toml',folder/'Cargo.toml')
        cls.ui_digest=hashlib.sha256(BINARY.read_bytes()).hexdigest()
        cls.routes['/ui']=BINARY.read_bytes()
        cls.publish_source(cls.ui_digest)

    @classmethod
    def publish_source(cls,sha):
        (cls.source/'installer-ui/artifacts.tsv').write_text(stand.PLATFORM+'\t'+cls.url+'/ui\t'+sha+'\n',encoding='utf-8')
        output=io.BytesIO()
        if stand.WINDOWS:
            with zipfile.ZipFile(output,'w',compression=zipfile.ZIP_DEFLATED) as archive:
                for path in cls.source.rglob('*'):
                    if path.is_file():archive.write(path,'forge-main/'+path.relative_to(cls.source).as_posix())
        else:
            with tarfile.open(fileobj=output,mode='w:gz') as archive:archive.add(cls.source,arcname='forge-main')
        cls.routes['/ui-source']=output.getvalue()

    def binary_args(self,base,target,preview=True,profile=None,components=None):
        args=[str(BINARY),'--source',str(self.source),'--install-dir',str(target),'--runtime-path',str(self.runtime),
              '--log-dir',str(base/'logs'),'--result',str(base/'result.json')]
        if preview:args+=['--preview']
        if profile:args+=['--profile',profile]
        if components is not None:args+=['--components='+components]
        return args

    def pty(self,base,env,command,scenario,columns=100):
        # The agent's NO_COLOR=1/TERM=dumb describes its output pipe, not the
        # native terminal created below. Exercise a capable terminal and the
        # explicit --no-color fallback separately.
        env.pop('NO_COLOR',None)
        env['TERM']='xterm-256color'
        env.update(FORGE_INSTALL_UI_COMMAND=json.dumps(command),FORGE_UI_SCENARIO=scenario,
            FORGE_INSTALL_UI_REPORT=str(base/'ui.json'),FORGE_UI_COLUMNS=str(columns))
        result=self.run_process([str(stand.NVIM),'-u','NONE','-i','NONE','-l',str(ROOT/'tests/diagnostics/install-ui-pty.lua')],env,base,'ui-driver')
        self.assert_ok(result)
        value=json.loads((base/'ui.json').read_text(encoding='utf-8'))
        self.assertTrue(value['ok'])
        # ConPTY may append SGR reset even when the child never emits colors.
        styled=any(code not in ('','0') for code in re.findall(r'\x1b\[([0-9;]*)m',value['frames'][-1]['raw']))
        self.assertEqual(styled,'--no-color' not in command,'Native color/no-color presentation')
        return value

    def root_entry(self,base,env,target,components='core',runtime=True):
        if stand.WINDOWS:
            quote=lambda value:"'"+str(value).replace("'","''")+"'"
            command='& ([scriptblock]::Create((Invoke-WebRequest -UseBasicParsing -Uri '+quote(self.url+'/entry')+').Content))'
            values=[('ArchiveUrl',self.url+'/ui-source'),('SourceRoot',base/'sources'),('InstallPath',target),('Components',components)]
            if runtime:values.append(('RuntimePath',self.runtime))
            for key,value in values:
                command+=' -'+key+' '+quote(value)
            args=[stand.SHELL,'-NoProfile','-ExecutionPolicy','Bypass','-Command',command]
        else:
            command='bash -c "$(curl --fail --silent '+shlex.quote(self.url+'/entry')+')" --'
            values=[('archive-url',self.url+'/ui-source'),('source-root',base/'sources'),('install-dir',target),('components',components)]
            if runtime:values.append(('runtime-path',self.runtime))
            for key,value in values:
                command+=' --'+key+' '+shlex.quote(str(value))
            args=[stand.SHELL,'-c',command]
        return self.run_process(args,env,base,'root-'+str(len(list(base.glob('root-*.json')))))

    def test_ui_01_preview_recommended(self):
        base,env,target=self.prepare('ui-recommended')
        self.pty(base,env,self.binary_args(base,target),'default')
        plan=json.loads((base/'result.json').read_text(encoding='utf-8'))
        self.assertIn('go',plan['components']);self.assertIn('node',plan['native_sdks']);self.assertNotIn('node-runtime',plan['components'])
        self.assertFalse(target.exists());self.assertFalse((base/'stages.txt').exists());self.assertFalse((base/'logs').exists())

    def test_ui_02_preview_custom_back(self):
        base,env,target=self.prepare('ui-back')
        self.pty(base,env,self.binary_args(base,target,profile='custom'),'custom-back')
        plan=json.loads((base/'result.json').read_text(encoding='utf-8'))
        self.assertNotIn('go',plan['components']);self.assertIn('go',plan['native_sdks']);self.assertFalse(target.exists())

    def test_ui_03_cancel(self):
        base,env,target=self.prepare('ui-cancel')
        report=self.pty(base,env,self.binary_args(base,target,profile='custom'),'cancel')
        self.assertEqual(report['exit'],130);self.assertFalse(target.exists());self.assertFalse((base/'result.json').exists())

    def test_ui_04_custom_paths(self):
        base,env,target=self.prepare('ui-paths');chosen=base/"new UI папка 'test'";commands=base/'new commands/bin'
        env.update(FORGE_UI_INSTALL_INPUT=str(chosen),FORGE_UI_COMMAND_INPUT=str(commands))
        self.pty(base,env,self.binary_args(base,target,profile='custom'),'custom-path')
        plan=json.loads((base/'result.json').read_text(encoding='utf-8'))
        self.assertEqual(plan['install_dir'],str(chosen));self.assertEqual(plan['command_dir'],str(commands))
        self.assertFalse(chosen.exists());self.assertFalse(commands.exists())

    def test_ui_05_core_native_install(self):
        base,env,target=self.prepare('ui-core')
        result=self.run_process(self.binary_args(base,target,preview=False,components='')+['--no-color'],env,base,'native')
        self.assert_ok(result);self.assertNotIn('\x1b',result.stdout+result.stderr)
        self.assertIn('Подготовка завершена',result.stderr);self.assertEqual((base/'stages.txt').read_text().splitlines(),['plugins','parsers','tools'])
        self.assert_ok(self.launch(base,env,target));logs=list((base/'logs').glob('*.log'));self.assertEqual(len(logs),1)
        text=logs[0].read_text(encoding='utf-8',errors='replace');self.assertIn('FRIDE_EVENT',text);self.assertIn('Launch:',text)

    def test_ui_06_backend_failure(self):
        base,env,target=self.prepare('ui-failure');env['FORGE_FAIL_STAGE']='parsers'
        result=self.run_process(self.binary_args(base,target,preview=False,components='core'),env,base,'failure')
        self.assertNotEqual(result.returncode,0);self.assertIn('ошибка',result.stderr)
        log=next((base/'logs').glob('*.log')).read_text(encoding='utf-8',errors='replace');self.assertIn('Command failed (13)',log)
        self.assertFalse((target/'bin/fride').exists())

    def test_ui_07_explicit_csv_policy(self):
        base,env,target=self.prepare('ui-csv')
        result=self.run_process(self.binary_args(base,target,components='python,sql')+['--print-plan'],env,base,'policy')
        self.assert_ok(result);plan=json.loads(result.stdout)
        self.assertEqual(plan['components'],['core','python','sql']);self.assertEqual(plan['native_sdks'],['go','python','node']);self.assertFalse(target.exists())

    def test_ui_08_unknown_component(self):
        base,env,target=self.prepare('ui-unknown')
        result=self.run_process(self.binary_args(base,target,preview=False,components='oops'),env,base,'unknown')
        self.assertNotEqual(result.returncode,0);self.assertIn('Unknown component',result.stderr);self.assertFalse(target.exists());self.assertFalse((base/'logs').exists())

    def test_ui_09_no_tty(self):
        base,env,target=self.prepare('ui-no-tty')
        result=self.run_process(self.binary_args(base,target,profile='custom'),env,base,'no-tty')
        self.assertNotEqual(result.returncode,0);self.assertIn('Custom',result.stderr);self.assertFalse(target.exists())

    def test_ui_10_root_automatic_delivery(self):
        base,env,target=self.prepare('ui-download')
        self.assert_ok(self.root_entry(base,env,target));self.assert_ok(self.launch(base,env,target))
        cache=list((base/'sources/.ui-cache').glob('*'));self.assertEqual(len(cache),1)
        self.assertEqual(hashlib.sha256(cache[0].read_bytes()).hexdigest(),self.ui_digest)
        self.assert_ok(self.root_entry(base,env,target))

    def test_ui_11_reject_ui_checksum(self):
        base,env,target=self.prepare('ui-bad-hash')
        try:
            self.publish_source('0'*64);result=self.root_entry(base,env,target)
            self.assertNotEqual(result.returncode,0);self.assertIn('UI SHA256 mismatch',result.stderr);self.assertFalse(target.exists())
        finally:self.publish_source(self.ui_digest)

    def test_ui_12_narrow_no_color(self):
        base,env,target=self.prepare('ui-narrow')
        self.pty(base,env,self.binary_args(base,target,profile='custom')+['--no-color'],'custom-back',columns=80)
        self.assertFalse(target.exists())

    def test_ui_13_custom_native_install(self):
        base,env,target=self.prepare('ui-custom-native')
        report=self.pty(base,env,self.binary_args(base,target,preview=False,profile='custom'),'custom-core')
        plan=json.loads((base/'result.json').read_text(encoding='utf-8'))
        self.assertEqual(plan['components'],['core'])
        self.assertEqual((base/'stages.txt').read_text().splitlines(),['plugins','parsers','tools'])
        self.assertIn('Подготовка завершена','\n'.join(report['frames'][-1]['lines']))
        self.assert_ok(self.launch(base,env,target))


if __name__=='__main__':
    print('work:',stand.BASE,'artifacts:',stand.ARTIFACTS,flush=True)
    names=sys.argv[1:] or [name for name in dir(UI) if name.startswith('test_ui_')]
    result=unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(UI(name) for name in names))
    summary={'tests':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),'platform':stand.PLATFORM,'ui_binary_sha256':hashlib.sha256(BINARY.read_bytes()).hexdigest()}
    (stand.BASE/'ui-summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
    if stand.BASE!=stand.ARTIFACTS:
        def ignore(directory,names):return [name for name in names if name in ('runtime','prepared','.runtime-cache','.ui-cache') or name.endswith(('.zip','.tar.gz')) or (Path(directory)/name).is_symlink()]
        shutil.copytree(stand.BASE,stand.ARTIFACTS,ignore=ignore)
    raise SystemExit(0 if result.wasSuccessful() else 1)
