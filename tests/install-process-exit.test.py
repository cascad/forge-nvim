"""IDE-BOOT-44: real private installer, child exits/signals and publication.

Only fixture children terminate their own PID. No host process control.
Config/stages are fixtures; this is not full Default acceptance.
"""
import importlib.util
import json
import os
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('process_exit_stand',ROOT/'tests/install-isolation.test.py')
stand=importlib.util.module_from_spec(spec);spec.loader.exec_module(stand)
STAGES=('plugins','parsers','tools')
SIGNAL_STAGE=r'''
vim.fn.writefile({arg[1]},vim.env.FORGE_STAGE_TRACE,'a')
if vim.env.FORGE_SIGNAL_STAGE==arg[1] then
  io.stdout:write('SIGNAL_STAGE '..arg[1]..'\n');io.stdout:flush()
  vim.uv.kill(vim.fn.getpid(),9);vim.wait(1000)
end
if vim.env.FORGE_FAIL_STAGE==arg[1] then vim.cmd('cquit 13') end
'''


class ProcessExit(stand.Isolation):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        (cls.source/'nvim_forge/scripts/setup-stage.lua').write_text(SIGNAL_STAGE,encoding='utf-8')

    def owned(self,target):
        return {name:stand.snapshot(target/name) for name in ('bin','config','runtime')} | {
            'owner':(target/'.forge-install.json').read_bytes()}

    def rejection(self,stage,repeat=False,probe=False,signal=True):
        base,env,target=self.prepare(('signal-' if signal else 'nonzero-')+stage+('-repeat' if repeat else '-first'))
        directory=base/'commands';env['PATH']=str(directory)+os.pathsep+env['PATH']
        if repeat:
            self.assert_ok(self.install(base,env,target,command_dir=directory))
            before=self.owned(target);registered=stand.snapshot(directory)
            (base/'stages.txt').unlink()
        if probe:
            manifest=self.runtime/'forge-runtime.json';raw=manifest.read_bytes()
            self.addCleanup(manifest.write_bytes,raw)
            data=json.loads(raw)
            command="lua io.stdout:write('SIGNAL_PROBE\\n');io.stdout:flush();vim.uv.kill(vim.fn.getpid(),9);vim.wait(1000)"
            data['probes']=[[data['nvim'],'--headless','-u','NONE','-i','NONE','--cmd',command]]
            manifest.write_text(json.dumps(data),encoding='utf-8')
        else:
            env['FORGE_SIGNAL_STAGE' if signal else 'FORGE_FAIL_STAGE']=stage
        result=self.install(base,env,target,command_dir=directory)
        self.assertNotEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertIn('signal='+('9' if signal else '0'),result.stderr)
        self.assertIn('Command failed (0)' if signal else 'Command failed (13)',result.stderr)
        log=target/'log'/('probe-1.log' if probe else 'setup-'+stage+'.log')
        self.assertIn(log.as_posix(),result.stderr.replace('\\','/'))
        if signal:self.assertIn('SIGNAL_PROBE' if probe else 'SIGNAL_STAGE '+stage,log.read_text(encoding='utf-8'))
        trace=base/'stages.txt'
        self.assertEqual(trace.read_text().splitlines() if trace.exists() else [],[] if probe else list(STAGES[:STAGES.index(stage)+1]))
        if repeat:
            self.assertEqual(self.owned(target),before)
            self.assertEqual(stand.snapshot(directory),registered)
            self.assert_ok(self.launch(base,env,target))
        else:
            self.assertFalse((target/'bin/fride').exists())
            self.assertFalse(json.loads((target/'.forge-install.json').read_text())['ready'])
            self.assertFalse(directory.exists())

    def test_exit_success_install_and_repeat(self):
        base,env,target=self.prepare('exit-success')
        self.assert_ok(self.install(base,env,target));self.assert_ok(self.launch(base,env,target))
        self.assert_ok(self.install(base,env,target));self.assert_ok(self.launch(base,env,target))
        self.assertEqual((base/'stages.txt').read_text().splitlines(),list(STAGES)*2)
        self.assertTrue(json.loads((target/'.forge-install.json').read_text())['ready'])


def stage_case(stage,repeat=False,probe=False,signal=True):
    def case(self):self.rejection(stage,repeat,probe,signal)
    return unittest.skipIf(stand.WINDOWS,'POSIX SIGKILL; native Windows exit controls below')(case) if signal else case


for stage in STAGES:
    for repeat in (False,True):
        setattr(ProcessExit,'test_exit_signal_'+stage+('_repeat' if repeat else '_first'),stage_case(stage,repeat))
    setattr(ProcessExit,'test_exit_nonzero_'+stage,stage_case(stage,signal=False))
for repeat in (False,True):
    setattr(ProcessExit,'test_exit_signal_probe'+('_repeat' if repeat else '_first'),stage_case('probe',repeat,probe=True))


if __name__=='__main__':
    names=sys.argv[1:] or sorted(name for name in ProcessExit.__dict__ if name.startswith('test_exit_'))
    suite=unittest.TestSuite(ProcessExit(name) for name in names)
    result=unittest.TextTestRunner(verbosity=2).run(suite)
    if not stand.WINDOWS:
        import shutil
        if stand.BASE!=stand.ARTIFACTS:
            def ignore(directory,names):
                return [name for name in names if name in ('runtime','prepared','.runtime-cache') or name.endswith(('.zip','.tar.gz')) or (Path(directory)/name).is_symlink() or not ((Path(directory)/name).is_file() or (Path(directory)/name).is_dir())]
            shutil.copytree(stand.BASE,stand.ARTIFACTS,ignore=ignore)
    raise SystemExit(0 if result.wasSuccessful() else 1)
