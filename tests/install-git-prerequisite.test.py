"""IDE-BOOT-27: native Git prerequisite, PTY decisions and real launcher/config.

Package managers are executable fixtures; no host installs, credentials or network Git.
"""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('actions', ROOT/'tests/install-sdk-actions.test.py')
actions = importlib.util.module_from_spec(spec); spec.loader.exec_module(actions)
ui, stand = actions.ui, actions.stand
GIT = shutil.which('git')


class Git(actions.Actions):
    def prepared(self, name, manager=True):
        base, env, target = super().prepared(name, manager)
        (Path(env['PATH'])/('git.exe' if stand.WINDOWS else 'git')).unlink()
        return base, env, target

    def arguments(self, base, target):
        args = super().arguments(base, target)
        args[args.index('--components')+1] = 'core'
        return args

    def check(self, base, env, target, extra=()):
        result = self.run_process(self.arguments(base, target)+['--check-tools', *extra], env, base, 'check-'+str(time.time_ns()))
        return result, json.loads(result.stdout)['tools'][0]

    def git_fixture(self, folder):
        folder.mkdir(parents=True, exist_ok=True)
        shutil.copy2(self.fixture, folder/('git.exe' if stand.WINDOWS else 'git'))
        return folder

    def test_git_01_missing_invalid_timeout_and_preview(self):
        base, env, target = self.prepared('git-check')
        target.mkdir(parents=True); (target/'keep').write_text('existing kit')
        before = stand.snapshot(target); start = len(self.requests)
        result, tool = self.check(base, env, target)
        self.assertEqual(result.returncode, 2); self.assertEqual(tool['status'], 'missing')
        self.git_fixture(Path(env['PATH']))
        for mode in ['invalid', 'exit', 'timeout']:
            env['SDK_PROBE_MODE'] = mode; start_time = time.monotonic()
            result, tool = self.check(base, env, target)
            self.assertEqual(result.returncode, 2); self.assertEqual(tool['status'], 'unavailable')
            self.assertLess(time.monotonic()-start_time, 7)
        env.update(SDK_PROBE_MARKER=str(base/'marker'), SDK_PROBE_MODE='invalid')
        self.assert_ok(self.run_process(self.arguments(base, target)+['--preview'], env, base, 'preview'))
        self.assertFalse((base/'marker').exists())
        result = self.run_process(self.arguments(base, target), env, base, 'noninteractive')
        self.assertNotEqual(result.returncode, 0); self.assertIn('Git prerequisite', result.stderr)
        self.assertEqual(self.requests[start:], []); self.assertEqual(stand.snapshot(target), before)
        self.assertFalse((base/'stages.txt').exists()); self.assertFalse((base/'package.tsv').exists())

    def test_git_02_choose_existing_cmd_repeat(self):
        base, env, target = self.prepared('git-existing')
        root = base/"Git ü 'choice'"; directory = self.git_fixture(root/'cmd')
        env['FORGE_UI_GIT_INPUT'] = str(root)
        report = self.interact(base, env, target, 'git-existing')
        self.assertNotIn('Пропустить зависимые компоненты', report['frames'][0]['raw'])
        self.assertEqual((target/'bin/sdk-paths.txt').read_text().splitlines(), [str(directory)])
        args = self.arguments(base, target); index = args.index('--result'); del args[index:index+2]
        self.assert_ok(self.run_process(args, env, base, 'repeat'))
        self.assertFalse((base/'package.tsv').exists())

    def test_git_03_cancel_preserves_kit(self):
        base, env, target = self.prepared('git-cancel')
        target.mkdir(parents=True); (target/'keep').write_text('existing kit'); before = stand.snapshot(target)
        self.interact(base, env, target, 'git-cancel', 130)
        self.assertEqual(stand.snapshot(target), before); self.assertFalse((base/'package.tsv').exists())

    def test_git_04_decline_does_not_install(self):
        base, env, target = self.prepared('git-decline')
        self.interact(base, env, target, 'git-decline', 130)
        self.assertFalse((base/'package.tsv').exists()); self.assertFalse(target.exists())

    def test_git_05_confirmed_native_recipe(self):
        base, env, target = self.prepared('git-install')
        self.interact(base, env, target, 'git-install')
        calls = (base/'package.tsv').read_text().splitlines()
        self.assertEqual(len(calls), 1); self.assertIn('Git.Git' if stand.WINDOWS else '\tgit', calls[0])
        if sys.platform != 'darwin': self.assertIn('--no-upgrade', calls[0])
        if stand.WINDOWS: self.assertIn('--source\twinget', calls[0])
        self.assertTrue((target/'bin/fride').exists()); self.assertTrue(list((base/'logs').glob('tools-*.json')))

    def test_git_06_zero_without_git_is_not_ready(self):
        base, env, target = self.prepared('git-noop'); env['SDK_PACKAGE_MODE'] = 'noop'
        self.interact(base, env, target, 'git-noop', 130)
        self.assertEqual(len((base/'package.tsv').read_text().splitlines()), 1)
        self.assertFalse(target.exists()); self.assertFalse((base/'result.json').exists())

    def test_git_07_real_git_config_launcher_and_local_commit(self):
        self.assertTrue(GIT, 'Prepared host Git required; test never installs it')
        base, env, target = self.prepared('git-real')
        config = base/'ordinary.gitconfig'; config.write_text('[user]\n\tname = Forge E2E\n\temail = e2e@localhost\n[credential]\n\thelper = fixture-do-not-invoke\n')
        original = config.read_bytes()
        env.update(GIT_CONFIG_GLOBAL=str(config), GIT_CONFIG_NOSYSTEM='1', GIT_TERMINAL_PROMPT='0', SSH_AUTH_SOCK='forge-ssh-marker')
        git_dir = Path(GIT).parent
        result, report = self.check(base, env, target, ['--tool-path', str(git_dir)])
        self.assert_ok(result); self.assertEqual(report['status'], 'ready')
        self.assertEqual(Path(report['tools'][0]['path']), Path(GIT))
        self.assert_ok(self.run_process(self.arguments(base, target)+['--tool-path', str(git_dir)], env, base, 'install-real'))
        observer = base/'git.lua'; output = base/'git.json'; project = base/'project'; project.mkdir()
        env.update(FORGE_GIT_REPORT=str(output), FORGE_GIT_PROJECT=str(project))
        observer.write_text("""local function git(args)
 local cmd={'git'};vim.list_extend(cmd,args)
 local r=vim.system(cmd,{cwd=vim.env.FORGE_GIT_PROJECT,text=true}):wait(10000)
 assert(r.code==0,(r.stderr or '')..vim.inspect(cmd));return vim.trim(r.stdout or '')
end
git({'init','--initial-branch=main'})
vim.fn.writefile({'native Git'},vim.env.FORGE_GIT_PROJECT..'/file.txt')
git({'add','file.txt'});git({'-c','commit.gpgsign=false','commit','-m','local fixture'})
vim.fn.writefile({vim.json.encode({exe=vim.fn.exepath('git'),config=git({'config','--global','--get','credential.helper'}),
 head=git({'rev-parse','HEAD'}),sock=vim.env.SSH_AUTH_SOCK,global=vim.env.GIT_CONFIG_GLOBAL})},vim.env.FORGE_GIT_REPORT)
""", encoding='utf-8')
        command = ([stand.SHELL, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(target/'bin/fride.ps1')] if stand.WINDOWS else [stand.SHELL, str(target/'bin/fride')])
        self.assert_ok(self.run_process(command+['--headless','-u','NONE','-i','NONE','-l',str(observer)], env, base, 'observe-real'))
        proof = json.loads(output.read_text()); self.assertEqual(Path(proof['exe']), Path(GIT))
        self.assertEqual(proof['config'], 'fixture-do-not-invoke'); self.assertEqual(proof['sock'], 'forge-ssh-marker')
        self.assertEqual(Path(proof['global']), config); self.assertRegex(proof['head'], r'^[0-9a-f]{40,64}$')
        self.assertEqual(config.read_bytes(), original); self.assertFalse((base/'package.tsv').exists())
        self.assertFalse(any(p.name.lower() in ('git','git.exe') for p in target.rglob('*')))

    def test_git_08_path_precedes_fallback(self):
        base, env, target = self.prepared('git-priority')
        first = self.git_fixture(Path(env['PATH'])); fallback = self.git_fixture(base/'fallback')
        result, report = self.check(base, env, target, ['--tool-path', str(fallback)])
        self.assert_ok(result); self.assertEqual(Path(report['tools'][0]['path']).parent, first)
        env['SDK_PROBE_MODE'] = 'invalid'
        result, report = self.check(base, env, target, ['--tool-path', str(Path(GIT).parent)])
        self.assertEqual(result.returncode, 2); self.assertEqual(Path(report['tools'][0]['path']).parent, first)

    @unittest.skipUnless(sys.platform == 'darwin', 'Native Apple shim acceptance only')
    def test_git_09_apple_shim_read_only(self):
        base, env, target = self.prepared('git-apple-shim')
        env['PATH'] = '/usr/bin:/bin'
        before = subprocess.run(['/usr/bin/xcode-select','--print-path'], env=env, capture_output=True, text=True, timeout=4)
        result, report = self.check(base, env, target)
        selected = Path(before.stdout.strip())
        available = before.returncode == 0 and selected.is_absolute() and (selected/'usr/bin/git').is_file()
        if available:
            self.assert_ok(result); self.assertEqual(report['status'], 'ready')
        else:
            self.assertEqual(result.returncode, 2); self.assertEqual(report['status'], 'unavailable')
            self.assertIn('Developer Tools', report['tools'][0]['detail'])
        self.assertTrue(list((base/'logs').glob('*.select.log')))
        after = subprocess.run(['/usr/bin/xcode-select','--print-path'], env=env, capture_output=True, text=True, timeout=4)
        self.assertEqual((before.returncode,before.stdout),(after.returncode,after.stdout))
        self.assertFalse(target.exists()); self.assertFalse((base/'package.tsv').exists())


if __name__ == '__main__':
    print('work:', stand.BASE, 'artifacts:', stand.ARTIFACTS, flush=True)
    names = sys.argv[1:] or [n for n in Git.__dict__ if n.startswith('test_git_')]
    result = unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(Git(n) for n in names))
    (stand.BASE/'git-summary.json').write_text(json.dumps({'tests':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),'platform':stand.PLATFORM},indent=2))
    if stand.BASE != stand.ARTIFACTS:
        def ignore(directory,names): return [n for n in names if n in ('runtime','prepared','.runtime-cache') or n.endswith(('.zip','.tar.gz')) or (Path(directory)/n).is_symlink()]
        shutil.copytree(stand.BASE, stand.ARTIFACTS, ignore=ignore)
    raise SystemExit(0 if result.wasSuccessful() else 1)
