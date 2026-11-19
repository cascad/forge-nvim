"""IDE-BOOT-52: real frontend/private Core, native OS-manager/cache fixture.

No host package installation/network. Cold production catalog acceptance is
separate. Commands/library cache and privilege boundaries use native processes.
"""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import sys
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('sdk_actions',ROOT/'tests/install-sdk-actions.test.py')
actions=importlib.util.module_from_spec(spec);spec.loader.exec_module(actions)
ui,stand=actions.ui,actions.stand
LINUX=sys.platform.startswith('linux')

CATALOG={'schema':1,'requirements':[
 {'id':'zip','scopes':['core'],'command':'fride-probe-unzip','apt':['unzip'],'pacman':['unzip']},
 {'id':'gui','scopes':['terminal'],'library':'libfride-fixture-gui.so.1','apt':['libegl1'],'pacman':['libglvnd']},
 {'id':'rust-build','scopes':['rust'],'command':'fride-probe-cc','apt':['build-essential'],'pacman':['base-devel']},
]}

class System(actions.Actions):
    def setUp(self):
        (self.source/'nvim_forge/scripts/system-dependencies.json').write_text(json.dumps(CATALOG))

    def setup(self,name,mode='success'):
        base,env,target=self.prepared(name)
        env.update(SYSTEM_FIXTURE_BIN=env['SDK_PACKAGE_BIN'],SYSTEM_FIXTURE_STATE=str(base/'libraries.ready'),
            SYSTEM_FIXTURE_TRACE=str(base/'system.tsv'),SYSTEM_FIXTURE_MODE=mode,DEBIAN_FRONTEND='parent-value')
        folder=Path(env['SYSTEM_FIXTURE_BIN'])
        if LINUX:
            for name in ('ldconfig','sudo','pacman'):shutil.copy2(self.fixture,folder/name)
            for name in ('awk','chmod'):(folder/name).symlink_to(shutil.which(name))
        return base,env,target

    def arguments(self,base,target,components='core',*extra):
        args=self.binary_args(base,target,preview=False,profile='default',components=components)
        if 'terminal' in components.split(','):
            index=args.index('--runtime-path');del args[index:index+2]
        if stand.WINDOWS:args+=['--powershell',stand.SHELL]
        return args+list(extra)

    def query(self,base,env,target,components='core',*extra):
        result=self.run_process(self.arguments(base,target,components,'--check-system',*extra),env,base,'query-'+str(len(list(base.glob('query-*.json')))))
        self.assertIn(result.returncode,(0,2),result.stdout+result.stderr)
        return result,json.loads(result.stdout)

    def test_system_01_readonly_no_sdk_or_manager_and_platform_scope(self):
        base,env,target=self.setup('system-check');env['SDK_PROBE_MARKER']=str(base/'sdk-called')
        result,data=self.query(base,env,target,'core,rust')
        self.assertEqual(result.returncode,2 if LINUX else 0)
        self.assertEqual(data['scopes'],['core'])
        if LINUX:self.assertEqual([item['id'] for item in data['missing']],['zip'])
        self.assertFalse((base/'system.tsv').exists());self.assertFalse((base/'sdk-called').exists());self.assertFalse(target.exists())

    @unittest.skipUnless(LINUX,'Native APT fixture applies to Linux only')
    def test_system_02_auto_install_rechecks_long_cache_reuse_and_sudo_env(self):
        base,env,target=self.setup('system-auto');original=env.copy()
        self.assert_ok(self.run_process(self.arguments(base,target,'core,terminal','--system-deps','install'),env,base,'install'))
        self.assertEqual(env,original)
        trace=(base/'system.tsv').read_text().splitlines()
        if actions.ARCH:
            self.assertTrue(any(line.startswith('sudo\tparent-value\t') and 'pacman' in line for line in trace))
            install=next(line for line in trace if line.startswith('pacman\tparent-value\t-S\t--needed\t--noconfirm'))
            self.assertIn('libglvnd',install);self.assertNotIn('base-devel',install)
            self.assertFalse(any(line.startswith('apt-get\t') for line in trace));self.assertEqual(len(trace),2)
            self.assertFalse(set(install.split('\t')) & {'-Sy','-Syu','--refresh','--sysupgrade'})
        else:
            self.assertTrue(any(line.startswith('sudo\tparent-value\t/usr/bin/env\tDEBIAN_FRONTEND=noninteractive') for line in trace))
            install=next(line for line in trace if line.startswith('apt-get\tnoninteractive\tinstall'))
            self.assertIn('--no-upgrade',install);self.assertIn('--no-remove',install)
            self.assertIn('libegl1',install);self.assertNotIn('build-essential',install);self.assertEqual(len(trace),4)
        self.assertIn('unzip',install)
        before=(base/'system.tsv').read_bytes();result,data=self.query(base,env,target,'core,terminal')
        self.assertEqual(result.returncode,0);self.assertEqual(data['missing'],[])
        repeat=self.arguments(base,target,'core,terminal','--system-deps','install')
        repeat[repeat.index('--result')+1]=str(base/'repeat-result.json')
        self.assert_ok(self.run_process(repeat,env,base,'repeat'))
        self.assertEqual((base/'system.tsv').read_bytes(),before)

    @unittest.skipUnless(LINUX,'Native APT fixture applies to Linux only')
    def test_system_03_check_policy_and_unattended_ask_do_not_install(self):
        for policy in ('check','ask'):
            with self.subTest(policy=policy):
                base,env,target=self.setup('system-policy-'+policy)
                result=self.run_process(self.arguments(base,target,'core','--system-deps',policy),env,base,'refused')
                self.assertNotEqual(result.returncode,0);self.assertIn('--system-deps install',result.stderr)
                self.assertFalse((base/'system.tsv').exists());self.assertFalse(target.exists())

    @unittest.skipUnless(LINUX,'Native APT fixture applies to Linux only')
    def test_system_04_tty_cancel_decline_and_confirm(self):
        for scenario in ('system-cancel','system-decline','system-install'):
            with self.subTest(scenario=scenario):
                base,env,target=self.setup(scenario);env['FORGE_UI_EXPECTED_EXIT']='0' if scenario=='system-install' else '130'
                self.pty(base,env,self.arguments(base,target),scenario)
                self.assertEqual(target.joinpath('.forge-install.json').exists(),scenario=='system-install')
                self.assertEqual((base/'system.tsv').exists(),scenario=='system-install')

    @unittest.skipUnless(LINUX,'Native APT fixture applies to Linux only')
    def test_system_05_failure_noop_preserve_owned_target(self):
        for mode in ('fail','noop'):
            with self.subTest(mode=mode):
                base,env,target=self.setup('system-'+mode,mode);target.mkdir(parents=True);(target/'keep').write_text('owned by user')
                before=stand.snapshot(target)
                result=self.run_process(self.arguments(base,target,'core','--system-deps','install'),env,base,'failed')
                self.assertNotEqual(result.returncode,0);self.assertEqual(stand.snapshot(target),before)
                self.assertFalse((base/'result.json').exists())

    def test_system_06_preview_no_probes_actions_and_invalid_policy(self):
        base,env,target=self.setup('system-preview');env['SDK_PROBE_MARKER']=str(base/'sdk-called')
        self.assert_ok(self.run_process(self.arguments(base,target,'core,terminal','--preview','--system-deps','install'),env,base,'preview'))
        self.assertFalse((base/'system.tsv').exists());self.assertFalse((base/'sdk-called').exists());self.assertFalse(target.exists())
        result=self.run_process(self.arguments(base,target,'core','--system-deps','invalid'),env,base,'invalid')
        self.assertNotEqual(result.returncode,0)
        self.assertFalse((base/'system.tsv').exists())

    def test_system_09_root_bootstrap_forwards_policy(self):
        base,env,target=self.setup('system-root-policy')
        self.publish_source(self.ui_digest)
        self.assert_ok(self.root_entry(base,env,target,system_dependencies='install'))
        self.assertTrue((target/'.forge-install.json').is_file())
        self.assertEqual((base/'system.tsv').exists(),LINUX)

    @unittest.skipUnless(LINUX,'Native linker scope applies to Linux only')
    def test_system_07_rust_only_after_explicit_language_preparation(self):
        base,env,target=self.setup('system-rust')
        result,data=self.query(base,env,target,'rust');self.assertEqual(data['scopes'],['core'])
        result,data=self.query(base,env,target,'rust','--prepare-languages')
        self.assertEqual(data['scopes'],['core','rust']);self.assertIn('base-devel' if actions.ARCH else 'build-essential',data['packages'])
        self.assertFalse((base/'system.tsv').exists())

    @unittest.skipUnless(LINUX,'Native installed SDK preparation applies to Linux only')
    def test_system_08_installed_prepare_cancel_preserves_kit(self):
        base,env,target=self.setup('system-maintenance')
        self.assert_ok(self.run_process(self.arguments(base,target,'core','--system-deps','install'),env,base,'install'))
        (Path(env['SYSTEM_FIXTURE_BIN'])/'fride-probe-unzip').unlink()
        before=stand.snapshot(target);env['FORGE_UI_EXPECTED_EXIT']='130'
        binary=target/'bin/fride-setup'
        self.pty(base,env,[str(binary),'--prepare-language','sql','--installed-kit',str(target),
            '--result',str(base/'language.json'),'--log-dir',str(base/'prepare logs')],'system-cancel')
        self.assertEqual(stand.snapshot(target),before);self.assertFalse((base/'language.json').exists())

if __name__=='__main__':
    print('work:',stand.BASE,flush=True)
    names=sys.argv[1:] or [name for name in System.__dict__ if name.startswith('test_system_')]
    result=unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(System(name) for name in names))
    (stand.BASE/'system-summary.json').write_text(json.dumps({'tests':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),'skipped':len(result.skipped)}))
    raise SystemExit(0 if result.wasSuccessful() else 1)
