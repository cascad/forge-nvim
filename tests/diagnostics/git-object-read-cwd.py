"""IDE-038: живой Git object read с cwd worktree и с явным git-dir."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile


def main():
    root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=root / '.tests/git-object-read-cwd.json')
    args = parser.parse_args()
    base_dir = root / '.tests/tmp' if os.name == 'nt' else Path(tempfile.gettempdir())
    base_dir.mkdir(parents=True, exist_ok=True)
    parent = base_dir.resolve()
    results = []
    for mode in ('with_C', 'explicit_only', 'explicit_without_worktree', 'inherited_linked', 'common_cwd'):
        with tempfile.TemporaryDirectory(prefix='git-object-cwd-', dir=parent) as folder:
            base = Path(folder)
            assert base.resolve().parent == parent, 'Unexpected private fixture path'
            main_tree, linked = base / 'main', base / 'linked with space'
            main_tree.mkdir()
            env = dict(os.environ, GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL='NUL' if os.name == 'nt' else '/dev/null',
                       GIT_TERMINAL_PROMPT='0', GIT_CEILING_DIRECTORIES=str(base))

            def git(*argv, cwd=main_tree):
                r = subprocess.run(['git', *argv], cwd=cwd, env=env, capture_output=True, timeout=10)
                assert r.returncode == 0, (argv, r.stderr)
                return r.stdout

            git('init', '--initial-branch=main')
            for key, value in (('user.name', 'Fixture'), ('user.email', 'fixture@example.invalid'),
                               ('commit.gpgsign', 'false'), ('core.autocrlf', 'false'),
                               ('core.hooksPath', str(base / 'no-hooks'))):
                git('config', key, value)
            main_bytes = b'MAIN_' + b'x' * 524283
            linked_bytes = b'LINKED_' + b'x' * 524281
            (main_tree / 'large.txt').write_bytes(main_bytes)
            git('add', '.'); git('commit', '-m', 'main fixture')
            head = git('rev-parse', 'HEAD')
            git('worktree', 'add', '-b', 'linked', str(linked))
            (linked / 'large.txt').write_bytes(linked_bytes)
            git('add', '.', cwd=linked); git('commit', '-m', 'linked fixture', cwd=linked)
            assert git('rev-parse', 'HEAD', cwd=linked) != head
            gitdir = git('rev-parse', '--absolute-git-dir', cwd=linked).decode().strip()
            common = Path(git('rev-parse', '--git-common-dir', cwd=linked).decode().strip())
            common = common.resolve() if common.is_absolute() else (linked / common).resolve()
            command = ['git']
            if mode == 'with_C':
                command += ['-C', str(linked)]
            command += ['--git-dir', gitdir]
            if mode != 'explicit_without_worktree':
                command += ['--work-tree', str(linked)]
            command += ['show', 'HEAD:large.txt']
            child_cwd = linked if mode == 'inherited_linked' else common if mode == 'common_cwd' else main_tree
            child = subprocess.Popen(command, cwd=child_cwd, env=env, stdin=subprocess.DEVNULL,
                                     stdout=subprocess.PIPE, stderr=subprocess.PIPE, bufsize=0,
                                     creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
            try:
                # Объект больше pipe: процесс не может закончить вывод до чтения.
                first = child.stdout.read(1)
                assert first and child.poll() is None, 'Git must still be alive'
                removed = subprocess.run(['git', 'worktree', 'remove', str(linked)], cwd=main_tree,
                                         env=env, capture_output=True, timeout=10)
                alive_after_remove = child.poll() is None
                output, error = child.communicate(timeout=5)
                result = dict(mode=mode, git_alive_after_remove=alive_after_remove,
                              remove_code=removed.returncode, remove_stderr=removed.stderr.decode(errors='replace'),
                              show_code=child.returncode, show_bytes=len(first + output), selected_head='linked')
                results.append(result)
                assert alive_after_remove and child.returncode == 0 and not error, result
                assert first + output == linked_bytes, 'Read must use linked HEAD, not inherited main cwd'
                expected = 255 if os.name == 'nt' and mode in ('with_C', 'inherited_linked') else 0
                assert removed.returncode == expected, result
                assert git('rev-parse', 'HEAD') == head
                assert (main_tree / 'large.txt').read_bytes() == main_bytes
                assert git('diff', '--cached') == b''
            finally:
                if child.poll() is None:
                    child.kill()
                    child.communicate(timeout=5)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(results, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(results))


if __name__ == '__main__':
    main()
