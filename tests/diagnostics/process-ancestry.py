"""Native controlled-snapshot proof; SDK и системные PPID не меняются."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def guard(fragment):
    before = '  DWORD pid = GetProcessId(proc);'
    after = before + '''
  FILETIME parent_start, exit_time, kernel_time, user_time;
  bool have_parent_start = GetProcessTimes(proc, &parent_start, &exit_time, &kernel_time, &user_time);'''
    assert fragment.count(before) == 1
    fragment = fragment.replace(before, after, 1)
    before = '            os_proc_tree_kill_rec(ph, sig);'
    after = '''            FILETIME child_start;
            // Не считать более старый процесс потомком переиспользованного PID.
            if (have_parent_start
                && GetProcessTimes(ph, &child_start, &exit_time, &kernel_time, &user_time)
                && CompareFileTime(&parent_start, &child_start) <= 0) {
              os_proc_tree_kill_rec(ph, sig);
            }'''
    assert fragment.count(before) == 1
    return fragment.replace(before, after, 1)


def run(source, out):
    assert os.name == 'nt', 'Windows-only native ABI probe'
    assert shutil.which('cl'), 'Запусти build-process-ancestry.ps1 с MSVC Build Tools'
    lock = json.loads((ROOT / 'scripts/sdk/windows.json').read_bytes())
    sdk_path = ROOT / '.tools/neovim/windows-x64'
    sdk_manifest = json.loads((sdk_path / 'forge-sdk.json').read_bytes())
    sdk_before = sha((sdk_path / 'bin/nvim.exe').read_bytes())
    assert sdk_before.upper() == sdk_manifest['BinarySHA256'].upper(), 'Установленный SDK уже не соответствует manifest'
    revision = subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip()
    assert revision == lock['SourceRevision'], 'Изменён pinned Neovim revision'
    original = subprocess.check_output(['git', '-C', str(source), 'show', revision + ':src/nvim/os/proc.c'])
    raw = (source / 'src/nvim/os/proc.c').read_bytes()
    text = raw.decode('utf-8').replace('\r\n', '\n')
    assert text == original.decode('utf-8').replace('\r\n', '\n'), 'proc.c уже изменён; source proof недействителен'
    start = text.index('static bool os_proc_tree_kill_rec(')
    fragment = text[start:text.index('\n#else', start)]
    template = (ROOT / 'tests/diagnostics/ancestry-harness.c').read_text('utf-8')
    assert template.count('/* FORGE_PROC_FRAGMENT */') == 1
    assert out.resolve().is_relative_to((ROOT / '.tests').resolve()), 'Build только внутри checkout .tests'
    out.mkdir(parents=True, exist_ok=False)
    metadata = {'source_revision': revision, 'source_sha256': sha(raw),
                'fragment_sha256': sha(fragment.encode()), 'harness_sha256': sha(template.encode()),
                'prototype_generator_sha256': sha(Path(__file__).read_bytes()),
                'mode': 'controlled-snapshot-real-workers', 'sdk_changed': False,
                'cases': [], 'limits': 'One stale snapshot edge is synthetic; native processes/times/signals are real. Docker caller unproven.'}
    for variant, body in [('upstream', fragment), ('guard', guard(fragment))]:
        generated = out / (variant + '.c')
        generated.write_text(template.replace('/* FORGE_PROC_FRAGMENT */', body), 'utf-8', newline='\n')
        executable = out / (variant + '.exe')
        compile_result = subprocess.run(['cl', '/nologo', '/std:c11', '/W4', '/WX', '/O2', '/utf-8',
            '/DUNICODE', '/D_UNICODE', '/Fe:' + str(executable), '/Fo:' + str(out / (variant + '.obj')),
            str(generated)], cwd=out, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=60)
        (out / (variant + '-build.txt')).write_text(compile_result.stdout + compile_result.stderr, 'utf-8')
        assert compile_result.returncode == 0, (out / (variant + '-build.txt')).read_text('utf-8')
        for case in ('valid', 'stale', 'child-query-failure', 'root-query-failure'):
            folder = out / (variant + '-' + case); folder.mkdir()
            result = subprocess.run([str(executable), case, str(folder / 'child.pid')],
                capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=15)
            (folder / 'stdout.txt').write_text(result.stdout, 'utf-8')
            (folder / 'stderr.txt').write_text(result.stderr, 'utf-8')
            assert result.returncode in (0, 1) and result.stdout.strip(), result.stderr
            report = json.loads(result.stdout)
            expected_red = variant == 'upstream' and case != 'valid'
            assert result.returncode == int(expected_red) and report['ok'] is not expected_red, (variant, case, report)
            assert report['outside_attempts'] == 0 and report['job_members_verified'] == 3
            assert report['scope_clean'] is True
            assert report['workers'][0]['creation_100ns'] < report['workers'][1]['creation_100ns'] <= report['workers'][2]['creation_100ns']
            report.update(variant=variant, case=case, expected_red=expected_red,
                          native_exit=result.returncode, generated_source_sha256=sha(generated.read_bytes()))
            (folder / 'report.json').write_text(json.dumps(report, indent=2) + '\n', 'utf-8')
            metadata['cases'].append(report)
            print(variant, case, 'expected RED' if expected_red else 'PASS', flush=True)
        metadata[variant + '_binary_sha256'] = sha(executable.read_bytes())
    assert sha((source / 'src/nvim/os/proc.c').read_bytes()) == metadata['source_sha256']
    sdk_after = sha((sdk_path / 'bin/nvim.exe').read_bytes())
    assert sdk_before == sdk_after, 'SDK изменился во время diagnostic run'
    metadata['installed_sdk_before_sha256'] = sdk_before
    metadata['installed_sdk_after_sha256'] = sdk_after
    (out / 'evidence.json').write_text(json.dumps(metadata, indent=2) + '\n', 'utf-8')
    print('evidence:', out / 'evidence.json')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=ROOT / '.tests/neovim-native/v0.12.2-src')
    parser.add_argument('--output', type=Path, default=ROOT / '.tests/ancestry-native' /
                        datetime.datetime.now().strftime('%Y%m%d-%H%M%S'))
    args = parser.parse_args()
    run(args.source.resolve(), args.output.resolve())
