"""IDE-BOOT-15: native Neovim, real Mason Lua provider/receipts/parser loader.
Install commands intentionally return success without doing work; no network.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import unittest

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'.tests/install-readiness'/(str(time.time_ns())+' ü space')
BASE.mkdir(parents=True)
DEPS=Path(os.environ.get('FORGE_E2E_DEPS',str(ROOT/'.tests/editor-deps')))
NVIM=Path(os.environ.get('FORGE_INSTALL_TEST_NVIM',str(ROOT/'.tools/neovim/windows-x64/bin/nvim.exe') if os.name=='nt' else shutil.which('nvim') or ''))
SOURCE=Path(os.environ.get('FORGE_INSTALL_READINESS_STAGE',str(ROOT/'nvim_forge/scripts/setup-stage.lua')))
assert NVIM.is_file() and (DEPS/'lazy/mason.nvim/lua/mason/init.lua').is_file()

class Readiness(unittest.TestCase):
    def execute(self,name,stage='tools'):
        base=BASE/name;base.mkdir();profile=base/'profile';(profile/'lua/forge').mkdir(parents=True);(profile/'scripts').mkdir()
        for module in ['tool_catalog','setup_readiness','install_profile']:
            shutil.copyfile(ROOT/('nvim_forge/lua/forge/'+module+'.lua'),profile/('lua/forge/'+module+'.lua'))
        shutil.copyfile(SOURCE,profile/'scripts/setup-stage.lua')
        parser='lua,forge_missing' if name=='missing-parser' else ('lua,forge_broken' if name=='broken-parser' else 'lua')
        (profile/'scripts/components.tsv').write_text('core\tFixture\t-\tfixture-native\t'+parser+'\nnode\tUnused\t-\tmissing-unselected\tmissing_unselected\n',encoding='utf-8')
        init=base/'init.lua';init.write_text("package.path="+json.dumps(str(profile/'lua/?.lua').replace('\\','/'),ensure_ascii=False)+"..';'..package.path\n"+
            "dofile("+json.dumps(str(ROOT/'tests/diagnostics/setup-readiness-fixture.lua').replace('\\','/'),ensure_ascii=False)+")\n"+
            "vim.api.nvim_create_user_command('Lazy',function() vim.api.nvim_create_user_command('MasonToolsInstallSync',function() vim.fn.writefile({'success without install'},vim.env.FORGE_READINESS_TRACE) end,{force=true}) end,{nargs='*',bang=true})\n"+
            "vim.api.nvim_create_user_command('ForgeTreesitterInstall',function() vim.fn.writefile({'success without install'},vim.env.FORGE_READINESS_TRACE) end,{})\n",encoding='utf-8')
        foreign=base/'foreign';foreign.mkdir();(foreign/'keep').write_text('owner data')
        env=os.environ.copy();env.update(HOME=str(foreign),USERPROFILE=str(foreign),LOCALAPPDATA=str(base/'local'),
            XDG_CONFIG_HOME=str(base/'config'),XDG_DATA_HOME=str(base/'data'),XDG_STATE_HOME=str(base/'state'),XDG_CACHE_HOME=str(base/'cache'),
            NVIM_APPNAME='readiness',NVIM_LOG_FILE=str(base/'nvim.log'),FORGE_NVIM_COMPONENTS='core',
            FORGE_READINESS_CASE=name,FORGE_READINESS_DEPS=str(DEPS),FORGE_READINESS_ROOT=str(base/'mason'),FORGE_READINESS_TRACE=str(base/'command.txt'))
        result=subprocess.run([str(NVIM),'--headless','-u',str(init),'-i','NONE','-l',str(profile/'scripts/setup-stage.lua'),stage],env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=30)
        (base/'result.json').write_text(json.dumps({'exit':result.returncode,'stdout':result.stdout,'stderr':result.stderr,'stage':stage,'source':str(SOURCE),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest()},ensure_ascii=False,indent=2),encoding='utf-8')
        self.assertEqual((foreign/'keep').read_text(),'owner data')
        self.assertTrue((base/'command.txt').exists(),'Install callback never ran; wrong failure')
        return result

    def failed(self,name,reason,stage='tools'):
        result=self.execute(name,stage);self.assertNotEqual(result.returncode,0,'Stage reported success without postconditions')
        self.assertIn('Setup stage '+stage+' failed',result.stderr);self.assertIn(reason,result.stderr)
        self.assertNotIn('Setup stage '+stage+' done',result.stdout)

    def test_01_missing_package(self):self.failed('missing-package','fixture-native')
    def test_02_missing_receipt(self):self.failed('missing-receipt','install receipt missing')
    def test_03_corrupt_receipt(self):self.failed('corrupt-receipt','fixture-native')
    def test_04_missing_source(self):self.failed('missing-source','source missing')
    def test_05_missing_export(self):self.failed('missing-export','export missing')
    def test_06_host_fallback(self):self.failed('host-fallback','export missing')
    def test_07_wrong_receipt(self):self.failed('wrong-receipt','another package')
    def test_08_tools_ready_selected(self):
        result=self.execute('ready');self.assertEqual(result.returncode,0,result.stdout+result.stderr);self.assertIn('Tool readiness:',result.stdout)
    def test_09_missing_parser(self):self.failed('missing-parser','forge_missing','parsers')
    def test_10_broken_parser(self):self.failed('broken-parser','forge_broken','parsers')
    def test_11_parsers_ready_selected(self):
        result=self.execute('ready-parser','parsers');self.assertEqual(result.returncode,0,result.stdout+result.stderr);self.assertIn('Parser readiness:',result.stdout)

    def test_12_share_opt_ready(self):
        result=self.execute('share-ready');self.assertEqual(result.returncode,0,result.stdout+result.stderr)
    def test_13_missing_share(self):self.failed('share-missing','share export missing')
    def test_14_missing_opt(self):self.failed('opt-missing','opt export missing')
    def test_15_legacy_receipt(self):
        result=self.execute('legacy-receipt');self.assertEqual(result.returncode,0,result.stdout+result.stderr)

    @unittest.skipIf(os.name=='nt','POSIX executable mode')
    def test_16_nonexecutable_export(self):self.failed('not-executable','not executable')

if __name__=='__main__':
    import sys
    print('artifacts:',BASE,flush=True)
    suite=unittest.defaultTestLoader.loadTestsFromNames(sys.argv[1:],sys.modules[__name__]) if len(sys.argv)>1 else unittest.defaultTestLoader.loadTestsFromTestCase(Readiness)
    result=unittest.TextTestRunner(verbosity=2).run(suite)
    (BASE/'summary.json').write_text(json.dumps({'tests':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),'source':str(SOURCE),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest()},indent=2))
    raise SystemExit(0 if result.wasSuccessful() else 1)
