"""IDE-BOOT-30: offline native Lazy/Git clone, checkout and build failures.

Requires prepared pinned Lazy in FORGE_E2E_DEPS, native Neovim and Git.
Never downloads plugins, installs SDKs or writes user Git configuration.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
BASE = Path(os.environ.get('FORGE_PLUGIN_TEST_ROOT', str(ROOT / '.tests/plugin-setup'))) / str(time.time_ns())
BASE.mkdir(parents=True)
DEPS = Path(os.environ.get('FORGE_E2E_DEPS', str(ROOT / '.tests/editor-deps')))
LAZY_SOURCE = DEPS / 'lazy/lazy.nvim'
LAZY = BASE / 'lazy.nvim'
NVIM = Path(os.environ.get('FORGE_INSTALL_TEST_NVIM', str(ROOT / '.tools/neovim/windows-x64/bin/nvim.exe') if os.name == 'nt' else shutil.which('nvim') or ''))
assert NVIM.is_file() and (LAZY_SOURCE / 'lua/lazy/init.lua').is_file(), 'Prepared native Neovim/Lazy required'
# Native Lazy regenerates its own help tags. Give it an owned writable copy.
shutil.copytree(LAZY_SOURCE, LAZY)


class Plugins(unittest.TestCase):
    def run_case(self, name, failure=None, existing=False, patch=False):
        base = BASE / name
        base.mkdir()
        env = os.environ.copy()
        for key in ['HOME', 'USERPROFILE', 'LOCALAPPDATA', 'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_STATE_HOME', 'XDG_CACHE_HOME', 'TEMP', 'TMP', 'TMPDIR']:
            path = base / key
            path.mkdir()
            env[key] = str(path)
        gitconfig = base / 'gitconfig'
        gitconfig.write_bytes(b'[core]\n\tlongpaths = false\n')
        env.update(NVIM_APPNAME='fride', NVIM_LOG_FILE=str(base / 'nvim.log'),
                   GIT_CONFIG_GLOBAL=str(gitconfig), GIT_CONFIG_NOSYSTEM='1', GIT_TERMINAL_PROMPT='0',
                   GIT_CONFIG_COUNT='1', GIT_CONFIG_KEY_0='protocol.file.allow', GIT_CONFIG_VALUE_0='always')
        def git(*args, cwd=base):
            result = subprocess.run(['git', '-c', 'core.longpaths=true', *args], cwd=cwd, env=env, capture_output=True, text=True)
            assert result.returncode == 0, result.stdout + result.stderr
            return result.stdout.strip()
        repo = base / 'upstream'
        repo.mkdir()
        git('init', '-q', cwd=repo)
        git('config', 'user.name', 'Fixture', cwd=repo)
        git('config', 'user.email', 'fixture@example.invalid', cwd=repo)
        git('config', 'core.longpaths', 'true', cwd=repo)
        # Upstream path is short; the SAME tracked path exceeds MAX_PATH only
        # after cloning into the deeper Neovim data/lazy/plugin directory.
        file = repo / ('directory-' * 6) / ('file-' * 16 + '.txt')
        file.parent.mkdir()
        file.write_bytes(b'pinned\n')
        (repo / 'control.lua').write_bytes(b'pinned\n')
        git('add', '.', cwd=repo)
        git('commit', '-qm', 'pinned', cwd=repo)
        pin = git('rev-parse', 'HEAD', cwd=repo)
        file.write_bytes(b'newer\n')
        git('commit', '-qam', 'newer', cwd=repo)
        branch = git('branch', '--show-current', cwd=repo)
        lazy_root = base / 'XDG_DATA_HOME/fride-data/lazy'
        if existing:
            lazy_root.mkdir(parents=True)
            git('clone', '-q', repo.as_posix(), str(lazy_root / 'fixture'))
            if patch or failure == 'dirty':
                git('checkout', '-q', pin, cwd=lazy_root / 'fixture')
                patched = lazy_root / 'fixture/control.lua'
                patched.write_text('known patch\n' if patch else 'unknown owner change\n')
                if patch: env['FORGE_PLUGIN_PATCH'] = str(patched)
        lock = base / 'lazy-lock.json'
        payload = {'fixture': {'branch': branch, 'commit': '0' * 40 if failure == 'pin' else pin}}
        if failure == 'spec': payload['unloaded'] = {'branch': branch, 'commit': pin}
        # Include prepared manager's actual pin: it is local in this native stand.
        lock.write_bytes((json.dumps(payload, indent=3) + '\n').encode())
        original = lock.read_bytes()
        source = str(base / 'absent') if failure == 'clone' else str(repo)
        init = base / 'init.lua'
        def lua_path(path):
            return json.dumps(str(path).replace('\\', '/'), ensure_ascii=False)
        init.write_text(
            'package.path=' + lua_path(ROOT / 'nvim_forge/lua/?.lua') + "..';'..package.path\n"
            'vim.opt.rtp:prepend(' + lua_path(ROOT / 'nvim_forge') + ')\n'
            'vim.opt.rtp:prepend(' + lua_path(LAZY) + ')\n'
            "require('lazy').setup({root=" + lua_path(lazy_root) + ',lockfile=' + lua_path(lock) +
            ",spec={{name='fixture',url=" + lua_path(source) +
            (",build=function() error('expected fixture build failure') end" if failure == 'build' else '') +
            "}},install={missing=false},checker={enabled=false},change_detection={enabled=false},rocks={enabled=false},performance={cache={enabled=false}}})\n",
            encoding='utf-8')
        command = [str(NVIM), '--headless', '-i', 'NONE', '-u', str(init), '-l', str(ROOT / 'tests/diagnostics/install-plugin-setup.lua')]
        (base / 'command.json').write_text(json.dumps({'argv': command, 'timeout': 45000}), encoding='utf-8')
        outer = subprocess.run([str(NVIM), '--headless', '-u', 'NONE', '-i', 'NONE', '-l', str(ROOT / 'tests/diagnostics/install-command-scope.lua'), str(ROOT), str(base)],
                               env=env, cwd=ROOT, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=70)
        self.assertEqual(outer.returncode, 0, outer.stdout + outer.stderr)
        result = json.loads((base / 'result.json').read_text(encoding='utf-8'))
        output = (base / 'output.txt').read_text(encoding='utf-8', errors='replace')
        self.assertEqual(lock.read_bytes(), original, 'Lazy changed source lock')
        self.assertEqual(gitconfig.read_bytes(), b'[core]\n\tlongpaths = false\n')
        cleanup = json.loads((base / 'controller/shutdown.json').read_text(encoding='utf-8'))
        self.assertTrue(cleanup['ok'], cleanup)
        if failure:
            self.assertNotEqual(result['code'], 0, output)
            self.assertIn('unloaded:' if failure == 'spec' else 'fixture:', output)
            self.assertNotIn('Plugin readiness:', output)
            if failure == 'dirty': self.assertEqual(patched.read_text(), 'unknown owner change\n')
        else:
            self.assertEqual(result['code'], 0, output)
            self.assertIn('Plugin readiness:', output)
            self.assertEqual(git('rev-parse', 'HEAD', cwd=lazy_root / 'fixture'), pin)
            self.assertEqual((lazy_root / 'fixture' / file.relative_to(repo)).read_text(), 'pinned\n')
        return output

    def test_01_cold_pinned_long_path(self): self.run_case('cold')
    def test_02_existing_wrong_head(self): self.run_case('existing', existing=True)
    def test_03_clone_failure(self): self.assertIn('clone', self.run_case('clone', 'clone'))
    def test_04_build_failure(self): self.assertIn('expected fixture build failure', self.run_case('build', 'build'))
    def test_05_missing_pin(self): self.assertIn('checkout', self.run_case('pin', 'pin'))
    def test_06_known_patch_restore(self): self.run_case('patched', existing=True, patch=True)
    def test_07_unknown_change_preserved(self): self.run_case('dirty', failure='dirty', existing=True)
    def test_08_missing_loaded_spec(self): self.assertIn('missing from loaded spec', self.run_case('spec', failure='spec'))


if __name__ == '__main__':
    print('evidence:', BASE, flush=True)
    unittest.main()
