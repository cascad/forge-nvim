"""IDE-BOOT-42: real frontend/PTY/private Neovim/Mason process/native Go; fixture package."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('go_policy_ui',ROOT/'tests/install-ui.test.py')
ui=importlib.util.module_from_spec(spec);spec.loader.exec_module(ui);stand=ui.stand
SUFFIX='.exe' if stand.WINDOWS else ''


class GoToolchain(ui.UI):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.go=Path(ROOT/'.tests/dap-tools/go/bin/go.exe' if stand.WINDOWS else shutil.which('go')).resolve()
        assert cls.go.is_file(),'Prepared native Go required; never installed by this stand'
        deps=Path(os.environ.get('FORGE_E2E_DEPS',str(ROOT/'.tests/editor-deps')))
        cls.mason=deps/'lazy/mason.nvim';assert (cls.mason/'lua/mason-core/process.lua').is_file()
        for name in ['setup_readiness','native_tools']:
            shutil.copyfile(ROOT/f'nvim_forge/lua/forge/{name}.lua',cls.source/f'nvim_forge/lua/forge/{name}.lua')
        cls.stage=cls.source/'nvim_forge/scripts/setup-tools-production.lua'
        shutil.copyfile(ROOT/'nvim_forge/scripts/setup-stage.lua',cls.stage)
        with (cls.source/'nvim_forge/init.lua').open('a',encoding='utf8') as f:
            f.write("\nvim.g.fride_go_policy_initial={toolchain=vim.env.GOTOOLCHAIN,mason_loaded=package.loaded['mason-core.process']~=nil}\n")
        (cls.source/'nvim_forge/scripts/setup-stage.lua').write_text(stand.STAGE+'''
local record={stage=arg[1],toolchain=vim.env.GOTOOLCHAIN,policy=vim.env.FRIDE_SETUP_GO_TOOLCHAIN}
vim.fn.writefile({vim.json.encode(record)},vim.env.FRIDE_GO_POLICY_STAGES,'a')
if arg[1]=='tools' then dofile(vim.env.FRIDE_GO_POLICY_HELPER) end
''',encoding='utf8')
        cls.publish_source(cls.ui_digest)

    def prepare_go(self,name,go=None):
        base,env,target=self.prepare(name)
        self.assert_ok(self.run_process([str(go or self.go),'version'],dict(env,GOTOOLCHAIN='local'),base,'local-go'))
        project=base/'IDE tool with spaces';project.mkdir()
        (project/'go.mod').write_text('module example.invalid/fride-policy-tool\n\ngo 1.21\n')
        (project/'main.go').write_text('package main\nimport "runtime"\nfunc main(){ println(runtime.Version()) }\n')
        binary=base/'tools'/('fride-policy-tool'+SUFFIX);binary.parent.mkdir()
        config=base/'go-config.json'
        config.write_text(json.dumps({'mason':str(self.mason),'project':str(project),
            'bin':str(binary.parent),'binary':str(binary),'stage':str(self.stage),'report':str(base/'native-go.json')}))
        goenv=base/'go-env';goenv.write_text('GOTOOLCHAIN=path\n')
        env.update(PATH=str((go or self.go).parent)+os.pathsep+env.get('PATH',''),
            GOROOT='',GOWORK='off',GOENV=str(goenv),GOTOOLCHAIN='go1.99.0',
            GOMODCACHE=str(base/'gomod'),GOPATH=str(base/'gopath'),GOCACHE=str(stand.BASE/'go-cache'),
            GOPROXY=self.url+'/go-proxy',GOSUMDB='off',GOTOOLDIR='',GOFLAGS='',GOMAXPROCS='2',GOMEMLIMIT='512MiB',
            GOTELEMETRY='off',FRIDE_GO_POLICY_CONFIG=str(config),FRIDE_GO_POLICY_HELPER=str(ROOT/'tests/diagnostics/install-go-toolchain.lua'),
            FRIDE_GO_POLICY_STAGES=str(base/'stage-policy.jsonl'))
        # Poisoned parent values must not turn an absent CLI choice into consent.
        env['FRIDE_SETUP_GO_TOOLCHAIN']='auto'
        self.addCleanup(lambda:self.assertEqual(goenv.read_text(),'GOTOOLCHAIN=path\n'))
        self.addCleanup(lambda:self.assertEqual(env['GOTOOLCHAIN'],'go1.99.0'))
        return base,env,target,project,binary

    def arguments(self,base,target,choice=None,preview=False):
        args=self.binary_args(base,target,preview=preview,profile='default',components='go')+['--no-color']
        if choice is not None:args+=['--go-toolchain-download',choice]
        return args

    def assert_native(self,base,binary,policy):
        report=json.loads((base/'native-go.json').read_text())
        self.assertTrue(report['success']);self.assertEqual((report['code'],report['signal']),(0,0))
        self.assertEqual(report['captured']['GOTOOLCHAIN'],policy)
        self.assertEqual(report['captured']['GOPROXY'],self.url+'/go-proxy')
        self.assertEqual(report['captured']['GOSUMDB'],'off')
        self.assertEqual(report['initial'],{'toolchain':policy,'mason_loaded':False})
        stages=[json.loads(s) for s in (base/'stage-policy.jsonl').read_text().splitlines()]
        self.assertEqual([(s['stage'],s['toolchain']) for s in stages],[('plugins','local'),('parsers','local'),('tools',policy)])
        self.assert_ok(self.run_process([str(binary)],os.environ.copy(),base,'native-tool'))

    def test_go_01_cli_plan_preview_validation(self):
        for choice,wanted in [(None,False),('deny',False),('allow',True)]:
            base,env,target=self.prepare('go-plan-'+str(choice))
            before=list(self.requests)
            result=self.run_process(self.arguments(base,target,choice,preview=True)+['--print-plan'],env,base,'plan')
            self.assert_ok(result);self.assertEqual(json.loads(result.stdout)['go_toolchain_download'],wanted)
            self.assertFalse(target.exists());self.assertFalse((base/'stages.txt').exists());self.assertEqual(self.requests,before)
        base,env,target=self.prepare('go-invalid')
        result=self.run_process(self.arguments(base,target,'maybe'),env,base,'invalid')
        self.assertNotEqual(result.returncode,0);self.assertIn('allow',result.stderr);self.assertFalse(target.exists())
        base,env,target,project,binary=self.prepare_go('go-check-preview')
        before=len(self.requests)
        result=self.run_process(self.arguments(base,target,'allow')+['--check-sdks'],env,base,'check-only')
        self.assert_ok(result);self.assertEqual(json.loads(result.stdout)['sdks'][0]['status'],'ready')
        self.assert_ok(self.run_process(self.arguments(base,target,'allow',preview=True),env,base,'preview-only'))
        self.assertFalse((base/'stages.txt').exists());self.assertFalse((base/'native-go.json').exists())
        self.assertFalse(target.exists());self.assertFalse(any('golang.org/toolchain' in str(r) for r in self.requests[before:]))

    def test_go_02_headless_default_denies_parent_optin(self):
        base,env,target,project,binary=self.prepare_go('go-default')
        result=self.run_process(self.arguments(base,target),env,base,'default');self.assert_ok(result)
        self.assertFalse(json.loads((base/'result.json').read_text())['go_toolchain_download'])
        self.assert_native(base,binary,'local')

    def test_go_03_allow_reuses_native_sdk(self):
        base,env,target,project,binary=self.prepare_go('go-allow')
        result=self.run_process(self.arguments(base,target,'allow'),env,base,'allow');self.assert_ok(result)
        self.assertTrue(json.loads((base/'result.json').read_text())['go_toolchain_download'])
        self.assert_native(base,binary,'auto')
        self.assertFalse(list((base/'gomod').glob('golang.org/toolchain*')))

    def test_go_04_old_native_go_builds_with_explicit_allow(self):
        old=shutil.which('go')
        if not old or Path(old).resolve()==self.go:self.skipTest('Second older native Go is not prepared on this OS')
        base,env,target,project,binary=self.prepare_go('go-old',Path(old))
        result=self.run_process(self.arguments(base,target,'allow'),env,base,'old');self.assert_ok(result)
        self.assert_native(base,binary,'auto')

    def test_go_05_download_failure_retains_kit_and_native_reason(self):
        base,env,target,project,binary=self.prepare_go('go-offline')
        self.assert_ok(self.run_process(self.arguments(base,target,'deny'),env,base,'before'))
        marker=(target/'.forge-install.json').read_bytes();runtime=(target/'runtime/nvim.sha256').read_bytes()
        (base/'result.json').unlink()  # Each invocation gets its own create_new report.
        (project/'go.mod').write_text('module example.invalid/fride-policy-tool\n\ngo 1.99.0\n')
        before=len(self.requests)
        result=self.run_process(self.arguments(base,target,'allow'),env,base,'offline')
        self.assertNotEqual(result.returncode,0);self.assertEqual((target/'.forge-install.json').read_bytes(),marker)
        self.assertEqual((target/'runtime/nvim.sha256').read_bytes(),runtime)
        report=json.loads((base/'native-go.json').read_text());self.assertFalse(report['success'])
        self.assertIn('go1.99.0',report['stderr']);self.assertIn('Native Go build failed',(target/'log/setup-tools.log').read_text())
        self.assertTrue(any('golang.org/toolchain' in str(r) for r in self.requests[before:]))

    def test_go_06_deny_does_not_attempt_toolchain_download(self):
        base,env,target,project,binary=self.prepare_go('go-no-fetch')
        (project/'go.mod').write_text('module example.invalid/fride-policy-tool\n\ngo 1.99.0\n')
        before=len(self.requests)
        result=self.run_process(self.arguments(base,target,'deny'),env,base,'deny')
        self.assertNotEqual(result.returncode,0);self.assertFalse(json.loads((target/'.forge-install.json').read_text())['ready'])
        self.assertFalse((target/'bin').exists());self.assertFalse((target/'runtime').exists())
        report=json.loads((base/'native-go.json').read_text());self.assertIn('GOTOOLCHAIN=local',report['stderr'])
        self.assertFalse(any('golang.org/toolchain' in str(r) for r in self.requests[before:]))

    def test_go_07_pty_allow(self):
        base,env,target,project,binary=self.prepare_go('go-pty-allow')
        self.pty(base,env,self.arguments(base,target),'go-policy-allow');self.assert_native(base,binary,'auto')

    def test_go_08_pty_default_no(self):
        base,env,target,project,binary=self.prepare_go('go-pty-no')
        self.pty(base,env,self.arguments(base,target),'go-policy-deny');self.assert_native(base,binary,'local')

    def test_go_09_pty_cancel(self):
        base,env,target,project,binary=self.prepare_go('go-pty-cancel')
        self.assert_ok(self.run_process(self.arguments(base,target,'deny'),env,base,'before'))
        marker=(target/'.forge-install.json').read_bytes();trace=(base/'stages.txt').read_bytes()
        env['FORGE_UI_EXPECTED_EXIT']='130'
        self.pty(base,env,self.arguments(base,target),'go-policy-cancel')
        self.assertEqual((target/'.forge-install.json').read_bytes(),marker);self.assertEqual((base/'stages.txt').read_bytes(),trace)

    def test_go_10_root_entry_forwards_choice(self):
        base,env,target,project,binary=self.prepare_go('go-root')
        self.assert_ok(self.root_entry(base,env,target,components='go',go_toolchain_download='allow'))
        self.assert_native(base,binary,'auto')

    def test_go_11_late_mason_policy_is_rejected(self):
        base,env,target,project,binary=self.prepare_go('go-late')
        config=Path(env['FRIDE_GO_POLICY_CONFIG']);data=json.loads(config.read_text());data['late_policy']=True
        config.write_text(json.dumps(data))
        result=self.run_process(self.arguments(base,target,'allow'),env,base,'late')
        self.assertNotEqual(result.returncode,0)
        self.assertIn('before Mason initialization',(target/'log/setup-tools.log').read_text())
        self.assertFalse(binary.exists());self.assertFalse((base/'native-go.json').exists())
        self.assertFalse(json.loads((target/'.forge-install.json').read_text())['ready'])


if __name__=='__main__':
    print('work:',stand.BASE,'artifacts:',stand.ARTIFACTS,flush=True)
    names=sys.argv[1:] or [n for n in GoToolchain.__dict__ if n.startswith('test_go_')]
    result=unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(GoToolchain(n) for n in names))
    (stand.BASE/'go-policy-summary.json').write_text(json.dumps({'tests':result.testsRun,'failures':len(result.failures),
        'errors':len(result.errors),'skipped':len(result.skipped),'platform':stand.PLATFORM},indent=2))
    if stand.BASE!=stand.ARTIFACTS:
        def ignore(directory,names):return [n for n in names if n in ('runtime','prepared','.runtime-cache','.ui-cache','go-cache','gomod','gopath') or n.endswith(('.zip','.tar.gz')) or (Path(directory)/n).is_symlink()]
        shutil.copytree(stand.BASE,stand.ARTIFACTS,ignore=ignore)
    raise SystemExit(0 if result.wasSuccessful() else 1)
