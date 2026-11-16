"""IDE-BOOT-28: pinned Terminal -> HTTP/component/launcher/native font + GUI.

Core plugins/setup are fixtures; Windows GUI is real. No host installs.
"""
import hashlib
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
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
ui=load('terminal_ui',ROOT/'tests/install-ui.test.py');stand=ui.stand
publisher=load('terminal_publisher',ROOT/'scripts/prepare-terminal-runtime.py')
PREPARED=Path(os.environ.get('FORGE_TERMINAL_RUNTIME',str(ROOT/'.tests/terminal-runtime'/stand.PLATFORM)))


class Terminal(ui.UI):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        shutil.copyfile(ROOT/'wezterm.lua',cls.source/'wezterm.lua')
        cls.archive_path=stand.BASE/('terminal.zip' if stand.WINDOWS else 'terminal.tar.gz')
        publisher.package(PREPARED,cls.archive_path)
        cls.good=cls.archive_path.read_bytes();cls.routes['/terminal-part']=cls.good
        cls.routes['/runtime-core']=cls.archive.read_bytes();cls.catalog()

    @classmethod
    def catalog(cls):
        rows=[]
        for id,path in [('core','/runtime-core'),('terminal','/terminal-part')]:
            rows.append('\t'.join([stand.PLATFORM,id,cls.url+path,hashlib.sha256(cls.routes[path]).hexdigest()]))
        (cls.source/'scripts/runtime/artifacts.tsv').write_text('\n'.join(rows)+'\n',encoding='utf-8');cls.publish_source(cls.ui_digest)

    def tearDown(self):
        self.routes['/terminal-part']=self.good;self.catalog()

    def prepared(self,name):
        base,env,target=self.prepare(name)
        if libs:=os.environ.get('FORGE_WEZTERM_TEST_LIBS'):env['LD_LIBRARY_PATH']=libs
        return base,env,target

    def install_terminal(self,base,env,target,components='terminal'):
        return self.root_entry(base,env,target,components,runtime=False)

    def command(self,target,terminal=False):
        name='fride-terminal' if terminal else 'fride'
        return [stand.SHELL,'-NoProfile','-ExecutionPolicy','Bypass','-File',str(target/'bin'/(name+'.ps1'))] if stand.WINDOWS else [stand.SHELL,str(target/'bin'/name)]

    def binary(self,target):
        return target/'runtime/terminal'/publisher.policy()['wezterm']['platforms'][stand.PLATFORM]['executable']

    def test_terminal_01_delivery_font_state_repeat(self):
        base,env,target=self.prepared('terminal-native');self.assert_ok(self.install_terminal(base,env,target))
        self.assertTrue((target/'bin/fride-terminal').is_file())
        self.assertNotIn('terminal',(target/'bin/runtime-paths.txt').read_text())
        state=target/'state/wezterm-window.json';state.write_text('{"w":900,"h":700,"font_size":17}')
        diagnostic=target/'config/diagnostic.lua'
        diagnostic.write_text("local w=require('wezterm');local c=dofile(w.config_dir..'/fride-wezterm.lua');io.stderr:write('FRIDE_FONT_SIZE='..tostring(c.font_size)..'\\n');return c\n",encoding='utf-8')
        result=self.run_process([str(self.binary(target)),'--config-file',str(diagnostic),'ls-fonts','--text','A'],env,base,'native-font')
        self.assert_ok(result);self.assertIn('FRIDE_FONT_SIZE=17',result.stderr)
        self.assertIn('CaskaydiaCove',result.stdout);self.assertIn('CaskaydiaCoveNerdFont-Regular.ttf',result.stdout)
        self.assertIn('runtime/terminal/fonts',result.stdout.replace('\\','/'))
        self.assertNotIn('error',result.stderr.lower())
        self.assert_ok(self.install_terminal(base,env,target));self.assertEqual(json.loads(state.read_text())['font_size'],17)
        self.assert_ok(self.launch(base,env,target))

    def test_terminal_02_publisher_rejects_modified_binary_license_and_source(self):
        base,env,target=self.prepared('terminal-tamper')
        copy=base/'prepared';shutil.copytree(PREPARED,copy)
        executable=copy/'terminal'/publisher.policy()['wezterm']['platforms'][stand.PLATFORM]['executable']
        for file in [executable,copy/'terminal/licenses/CascadiaCode-LICENSE',copy/'sources'/publisher.sources(stand.PLATFORM)[0]['archive']]:
            original=file.read_bytes();file.write_bytes(original+b'changed')
            with self.assertRaisesRegex(ValueError,'SHA mismatch|differs from pinned source'):
                publisher.package(copy,base/'bad.zip')
            file.write_bytes(original)
        self.assertFalse((base/'bad.zip').exists());self.assertFalse(target.exists())

    def test_terminal_03_probe_failure_preserves_previous_kit(self):
        base,env,target=self.prepared('terminal-old-kit');self.assert_ok(self.install_terminal(base,env,target))
        before=stand.snapshot(target)
        # Hash-valid transport with a wrong native probe must still fail before publish.
        mutate=load('terminal_runtime_fixture',ROOT/'tests/install-runtime.test.py').Runtime.mutate
        self.routes['/terminal-part']=mutate(self.good,lambda m:dict(m,probes=[['terminal/missing-native','--version']]))
        self.catalog();result=self.install_terminal(base,env,target)
        self.assertNotEqual(result.returncode,0);self.assertEqual(stand.snapshot(target),before)
        self.assert_ok(self.launch(base,env,target))

    def test_terminal_04_core_without_terminal(self):
        base,env,target=self.prepared('terminal-unselected');self.assert_ok(self.install_terminal(base,env,target,'core'))
        self.assertFalse((target/'bin/fride-terminal').exists());self.assertFalse((target/'config/fride-wezterm.lua').exists())
        self.assert_ok(self.launch(base,env,target))

    @unittest.skipUnless(stand.WINDOWS or os.environ.get('FORGE_TERMINAL_GUI')=='1','Native GUI session required')
    def test_terminal_05_real_gui_editor_roundtrip(self):
        base,env,target=self.prepared('terminal-gui');self.assert_ok(self.install_terminal(base,env,target))
        project=base/"project ü 'space'";project.mkdir();file=project/"file ü 'new'.txt";proof=base/'gui.json'
        observer=base/'observe.lua';observer.write_text("vim.fn.writefile({vim.json.encode({exe=vim.v.progpath,file=vim.api.nvim_buf_get_name(0),cwd=vim.uv.cwd(),pane=vim.env.WEZTERM_PANE,socket=vim.env.WEZTERM_UNIX_SOCKET,config=vim.env.WEZTERM_CONFIG_FILE})},vim.env.FORGE_TERMINAL_PROOF)\n",encoding='utf-8')
        env.update(FORGE_TERMINAL_PROOF=str(proof),FORGE_TERMINAL_OBSERVER=str(observer))
        if stand.WINDOWS:
            # NVIDIA writes its own GL cache below USERPROFILE/AppData/Local.
            # Keep driver output in this test's GUI profile, separate from guarded
            # foreign config/SDK files; no production launcher environment change.
            home=base/'gui-profile';home.mkdir();env['USERPROFILE']=str(home)
            env['WEZTERM_CONFIG_FILE']=str(base/'foreign/.config/wezterm/wezterm.lua')
        arguments=self.command(target,True)+['-u','NONE','-i','NONE',str(file),'-c','lua dofile(vim.env.FORGE_TERMINAL_OBSERVER)']
        with (base/'gui-stdout.txt').open('w',encoding='utf-8') as stdout,(base/'gui-stderr.txt').open('w',encoding='utf-8') as stderr:
            process=subprocess.Popen(arguments,cwd=project,env=env,stdout=stdout,stderr=stderr)
        try:
            deadline=time.monotonic()+35
            while not proof.exists() and time.monotonic()<deadline:time.sleep(.05)
            self.assertTrue(proof.exists(),(base/'gui-stderr.txt').read_text(encoding='utf-8',errors='replace'))
            value=json.loads(proof.read_text(encoding='utf-8'));self.assertEqual(Path(value['file']),file)
            self.assertEqual(Path(value['cwd']),project);self.assertTrue(Path(value['exe']).is_relative_to(target/'runtime'))
            self.assertTrue(value['pane']);env['WEZTERM_UNIX_SOCKET']=value['socket']
            text='\x1bi'+'fride native terminal'+'\x1b:w\r'
            self.assert_ok(self.run_process([str(self.binary(target)),'cli','--no-auto-start','send-text','--pane-id',value['pane'],'--no-paste',text],env,base,'native-input'))
            deadline=time.monotonic()+10
            while not file.exists() and time.monotonic()<deadline:time.sleep(.05)
            self.assertEqual(file.read_text(encoding='utf-8').strip(),'fride native terminal')
            self.assert_ok(self.run_process([str(self.binary(target)),'cli','--no-auto-start','send-text','--pane-id',value['pane'],'--no-paste','\x1b:qa!\r'],env,base,'native-quit'))
            process.wait(timeout=15)
        finally:
            if stand.WINDOWS:
                owned=target/'runtime/terminal/wezterm/wezterm-gui.exe';self.assertTrue(owned.is_relative_to(stand.BASE))
                subprocess.run([stand.SHELL,'-NoProfile','-File',str(ROOT/'tests/diagnostics/install-terminal-stop.ps1'),'-BinaryPath',str(owned)],check=True,capture_output=True)
            if process.poll() is None:process.terminate();process.wait(timeout=5)

    def test_terminal_06_hash_valid_bad_fonts_keep_working_kit(self):
        base,env,target=self.prepared('terminal-bad-fonts');self.assert_ok(self.install_terminal(base,env,target))
        before={name:stand.snapshot(target/name) for name in ['runtime','config','bin']}
        bad=base/'bad-terminal';shutil.copytree(PREPARED/'terminal',bad/'terminal')
        for font in (bad/'terminal/fonts').glob('*.ttf'):font.write_bytes(b'not a font')
        binary='terminal/'+publisher.policy()['wezterm']['platforms'][stand.PLATFORM]['executable']
        recipe=base/'bad-recipe.json';recipe.write_text(json.dumps({'schema':1,'platform':stand.PLATFORM,'components':['terminal'],'paths':[],'probes':[[binary,'--version']]}))
        archive=base/('bad-terminal.zip' if stand.WINDOWS else 'bad-terminal.tar.gz')
        # Deliberately bypass publisher: even a hash-valid catalog/component
        # must pass its real installed config/font consumer before publish.
        stand.packager.package(bad,recipe,archive,component='terminal')
        self.routes['/terminal-part']=archive.read_bytes();self.catalog()
        result=self.install_terminal(base,env,target);self.assertNotEqual(result.returncode,0)
        for name,value in before.items():self.assertEqual(stand.snapshot(target/name),value)
        self.assertTrue(json.loads((target/'.forge-install.json').read_text())['ready'])
        self.assert_ok(self.launch(base,env,target))


if __name__=='__main__':
    print('work:',stand.BASE,'artifacts:',stand.ARTIFACTS,flush=True)
    names=sys.argv[1:] or [n for n in Terminal.__dict__ if n.startswith('test_terminal_')]
    result=unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(Terminal(n) for n in names))
    (stand.BASE/'terminal-summary.json').write_text(json.dumps({'tests':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),'skips':len(result.skipped),'platform':stand.PLATFORM},indent=2))
    if stand.BASE!=stand.ARTIFACTS:
        def ignore(directory,names):return [n for n in names if n in ('runtime','prepared','.runtime-cache') or n.endswith(('.zip','.tar.gz')) or (Path(directory)/n).is_symlink()]
        shutil.copytree(stand.BASE,stand.ARTIFACTS,ignore=ignore)
    raise SystemExit(0 if result.wasSuccessful() else 1)
