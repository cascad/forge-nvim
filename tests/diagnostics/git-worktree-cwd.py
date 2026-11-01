"""IDE-034: обычные процессы Git с cwd внутри/снаружи удаляемого worktree."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time


def main():
    root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=root / '.tests/git-worktree-cwd.json')
    args = parser.parse_args()
    results = []
    base_dir = root / '.tests/tmp' if os.name == 'nt' else None
    if base_dir:
        base_dir.mkdir(parents=True, exist_ok=True)
    for kind in ('git_cwd_inside', 'git_cwd_outside', 'other_process_cwd_inside'):
        with tempfile.TemporaryDirectory(prefix='git-remove-cwd-', dir=base_dir) as folder:
            base = Path(folder)
            project, linked = base / 'project', base / 'linked with space'
            env = dict(os.environ, GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL='NUL' if os.name == 'nt' else '/dev/null',
                       GIT_TERMINAL_PROMPT='0', GIT_CEILING_DIRECTORIES=str(base))

            def git(cwd, *argv):
                return subprocess.run(['git', *argv], cwd=cwd, env=env, capture_output=True,
                                      text=True, errors='replace', timeout=10)

            project.mkdir()
            for argv in (('init',), ('config', 'user.name', 'Fixture'), ('config', 'user.email', 'fixture@example.invalid'),
                         ('config', 'commit.gpgsign', 'false'), ('config', 'core.hooksPath', str(base / 'no-hooks'))):
                r = git(project, *argv)
                assert r.returncode == 0, r.stderr
            (project / 'file.txt').write_text('fixture\n', encoding='utf-8')
            for argv in (('add', '.'), ('commit', '-m', 'fixture'), ('worktree', 'add', '-b', 'linked', str(linked))):
                r = git(project, *argv)
                assert r.returncode == 0, r.stderr
            holder = None
            try:
                if kind == 'other_process_cwd_inside':
                    ready = base / 'ready'
                    holder = subprocess.Popen([sys.executable, '-B', '-c',
                        'import pathlib,sys;pathlib.Path(sys.argv[1]).write_text("ready");sys.stdin.readline()', str(ready)],
                        cwd=linked, env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                        creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
                    deadline = time.monotonic() + 5
                    while not ready.exists() and time.monotonic() < deadline:
                        time.sleep(.01)
                    assert ready.exists(), 'Процесс с cwd внутри worktree не запустился'
                r = git(linked if kind == 'git_cwd_inside' else project, 'worktree', 'remove', str(linked))
                result = dict(kind=kind, returncode=r.returncode, stdout=r.stdout, stderr=r.stderr,
                              directory_exists=linked.exists(),
                              remaining=[p.name for p in linked.iterdir()] if linked.exists() else [])
                results.append(result)
                if kind == 'git_cwd_outside' or os.name != 'nt':
                    assert r.returncode == 0 and not linked.exists(), result
                else:
                    assert r.returncode != 0 and linked.exists() and not result['remaining'], result
            finally:
                if holder:
                    holder.communicate(input=b'continue\n', timeout=5)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(results, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(results))


if __name__ == '__main__':
    main()
