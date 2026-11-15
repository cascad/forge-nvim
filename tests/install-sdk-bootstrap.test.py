"""IDE-BOOT-21: explicit native manager bootstrap; never installs host packages."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import sys
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('actions',ROOT/'tests/install-sdk-actions.test.py')
actions=importlib.util.module_from_spec(spec);spec.loader.exec_module(actions)
stand=actions.stand
MAC=sys.platform=='darwin'

class Bootstrap(actions.Actions):
    def prepared_bootstrap(self,name):
        if not stand.WINDOWS and not MAC:self.skipTest('Ubuntu uses OS APT; see SDK actions missing-manager case')
        if MAC and any(Path(p).is_file() for p in ['/opt/homebrew/bin/brew','/usr/local/bin/brew']):
            self.skipTest('Bootstrap needs a clean macOS stand without standard Homebrew; existing brew is deliberately reused')
        base,env,target=self.prepared(name,False)
        # Explicitly installed manager has its own fixture user area. The base
        # stand's ordinary nvim/profile snapshot remains protected unchanged.
        if stand.WINDOWS:env['LOCALAPPDATA']=str(base/'bootstrap user/local')
        toolkit=Path(env['PATH']);program=toolkit/('powershell.exe' if stand.WINDOWS else 'bash')
        program.unlink(missing_ok=True);shutil.copy2(self.fixture,program)
        manager_bin=Path(env['LOCALAPPDATA'])/'Microsoft/WindowsApps' if stand.WINDOWS else toolkit
        env.update(SDK_BOOTSTRAP_TRACE=str(base/'bootstrap.tsv'),SDK_BOOTSTRAP_MODE='success',SDK_BOOTSTRAP_BIN=str(manager_bin))
        return base,env,target

    def test_bootstrap_01_default_decline(self):
        base,env,target=self.prepared_bootstrap('bootstrap-decline')
        self.interact(base,env,target,'sdk-bootstrap-decline',130)
        self.assertFalse((base/'bootstrap.tsv').exists());self.assertFalse((base/'package.tsv').exists());self.assertFalse(target.exists())

    def test_bootstrap_02_confirmed_then_sdk(self):
        base,env,target=self.prepared_bootstrap('bootstrap-install')
        self.interact(base,env,target,'sdk-bootstrap-install')
        calls=(base/'bootstrap.tsv').read_text(encoding='utf-8').splitlines();self.assertEqual(len(calls),1)
        if stand.WINDOWS:
            self.assertIn('Microsoft.WinGet.Client',calls[0]);self.assertIn('-Scope CurrentUser',calls[0]);self.assertNotIn('-AllUsers',calls[0]);self.assertNotIn('Set-PSRepository',calls[0])
            script=base/'actual bootstrap recipe.ps1';script.write_text(calls[0].split('\t')[-1],encoding='utf-8')
            expected={'missing':['provider','module','import','repair'],'module':['import','repair'],
                'provider':['module','import','repair'],'failure':['provider','module']}
            for mode,steps in expected.items():
                trace=base/(mode+'-cmdlets.json')
                result=self.run_process([stand.SHELL,'-NoProfile','-File',str(ROOT/'tests/diagnostics/bootstrap-winget.test.ps1'),
                    '-ScriptPath',str(script),'-TracePath',str(trace),'-Mode',mode],env,base,'cmdlets-'+mode)
                self.assertEqual(result.returncode==0,mode!='failure',result.stderr)
                self.assertEqual(json.loads(trace.read_text(encoding='utf-8-sig')),steps)
        else:
            self.assertIn('https://raw.githubusercontent.com/Homebrew/install/e5b3c5834e3932c8aaa42deef4794076c9b0cbf0/install.sh',calls[0]);self.assertIn('set -e;',calls[0])
        self.assertEqual(len((base/'package.tsv').read_text().splitlines()),1)
        self.assertEqual(len(list((base/'logs').glob('sdk-install-*.log'))),2)
        self.assertTrue((target/'bin/fride').exists());self.assertEqual((target/'bin/sdk-paths.txt').read_text(),'')
        if stand.WINDOWS:self.assertNotIn(env['SDK_BOOTSTRAP_BIN'],env['PATH'])

    def test_bootstrap_03_separate_sdk_decline(self):
        base,env,target=self.prepared_bootstrap('bootstrap-sdk-decline')
        self.interact(base,env,target,'sdk-bootstrap-sdk-decline',130)
        self.assertTrue((base/'bootstrap.tsv').exists());self.assertFalse((base/'package.tsv').exists());self.assertFalse((base/'result.json').exists())
        self.assertTrue(any(Path(env['SDK_BOOTSTRAP_BIN']).glob('winget.exe' if stand.WINDOWS else 'brew')))

    def test_bootstrap_04_failure_retry(self):
        base,env,target=self.prepared_bootstrap('bootstrap-retry');env['SDK_BOOTSTRAP_MODE']='once-fail'
        self.interact(base,env,target,'sdk-bootstrap-retry')
        self.assertEqual(len((base/'bootstrap.tsv').read_text().splitlines()),2)
        self.assertEqual(len((base/'package.tsv').read_text().splitlines()),1)
        logs=[p.read_text(encoding='utf-8') for p in (base/'logs').glob('sdk-install-*.log')]
        self.assertTrue(any('7' in log and 'fixture manager bootstrap' in log for log in logs))

    def test_bootstrap_05_exit_zero_without_manager(self):
        base,env,target=self.prepared_bootstrap('bootstrap-noop');env['SDK_BOOTSTRAP_MODE']='noop'
        self.interact(base,env,target,'sdk-bootstrap-noop',130)
        self.assertFalse((base/'package.tsv').exists());self.assertFalse(target.exists());self.assertFalse((base/'result.json').exists())

    def test_bootstrap_06_escape(self):
        base,env,target=self.prepared_bootstrap('bootstrap-escape')
        self.interact(base,env,target,'sdk-bootstrap-cancel',130)
        self.assertFalse((base/'bootstrap.tsv').exists());self.assertFalse((base/'package.tsv').exists())

    @unittest.skipUnless(stand.WINDOWS,'Windows standard execution alias outside PATH')
    def test_bootstrap_07_existing_standard_alias(self):
        base,env,target=self.prepared_bootstrap('bootstrap-alias')
        aliases=Path(env['SDK_BOOTSTRAP_BIN']);aliases.mkdir(parents=True);shutil.copy2(self.fixture,aliases/'winget.exe')
        self.interact(base,env,target,'sdk-install')
        self.assertFalse((base/'bootstrap.tsv').exists());self.assertEqual(len((base/'package.tsv').read_text().splitlines()),1)

    def test_bootstrap_08_cancel_preserves_old_kit(self):
        base,env,target=self.prepared_bootstrap('bootstrap-installed-cancel');target.mkdir(parents=True)
        (target/'keep').write_text('existing kit');before=stand.snapshot(target)
        self.interact(base,env,target,'sdk-bootstrap-install-cancel',130)
        self.assertEqual(stand.snapshot(target),before);self.assertFalse((base/'result.json').exists())
        self.assertTrue((base/'bootstrap.tsv').exists());self.assertTrue((base/'package.tsv').exists())

    def test_bootstrap_09_noninteractive_never_installs(self):
        base,env,target=self.prepared('bootstrap-headless',False)
        for extra,success in [([],False),(['--preview'],True),(['--check-sdks'],False)]:
            args=self.arguments(base,target)+extra
            result=self.run_process(args,env,base,'headless-'+str(len(extra))+'-'+str(success))
            self.assertEqual(result.returncode==0,success,result.stderr)
        self.assertFalse((base/'package.tsv').exists());self.assertFalse(target.exists());self.assertFalse((base/'bootstrap.tsv').exists())

if __name__=='__main__':
    print('work:',stand.BASE,'artifacts:',stand.ARTIFACTS,flush=True)
    names=sys.argv[1:] or [n for n in Bootstrap.__dict__ if n.startswith('test_bootstrap_')]
    result=unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(Bootstrap(n) for n in names))
    (stand.BASE/'sdk-bootstrap-summary.json').write_text(json.dumps({'tests':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),'skipped':len(result.skipped),'platform':stand.PLATFORM},indent=2))
    if stand.BASE!=stand.ARTIFACTS:
        def ignore(directory,names):return [n for n in names if n in ('runtime','prepared','.runtime-cache') or n.endswith(('.zip','.tar.gz')) or (Path(directory)/n).is_symlink()]
        shutil.copytree(stand.BASE,stand.ARTIFACTS,ignore=ignore)
    raise SystemExit(0 if result.wasSuccessful() else 1)
