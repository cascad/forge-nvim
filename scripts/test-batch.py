"""IDE-TEST-10: file batch/regression plan, reusing tests/run.lua for registry tests."""
import argparse
import datetime
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]

def environment():
    env = os.environ.copy()
    cleared = []
    for name in list(env):
        if name == 'FORGE_TEST_ID' or name.startswith('FORGE_') and name.endswith('_CASE'):
            cleared.append(name)
            del env[name]
    temporary = Path(env.get('FORGE_TEST_TMPDIR', str(ROOT / '.tests/tmp')))
    temporary.mkdir(parents=True, exist_ok=True)
    env.update(TEMP=str(temporary), TMP=str(temporary), TMPDIR=str(temporary),
               NVIM_LOG_FILE=str(temporary / 'batch-nvim.log'), PYTHONUTF8='1', PYTHONDONTWRITEBYTECODE='1')
    return env, sorted(cleared)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', choices=['quick','e2e','full','regression'], default='e2e')
    parser.add_argument('--nvim', default='nvim')
    parser.add_argument('--file', action='append', default=[])
    parser.add_argument('--plan', action='store_true')
    args = parser.parse_args()
    if args.mode == 'regression' and args.file:
        parser.error('regression is complete; use e2e --file for a selected block')
    nvim = shutil.which(args.nvim)
    if not nvim:
        parser.error('Prepared Neovim required: '+args.nvim)
    folder = ROOT / '.tests/batches' / str(time.time_ns())
    folder.mkdir(parents=True)
    env, cleared = environment()
    installers = sorted(path.relative_to(ROOT).as_posix() for path in ROOT.glob('tests/*.test.py'))
    request = folder / 'request.json'
    request.write_text(json.dumps({'mode':args.mode, 'files':args.file, 'installers':installers}), encoding='utf-8')
    registry = folder / 'registry.lua'
    planned = subprocess.run([nvim,'-u','NONE','-i','NONE','-l',str(ROOT/'scripts/test-plan.lua'),str(ROOT),str(request),str(registry)],
                             cwd=ROOT, env=env, capture_output=True, text=True, encoding='utf-8', timeout=30)
    if planned.returncode:
        sys.stderr.write(planned.stdout+planned.stderr)
        return planned.returncode
    selected = json.loads(planned.stdout)
    commands = []
    if selected['registry']:
        commands.append({'name':'registry', 'argv':[nvim,'-l','tests/run.lua',*selected['suites'],'--registry',str(registry)], 'timeout':None})
    for name in selected['installers']:
        commands.append({'name':name, 'argv':[sys.executable,'-B',name], 'timeout':1800})
    if not commands:
        parser.error('Empty test batch')
    env['FORGE_INSTALL_TEST_NVIM'] = nvim
    report = {'mode':args.mode, 'started_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'registry_files':[row['file'] for row in selected['registry']], 'installers':selected['installers'],
              'commands':commands, 'results':[], 'filters_cleared':cleared, 'report':str(folder/'report.json')}
    destination = folder / 'plan.json'
    destination.write_text(json.dumps(report,indent=2,ensure_ascii=False), encoding='utf-8')
    if args.plan:
        print(json.dumps(report,indent=2,ensure_ascii=False))
        return 0
    print(f"Batch: {len(selected['registry'])} registered files, {len(selected['installers'])} native Python suites",flush=True)
    print('Plan: '+str(destination),flush=True)
    started = time.monotonic()
    for index, command in enumerate(commands):
        log = folder / f'{index:02d}.log'
        before = time.monotonic()
        print('Running '+command['name'],flush=True)
        timed_out = False
        with log.open('wb') as stream:
            try:
                result = subprocess.run(command['argv'],cwd=ROOT,env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=command['timeout'])
                code = result.returncode
            except subprocess.TimeoutExpired:
                code, timed_out = 124, True
        elapsed = round(time.monotonic()-before,2)
        report['results'].append({'name':command['name'],'exit':code,'seconds':elapsed,'log':str(log),'timeout':timed_out})
        report['seconds'] = round(time.monotonic()-started,2)
        (folder/'report.json').write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf-8')
        print(f"{'PASS' if code==0 else 'FAIL'} {command['name']} ({elapsed}s); {log}",flush=True)
        if timed_out:
            break
    report['complete'] = len(report['results']) == len(commands)
    report['ok'] = report['complete'] and all(row['exit']==0 for row in report['results'])
    (folder/'report.json').write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf-8')
    print('Report: '+str(folder/'report.json'),flush=True)
    return 0 if report['ok'] else 1

if __name__ == '__main__':
    raise SystemExit(main())
